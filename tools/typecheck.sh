#!/usr/bin/env bash
# Strict Luau type-check of the whole game against the Roblox API (luau-lsp).
# Usage: tools/typecheck.sh [path to luau-lsp] [path to globalTypes.d.luau]
set -euo pipefail
cd "$(dirname "$0")/.."
LSP="${1:-${LUAU_LSP:-luau-lsp}}"
DEFS="${2:-${ROBLOX_DEFS:-globalTypes.d.luau}}"
rojo sourcemap default.project.json -o sourcemap.json
"$LSP" analyze --platform=roblox --sourcemap=sourcemap.json --definitions="@roblox=$DEFS" --flag:LuauSolverV2=false src
