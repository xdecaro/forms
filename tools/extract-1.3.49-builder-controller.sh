#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"; V="1.3.49"; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$ROOT/releases/$V/pkg_decaroforms_$V.zip" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_$V.zip" -d "$TMP/c"
sed -n '1,240p' "$TMP/c/administrator/components/com_decaroforms/src/Controller/BuilderController.php" > "$ROOT/tools/audit-1.3.49-builder-controller-save.txt"
