#!/usr/bin/env bash
# Paso 6: copias cifradas con restic al disco USB externo + prueba de restauración.
#   sudo ./60-backup.sh
# ANTES: conecta el disco USB, dale formato ext4 y pon su UUID en BACKUP_DISK_UUID
# (instrucciones en README.md, sección "Disco de copias").
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_root
require_debian13
load_config

mountpoint -q "$DATA_MOUNT" || die "$DATA_MOUNT no está montada. Ejecuta antes 40-data-luks.sh."
[[ -n "${BACKUP_DISK_UUID:-}" ]] || die "Pon el UUID del disco USB en BACKUP_DISK_UUID ($ALFRED_CONFIG). Ver README."
[[ -e "/dev/disk/by-uuid/$BACKUP_DISK_UUID" ]] || die "No encuentro el disco $BACKUP_DISK_UUID. ¿Está conectado?"

apt_install restic

log "Montaje del disco de copias (sólo durante la copia)"
mkdir -p "$BACKUP_MOUNT"
sed -i "\|[[:space:]]${BACKUP_MOUNT}[[:space:]]|d" /etc/fstab
echo "UUID=$BACKUP_DISK_UUID $BACKUP_MOUNT auto noauto,nofail,noatime,nodev,nosuid,noexec 0 0" >>/etc/fstab
systemctl daemon-reload

pass="$DATA_MOUNT/secrets/restic.pass"
if [[ ! -s "$pass" ]]; then
    log "Generando la contraseña del repositorio de copias"
    (umask 077; head -c 48 /dev/urandom | base64 -w0 >"$pass")
    warn "Guarda una copia de esta contraseña FUERA del M80q (gestor de contraseñas)."
    warn "Sin ella, las copias no se pueden leer. Para verla:  sudo cat $pass"
fi

export RESTIC_REPOSITORY="$BACKUP_MOUNT/restic" RESTIC_PASSWORD_FILE="$pass"
export RESTIC_CACHE_DIR="$DATA_MOUNT/.cache/restic"
mount "$BACKUP_MOUNT"
trap 'umount "$BACKUP_MOUNT" 2>/dev/null || true' EXIT
if ! restic cat config >/dev/null 2>&1; then
    log "Creando el repositorio restic en el disco USB"
    restic init
fi
umount "$BACKUP_MOUNT"
trap - EXIT

log "Programando copia diaria (03:30) y prueba de restauración mensual"
for b in alfred-backup alfred-restore-test; do install_bin "$b"; done
for u in alfred-backup.service alfred-backup.timer alfred-restore-test.service alfred-restore-test.timer; do
    install_unit "$u"
done
systemctl daemon-reload
systemctl enable --now alfred-backup.timer alfred-restore-test.timer

log "Primera copia (puede tardar unos minutos)"
systemctl start alfred-backup.service || die "La primera copia ha fallado: journalctl -u alfred-backup"
log "Prueba de restauración"
/usr/local/sbin/alfred-restore-test
log "Hecho. Copias listas."
