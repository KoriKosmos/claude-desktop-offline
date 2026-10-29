#!/bin/bash
# Run this ONLINE (or let the Mirror GitHub Actions workflow run it). Downloads
# the Claude desktop app's signed Windows MSIX into releases/ so the repo can be
# cloned and installed with install.ps1 on a machine whose proxy blocks
# downloads.claude.ai.
#
# Usage: ./mirror.sh [ARCH ...]
#   ARCH: x64 arm64 (default: x64)
#
# The MSIX is bigger than GitHub's 100MB per-file limit, so it's stored as
# 90MB parts (Claude.msix.part-aa, -ab, ...) plus the SHA-256 of the whole file.

set -e
cd "$(dirname "$0")"

LATEST_URL="https://claude.ai/api/desktop/win32/%s/msix/latest/redirect"
ALL_ARCHES=(x64 arm64)
PART_SIZE=90M

ARCHES=("$@")
if [ ${#ARCHES[@]} -eq 0 ]; then
    ARCHES=(x64)
fi
for arch in "${ARCHES[@]}"; do
    if [[ ! " ${ALL_ARCHES[*]} " =~ " $arch " ]]; then
        echo "Unknown arch: $arch (expected one of: ${ALL_ARCHES[*]})" >&2
        exit 1
    fi
done

for cmd in curl split; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd is required" >&2; exit 1; }
done

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

version=""
for arch in "${ARCHES[@]}"; do
    # The redirect points at .../releases/win32/<arch>/<version>/Claude-<hash>.msix
    url=$(curl -fsS -o /dev/null -w '%{redirect_url}' "$(printf "$LATEST_URL" "$arch")")
    v=$(echo "$url" | sed -nE 's#.*/win32/[^/]+/([0-9]+\.[0-9]+\.[0-9]+)/[^/]+\.msix$#\1#p')
    if [ -z "$v" ]; then
        echo "Got an unexpected download URL for $arch: $url" >&2
        exit 1
    fi
    version="$v"
    echo "Mirroring Claude desktop $v ($arch)"

    adir="releases/$v/$arch"
    if [ -f "$adir/checksum" ] && ls "$adir"/Claude.msix.part-* >/dev/null 2>&1; then
        echo "  already mirrored"
        continue
    fi
    rm -rf "$adir"
    mkdir -p "$adir"
    tmp="$adir/Claude.msix.tmp"
    curl -fSL --progress-bar -o "$tmp" "$url"
    sha256 "$tmp" > "$adir/checksum"
    split -b "$PART_SIZE" "$tmp" "$adir/Claude.msix.part-"
    rm -f "$tmp"
done

# The offline installer resolves "latest" from this file.
echo "$version" > releases/latest

echo ""
echo "Done. Commit and push:"
echo "    git add releases && git commit -m \"Mirror Claude desktop $version\" && git push"
