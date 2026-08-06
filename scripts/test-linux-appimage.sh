#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
driver_root="$project_root/tests/linux/.tauri-driver-root"
driver_bin="$project_root/tests/linux/.tauri-driver-bin"
cleanup() {
  rm -rf -- "$driver_root"
  rm -f -- "$driver_bin"
}
trap cleanup EXIT

appimage="${1:-}"
if [[ -z "$appimage" ]]; then
  appimage="$(find "$project_root/src-tauri/target/release/bundle/appimage" -maxdepth 1 -type f -name '*.AppImage' -print -quit)"
fi
[[ -f "$appimage" ]] || { echo "AppImage not found" >&2; exit 1; }

printf '[T2] building clean AppImage smoke image\n'
timeout --signal=TERM --kill-after=10s 5m \
  docker build --platform linux/amd64 -t ghostty-studio-appimage-smoke "$project_root/tests/linux"
printf '[T2] checking dependency closure and rendered pixels\n'
timeout --signal=TERM --kill-after=10s 2m \
  docker run --rm --platform linux/amd64 --read-only --tmpfs /tmp:exec \
  --tmpfs /home/smoke:uid=10001,gid=10001,mode=700 \
  -v "$(cd -- "$(dirname -- "$appimage")" && pwd):/artifacts:ro" \
  ghostty-studio-appimage-smoke "/artifacts/$(basename -- "$appimage")"

printf '[T3] compiling pinned tauri-driver on the native runner\n'
timeout --signal=TERM --kill-after=10s 5m \
  cargo install tauri-driver --version 2.0.6 --locked --debug --root "$driver_root"
install -m 0755 "$driver_root/bin/tauri-driver" "$driver_bin"

printf '[T3] building real Ghostty 1.3.1 E2E image\n'
timeout --signal=TERM --kill-after=10s 5m docker build --platform linux/amd64 \
  -f "$project_root/tests/linux/Dockerfile.e2e" \
  -t ghostty-studio-appimage-e2e \
  "$project_root/tests/linux"
printf '[T3] running AppImage/WebDriver/apply/restore loop with isolated HOME\n'
timeout --signal=TERM --kill-after=10s 5m \
  docker run --rm --platform linux/amd64 --read-only --shm-size=1g --tmpfs /tmp:exec \
  --tmpfs /home/smoke:uid=10001,gid=10001,mode=700 \
  -v "$(cd -- "$(dirname -- "$appimage")" && pwd):/artifacts:ro" \
  ghostty-studio-appimage-e2e "/artifacts/$(basename -- "$appimage")"
