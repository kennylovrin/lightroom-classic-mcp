#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_SRC="$PROJECT_DIR/plugin/LightroomMCPCustom.lrplugin"
LIGHTROOM_ROOT="${LIGHTROOM_ROOT:-$HOME/Library/Application Support/Adobe/Lightroom}"
WRITE_PREFS="${LIGHTROOM_WRITE_PREFS:-1}"

DESTINATIONS=(
  "$LIGHTROOM_ROOT/Modules/LightroomMCPCustom.lrplugin"
  "$LIGHTROOM_ROOT/Modules/LightroomMCPCustom.lrdevplugin"
  "$LIGHTROOM_ROOT/Plugins/LightroomMCPCustom.lrplugin"
)

for dst in "${DESTINATIONS[@]}"; do
  mkdir -p "$(dirname "$dst")"
  rm -rf "$dst"
  cp -R "$PLUGIN_SRC" "$dst"
  echo "Installed plugin to: $dst"
done

PREFERRED_PATH="$LIGHTROOM_ROOT/Modules/LightroomMCPCustom.lrdevplugin"
if [[ "$WRITE_PREFS" == "1" ]]; then
  PREF_VALUE=$(cat <<EOF
t = {
	["$PREFERRED_PATH"] = true,
}
EOF
  )
  defaults write com.adobe.LightroomClassicCC7 AgSdkPluginLoader_installedPluginPaths -string "$PREF_VALUE"

  DISABLED_PREF_VALUE=$(cat <<'EOF'
t = {
}
EOF
  )
  defaults write com.adobe.LightroomClassicCC7 AgSdkPluginLoader_disabledPluginPaths -string "$DISABLED_PREF_VALUE"
  echo "Updated Lightroom plugin loader prefs with: $PREFERRED_PATH"
else
  echo "Skipped Lightroom plugin loader preference update."
fi

echo "If bridge still does not start, open Lightroom Plug-in Manager and add:"
echo "  $PREFERRED_PATH"
