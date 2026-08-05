#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output_path="${1:-}"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

official_snap_url="https://api.snapcraft.io/api/v1/snaps/download/0Js0ucdWpbxjd5LqmGT5MVUywEWyNbvs_820.snap"
official_snap_sha256="dde45721e9fe0ae93852e78e26529cdda56051d1d43b0707dc7c96e5de7a0f47"
core24_url="https://api.snapcraft.io/api/v1/snaps/download/dwTAh7MZZ01zyriOZErqd1JynQLiOGvM_1643.snap"
core24_sha256="1c63b692a11edab44387e97911b9681d9010305cb9f9218c38bfbe2bedb50e45"
pkgforge_url="https://github.com/pkgforge-dev/ghostty-appimage/releases/download/v1.3.1/Ghostty-1.3.1-x86_64.AppImage"
pkgforge_sha256="fde48d2b716afd1978766879bbf1aae30dd305e8ad86a1037a2614a14d82dc28"

curl --fail --location --retry 3 "$official_snap_url" --output "$work/ghostty.snap"
curl --fail --location --retry 3 "$core24_url" --output "$work/core24.snap"
curl --fail --location --retry 3 "$pkgforge_url" --output "$work/Ghostty.AppImage"
verify_sha256() {
  local expected="$1"
  local path="$2"
  local actual
  actual="$(openssl dgst -sha256 -r "$path" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    printf 'SHA-256 mismatch for %s: expected %s, got %s\n' "$path" "$expected" "$actual" >&2
    return 1
  fi
}
verify_sha256 "$official_snap_sha256" "$work/ghostty.snap"
verify_sha256 "$core24_sha256" "$work/core24.snap"
verify_sha256 "$pkgforge_sha256" "$work/Ghostty.AppImage"
chmod 0755 "$work/Ghostty.AppImage"

docker run --rm --platform linux/amd64 \
  --volume "$work:/audit" \
  ubuntu:22.04 bash -euo pipefail -c '
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq squashfs-tools >/dev/null
    mkdir -p /snap/core24 /snap/ghostty \
      /tmp/official-home/user-data /tmp/official-home/common /tmp/pkgforge-home
    unsquashfs -d /snap/core24/current /audit/core24.snap >/dev/null
    unsquashfs -d /snap/ghostty/820 /audit/ghostty.snap >/dev/null
    ln -s 820 /snap/ghostty/current

    SNAP=/snap/ghostty/820 \
    SNAP_REAL_HOME=/tmp/official-home \
    SNAP_USER_DATA=/tmp/official-home/user-data \
    SNAP_USER_COMMON=/tmp/official-home/common \
    SNAP_REVISION=820 \
    SNAP_ARCH=amd64 \
    GHOSTTY_RESOURCES_DIR=/snap/ghostty/current/share/ghostty \
    LC_ALL=C.UTF-8 \
      /snap/ghostty/820/app/launcher /snap/ghostty/820/bin/ghostty \
      +show-config --default --docs > /audit/official.schema

    cd /tmp
    /audit/Ghostty.AppImage --appimage-extract >/dev/null
    HOME=/tmp/pkgforge-home LC_ALL=C.UTF-8 \
      /tmp/squashfs-root/AppRun +show-config --default --docs \
      > /audit/pkgforge.schema
  '

cmp "$work/official.schema" "$work/pkgforge.schema"

python3 - "$work/official.schema" "$work/pkgforge.schema" "$output_path" <<'PY'
import hashlib
import json
import pathlib
import sys

POLICY = {
    "font-size": ("number", []),
    "minimum-contrast": ("number", []),
    "background-opacity": ("number", []),
    "cursor-opacity": ("number", []),
    "unfocused-split-opacity": ("number", []),
    "background": ("color", []),
    "foreground": ("color", []),
    "selection-foreground": ("color", []),
    "selection-background": ("color", []),
    "cursor-color": ("color", []),
    "split-divider-color": ("color", []),
    "cursor-style": ("select", ["block", "bar", "underline", "block_hollow"]),
}

def parse(path):
    document = pathlib.Path(path).read_text()
    options = {}
    documentation = []
    for line in document.splitlines():
        if line.startswith("#"):
            comment = line[1:].strip()
            if comment:
                documentation.append(comment)
            continue
        if not line.strip():
            continue
        if "=" not in line:
            documentation = []
            continue
        key, value = (part.strip() for part in line.split("=", 1))
        docs = " ".join(documentation)
        documentation = []
        if key in POLICY:
            observed = options.setdefault(key, {
                "defaults": [],
                "docs_sha256": hashlib.sha256(docs.encode()).hexdigest(),
            })
            observed["defaults"].append(value)
    return document.encode(), options

official_bytes, official = parse(sys.argv[1])
pkgforge_bytes, pkgforge = parse(sys.argv[2])
if set(official) != set(POLICY) or set(pkgforge) != set(POLICY):
    raise SystemExit("audited key set is incomplete")
if official != pkgforge:
    raise SystemExit("audited defaults or documented domains differ")

record = {
    "sources": {
        "official": {
            "name": "Ghostty stable snap amd64 revision 820",
            "url": "https://api.snapcraft.io/api/v1/snaps/download/0Js0ucdWpbxjd5LqmGT5MVUywEWyNbvs_820.snap",
            "sha256": "dde45721e9fe0ae93852e78e26529cdda56051d1d43b0707dc7c96e5de7a0f47",
        },
        "pkgforge": {
            "name": "pkgforge-dev Ghostty 1.3.1 x86_64 AppImage",
            "url": "https://github.com/pkgforge-dev/ghostty-appimage/releases/download/v1.3.1/Ghostty-1.3.1-x86_64.AppImage",
            "sha256": "fde48d2b716afd1978766879bbf1aae30dd305e8ad86a1037a2614a14d82dc28",
        },
    },
    "full_schema": {
        "official_sha256": hashlib.sha256(official_bytes).hexdigest(),
        "pkgforge_sha256": hashlib.sha256(pkgforge_bytes).hexdigest(),
        "byte_identical": official_bytes == pkgforge_bytes,
    },
    "audited_contract": {
        key: {
            "kind": POLICY[key][0],
            "choices": POLICY[key][1],
            "official": official[key],
            "pkgforge": pkgforge[key],
        }
        for key in sorted(POLICY)
    },
}
rendered = json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
if sys.argv[3]:
    pathlib.Path(sys.argv[3]).write_text(rendered)
else:
    print(rendered, end="")
PY
