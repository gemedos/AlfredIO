#!/usr/bin/env bash
# Paso 5b: usuario "clips" con su propio Docker rootless, separado de "alfred" (proyecto Clipmation).
#   sudo ./55-clips-user.sh
# Requisitos: 40-data-luks.sh y 50-docker-rootless.sh ya ejecutados (Docker instalado, datos montados).
# - No instala paquetes ni toca a "alfred", el cortafuegos, SSH ni Tailscale.
# - Usuario sin contraseña, sin SSH y sin sudo. Sus datos van en $DATA_MOUNT/clips (cifrado, modo 0700).
# - Límites del sistema a TODO lo que corra ese usuario (contenedores incluidos): CPU, prioridad y RAM.
# - Si la partición de datos no está montada, su Docker no arranca.
# Se puede repetir sin problemas. Ver docs/conflict-alfred-clipmation.md.
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_root
require_debian13
load_config

CLIPS_USER="${CLIPS_USER:-clips}"
CLIPS_CPU_QUOTA="${CLIPS_CPU_QUOTA:-800%}"   # 800 % = 8 hilos como máximo (el M80q tiene 12)
CLIPS_CPU_WEIGHT="${CLIPS_CPU_WEIGHT:-20}"   # prioridad baja frente al peso por defecto (100)
CLIPS_MEM_MAX="${CLIPS_MEM_MAX:-8G}"
CLIPS_TASKS_MAX="${CLIPS_TASKS_MAX:-4096}"

[[ "$CLIPS_USER" =~ ^[a-z][a-z0-9_-]{1,30}$ ]] || die "Nombre de usuario no válido: $CLIPS_USER"
[[ "$CLIPS_USER" != "$ALFRED_USER" && "$CLIPS_USER" != "${ADMIN_USER:-}" && "$CLIPS_USER" != root ]] \
    || die "CLIPS_USER debe ser un usuario distinto de $ALFRED_USER, de tu usuario y de root."
mountpoint -q "$DATA_MOUNT" || die "$DATA_MOUNT no está montada. Ejecuta antes 40-data-luks.sh."
command -v dockerd-rootless-setuptool.sh >/dev/null || die "Docker no está instalado. Ejecuta antes 50-docker-rootless.sh."

# Deja constancia de los valores en la configuración (sin pisar lo que ya haya).
for key in CLIPS_USER CLIPS_CPU_QUOTA CLIPS_CPU_WEIGHT CLIPS_MEM_MAX CLIPS_TASKS_MAX; do
    grep -q "^${key}=" "$ALFRED_CONFIG" || set_config "$key" "${!key}"
done

log "Usuario $CLIPS_USER (sin contraseña, sin SSH, sin sudo)"
if ! id "$CLIPS_USER" >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash "$CLIPS_USER"
fi
passwd -l "$CLIPS_USER" >/dev/null
if ! grep -q "^$CLIPS_USER:" /etc/subuid || ! grep -q "^$CLIPS_USER:" /etc/subgid; then
    die "$CLIPS_USER no tiene rangos en /etc/subuid y /etc/subgid."
fi
uid=$(user_uid "$CLIPS_USER")
home=$(getent passwd "$CLIPS_USER" | cut -d: -f6)

log "Datos en $DATA_MOUNT/clips (cifrado, sólo $CLIPS_USER)"
install -d -o "$CLIPS_USER" -g "$CLIPS_USER" -m 0700 "$DATA_MOUNT/clips"
install -d -o "$CLIPS_USER" -g "$CLIPS_USER" -m 0710 "$DATA_MOUNT/clips/docker"
# `install -d` crea los intermedios a nombre de root: se crea ~/.config aparte (ver paso 50).
install -d -o "$CLIPS_USER" -g "$CLIPS_USER" -m 0700 "$home/.config"
install -d -o "$CLIPS_USER" -g "$CLIPS_USER" -m 0700 "$home/.config/docker"
sed "s|@DATA_MOUNT@/docker|$DATA_MOUNT/clips/docker|" "$M80Q_DIR/files/docker/daemon.json" >"$home/.config/docker/daemon.json"
grep -q "$DATA_MOUNT/clips/docker" "$home/.config/docker/daemon.json" || die "No se pudo escribir daemon.json con la ruta de datos."
chown "$CLIPS_USER:$CLIPS_USER" "$home/.config/docker/daemon.json"

log "Límites: CPU $CLIPS_CPU_QUOTA, peso $CLIPS_CPU_WEIGHT, RAM $CLIPS_MEM_MAX, procesos $CLIPS_TASKS_MAX"
install -d -m 0755 "/etc/systemd/system/user-$uid.slice.d"
cat >"/etc/systemd/system/user-$uid.slice.d/50-clips-limits.conf" <<LIM
# Generado por 55-clips-user.sh. Afecta a todos los procesos de $CLIPS_USER, contenedores incluidos.
[Slice]
CPUQuota=$CLIPS_CPU_QUOTA
CPUWeight=$CLIPS_CPU_WEIGHT
MemoryMax=$CLIPS_MEM_MAX
TasksMax=$CLIPS_TASKS_MAX
LIM

log "Arranque automático sin iniciar sesión (linger)"
loginctl enable-linger "$CLIPS_USER"
mount_unit=$(systemd-escape -p --suffix=mount "$DATA_MOUNT")
install -d -m 0755 "/etc/systemd/system/user@$uid.service.d"
printf '[Unit]\nAfter=%s\n' "$mount_unit" >"/etc/systemd/system/user@$uid.service.d/alfred-data.conf"
systemctl daemon-reload
systemctl start "user@$uid.service"
for _ in $(seq 1 20); do [[ -S "/run/user/$uid/bus" ]] && break; sleep 0.5; done

log "Instalando Docker rootless para $CLIPS_USER"
run_as_user "$CLIPS_USER" dockerd-rootless-setuptool.sh install
# Si la partición de datos no está montada, Docker NO arranca (no escribe en el disco sin cifrar).
dropin="$home/.config/systemd/user/docker.service.d"
install -d -o "$CLIPS_USER" -g "$CLIPS_USER" -m 0755 "$dropin"
printf '[Unit]\nConditionPathIsMountPoint=%s\n' "$DATA_MOUNT" >"$dropin/alfred-data.conf"
chown "$CLIPS_USER:$CLIPS_USER" "$dropin/alfred-data.conf"
run_as_user "$CLIPS_USER" systemctl --user daemon-reload
run_as_user "$CLIPS_USER" systemctl --user enable docker.service
run_as_user "$CLIPS_USER" systemctl --user restart docker.service

bashrc="$home/.bashrc"
grep -q 'DOCKER_HOST=' "$bashrc" 2>/dev/null || \
    echo "export DOCKER_HOST=unix:///run/user/$uid/docker.sock" >>"$bashrc"

log "Comprobando"
run_as_user "$CLIPS_USER" env DOCKER_HOST="unix:///run/user/$uid/docker.sock" \
    docker info --format '  Docker {{.ServerVersion}} | opciones: {{.SecurityOptions}} | datos: {{.DockerRootDir}}'
echo "  Límites activos de user-$uid.slice:"
systemctl show "user-$uid.slice" -p CPUQuotaPerSecUSec -p CPUWeight -p MemoryMax -p TasksMax | sed 's/^/    /'
log "Hecho. Para usar Docker: sudo -iu $CLIPS_USER   y luego   docker ps"
echo "      Los límites (CPU/RAM) y la temperatura hay que MEDIRLOS con una tanda real antes de activar el runner."
echo "      Copias: compose.yml y .env de Clipmation irán a restic en el paso 60 (aún no los incluye)."
