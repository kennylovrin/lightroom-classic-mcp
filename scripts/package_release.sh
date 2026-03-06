#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
STAGING_DIR="$DIST_DIR/release-staging"
cd "$PROJECT_DIR"
VERSION="$(python3 - <<'PY'
from pathlib import Path
import re

text = Path("pyproject.toml").read_text(encoding="utf-8")
match = re.search(r'^version = "([^"]+)"', text, re.M)
if not match:
    raise SystemExit("Could not determine version from pyproject.toml")
print(match.group(1))
PY
)"

mkdir -p "$DIST_DIR"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

rsync -a \
  --exclude '.git' \
  --exclude '.github' \
  --exclude '.pytest_cache' \
  --exclude '.venv' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude '*.pyo' \
  --exclude '*.egg-info' \
  --exclude 'build' \
  --exclude 'dist' \
  --exclude 'plugin/LightroomMCPCustom.lrplugin/*.backup.*' \
  "$PROJECT_DIR/" "$STAGING_DIR/lightroom-classic-mcp/"

(cd "$STAGING_DIR" && zip -qr "$DIST_DIR/lightroom-classic-mcp-$VERSION-source.zip" lightroom-classic-mcp)
(cd "$PROJECT_DIR/plugin" && zip -qr "$DIST_DIR/lightroom-classic-mcp-$VERSION-plugin.zip" LightroomMCPCustom.lrplugin)

echo "Created:"
echo "  $DIST_DIR/lightroom-classic-mcp-$VERSION-source.zip"
echo "  $DIST_DIR/lightroom-classic-mcp-$VERSION-plugin.zip"
