# shellcheck shell=bash
# Utilidades comunes de los tests (bats).

M80Q="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# Entorno falso: configuración, estado, notificador y apagado simulados.
setup_fake_env() {
    export ALFRED_ETC="$BATS_TEST_TMPDIR/etc"
    export ALFRED_STATE_DIR="$BATS_TEST_TMPDIR/state"
    export ALFRED_HWMON_ROOT="$BATS_TEST_TMPDIR/hwmon"
    export NOTIFY_LOG="$BATS_TEST_TMPDIR/notify.log"
    export POWEROFF_LOG="$BATS_TEST_TMPDIR/poweroff.log"
    mkdir -p "$ALFRED_ETC" "$ALFRED_STATE_DIR" "$ALFRED_HWMON_ROOT"
    cp "$M80Q/config/m80q.env.example" "$ALFRED_ETC/m80q.env"
    : >"$NOTIFY_LOG"

    cat >"$BATS_TEST_TMPDIR/fake-notify" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NOTIFY_LOG"
EOF
    cat >"$BATS_TEST_TMPDIR/fake-poweroff" <<'EOF'
#!/usr/bin/env bash
echo poweroff >>"$POWEROFF_LOG"
EOF
    chmod +x "$BATS_TEST_TMPDIR/fake-notify" "$BATS_TEST_TMPDIR/fake-poweroff"
    export ALFRED_NOTIFY="$BATS_TEST_TMPDIR/fake-notify"
    export ALFRED_POWEROFF="$BATS_TEST_TMPDIR/fake-poweroff"
}

# Sensor coretemp falso a la temperatura indicada (°C).
set_cpu_temp() {
    local d="$ALFRED_HWMON_ROOT/hwmon3"
    mkdir -p "$d"
    echo coretemp >"$d/name"
    echo "Package id 0" >"$d/temp1_label"
    echo $(( $1 * 1000 )) >"$d/temp1_input"
    echo "Core 0" >"$d/temp2_label"
    echo 20000 >"$d/temp2_input"
}

notify_count() { grep -c . "$NOTIFY_LOG" || true; }
