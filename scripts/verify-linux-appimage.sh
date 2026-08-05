#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "usage: $0 <AppImage>" >&2
  exit 2
fi

appimage="$(cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")"
[[ -f "$appimage" ]] || { echo "AppImage not found: $appimage" >&2; exit 1; }
file "$appimage" | grep -Eq 'ELF 64-bit.*x86-64'

extract_root="$(mktemp -d)"
cleanup() {
  rm -rf -- "$extract_root"
}
trap cleanup EXIT
(
  cd "$extract_root"
  chmod +x "$appimage"
  "$appimage" --appimage-extract >/dev/null
)

binary="$extract_root/squashfs-root/usr/bin/ghostty-studio"
[[ -x "$binary" ]] || { echo "main binary missing from AppImage" >&2; exit 1; }
file "$binary" | grep -Eq 'ELF 64-bit.*x86-64'
needed_count="$(readelf -d "$binary" | awk '/\(NEEDED\)/ { count += 1 } END { print count + 0 }')"
[[ "$needed_count" -gt 0 ]] || { echo "ELF dependency table is empty" >&2; exit 1; }
printf 'Static dependency table: %s NEEDED entries (runtime closure is checked in the clean container)\n' "$needed_count"

if grep -R -a -l -F -- "${HOME:?HOME must be set}/" "$extract_root/squashfs-root" >/dev/null 2>&1; then
  echo "AppImage contains the local build home path" >&2
  exit 1
fi
