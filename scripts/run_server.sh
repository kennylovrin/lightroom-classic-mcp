#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

"$PROJECT_DIR/scripts/bootstrap_runtime.sh" >&2

VENV_DIR="${LIGHTROOM_VENV_DIR:-$PROJECT_DIR/.venv}"
VENV_PYTHON="$VENV_DIR/bin/python3"

export PYTHONPATH="$PROJECT_DIR/src:${PYTHONPATH:-}"
exec "$VENV_PYTHON" -m lightroom_mcp_custom.server
