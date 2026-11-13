#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SOURCE="$PWD/build/Tab Switcher Pro.app"
DEST="$HOME/Applications/Tab Switcher Pro.app"
if [[ ! -d "$SOURCE" ]]; then ./scripts/build.sh; fi
if pgrep -x TabSwitcherPro >/dev/null; then
  echo 'Quit Tab Switcher Pro from its menu before installing.' >&2
  exit 1
fi
mkdir -p "$HOME/Applications"
ditto "$SOURCE" "$DEST"
printf 'Installed: %s\nOpen this application in Finder, then grant permissions through System Settings.\n' "$DEST"
