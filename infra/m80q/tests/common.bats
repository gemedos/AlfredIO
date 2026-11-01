#!/usr/bin/env bats
# Tests de lib/common.sh y alfred-notify.

bats_require_minimum_version 1.5.0
load helpers

setup() {
    setup_fake_env
    export ALFRED_CONFIG="$ALFRED_ETC/m80q.env"
    # shellcheck source=../lib/common.sh
    source "$M80Q/lib/common.sh"
}

@test "is_tailnet_ip: acepta IPs de Tailscale" {
    is_tailnet_ip 100.64.0.1
    is_tailnet_ip 100.101.102.103
    is_tailnet_ip 100.127.255.254
    is_tailnet_ip ::ffff:100.100.1.1
    is_tailnet_ip fd7a:115c:a1e0::1234
}

@test "is_tailnet_ip: rechaza la red local y otras" {
    # (en bats, `! cmd` sólo falla en la última línea: por eso `run !`)
    run ! is_tailnet_ip 192.168.1.20
    run ! is_tailnet_ip 100.63.255.255
    run ! is_tailnet_ip 100.128.0.1
    run ! is_tailnet_ip 10.0.0.5
    run ! is_tailnet_ip fe80::1
    run ! is_tailnet_ip ""
}

@test "set_config reemplaza y añade claves" {
    set_config DATA_LUKS_UUID abc-123
    grep -qx 'DATA_LUKS_UUID=abc-123' "$ALFRED_CONFIG"
    set_config DATA_LUKS_UUID def-456
    [ "$(grep -c '^DATA_LUKS_UUID=' "$ALFRED_CONFIG")" -eq 1 ]
    grep -qx 'DATA_LUKS_UUID=def-456' "$ALFRED_CONFIG"
    set_config NUEVA_CLAVE x
    grep -qx 'NUEVA_CLAVE=x' "$ALFRED_CONFIG"
}

@test "alfred-notify (dry-run): antepone el equipo y recorta mensajes largos" {
    long=$(head -c 5000 /dev/zero | tr '\0' 'a')
    run env ALFRED_NOTIFY_DRYRUN=1 bash "$M80Q/bin/alfred-notify" "$long"
    [ "$status" -eq 0 ]
    [[ "$output" == "DRYRUN: ["* ]]
    [ "${#output}" -le 3810 ]
}

@test "alfred-notify: sin secretos falla sin enviar nada" {
    run bash "$M80Q/bin/alfred-notify" "hola"
    [ "$status" -eq 1 ]
}

@test "alfred-notify: sin mensaje muestra el uso" {
    run bash "$M80Q/bin/alfred-notify"
    [ "$status" -eq 2 ]
}

@test "ningún script mete secretos en la línea de comandos de curl" {
    run ! grep -nE 'curl[^|]*(TOKEN|PASSWORD)' "$M80Q"/bin/* "$M80Q"/*.sh
}
