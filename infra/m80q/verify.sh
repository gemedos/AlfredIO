#!/usr/bin/env bash
# Verificación de la Fase 0 en un solo comando. Sólo lee; no cambia nada.
#   sudo ./verify.sh
# Sale con código 0 si no hay ningún FALLO (los AVISO no cuentan: suelen ser hardware pendiente).
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
set +e  # queremos ver todas las comprobaciones, no parar en la primera
require_root
load_config

fails=0 warns=0
ok()   { printf '  \033[32mOK\033[0m     %s\n' "$*"; }
bad()  { printf '  \033[31mFALLO\033[0m  %s\n' "$*"; fails=$((fails + 1)); }
note() { printf '  \033[33mAVISO\033[0m  %s\n' "$*"; warns=$((warns + 1)); }
info() { printf '  \033[36mINFO\033[0m   %s\n' "$*"; }
check() { local msg="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$msg"; else bad "$msg"; fi; }
age_hours() { local f="$1"; [[ -r "$f" ]] || { echo 9999; return; }; echo $(( ($(date +%s) - $(cat "$f")) / 3600 )); }

log "Sistema"
check "Debian 13" grep -q '^VERSION_ID="13"' /etc/os-release
check "Suspensión bloqueada (sleep.target enmascarado)" test "$(systemctl is-enabled sleep.target 2>/dev/null)" = masked
check "Actualizaciones automáticas activas" systemctl is-enabled unattended-upgrades.service
check "Reinicio automático tras actualizaciones configurado" sh -c "apt-config dump | grep -q 'Automatic-Reboot \"true\"'"
check "Zona horaria Europe/Madrid" test "$(timedatectl show -p Timezone --value)" = Europe/Madrid
check "Hora sincronizada (NTP)" test "$(timedatectl show -p NTPSynchronized --value)" = yes
check "Logs persistentes" test -d /var/log/journal
if swapon --show=NAME --noheadings | grep -qv zram; then bad "Hay swap en disco sin cifrar"; else ok "Sin swap en disco (zram)"; fi

log "Tailscale y SSH"
ts_state=$(tailscale status --json 2>/dev/null | jq -r '.BackendState')
if [[ "$ts_state" == "Running" ]]; then ok "Tailscale conectado ($(tailscale ip -4))"; else bad "Tailscale no conectado ($ts_state)"; fi
sshd_cfg=$(sshd -T 2>/dev/null)
check "SSH: sin contraseñas" grep -qx 'passwordauthentication no' <<<"$sshd_cfg"
check "SSH: sin teclado interactivo" grep -qx 'kbdinteractiveauthentication no' <<<"$sshd_cfg"
check "SSH: sin root" grep -qx 'permitrootlogin no' <<<"$sshd_cfg"
check "SSH: sólo $ADMIN_USER" grep -qx "allowusers $ADMIN_USER" <<<"$sshd_cfg"

log "Cortafuegos"
ufw_out=$(ufw status verbose 2>/dev/null)
check "UFW activo" grep -q '^Status: active' <<<"$ufw_out"
check "UFW deniega entrada por defecto" grep -q 'Default: deny (incoming)' <<<"$ufw_out"
open_rules=$(ufw status | grep -E 'ALLOW' | grep -v 'on tailscale0')
if [[ -z "$open_rules" ]]; then ok "Ninguna regla permite entrar fuera de tailscale0"; else bad "Reglas abiertas fuera de Tailscale: $open_rules"; fi
check "fail2ban vigilando SSH" fail2ban-client status sshd
# Procesos escuchando fuera de loopback y de la tailnet (UFW los bloquea igualmente; aquí se ven).
while read -r proto addrport; do
    addr="${addrport%:*}" port="${addrport##*:}"
    addr="${addr#[}" addr="${addr%]}" addr="${addr%%%*}"
    case "$addr" in 127.*|::1) continue ;; esac
    is_tailnet_ip "$addr" && continue
    case "$proto/$port" in tcp/22|udp/41641|udp/68|udp/546|udp/5353) continue ;; esac
    note "Escucha en $proto $addrport (bloqueado por UFW, pero revisa si hace falta)"
done < <(ss -Hlntu | awk '{print $1, $5}')
if iptables -S ts-input 2>/dev/null | grep -q -- '-i tailscale0 -j ACCEPT'; then
    info "Tailscale acepta todo lo que llega por tailscale0 antes que UFW: dentro de la tailnet el filtro efectivo es la ACL de Tailscale (sólo puerto 22)."
fi

log "Partición de datos cifrada"
if mountpoint -q "$DATA_MOUNT" && [[ "$(findmnt -no SOURCE "$DATA_MOUNT")" == "/dev/mapper/alfred-data" ]]; then
    ok "$DATA_MOUNT montada desde LUKS"
else
    bad "$DATA_MOUNT no está montada desde /dev/mapper/alfred-data"
fi
if [[ -n "${DATA_LUKS_UUID:-}" ]]; then
    dump=$(cryptsetup luksDump "/dev/disk/by-uuid/$DATA_LUKS_UUID" 2>/dev/null)
    check "Desbloqueo por TPM 2.0 configurado" grep -q 'systemd-tpm2' <<<"$dump"
    check "Clave de recuperación configurada" grep -q 'systemd-recovery' <<<"$dump"
    slots=$(grep -cE '^\s+[0-9]+: luks2' <<<"$dump")
    if ((slots == 2)); then ok "Sólo 2 huecos de clave (TPM + recuperación)"; else note "$slots huecos de clave (esperados 2)"; fi
else
    bad "DATA_LUKS_UUID vacío (¿se ejecutó 40-data-luks.sh?)"
fi
check "Aviso de desbloqueo fallido programado" systemctl is-enabled alfred-data-check.timer

log "Docker rootless"
if systemctl is-active --quiet docker.service; then bad "El Docker con root del sistema está activo"; else ok "Docker con root apagado"; fi
check "Linger activo para $ALFRED_USER" grep -qx 'Linger=yes' <<<"$(loginctl show-user "$ALFRED_USER" -p Linger 2>/dev/null)"
uid=$(id -u "$ALFRED_USER" 2>/dev/null)
dinfo=$(run_as_user "$ALFRED_USER" env DOCKER_HOST="unix:///run/user/$uid/docker.sock" \
    docker info --format '{{.SecurityOptions}} {{.DockerRootDir}}' 2>/dev/null)
check "Docker de $ALFRED_USER en modo rootless" grep -q 'rootless' <<<"$dinfo"
check "Datos de Docker en la partición cifrada" grep -q "$DATA_MOUNT/docker" <<<"$dinfo"

log "Copias de seguridad"
if [[ -z "${BACKUP_DISK_UUID:-}" ]]; then
    note "Copias pendientes: falta el disco USB (BACKUP_DISK_UUID vacío)"
else
    check "Copia diaria programada" systemctl is-enabled alfred-backup.timer
    h=$(age_hours /var/lib/alfred/last-backup-ok)
    if ((h <= 26)); then ok "Última copia correcta hace ${h} h"; else bad "Última copia correcta hace más de 26 h"; fi
    h=$(age_hours /var/lib/alfred/last-restore-test-ok)
    if ((h <= 24 * 32)); then ok "Prueba de restauración correcta hace ${h} h"; else bad "Sin prueba de restauración en el último mes"; fi
fi

log "Vigilancia y avisos"
check "Secretos de avisos con permisos 600" test "$(stat -c %a "$ALFRED_ETC/secrets.env" 2>/dev/null)" = 600
if grep -qE '^TELEGRAM_BOT_TOKEN=.+' "$ALFRED_ETC/secrets.env" 2>/dev/null \
    && grep -qE '^TELEGRAM_CHAT_ID=.+' "$ALFRED_ETC/secrets.env"; then
    ok "Bot de alertas de Telegram configurado"
else
    bad "Faltan TELEGRAM_BOT_TOKEN o TELEGRAM_CHAT_ID en $ALFRED_ETC/secrets.env"
fi
check "Vigilancia de temperatura activa" systemctl is-active alfred-temp-watch.timer
temp=$(ALFRED_STATE_DIR=$(mktemp -d) ALFRED_NOTIFY=true /usr/local/sbin/alfred-temp-watch 2>/dev/null)
if [[ -n "$temp" ]]; then ok "Lectura actual: $temp"; else bad "No se lee la temperatura"; fi
if [[ -z "${SHELLY_HOST:-}" ]]; then
    note "Vigilancia de consumo pendiente: falta el Shelly (SHELLY_HOST vacío)"
else
    check "Vigilancia de consumo activa" systemctl is-active alfred-power-watch.timer
    p=$(/usr/local/sbin/alfred-power-watch --read 2>/dev/null)
    if [[ -n "$p" ]]; then ok "Consumo actual: $p"; else bad "No se lee el Shelly"; fi
fi

log "Arranque seguro"
sb_var=$(compgen -G '/sys/firmware/efi/efivars/SecureBoot-*' | head -1)
if [[ -n "$sb_var" && "$(od -An -t u1 -j4 -N1 "$sb_var" | tr -d ' ')" == "1" ]]; then ok "Secure Boot activado"; else note "Secure Boot desactivado"; fi

echo
if ((fails == 0)); then
    log "RESULTADO: OK ($warns aviso(s))"
    exit 0
fi
log "RESULTADO: $fails FALLO(S), $warns aviso(s)"
exit 1
