#!/usr/bin/env bats
# Tests de alfred-net-watch (escalada de reconexión, reinicio con enfriamiento y aviso al recuperarse).

load helpers

setup() {
    setup_fake_env
    NW="$M80Q/bin/alfred-net-watch"
    export CALLS="$BATS_TEST_TMPDIR/calls.log" NET_UP="$BATS_TEST_TMPDIR/net-up" WIFI_IFACE=wlx0
    : >"$CALLS"
    mk() { printf '#!/usr/bin/env bash\n%s\n' "$2" >"$BATS_TEST_TMPDIR/$1"; chmod +x "$BATS_TEST_TMPDIR/$1"; }
    mk fake-ping '[[ -e "$NET_UP" ]]'
    mk fake-nmcli 'if [[ "$1" == "-t" ]]; then [[ -n "$WIFI_IFACE" ]] && echo "$WIFI_IFACE:wifi"; echo "lo:loopback"; else echo "nmcli $*" >>"$CALLS"; fi'
    mk fake-systemctl 'echo "systemctl $*" >>"$CALLS"'
    mk fake-modprobe 'echo "modprobe $*" >>"$CALLS"'
    mk fake-reboot 'echo reboot >>"$CALLS"'
    export ALFRED_PING="$BATS_TEST_TMPDIR/fake-ping" ALFRED_NMCLI="$BATS_TEST_TMPDIR/fake-nmcli"
    export ALFRED_SYSTEMCTL="$BATS_TEST_TMPDIR/fake-systemctl" ALFRED_MODPROBE="$BATS_TEST_TMPDIR/fake-modprobe"
    export ALFRED_REBOOT="$BATS_TEST_TMPDIR/fake-reboot" ALFRED_SLEEP=true
    export ALFRED_GATEWAY=192.0.2.1 ALFRED_WIFI_DRIVER=rtl8xxxu
}

net_down() { rm -f "$NET_UP"; }
net_up() { touch "$NET_UP"; }
times() { local n="$1"; shift; for _ in $(seq 1 "$n"); do bash "$NW" >/dev/null || return 1; done; }
calls() { grep -c "$1" "$CALLS" || true; }

@test "red normal: no hace nada ni avisa" {
    net_up
    times 5
    [ ! -s "$CALLS" ]
    [ "$(notify_count)" -eq 0 ]
}

@test "2 minutos sin red: todavía no actúa" {
    net_down
    times 2
    [ ! -s "$CALLS" ]
}

@test "3 minutos sin red: reconecta el wifi una sola vez" {
    net_down
    times 3
    [ "$(calls 'nmcli device connect wlx0')" -eq 1 ]
    times 2
    [ "$(calls 'nmcli device connect wlx0')" -eq 1 ]
    [ "$(calls 'systemctl restart')" -eq 0 ]
}

@test "6 minutos: reinicia NetworkManager y recarga el driver, una vez" {
    net_down
    times 8
    [ "$(calls 'systemctl restart NetworkManager')" -eq 1 ]
    [ "$(calls 'modprobe -r rtl8xxxu')" -eq 1 ]
    [ "$(calls 'modprobe rtl8xxxu')" -eq 1 ]
    [ "$(calls reboot)" -eq 0 ]
}

@test "15 minutos: reinicia el equipo" {
    net_down
    times 15
    [ "$(calls reboot)" -eq 1 ]
    grep -q "^STEP=3" "$ALFRED_STATE_DIR/net-state"
}

@test "no reinicia dos veces dentro del enfriamiento" {
    net_down
    printf 'FAILS=14\nSTEP=2\nLAST_REBOOT=%s\n' "$(( $(date +%s) - 3600 ))" >"$ALFRED_STATE_DIR/net-state"
    run bash "$NW"
    [[ "$output" == *"Reinicio pospuesto"* ]]
    [ "$(calls reboot)" -eq 0 ]
}

@test "reinicia de nuevo pasado el enfriamiento" {
    net_down
    printf 'FAILS=14\nSTEP=2\nLAST_REBOOT=%s\n' "$(( $(date +%s) - 25000 ))" >"$ALFRED_STATE_DIR/net-state"
    bash "$NW" >/dev/null
    [ "$(calls reboot)" -eq 1 ]
}

@test "recuperación tras 3+ minutos: avisa con la duración" {
    net_down
    times 4
    net_up
    bash "$NW" >/dev/null
    [ "$(notify_count)" -eq 1 ]
    grep -q "ha vuelto tras unos 4 min" "$NOTIFY_LOG"
    grep -q "reconectando el wifi" "$NOTIFY_LOG"
}

@test "corte de 1-2 minutos: no avisa" {
    net_down
    times 2
    net_up
    bash "$NW" >/dev/null
    [ "$(notify_count)" -eq 0 ]
    grep -q "^FAILS=0" "$ALFRED_STATE_DIR/net-state"
}

@test "tras un reinicio por la red: el aviso lo dice" {
    printf 'FAILS=16\nSTEP=3\nLAST_REBOOT=%s\n' "$(date +%s)" >"$ALFRED_STATE_DIR/net-state"
    net_up
    bash "$NW" >/dev/null
    grep -q "se reinició" "$NOTIFY_LOG"
}

@test "sin interfaz wifi (cable): no intenta reconectar wifi ni recargar driver" {
    export WIFI_IFACE=""
    net_down
    times 7
    [ "$(calls 'nmcli device connect')" -eq 0 ]
}
