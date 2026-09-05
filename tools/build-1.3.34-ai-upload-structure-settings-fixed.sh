#!/usr/bin/env bash
set -euo pipefail
TMP_SCRIPT="$(mktemp)"
trap 'rm -f "$TMP_SCRIPT"' EXIT
sed 's/data-ai-main-label/df-ai-main-label/g' tools/build-1.3.34-ai-upload-structure-settings.sh > "$TMP_SCRIPT"
bash "$TMP_SCRIPT"
