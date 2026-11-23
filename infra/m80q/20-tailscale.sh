#!/usr/bin/env bash
# Paso 2: Tailscale (acceso remoto sin abrir puertos).
#   sudo ./20-tailscale.sh
# ANTES: pega infra/tailscale/policy.hujson en https://login.tailscale.com/admin/acls
# (si no, `tailscale up` rechaza la etiqueta tag:alfred).
# Se instala desde el repositorio oficial de Tailscale por apt; nada de `curl | sh`.
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_root
require_debian13
load_config

KEYRING=/usr/share/keyrings/tailscale-archive-keyring.gpg

if ! command -v tailscale >/dev/null; then
    log "Añadiendo el repositorio de Tailscale (pkgs.tailscale.com)"
    curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg -o "$KEYRING"
    chmod 0644 "$KEYRING"
    echo "  Huella de la clave del repositorio (queda registrada aquí):"
    gpg --show-keys --with-fingerprint "$KEYRING" 2>/dev/null | sed 's/^/    /'
    echo "deb [signed-by=$KEYRING] https://pkgs.tailscale.com/stable/debian trixie main" \
        >/etc/apt/sources.list.d/tailscale.list
    apt-get update
    apt_install tailscale
fi
systemctl enable --now tailscaled

if [[ "$(tailscale status --json 2>/dev/null | jq -r '.BackendState')" != "Running" ]]; then
    log "Conectando a Tailscale: abre en el móvil o el PC la URL que aparece abajo"
    # --ssh=false: SSH lo hace OpenSSH con tu clave, no Tailscale SSH.
    # --accept-dns=false: el servidor no depende del DNS de Tailscale para salir a internet.
    tailscale up --hostname="$TS_HOSTNAME" --advertise-tags="$TS_TAG" \
        --ssh=false --accept-dns=false --accept-routes=false
fi

ts_ip=$(tailscale ip -4)
log "Tailscale funcionando. IP del M80q en la tailnet: $ts_ip"
echo
echo "  Ahora, DESDE TU PC o MÓVIL (con Tailscale activo), comprueba que entras:"
echo "      ssh ${ADMIN_USER}@${ts_ip}"
echo "  y ejecuta el paso 30 desde ESA sesión."
