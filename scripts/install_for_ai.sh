#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVER_NAME="lightroom-classic"
CLIENT="both"
CLAUDE_SCOPE="local"
SKIP_PLUGIN=0
SKIP_RUNTIME=0
AUTO_LAUNCH=0

usage() {
  cat <<'EOF'
Usage: ./scripts/install_for_ai.sh [options]

Options:
  --client <codex|claude|both|none>  Which client(s) to configure. Default: both
  --claude-scope <local|project|user>
                                     Claude MCP config scope. Default: local
  --auto-launch                      Let the registered MCP command open Lightroom if needed
  --skip-plugin                      Do not reinstall the Lightroom plugin bundle
  --skip-runtime                     Do not bootstrap the Python runtime
  -h, --help                         Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --client)
      CLIENT="${2:-}"
      shift 2
      ;;
    --claude-scope)
      CLAUDE_SCOPE="${2:-}"
      shift 2
      ;;
    --auto-launch)
      AUTO_LAUNCH=1
      shift
      ;;
    --skip-plugin)
      SKIP_PLUGIN=1
      shift
      ;;
    --skip-runtime)
      SKIP_RUNTIME=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$CLIENT" in
  codex|claude|both|none) ;;
  *)
    echo "Invalid --client value: $CLIENT" >&2
    exit 1
    ;;
esac

case "$CLAUDE_SCOPE" in
  local|project|user) ;;
  *)
    echo "Invalid --claude-scope value: $CLAUDE_SCOPE" >&2
    exit 1
    ;;
esac

if [[ "$SKIP_PLUGIN" != "1" ]]; then
  "$PROJECT_DIR/scripts/install_plugin.sh"
fi

if [[ "$SKIP_RUNTIME" != "1" ]]; then
  "$PROJECT_DIR/scripts/bootstrap_runtime.sh"
fi

register_codex() {
  if ! command -v codex >/dev/null 2>&1; then
    echo "Skipped Codex setup: 'codex' command not found." >&2
    return 0
  fi

  codex mcp remove "$SERVER_NAME" >/dev/null 2>&1 || true
  if [[ "$AUTO_LAUNCH" == "1" ]]; then
    codex mcp add "$SERVER_NAME" --env LIGHTROOM_AUTO_LAUNCH=1 -- bash -lc "cd \"$PROJECT_DIR\" && ./scripts/start_managed_server.sh"
  else
    codex mcp add "$SERVER_NAME" -- bash -lc "cd \"$PROJECT_DIR\" && ./scripts/start_managed_server.sh"
  fi
}

register_claude() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "Skipped Claude setup: 'claude' command not found." >&2
    return 0
  fi

  claude mcp remove "$SERVER_NAME" -s "$CLAUDE_SCOPE" >/dev/null 2>&1 || true
  if [[ "$AUTO_LAUNCH" == "1" ]]; then
    claude mcp add -s "$CLAUDE_SCOPE" -e LIGHTROOM_AUTO_LAUNCH=1 "$SERVER_NAME" -- bash -lc "cd \"$PROJECT_DIR\" && ./scripts/start_managed_server.sh"
  else
    claude mcp add -s "$CLAUDE_SCOPE" "$SERVER_NAME" -- bash -lc "cd \"$PROJECT_DIR\" && ./scripts/start_managed_server.sh"
  fi
}

case "$CLIENT" in
  codex)
    register_codex
    ;;
  claude)
    register_claude
    ;;
  both)
    register_codex
    register_claude
    ;;
  none)
    ;;
esac

cat <<EOF

Lightroom Classic MCP install complete.

Project: $PROJECT_DIR
Server name: $SERVER_NAME
Configured client target: $CLIENT
Auto-launch Lightroom: $AUTO_LAUNCH

Next step:
  Start the MCP server from your client, or test locally with:
  cd "$PROJECT_DIR" && ./scripts/start_managed_server.sh
EOF
