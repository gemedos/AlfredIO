#!/usr/bin/env bash
# Paso 7: vigilancia de temperatura (lm-sensors/coretemp) y de consumo (Shelly), con avisos por Telegram.
#   sudo ./70-monitoring.sh
# El consumo sólo se activa si SHELLY_HOST está relleno (el Shelly aún no está comprado).
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
require_root
require_debian13
load_config

for b in alfred-temp-watch alfred-power-watch; do install_bin "$b"; done
for u in alfred-temp-watch.service alfred-temp-watch.timer alfred-power-watch.service alfred-power-watch.timer; do
    install_unit "$u"
done
systemctl daemon-reload

log "Temperatura"
/usr/local/sbin/alfred-temp-watch || die "No se lee la temperatura. Prueba: sensors"
systemctl enable --now alfred-temp-watch.timer

log "Consumo"
if [[ -n "${SHELLY_HOST:-}" ]]; then
    /usr/local/sbin/alfred-power-watch --read || die "No se lee el Shelly en $SHELLY_HOST (revisa IP y SHELLY_PASSWORD)"
    systemctl enable --now alfred-power-watch.timer
else
    warn "SHELLY_HOST vacío: vigilancia de consumo pendiente del enchufe (vuelve a ejecutar este paso cuando lo tengas)."
    systemctl disable --now alfred-power-watch.timer 2>/dev/null || true
fi

log "Hecho. Prueba de aceptación (llega un aviso marcado como SIMULACIÓN):"
echo "      sudo alfred-temp-watch --simulate 96"
echo "      sudo alfred-temp-watch --simulate 96 --sustained"
