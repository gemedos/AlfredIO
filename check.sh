#!/usr/bin/env bash
# Verificación del repositorio en un paso: shellcheck + tests (bats).
#   ./check.sh
# Si shellcheck, bats y jq no están instalados, lo ejecuta en un contenedor Debian 13 (Docker).
# (La verificación del propio M80q es otra: sudo ./infra/m80q/verify.sh, en el servidor.)
set -euo pipefail
cd "$(dirname "$0")"

run_checks() {
    echo "== shellcheck"
    mapfile -t scripts < <(find infra -type f \( -name '*.sh' -o -path '*/bin/*' \) | sort)
    shellcheck -x "${scripts[@]}" check.sh
    echo "   ${#scripts[@]} scripts sin avisos"
    echo "== tests"
    bats infra/m80q/tests
}

if [[ "${1:-}" == "--inside" ]] || { command -v shellcheck && command -v bats && command -v jq; } >/dev/null 2>&1; then
    run_checks
    exit
fi

command -v docker >/dev/null || { echo "Necesitas shellcheck+bats+jq o Docker." >&2; exit 1; }
image=alfred-check:debian13
docker build -q -t "$image" infra/m80q/tests >/dev/null
repo=$(pwd -W 2>/dev/null || pwd)   # en Git Bash de Windows, ruta con letra de unidad
MSYS_NO_PATHCONV=1 docker run --rm -v "$repo:/repo:ro" -w /repo "$image" bash ./check.sh --inside
