#!/usr/bin/env bash
set -euo pipefail

appimage="${1:?AppImage path is required}"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
cd "$work"
"$appimage" --appimage-extract >/dev/null

mkdir -p "$HOME/.config/ghostty" "$HOME/.local/bin"
printf 'font-size = 13\n' >"$HOME/.config/ghostty/config"
cat >"$HOME/.local/bin/ghostty" <<'EOF'
#!/bin/sh
case "${1:-}" in
  --version) printf 'Ghostty 1.3.1\n' ;;
  +show-config) printf '# Font size.\nfont-size = 13\n' ;;
  +validate-config) exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod 0755 "$HOME/.local/bin/ghostty"
export PATH="$HOME/.local/bin:/usr/bin:/bin"
export WEBKIT_DISABLE_DMABUF_RENDERER=1

# The single-quoted body is intentionally evaluated by the isolated inner shell.
# shellcheck disable=SC2016
dbus-run-session -- xvfb-run -a sh -c '
  "$1/squashfs-root/AppRun" >"$2/app.log" 2>&1 &
  app_pid=$!
  trap "kill $app_pid 2>/dev/null || true" EXIT
  for _ in $(seq 1 30); do
    if xdotool search --name "Ghostty Studio" >/dev/null 2>&1; then
      exit 0
    fi
    kill -0 "$app_pid" 2>/dev/null || { cat "$2/app.log" >&2; exit 1; }
    sleep 1
  done
  cat "$2/app.log" >&2
  exit 1
' sh "$work" "$work"
