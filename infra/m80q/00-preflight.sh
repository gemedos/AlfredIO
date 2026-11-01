#!/usr/bin/env bash
# Paso 0: comprobaciones previas. SÓLO LEE, no cambia nada.
#   sudo ./00-preflight.sh
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_root

fails=0
ok()   { printf '  \033[32mOK\033[0m    %s\n' "$*"; }
bad()  { printf '  \033[31mFALLO\033[0m %s\n' "$*"; fails=$((fails + 1)); }
note() { printf '  \033[33mAVISO\033[0m %s\n' "$*"; }

log "Sistema"
# shellcheck disable=SC1091
. /etc/os-release
if [[ "$ID" == "debian" && "$VERSION_ID" == "13" ]]; then ok "$PRETTY_NAME"; else bad "Se esperaba Debian 13, hay $PRETTY_NAME"; fi
if [[ -d /sys/firmware/efi ]]; then ok "Arranque UEFI"; else bad "No arranca en modo UEFI (necesario para TPM + Secure Boot)"; fi
if systemctl list-unit-files --type=service | grep -q '^gdm\|^lightdm\|^sddm'; then
    note "Hay un gestor de escritorio instalado; no hace falta en un servidor"
fi
grep -m1 'model name' /proc/cpuinfo | sed 's/.*: /  CPU: /'
awk '/MemTotal/ {printf "  RAM: %.1f GB\n", $2/1024/1024}' /proc/meminfo

log "Secure Boot y TPM"
sb_var=$(compgen -G '/sys/firmware/efi/efivars/SecureBoot-*' | head -1 || true)
if [[ -n "$sb_var" && "$(od -An -t u1 -j4 -N1 "$sb_var" | tr -d ' ')" == "1" ]]; then
    ok "Secure Boot activado"
else
    note "Secure Boot desactivado: el TPM funcionará, pero protege menos (ver docs/INSTALAR_DEBIAN.md)"
fi
if [[ -e /dev/tpmrm0 ]]; then
    ok "TPM 2.0 presente (/dev/tpmrm0)"
    [[ -r /sys/class/tpm/tpm0/tpm_version_major ]] && \
        echo "  versión TPM: $(cat /sys/class/tpm/tpm0/tpm_version_major)"
else
    bad "No hay TPM 2.0 visible: actívalo en la BIOS (Security → Security Chip)"
fi

log "Discos"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS | sed 's/^/  /'
root_src=$(findmnt -no SOURCE /)
root_disk=$(lsblk -no PKNAME "$root_src")
candidates=()
while read -r name type fstype; do
    [[ "$type" == "part" && -z "$fstype" ]] && candidates+=("/dev/$name")
done < <(lsblk -lnpo NAME,TYPE,FSTYPE "/dev/$root_disk" | sed 's|/dev/||')
if ((${#candidates[@]} == 1)); then
    ok "Partición de datos candidata (sin formato): ${candidates[0]}"
    echo "     → la usarás así: sudo ./40-data-luks.sh ${candidates[0]}"
elif ((${#candidates[@]} == 0)); then
    if [[ -e /dev/mapper/alfred-data ]]; then ok "La partición de datos ya está cifrada y abierta"
    else bad "No hay ninguna partición sin formato para los datos (ver paso 7 de docs/INSTALAR_DEBIAN.md)"; fi
else
    note "Hay varias particiones sin formato: ${candidates[*]}. Elige la de datos con cuidado."
fi
if swapon --show --noheadings | grep -q .; then note "Hay swap en disco (sin cifrar). Recomendado quitarla: la sustituye zram."; fi

log "Red"
if ip route show default | grep -q .; then ok "Ruta por defecto: $(ip route show default | head -1)"; else bad "Sin ruta por defecto"; fi
if getent hosts deb.debian.org >/dev/null; then ok "DNS funciona"; else bad "No resuelve deb.debian.org"; fi
ip -4 -o addr show scope global | awk '{print "  IP: " $2 " " $4}'

log "Acceso"
admin="${SUDO_USER:-}"
if [[ -n "$admin" && -s "/home/$admin/.ssh/authorized_keys" ]]; then
    ok "$admin tiene $(grep -c '^ssh-\|^ecdsa-\|^sk-' "/home/$admin/.ssh/authorized_keys") clave(s) SSH autorizadas"
else
    bad "${admin:-tu usuario} no tiene ~/.ssh/authorized_keys: copia tu clave antes del paso 30 (ver README)"
fi

echo
if ((fails > 0)); then
    die "$fails comprobación(es) fallida(s). Corrígelas antes de seguir."
fi
log "Todo listo para 10-base.sh"
