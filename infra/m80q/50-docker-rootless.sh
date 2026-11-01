#!/usr/bin/env bash
# Paso 5: Docker en modo rootless para el usuario sin privilegios "alfred".
#   sudo ./50-docker-rootless.sh
# - Instala Docker desde su repositorio oficial por apt (nada de `curl | sh`).
# - Deja APAGADO el Docker con root del sistema.
# - Los datos de Docker van a la partición cifrada; si no está montada, Docker no arranca.
# - Arranca solo al encender el equipo (linger), sin que nadie inicie sesión.
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_root
require_debian13
load_config

mountpoint -q "$DATA_MOUNT" || die "$DATA_MOUNT no está montada. Ejecuta antes 40-data-luks.sh."

KEYRING=/etc/apt/keyrings/docker.asc
if ! command -v dockerd-rootless-setuptool.sh >/dev/null; then
    log "Añadiendo el repositorio de Docker (download.docker.com)"
    install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o "$KEYRING"
    chmod 0644 "$KEYRING"
    echo "  Huella de la clave del repositorio:"
    gpg --show-keys --with-fingerprint "$KEYRING" 2>/dev/null | sed 's/^/    /'
    echo "deb [arch=$(dpkg --print-architecture) signed-by=$KEYRING] https://download.docker.com/linux/debian trixie stable" \
        >/etc/apt/sources.list.d/docker.list
    apt-get update
fi
apt_install docker-ce docker-ce-cli containerd.io docker-ce-rootless-extras \
    docker-compose-plugin uidmap dbus-user-session slirp4netns fuse-overlayfs iptables

log "Apagando el Docker con root del sistema (sólo se usa el rootless)"
systemctl disable --now docker.service docker.socket containerd.service 2>/dev/null || true
rm -f /var/run/docker.sock

log "Usuario $ALFRED_USER (sin contraseña, sin SSH, sin sudo)"
if ! id "$ALFRED_USER" >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash "$ALFRED_USER"
fi
passwd -l "$ALFRED_USER" >/dev/null
# useradd asigna rangos de subuid/subgid propios; sin ellos Docker rootless no funciona.
if ! grep -q "^$ALFRED_USER:" /etc/subuid || ! grep -q "^$ALFRED_USER:" /etc/subgid; then
    die "$ALFRED_USER no tiene rangos en /etc/subuid y /etc/subgid."
fi
uid=$(user_uid "$ALFRED_USER")
home=$(getent passwd "$ALFRED_USER" | cut -d: -f6)

log "Datos de Docker en $DATA_MOUNT/docker (cifrado)"
install -d -o "$ALFRED_USER" -g "$ALFRED_USER" -m 0710 "$DATA_MOUNT/docker"
install -d -o "$ALFRED_USER" -g "$ALFRED_USER" -m 0700 "$home/.config/docker"
sed "s|@DATA_MOUNT@|$DATA_MOUNT|" "$M80Q_DIR/files/docker/daemon.json" >"$home/.config/docker/daemon.json"
chown "$ALFRED_USER:$ALFRED_USER" "$home/.config/docker/daemon.json"

log "Arranque automático sin iniciar sesión (linger)"
loginctl enable-linger "$ALFRED_USER"
# El gestor de servicios del usuario espera a que esté montada la partición de datos.
mount_unit=$(systemd-escape -p --suffix=mount "$DATA_MOUNT")
install -d -m 0755 "/etc/systemd/system/user@$uid.service.d"
printf '[Unit]\nAfter=%s\n' "$mount_unit" >"/etc/systemd/system/user@$uid.service.d/alfred-data.conf"
systemctl daemon-reload
systemctl start "user@$uid.service"
for _ in $(seq 1 20); do [[ -S "/run/user/$uid/bus" ]] && break; sleep 0.5; done

log "Instalando Docker rootless para $ALFRED_USER"
run_as_user "$ALFRED_USER" dockerd-rootless-setuptool.sh install
# Si la partición de datos no está montada, Docker NO arranca (no escribe en el disco sin cifrar).
dropin="$home/.config/systemd/user/docker.service.d"
install -d -o "$ALFRED_USER" -g "$ALFRED_USER" -m 0755 "$dropin"
printf '[Unit]\nConditionPathIsMountPoint=%s\n' "$DATA_MOUNT" >"$dropin/alfred-data.conf"
chown "$ALFRED_USER:$ALFRED_USER" "$dropin/alfred-data.conf"
run_as_user "$ALFRED_USER" systemctl --user daemon-reload
run_as_user "$ALFRED_USER" systemctl --user enable docker.service
run_as_user "$ALFRED_USER" systemctl --user restart docker.service

bashrc="$home/.bashrc"
grep -q 'DOCKER_HOST=' "$bashrc" 2>/dev/null || \
    echo "export DOCKER_HOST=unix:///run/user/$uid/docker.sock" >>"$bashrc"

log "Comprobando"
run_as_user "$ALFRED_USER" env DOCKER_HOST="unix:///run/user/$uid/docker.sock" \
    docker info --format '  Docker {{.ServerVersion}} | opciones: {{.SecurityOptions}} | datos: {{.DockerRootDir}}'
dpkg-query -W -f='${Package} ${Version}\n' docker-ce docker-ce-rootless-extras containerd.io \
    >/etc/alfred/versions-docker.txt
log "Hecho. Para usar Docker: sudo -iu $ALFRED_USER   y luego   docker ps"
