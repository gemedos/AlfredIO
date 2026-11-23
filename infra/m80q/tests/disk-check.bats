#!/usr/bin/env bats
# Tests de alfred-disk-check (umbrales, avisos, repeticiones y recuperación).

load helpers

setup() {
    setup_fake_env
    DC="$M80Q/bin/alfred-disk-check"
    export DF_OUT="$BATS_TEST_TMPDIR/df-out"
    cat >"$BATS_TEST_TMPDIR/fake-df" <<'EOS'
#!/usr/bin/env bash
cat "$DF_OUT"
EOS
    printf '#!/usr/bin/env bash\nexit 0\n' >"$BATS_TEST_TMPDIR/fake-mountpoint"
    chmod +x "$BATS_TEST_TMPDIR/fake-df" "$BATS_TEST_TMPDIR/fake-mountpoint"
    export ALFRED_DF="$BATS_TEST_TMPDIR/fake-df"
    export ALFRED_MOUNTPOINT="$BATS_TEST_TMPDIR/fake-mountpoint"
}

# Disco falso: % usado y GB libres.
set_disk() { printf 'Use%% Avail\n %s%% %sG\n' "$1" "$2" >"$DF_OUT"; }

@test "uso normal: no avisa" {
    set_disk 40 100
    run bash "$DC"
    [ "$status" -eq 0 ]
    [[ "$output" == *"40 % usado, 100 GB libres"* ]]
    [ "$(notify_count)" -eq 0 ]
}

@test "80 %: avisa una vez y no repite enseguida" {
    set_disk 82 30
    bash "$DC"
    [ "$(notify_count)" -eq 1 ]
    grep -q "Aviso: el disco de datos está al 82 %" "$NOTIFY_LOG"
    bash "$DC"
    [ "$(notify_count)" -eq 1 ]
}

@test "90 %: avisa como crítico aunque ya hubiera aviso" {
    set_disk 82 30
    bash "$DC"
    set_disk 93 12
    bash "$DC"
    [ "$(notify_count)" -eq 2 ]
    grep -q "CRÍTICO: el disco de datos está al 93 %" "$NOTIFY_LOG"
}

@test "repite el aviso pasadas 6 horas" {
    set_disk 85 27
    bash "$DC"
    printf 'PREV_LEVEL=1\nLAST_WARN=%s\n' "$(( $(date +%s) - 22000 ))" >"$ALFRED_STATE_DIR/disk-state"
    bash "$DC"
    [ "$(notify_count)" -eq 2 ]
}

@test "recuperación: avisa al bajar 5 puntos del umbral, no antes" {
    set_disk 85 27
    bash "$DC"
    set_disk 78 40
    bash "$DC"
    [ "$(notify_count)" -eq 1 ]
    set_disk 70 55
    bash "$DC"
    [ "$(notify_count)" -eq 2 ]
    grep -q "Disco de datos normal de nuevo" "$NOTIFY_LOG"
}

@test "partición sin montar: no mide ni avisa" {
    printf '#!/usr/bin/env bash\nexit 1\n' >"$BATS_TEST_TMPDIR/fake-mountpoint"
    set_disk 99 1
    run bash "$DC"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no está montada"* ]]
    [ "$(notify_count)" -eq 0 ]
}

@test "df ilegible: falla sin avisar" {
    printf 'basura\n' >"$DF_OUT"
    run bash "$DC"
    [ "$status" -ne 0 ]
    [ "$(notify_count)" -eq 0 ]
}
