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

"/usr/local/bin/verify-appimage-dependencies" "$work/squashfs-root"

printf '[T2] dependency closure passed; launching AppImage under Xvfb\n'

# The single-quoted body is intentionally evaluated by the isolated inner shell.
# shellcheck disable=SC2016
timeout --signal=TERM --kill-after=5s 75s dbus-run-session -- xvfb-run -a sh -c '
  "$1/squashfs-root/AppRun" >"$2/app.log" 2>&1 &
  app_pid=$!
  cleanup() {
    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
  }
  trap cleanup EXIT
  for _ in $(seq 1 30); do
    window_id=$(xdotool search --name "Ghostty Studio" 2>/dev/null | sed -n "1p" || true)
    if [ -n "$window_id" ]; then
      printf "[T2] window=%s; capturing pixels\n" "$window_id"
      timeout --signal=TERM --kill-after=2s 15s \
        import -window "$window_id" "$2/render.png" || {
          status=$?
          echo "screenshot command failed or timed out (status=$status)" >&2
          cat "$2/app.log" >&2
          exit "$status"
        }
      read -r color_count deviation <<EOF
$(convert "$2/render.png" -format "%k %[fx:standard_deviation]" info:)
EOF
      awk -v colors="$color_count" -v deviation="$deviation" \
        "BEGIN { exit !(colors >= 100 && deviation >= 0.05) }" || {
          echo "window exists but rendered content lacks visual variance: colors=$color_count deviation=$deviation" >&2
          exit 1
        }
      printf "T2 rendered content: colors=%s deviation=%s\n" "$color_count" "$deviation"
      exit 0
    fi
    kill -0 "$app_pid" 2>/dev/null || { cat "$2/app.log" >&2; exit 1; }
    sleep 1
  done
  cat "$2/app.log" >&2
  echo "timed out waiting for the Ghostty Studio window" >&2
  exit 1
' sh "$work" "$work"
