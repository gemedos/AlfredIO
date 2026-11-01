#!/usr/bin/env bats
# Tests de alfred-power-watch (lectura del Shelly, umbrales y fallos de lectura).

load helpers

setup() {
    setup_fake_env
    PW="$M80Q/bin/alfred-power-watch"
    sed -i 's/^SHELLY_HOST=.*/SHELLY_HOST=192.0.2.10/' "$ALFRED_ETC/m80q.env"
    export ALFRED_SHELLY_JSON="$BATS_TEST_TMPDIR/shelly.json"
}

set_watts() {
    printf '{"id":0,"output":true,"apower":%s,"voltage":231.2}\n' "$1" >"$ALFRED_SHELLY_JSON"
}

@test "sin SHELLY_HOST: no hace nada" {
    sed -i 's/^SHELLY_HOST=.*/SHELLY_HOST=/' "$ALFRED_ETC/m80q.env"
    run bash "$PW"
    [ "$status" -eq 0 ]
    [[ "$output" == *"desactivada"* ]]
}

@test "--read redondea los vatios" {
    set_watts 12.6
    run bash "$PW" --read
    [ "$status" -eq 0 ]
    [ "$output" = "13 W" ]
}

@test "consumo normal: no avisa" {
    set_watts 9.4
    run bash "$PW"
    [ "$status" -eq 0 ]
    [ "$(notify_count)" -eq 0 ]
}

@test "consumo alto sostenido: avisa al llegar a POWER_WARN_MINUTES y no repite" {
    set_watts 70
    for _ in $(seq 1 9); do bash "$PW"; done
    [ "$(notify_count)" -eq 0 ]
    bash "$PW"
    [ "$(notify_count)" -eq 1 ]
    grep -q "Consumo anómalo: 70 W durante 10 min" "$NOTIFY_LOG"
    bash "$PW"
    [ "$(notify_count)" -eq 1 ]
}

@test "pico corto: el contador se reinicia" {
    for w in 70 70 70 70 70 70 70 70 70 20 70; do set_watts "$w"; bash "$PW"; done
    [ "$(notify_count)" -eq 0 ]
}

@test "no se puede leer el Shelly: avisa a los 5 fallos y al recuperarse" {
    echo 'no es json' >"$ALFRED_SHELLY_JSON"
    for _ in 1 2 3 4; do run bash "$PW"; [ "$status" -eq 1 ]; done
    [ "$(notify_count)" -eq 0 ]
    run bash "$PW"
    [ "$(notify_count)" -eq 1 ]
    grep -q "No puedo leer el enchufe Shelly" "$NOTIFY_LOG"
    run bash "$PW"
    [ "$(notify_count)" -eq 1 ]
    set_watts 10
    run bash "$PW"
    [ "$status" -eq 0 ]
    [ "$(notify_count)" -eq 2 ]
    grep -q "Vuelvo a leer el enchufe" "$NOTIFY_LOG"
}

@test "apower no numérico cuenta como fallo de lectura" {
    printf '{"apower":"mucho"}\n' >"$ALFRED_SHELLY_JSON"
    run bash "$PW"
    [ "$status" -eq 1 ]
}
