# shellcheck shell=bash
# Funciones comunes de los scripts de instalación del M80q. Se carga con `source`.

set -euo pipefail

M80Q_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALFRED_ETC="${ALFRED_ETC:-/etc/alfred}"
ALFRED_CONFIG="${ALFRED_CONFIG:-$ALFRED_ETC/m80q.env}"

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\033[1;33mAVISO:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

require_root() {
    [[ $EUID -eq 0 ]] || die "Ejecuta este script con sudo."
}

require_debian13() {
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ "${ID:-}" == "debian" && "${VERSION_ID:-}" == "13" ]] \
        || die "Este script es para Debian 13 (encontrado: ${PRETTY_NAME:-desconocido})."
}

load_config() {
    [[ -r "$ALFRED_CONFIG" ]] || die "Falta $ALFRED_CONFIG. Ejecuta antes 10-base.sh."
    # shellcheck disable=SC1090
    . "$ALFRED_CONFIG"
}

# Escribe o reemplaza CLAVE=valor en el archivo de configuración.
set_config() {
    local key="$1" value="$2"
    if grep -q "^${key}=" "$ALFRED_CONFIG"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$ALFRED_CONFIG"
    else
        printf '%s=%s\n' "$key" "$value" >>"$ALFRED_CONFIG"
    fi
}

# Pide escribir un texto exacto para continuar (para pasos destructivos).
confirm_exact() {
    local expected="$1" prompt="$2" answer
    read -r -p "$prompt " answer
    [[ "$answer" == "$expected" ]] || die "No coincide. No se ha cambiado nada."
}

# Copia un script de infra/m80q/bin a /usr/local/sbin (root, 0755).
install_bin() {
    local name="$1"
    install -o root -g root -m 0755 "$M80Q_DIR/bin/$name" "/usr/local/sbin/$name"
}

# Copia una unidad de infra/m80q/systemd a /etc/systemd/system.
install_unit() {
    local name="$1"
    install -o root -g root -m 0644 "$M80Q_DIR/systemd/$name" "/etc/systemd/system/$name"
}

# Copia un archivo de infra/m80q/files a su destino (root, modo indicado o 0644).
install_file() {
    local src="$1" dest="$2" mode="${3:-0644}"
    install -D -o root -g root -m "$mode" "$M80Q_DIR/files/$src" "$dest"
}

apt_install() {
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

user_uid() { id -u "$1"; }

# ¿Está la IP en la red de Tailscale (100.64.0.0/10 o fd7a:115c:a1e0::/48)?
is_tailnet_ip() {
    local ip="$1"
    if [[ "$ip" == fd7a:115c:a1e0:* ]]; then return 0; fi
    ip="${ip#::ffff:}"
    local a b
    IFS=. read -r a b _ _ <<<"$ip"
    [[ "$a" == "100" && "$b" =~ ^[0-9]+$ ]] && ((b >= 64 && b <= 127))
}

# Ejecuta un comando como el usuario indicado con su bus de systemd --user.
run_as_user() {
    local user="$1"; shift
    local uid; uid="$(user_uid "$user")"
    sudo -u "$user" XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" "$@"
}
