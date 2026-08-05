#!/usr/bin/env bash
set -euo pipefail

appdir="${1:?extracted AppDir path is required}"
binary="$appdir/usr/bin/ghostty-studio"
[[ -x "$binary" ]] || { echo "AppImage binary is missing: $binary" >&2; exit 1; }

mapfile -t library_directories < <(
  find "$appdir" -type f -name '*.so*' -print0 \
    | xargs -0 -r -n1 dirname \
    | sort -u
)
[[ "${#library_directories[@]}" -gt 0 ]] || {
  echo "AppImage contains no bundled shared-library directories" >&2
  exit 1
}
library_path="$(IFS=:; echo "${library_directories[*]}")"

needed_count="$(readelf -d "$binary" | awk '/\(NEEDED\)/ { count += 1 } END { print count + 0 }')"
[[ "$needed_count" -gt 0 ]] || {
  echo "ELF dependency table is empty" >&2
  exit 1
}

dependencies="$(LD_LIBRARY_PATH="$library_path" ldd "$binary")"
printf '%s\n' "$dependencies"
if grep -q 'not found' <<<"$dependencies"; then
  echo "AppImage has unresolved runtime dependencies in the clean container" >&2
  exit 1
fi

webkit_path="$(awk '/libwebkit2gtk-4\.1\.so\.0/ { print $3; exit }' <<<"$dependencies")"
[[ "$webkit_path" == "$appdir"/* ]] || {
  echo "WebKitGTK was not resolved from inside the AppImage: ${webkit_path:-missing}" >&2
  exit 1
}
printf 'Dependency closure: %s NEEDED entries; bundled WebKitGTK=%s\n' "$needed_count" "$webkit_path"
