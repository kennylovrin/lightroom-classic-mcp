#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cat <<EOF
{
  "mcpServers": {
    "lightroom-classic": {
      "command": "bash",
      "args": ["-lc", "cd \"$PROJECT_DIR\" && ./scripts/start_managed_server.sh"]
    }
  }
}
EOF
