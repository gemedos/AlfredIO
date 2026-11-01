#!/usr/bin/env bats
# Tests de alfred-temp-watch (umbrales, avisos, apagado y simulación).

load helpers

setup() {
    setup_fake_env
    TW="$M80Q/bin/alfred-temp-watch"
}

@test "temperatura normal: no avisa ni apaga" {
    set_cpu_temp 50
    run bash "$TW"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CPU 50 °C"* ]]
    [ "$(notify_count)" -eq 0 ]
    [ ! -e "$POWEROFF_LOG" ]
}

@test "temperatura alta: avisa una vez y no repite antes de 30 min" {
    set_cpu_temp 88
    run bash "$TW"
    [ "$(notify_count)" -eq 1 ]
    grep -q "Temperatura alta: CPU a 88 °C" "$NOTIFY_LOG"
    run bash "$TW"
    [ "$(notify_count)" -eq 1 ]
}

@test "vuelta a la normalidad: avisa al bajar 10 °C del umbral" {
    set_cpu_temp 88
    bash "$TW"
    set_cpu_temp 80
    bash "$TW"
    [ "$(notify_count)" -eq 1 ]
    set_cpu_temp 70
    bash "$TW"
    [ "$(notify_count)" -eq 2 ]
    grep -q "Temperatura normal de nuevo" "$NOTIFY_LOG"
}

@test "crítica sostenida: apaga al llegar a TEMP_CRIT_MINUTES" {
    set_cpu_temp 97
    for _ in 1 2 3 4; do bash "$TW"; done
    [ ! -e "$POWEROFF_LOG" ]
    bash "$TW"
    [ "$(cat "$POWEROFF_LOG")" = "poweroff" ]
    grep -q "CRÍTICO: CPU a 97 °C durante 5 min" "$NOTIFY_LOG"
}

@test "crítica intermitente: el contador se reinicia y no apaga" {
    for t in 97 97 97 97 90 97 97 97 97; do set_cpu_temp "$t"; bash "$TW"; done
    [ ! -e "$POWEROFF_LOG" ]
}

@test "simulación: avisa marcado como SIMULACIÓN y no toca el estado real" {
    set_cpu_temp 40
    run bash "$TW" --simulate 96
    [ "$status" -eq 0 ]
    grep -q "^\[SIMULACIÓN\] Temperatura alta: CPU a 96 °C" "$NOTIFY_LOG"
    [ ! -e "$ALFRED_STATE_DIR/temp-state" ]
    [ ! -e "$POWEROFF_LOG" ]
}

@test "simulación sostenida: recorre el camino de apagado SIN apagar" {
    run bash "$TW" --simulate 96 --sustained
    [ "$status" -eq 0 ]
    grep -q "^\[SIMULACIÓN\] CRÍTICO" "$NOTIFY_LOG"
    grep -q "NO se apaga" "$NOTIFY_LOG"
    [ ! -e "$POWEROFF_LOG" ]
}

@test "sin sensor coretemp: avisa una sola vez y falla" {
    run bash "$TW"
    [ "$status" -eq 1 ]
    run bash "$TW"
    [ "$status" -eq 1 ]
    [ "$(notify_count)" -eq 1 ]
    grep -q "No puedo leer la temperatura" "$NOTIFY_LOG"
}

@test "simulación rechaza valores no numéricos" {
    run bash "$TW" --simulate 'abc'
    [ "$status" -eq 2 ]
}
