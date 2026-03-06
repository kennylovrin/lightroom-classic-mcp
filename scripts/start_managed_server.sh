#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

SKIP_INSTALL="${LIGHTROOM_SKIP_INSTALL:-0}"
FORCE_RESTART="${LIGHTROOM_FORCE_RESTART:-0}"
WAIT_SECONDS="${LIGHTROOM_WAIT_SECONDS:-120}"
PORT_FILE="/tmp/lightroom_mcp_custom_ports.json"
LIGHTROOM_APP="${LIGHTROOM_APP:-Adobe Lightroom Classic}"
LIGHTROOM_APP_PATH="${LIGHTROOM_APP_PATH:-/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app}"
LIGHTROOM_BIN_PATH="${LIGHTROOM_BIN_PATH:-/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app/Contents/MacOS/Adobe Lightroom Classic}"
REQUIRE_LIVE_PORTS="${LIGHTROOM_REQUIRE_LIVE_PORTS:-0}"
AUTO_LAUNCH="${LIGHTROOM_AUTO_LAUNCH:-0}"

is_lightroom_running() {
  pgrep -f "$LIGHTROOM_BIN_PATH" >/dev/null 2>&1
}

open_lightroom_if_needed() {
  if ! is_lightroom_running; then
    if [[ -d "$LIGHTROOM_APP_PATH" ]]; then
      open "$LIGHTROOM_APP_PATH"
    else
      open -a "$LIGHTROOM_APP"
    fi
  fi
}

wait_for_bridge_ready() {
  local deadline=$((SECONDS + WAIT_SECONDS))
  while true; do
    if [[ -f "$PORT_FILE" ]]; then
      if python3 - "$PORT_FILE" "$REQUIRE_LIVE_PORTS" <<'PY'
import json
import socket
import sys
from pathlib import Path

path = Path(sys.argv[1])
require_live_ports = str(sys.argv[2]) == "1"
try:
    data = json.loads(path.read_text())
    send_port = int(data["send_port"])
    recv_port = int(data["receive_port"])
except Exception:
    sys.exit(2)

if not require_live_ports:
    sys.exit(0)

def can_connect(port: int) -> bool:
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.5):
            return True
    except Exception:
        return False

sys.exit(0 if (can_connect(send_port) and can_connect(recv_port)) else 1)
PY
      then
        return 0
      fi
    fi

    if (( SECONDS >= deadline )); then
      return 1
    fi
    sleep 0.5
  done
}

if [[ "$SKIP_INSTALL" != "1" ]]; then
  ./scripts/install_plugin.sh >&2
fi

if [[ "$FORCE_RESTART" == "1" ]]; then
  pkill -f "$LIGHTROOM_BIN_PATH" >/dev/null 2>&1 || true
  sleep 2
  rm -f "$PORT_FILE"
  open_lightroom_if_needed
else
  if is_lightroom_running; then
    :
  elif [[ "$AUTO_LAUNCH" == "1" ]]; then
    open_lightroom_if_needed
  else
    echo "Lightroom Classic is not running." >&2
    echo "Open Lightroom first, or re-run with LIGHTROOM_AUTO_LAUNCH=1." >&2
    exit 1
  fi
fi

if ! wait_for_bridge_ready; then
  if [[ "$AUTO_LAUNCH" == "1" || "$FORCE_RESTART" == "1" ]]; then
    echo "Bridge was not ready on first attempt; retrying with one forced Lightroom restart..." >&2
    pkill -f "$LIGHTROOM_BIN_PATH" >/dev/null 2>&1 || true
    sleep 2
    rm -f "$PORT_FILE"
    open_lightroom_if_needed
    if ! wait_for_bridge_ready; then
      echo "Timed out waiting for live Lightroom bridge: $PORT_FILE" >&2
      echo "Check Lightroom Plug-in Manager: ensure 'Lightroom MCP Custom' is enabled." >&2
      exit 1
    fi
  else
    echo "Timed out waiting for live Lightroom bridge: $PORT_FILE" >&2
    echo "Check Lightroom Plug-in Manager and ensure Lightroom MCP Custom is enabled." >&2
    echo "If you want Codex or Claude to open Lightroom automatically, set LIGHTROOM_AUTO_LAUNCH=1." >&2
    exit 1
  fi
fi

echo "Lightroom bridge ready: $(cat "$PORT_FILE")" >&2
echo "Starting MCP server (long-lived mode)..." >&2

exec ./scripts/run_server.sh
