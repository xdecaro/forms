#!/usr/bin/env bash
set -euo pipefail
TMP_SCRIPT="$(mktemp)"
trap 'rm -f "$TMP_SCRIPT"' EXIT
cp tools/build-1.3.61-uniform-structure-drag.sh "$TMP_SCRIPT"
sed -i 's/min-height:68px!important/min-height:68px/g' "$TMP_SCRIPT"
bash "$TMP_SCRIPT"
