#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "--uninstall" ]; then
  DEST="${2:-$HOME/.local/share/kwin/tabbox/circular}"
  rm -rf "$DEST"
  echo "Removed $DEST"
  exit 0
fi

DEST="${1:-$HOME/.local/share/kwin/tabbox/circular}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$DEST"
cp -r "$SCRIPT_DIR"/contents "$SCRIPT_DIR"/metadata.json "$DEST"/

echo "Done. Select \"Circular Alt+Tab\" in System Settings → Window Management → Task Switcher."
