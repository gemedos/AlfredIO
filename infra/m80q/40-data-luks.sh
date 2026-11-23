#!/usr/bin/env bash
# Paso 4: cifra la partición de datos con LUKS2 y desbloqueo automático por TPM 2.0.
#   sudo ./40-data-luks.sh /dev/nvme0n1p3
#
# ⚠️  BORRA la partición indicada. Te pide escribir su ruta para confirmar.
#
# Cómo queda:
#   - Hueco 1: clave de recuperación (la apuntas tú, en papel o gestor de contraseñas).
#   - Hueco 2: TPM 2.0 sellado a PCR 7 (estado de Secure Boot). Arranca solo, sin pantalla.
#   - La clave temporal de instalación se borra al final.
# Si el TPM no desbloquea (p. ej., tras cambiar la BIOS), el sistema arranca igual,
# te llega un aviso por Telegram y lo desbloqueas por SSH con: sudo alfred-unlock-data
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_root
require_debian13
load_config

MAPPER=alfred-data
dev="${1:-}"
[[ -n "$dev" ]] || die "Uso: sudo $0 /dev/PARTICIÓN   (00-preflight.sh te dice cuál)"
[[ -b "$dev" ]] || die "$dev no existe."
[[ "$(lsblk -no TYPE "$dev")" == "part" ]] || die "$dev no es una partición."
for mnt in / /boot /boot/efi; do
    src=$(findmnt -no SOURCE "$mnt" 2>/dev/null || true)
    [[ -n "$src" && "$(readlink -f "$src")" == "$(readlink -f "$dev")" ]] && die "$dev es la partición de $mnt. ¡No!"
done
findmnt -S "$dev" >/dev/null && die "$dev está montada."

log "Paquetes de cifrado y TPM"
apt_install cryptsetup tpm2-tools
command -v systemd-cryptenroll >/dev/null || apt_install systemd-cryptsetup
SYSTEMD_CRYPTSETUP=$(command -v systemd-cryptsetup || echo /usr/lib/systemd/systemd-cryptsetup)
[[ -x "$SYSTEMD_CRYPTSETUP" ]] || die "No encuentro systemd-cryptsetup."
systemd-cryptenroll --tpm2-device=list | grep -q /dev/ \
    || die "systemd no ve el TPM. Revisa la BIOS (Security Chip) y 00-preflight.sh."

fstype=$(blkid -o value -s TYPE "$dev" || true)
if [[ "$fstype" == "crypto_LUKS" ]]; then
    luks_uuid=$(cryptsetup luksUUID "$dev")
    [[ "$luks_uuid" == "${DATA_LUKS_UUID:-}" ]] \
        || die "$dev ya tiene LUKS pero no es la registrada en $ALFRED_CONFIG. No la toco."
    log "La partición ya está cifrada ($luks_uuid). Sólo reaplico la configuración."
elif [[ -n "$fstype" ]]; then
    die "$dev contiene un sistema de ficheros ($fstype). No la toco: revisa que es la correcta."
else
    echo
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$dev"
    echo
    warn "Se va a BORRAR $dev y cifrar con LUKS2."
    confirm_exact "$dev" "Escribe la ruta exacta ($dev) para continuar:"

    tmpkey=$(mktemp -p /run alfred-luks.XXXXXX)
    trap 'shred -u "$tmpkey" 2>/dev/null || rm -f "$tmpkey"' EXIT
    head -c 64 /dev/urandom >"$tmpkey"

    log "Formateando con LUKS2"
    cryptsetup luksFormat --type luks2 --batch-mode --label alfred-data --key-file "$tmpkey" "$dev"
    luks_uuid=$(cryptsetup luksUUID "$dev")

    echo
    warn "Ahora aparecerá la CLAVE DE RECUPERACIÓN. Apúntala SIN ERRORES (papel o gestor de"
    warn "contraseñas, nunca en el chat). Es la única forma de abrir los datos si falla el TPM."
    read -r -p "Pulsa Intro cuando estés listo..." _
    systemd-cryptenroll --unlock-key-file="$tmpkey" --recovery-key "$dev"
    echo
    log "Comprueba que la has apuntado bien: escríbela ahora (no se verá en pantalla)."
    ok_recovery=0
    for _ in 1 2 3; do
        if cryptsetup open --test-passphrase "$dev"; then ok_recovery=1; break; fi
    done
    if ((ok_recovery == 0)); then
        wipefs -a "$dev" >/dev/null
        die "La clave de recuperación no coincide. He vaciado $dev (no tenía datos). Vuelve a ejecutar el script."
    fi

    log "Sellando la clave con el TPM (PCR 7 = estado de Secure Boot)"
    systemd-cryptenroll --unlock-key-file="$tmpkey" --tpm2-device=auto --tpm2-pcrs=7 "$dev"
    log "Probando el desbloqueo por TPM, como en el arranque"
    "$SYSTEMD_CRYPTSETUP" attach alfred-tpmtest "$dev" none tpm2-device=auto,headless=true,readonly \
        || die "El TPM no desbloquea. La partición queda cifrada; revisa la BIOS y vuelve a ejecutar."
    "$SYSTEMD_CRYPTSETUP" detach alfred-tpmtest

    log "Creando el sistema de ficheros"
    cryptsetup open --key-file "$tmpkey" "$dev" "$MAPPER"
    mkfs.ext4 -q -L alfred-data "/dev/mapper/$MAPPER"

    log "Borrando la clave temporal de instalación (hueco 0)"
    cryptsetup luksKillSlot --batch-mode "$dev" 0
    set_config DATA_LUKS_UUID "$luks_uuid"
fi

log "Desbloqueo en el arranque (/etc/crypttab) y montaje (/etc/fstab)"
sed -i "/^${MAPPER}[[:space:]]/d" /etc/crypttab
# headless=true: si el TPM falla no se queda esperando una contraseña en una pantalla que no hay.
# nofail: el sistema (y Tailscale/SSH) arrancan igual aunque los datos sigan cerrados.
echo "$MAPPER UUID=$luks_uuid none tpm2-device=auto,headless=true,nofail" >>/etc/crypttab
sed -i "\|^/dev/mapper/${MAPPER}[[:space:]]|d" /etc/fstab
echo "/dev/mapper/$MAPPER $DATA_MOUNT ext4 defaults,noatime,nofail,x-systemd.device-timeout=90s 0 2" >>/etc/fstab

mkdir -p "$DATA_MOUNT"
if ! mountpoint -q "$DATA_MOUNT"; then
    # Inmutable mientras NO esté montada: si el desbloqueo falla, nada puede escribir
    # datos en el disco del sistema (que no está cifrado) por error.
    chattr +i "$DATA_MOUNT"
    [[ -e "/dev/mapper/$MAPPER" ]] || "$SYSTEMD_CRYPTSETUP" attach "$MAPPER" "UUID=$luks_uuid" none tpm2-device=auto,headless=true
    systemctl daemon-reload
    mount "$DATA_MOUNT"
fi
install -d -o root -g root -m 0755 "$DATA_MOUNT"
install -d -o root -g root -m 0700 "$DATA_MOUNT/secrets"
install -d -o root -g root -m 0755 "$DATA_MOUNT/data"

log "Avisos y desbloqueo manual"
install_bin alfred-unlock-data
install_bin alfred-data-check
install_unit alfred-data-check.service
install_unit alfred-data-check.timer
systemctl daemon-reload
systemctl enable alfred-data-check.timer

echo
cryptsetup luksDump "$dev" | grep -E '^\s+[0-9]+: (luks2|systemd-)' | sed 's/^/  /' || true
log "Hecho. $DATA_MOUNT montada y cifrada. Prueba de fuego: 'sudo reboot' y comprueba que vuelve montada sola:"
echo "      findmnt $DATA_MOUNT"
