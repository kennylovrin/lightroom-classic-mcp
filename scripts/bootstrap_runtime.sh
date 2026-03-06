#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_DIR="${LIGHTROOM_VENV_DIR:-$PROJECT_DIR/.venv}"
BOOTSTRAP_PYTHON="${LIGHTROOM_BOOTSTRAP_PYTHON:-python3}"

if [[ ! -x "$VENV_DIR/bin/python3" ]]; then
  "$BOOTSTRAP_PYTHON" -m venv "$VENV_DIR"
fi

VENV_PYTHON="$VENV_DIR/bin/python3"
VENV_PIP="$VENV_DIR/bin/pip"

if ! "$VENV_PYTHON" - <<'PY' >/dev/null 2>&1
import importlib.util
raise SystemExit(0 if importlib.util.find_spec("mcp") else 1)
PY
then
  "$VENV_PIP" install --quiet --upgrade pip >&2
  "$VENV_PIP" install --quiet -e "$PROJECT_DIR" >&2
fi

echo "Runtime ready in: $VENV_DIR"
