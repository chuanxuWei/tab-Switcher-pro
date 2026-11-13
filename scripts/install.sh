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
touch "$DEST"
REGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
if [[ -x "$REGISTER" ]]; then "$REGISTER" -f "$DEST"; fi
printf 'Installed: %s\nOpen this application in Finder, then grant permissions through System Settings.\n' "$DEST"
