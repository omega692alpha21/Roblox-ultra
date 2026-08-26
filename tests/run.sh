#!/usr/bin/env bash
# Build pure-module copies and run the Lunch Money Legends test suite.
# Requires the `luau` CLI on PATH or at $LUAU.
set -euo pipefail
cd "$(dirname "$0")"
python3 build.py
LUAU_BIN="${LUAU:-luau}"
exec "$LUAU_BIN" run.luau
