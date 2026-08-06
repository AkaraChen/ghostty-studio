#!/usr/bin/env bash
set -euo pipefail

appimage="${1:?AppImage path is required}"
mkdir -p "$HOME/.config/ghostty"
cat >"$HOME/.config/ghostty/config" <<'EOF'
# cross-platform setting must survive every write
macos-titlebar-style = native
font-size = 13
EOF
cp "$HOME/.config/ghostty/config" /tmp/original-config

export PATH="/usr/local/bin:/usr/bin:/bin"
export APPIMAGE_EXTRACT_AND_RUN=1
export NO_AT_BRIDGE=1

ghostty_version="$(ghostty --version)"
[[ "$ghostty_version" == *"1.3.1"* ]] || {
  echo "unexpected real Ghostty version: $ghostty_version" >&2
  exit 1
}

dbus-run-session -- xvfb-run -a python3 \
  /usr/local/lib/ghostty-studio/e2e_appimage.py \
  "$appimage" "$HOME/.config/ghostty/config" /tmp/original-config
