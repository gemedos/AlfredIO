#!/usr/bin/env bash
# Paso 3: SSH sólo con clave + cortafuegos (denegar por defecto, SSH sólo por Tailscale) + fail2ban.
#   sudo ./30-ssh-firewall.sh        (desde una sesión SSH que entre POR TAILSCALE)
# Para no dejarte fuera, se niega a seguir si:
#   - Tailscale no está funcionando,
#   - tu usuario no tiene ninguna clave SSH autorizada,
#   - la sesión SSH actual entra por la red local en vez de por Tailscale.
# Desde la consola física (sin SSH) sí deja seguir.
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_root
require_debian13
load_config

log "Comprobaciones de seguridad antes de cerrar nada"
[[ "$(tailscale status --json 2>/dev/null | jq -r '.BackendState')" == "Running" ]] \
    || die "Tailscale no está funcionando. Ejecuta antes 20-tailscale.sh."
keys="/home/$ADMIN_USER/.ssh/authorized_keys"
[[ -s "$keys" ]] || die "$ADMIN_USER no tiene claves en $keys. Te quedarías fuera."
if [[ -n "${SSH_CONNECTION:-}" ]]; then
    client_ip="${SSH_CONNECTION%% *}"
    is_tailnet_ip "$client_ip" \
        || die "Tu sesión SSH viene de $client_ip (red local). Entra por Tailscale: ssh $ADMIN_USER@$(tailscale ip -4)"
    log "Sesión SSH por Tailscale ($client_ip): OK"
else
    warn "No es una sesión SSH (consola física): sigo."
fi

log "Configurando SSH (sólo clave, sin root, sólo $ADMIN_USER)"
install -d -m 0755 /etc/ssh/sshd_config.d
sed "s/@ADMIN_USER@/$ADMIN_USER/" "$M80Q_DIR/files/ssh/10-alfred.conf" >/etc/ssh/sshd_config.d/10-alfred.conf
chmod 0644 /etc/ssh/sshd_config.d/10-alfred.conf
sshd -t || die "La configuración de SSH no es válida; no se ha recargado."
systemctl reload ssh

log "Cortafuegos UFW: denegar entrada por defecto, SSH sólo por tailscale0"
apt_install ufw fail2ban python3-systemd
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed
# Quita reglas genéricas de SSH que pudiera haber (abiertas a cualquier interfaz).
for rule in "OpenSSH" "22" "22/tcp" "ssh"; do ufw delete allow "$rule" >/dev/null 2>&1 || true; done
ufw allow in on tailscale0 to any port 22 proto tcp comment 'SSH solo por Tailscale'
ufw logging low
ufw --force enable
ufw status verbose | sed 's/^/  /'

log "fail2ban"
install_file fail2ban/alfred.local /etc/fail2ban/jail.d/alfred.local
systemctl enable fail2ban
systemctl restart fail2ban

log "Hecho. NO cierres esta sesión: abre OTRA terminal y comprueba que entras con"
echo "      ssh ${ADMIN_USER}@$(tailscale ip -4)"
echo "  Si no puedes, en esta sesión: sudo ufw disable   (y avísame)."
