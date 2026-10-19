#!/usr/bin/env bash
# Deduplicated type-check output (one line per error)
cd "$(dirname "$0")/.."
LUAU_LSP=${LUAU_LSP:-/root/tools/luau-lsp/build/luau-lsp} ROBLOX_DEFS=${ROBLOX_DEFS:-/root/tools/luau-lsp/scripts/globalTypes.None.d.luau} tools/typecheck.sh 2>&1 | grep -E "^/.*\([0-9]+,[0-9]+\)" | sed -E 's#^/home/user/Sport-Battlegrounds/##; s# \[game/[^]]*\]##' | sort -u -t: -k1,1 -k2 | awk '!seen[$0]++'
