#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

lua5.1 scripts/check-toc.lua BattleBuddy
luacheck --no-color BattleBuddy tests scripts

failed=0
for t in tests/*_test.lua; do
    if lua5.1 "$t" . >/dev/null; then
        echo "ok   $t"
    else
        echo "FAIL $t"
        failed=1
    fi
done
exit "$failed"
