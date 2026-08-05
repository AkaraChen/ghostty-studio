#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
appimage="${1:-}"
if [[ -z "$appimage" ]]; then
  appimage="$(find "$project_root/src-tauri/target/release/bundle/appimage" -maxdepth 1 -type f -name '*.AppImage' -print -quit)"
fi
[[ -f "$appimage" ]] || { echo "AppImage not found" >&2; exit 1; }

docker build -t ghostty-studio-appimage-smoke "$project_root/tests/linux"
docker run --rm --read-only --tmpfs /tmp:exec --tmpfs /home/smoke \
  -v "$(cd -- "$(dirname -- "$appimage")" && pwd):/artifacts:ro" \
  ghostty-studio-appimage-smoke "/artifacts/$(basename -- "$appimage")"
