#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TMP="$(mktemp -d)"
OUT="$ROOT/tools/inspect-1.2.22"
rm -rf "$OUT"
mkdir -p "$OUT/files"
unzip -q "$ROOT/releases/1.2.22/pkg_decaroforms_1.2.22.zip" -d "$TMP/outer"
mkdir -p "$TMP/unpacked"
cp -R "$TMP/outer/." "$TMP/unpacked/outer/"
while IFS= read -r z; do
  name="$(basename "$z" .zip)"
  mkdir -p "$TMP/unpacked/$name"
  unzip -q "$z" -d "$TMP/unpacked/$name" || true
done < <(find "$TMP/outer" -type f -name '*.zip' | sort)
find "$TMP/unpacked" -type f | sed "s#^$TMP/unpacked/##" | sort > "$OUT/tree.txt"
# Save all text implementation/configuration files so the next release can be reviewed safely.
while IFS= read -r f; do
  rel="${f#$TMP/unpacked/}"
  dest="$OUT/files/$rel"
  mkdir -p "$(dirname "$dest")"
  cp "$f" "$dest"
done < <(find "$TMP/unpacked" -type f \( -name '*.php' -o -name '*.js' -o -name '*.css' -o -name '*.xml' -o -name '*.ini' -o -name '*.json' -o -name '*.txt' \) | sort)
printf 'Inspection generated from Forms 1.2.22\n' > "$OUT/README.txt"
