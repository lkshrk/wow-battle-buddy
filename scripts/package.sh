#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:?usage: scripts/package.sh <version>}"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

cp -R BattleBuddy "$stage/BattleBuddy"
rm -f "$stage/BattleBuddy/pkgmeta.yaml"
cp LICENSE "$stage/BattleBuddy/LICENSE"
mkdir -p "$stage/BattleBuddy/Licenses"
cp third_party/pbs/LICENSE.md "$stage/BattleBuddy/Licenses/PBS-LICENSE.md"
sed -i.bak "s/@project-version@/$version/" "$stage/BattleBuddy/BattleBuddy.toc"
rm -f "$stage/BattleBuddy/BattleBuddy.toc.bak"

lua5.1 scripts/check-toc.lua "$stage/BattleBuddy"
if find "$stage/BattleBuddy" -name '*.md' ! -path '*/Licenses/*' | grep -q .; then
    echo "unexpected markdown in package" >&2
    exit 1
fi

mkdir -p dist
archive="dist/BattleBuddy-$version.zip"
rm -f "$archive"
(cd "$stage" && zip -qr "$OLDPWD/$archive" BattleBuddy)
shasum -a 256 "$archive" | tee "$archive.sha256"
