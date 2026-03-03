#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/abacus-appliance/selftest"
VENV_DIR="/opt/abacus-appliance/.venv-selftest"
export SELFTEST_SPEC_FILE="/etc/abacus-appliance/specs.yaml"

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  python3 -m venv "$VENV_DIR"
  "$VENV_DIR/bin/pip" install --upgrade pip
  "$VENV_DIR/bin/pip" install -r "$BASE_DIR/requirements.txt"
fi

if [[ ! -f "$SELFTEST_SPEC_FILE" ]]; then
  export SELFTEST_SPEC_FILE="$BASE_DIR/specs.yaml"
fi

exec "$VENV_DIR/bin/pytest" -q "$BASE_DIR/test_selftest.py" --hosts=local://
