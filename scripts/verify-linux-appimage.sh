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
while read -r library; do
  if ! find "$extract_root/squashfs-root" -type f -name "$library" -print -quit | grep -q .; then
    echo "unresolved shared library in AppImage: $library" >&2
    exit 1
  fi
done < <(ldd "$binary" | awk '/not found/ { print $1 }')

if grep -R -a -l -F -- "${HOME:?HOME must be set}/" "$extract_root/squashfs-root" >/dev/null 2>&1; then
  echo "AppImage contains the local build home path" >&2
  exit 1
fi
