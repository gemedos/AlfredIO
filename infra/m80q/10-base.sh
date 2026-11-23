#!/usr/bin/env bash
# Paso 1: sistema base. Se puede repetir sin problemas.
#   sudo ./10-base.sh
# - Actualiza Debian y activa actualizaciones de seguridad automáticas (reinicio 04:30 si hace falta).
# - Bloquea la suspensión (CLAUDE.md §3: no suspender el M80q).
# - Hora por NTP, zona Europe/Madrid, logs persistentes con límite, swap en RAM (zram).
# - Crea /etc/alfred (configuración y secretos) e instala alfred-notify.
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_root
require_debian13

log "Configuración en $ALFRED_ETC"
install -d -o root -g root -m 0750 "$ALFRED_ETC"
install -d -o root -g root -m 0750 /var/lib/alfred
if [[ ! -e "$ALFRED_CONFIG" ]]; then
    install -o root -g root -m 0640 "$M80Q_DIR/config/m80q.env.example" "$ALFRED_CONFIG"
    log "Creado $ALFRED_CONFIG"
fi
if [[ ! -e "$ALFRED_ETC/secrets.env" ]]; then
    install -o root -g root -m 0600 "$M80Q_DIR/config/secrets.env.example" "$ALFRED_ETC/secrets.env"
    log "Creado $ALFRED_ETC/secrets.env (vacío: rellénalo tú)"
fi
chmod 0600 "$ALFRED_ETC/secrets.env"
load_config
if [[ -z "${ADMIN_USER:-}" ]]; then
    [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]] || die "Define ADMIN_USER en $ALFRED_CONFIG"
    set_config ADMIN_USER "$SUDO_USER"
    log "ADMIN_USER=$SUDO_USER"
fi

log "Actualizando el sistema (puede tardar)"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y full-upgrade
apt_install unattended-upgrades apt-listchanges ca-certificates curl gnupg jq \
    lm-sensors systemd-timesyncd systemd-zram-generator e2fsprogs

log "Actualizaciones de seguridad automáticas"
install_file apt/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades
install_file apt/52alfred-unattended-upgrades /etc/apt/apt.conf.d/52alfred-unattended-upgrades
systemctl enable --now unattended-upgrades.service apt-daily.timer apt-daily-upgrade.timer

log "Bloqueando suspensión e hibernación"
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

log "Hora y zona horaria"
timedatectl set-timezone Europe/Madrid
timedatectl set-ntp true

log "Logs persistentes (máx. 500 MB, 3 meses)"
install_file journald/alfred.conf /etc/systemd/journald.conf.d/alfred.conf
systemctl restart systemd-journald

log "Swap comprimida en RAM (zram)"
install_file zram-generator.conf /etc/systemd/zram-generator.conf
systemctl daemon-reload
systemctl start systemd-zram-setup@zram0.service || warn "zram se activará en el próximo arranque"
if swapon --show=NAME --noheadings | grep -qv zram; then
    warn "Hay swap en disco sin cifrar. Quítala de /etc/fstab y ejecuta 'swapoff -a' + reinicio."
fi

log "Sensores de temperatura"
sensors-detect --auto >/dev/null 2>&1 || true
sensors 2>/dev/null | grep -E 'Package id 0|Core 0' | sed 's/^/  /' || warn "No se leen sensores todavía"

log "Notificador de Telegram"
install_bin alfred-notify

log "Hecho. Siguiente: rellena $ALFRED_ETC/secrets.env y prueba: sudo alfred-notify 'prueba'"
