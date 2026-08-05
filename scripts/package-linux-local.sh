#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  echo "package:linux-local requires x86_64 Linux" >&2
  exit 1
fi

for required_tool in pnpm node cargo file ldd sha256sum grep find awk; do
  if ! command -v "$required_tool" >/dev/null 2>&1; then
    echo "missing required tool: $required_tool" >&2
    exit 1
  fi
done

build_user_home="${HOME:?HOME must be set for release path remapping}"
release_rustflags="${RUSTFLAGS:-}"
if [[ -n "$release_rustflags" ]]; then
  release_rustflags+=" "
fi
release_rustflags+="--remap-path-prefix=$build_user_home=/build/home"

RUSTFLAGS="$release_rustflags" pnpm tauri build --bundles appimage --ci -- --locked

mapfile -t appimages < <(find src-tauri/target/release/bundle/appimage -maxdepth 1 -type f -name '*.AppImage' -print)
if [[ "${#appimages[@]}" -ne 1 ]]; then
  echo "expected exactly one AppImage, found ${#appimages[@]}" >&2
  exit 1
fi

scripts/verify-linux-appimage.sh "${appimages[0]}"
checksum="$(sha256sum "${appimages[0]}" | awk '{print $1}')"
printf 'Created %s\nSHA-256 %s\n' "${appimages[0]}" "$checksum"
