#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.50"
NEW="1.3.51"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1351-builder.js' EXIT
mkdir -p "$TMP/outer" "$TMP/children" "$TARGET_DIR"
test -f "$BASE"
unzip -q "$BASE" -d "$TMP/outer"

# Rebuild every child ZIP so extension manifests and internal version strings stay coherent.
idx=0
for ZIP in "$TMP/outer"/*.zip; do
  [ -e "$ZIP" ] || continue
  idx=$((idx+1))
  NAME="$(basename "$ZIP")"
  NEWNAME="${NAME//$OLD/$NEW}"
  CHILD="$TMP/children/$idx"
  mkdir -p "$CHILD"
  unzip -q "$ZIP" -d "$CHILD"
  find "$CHILD" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.js' -o -name '*.json' -o -name '*.css' -o -name '*.txt' -o -name '*.md' \) -print0 \
    | xargs -0 -r sed -i 's/1\.3\.50/1.3.51/g'
  while IFS= read -r -d '' PHP; do php -l "$PHP" >/dev/null; done < <(find "$CHILD" -type f -name '*.php' -print0)
  rm -f "$ZIP"
  (cd "$CHILD" && zip -qr "$TMP/outer/$NEWNAME" .)
done

# Outer package manifest/text files.
find "$TMP/outer" -maxdepth 1 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.json' -o -name '*.txt' -o -name '*.md' \) -print0 \
  | xargs -0 -r sed -i 's/1\.3\.50/1.3.51/g'

# Locate and verify the rebuilt Builder source.
B="$(find "$TMP/children" -path '*/administrator/components/com_decaroforms/tmpl/builder/default.php' -print -quit)"
C="$(find "$TMP/children" -path '*/administrator/components/com_decaroforms/src/Controller/BuilderController.php' -print -quit)"
test -n "$B" && test -f "$B"
test -n "$C" && test -f "$C"
php -l "$B"
php -l "$C"
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
js='\n'.join(m.group(1) for m in re.finditer(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I))
js=re.sub(r'<\?(?:php|=).*?\?>','null',js,flags=re.S|re.I)
Path('/tmp/forms-1351-builder.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1351-builder.js

grep -q "function newRowId" "$B"
grep -q "function logicalRowNumbers" "$B"
grep -q "rowGroup.dataset.rowId=rowId" "$B"
grep -q "data-slot-target-key" "$B"
grep -q "slot.dataset.slotTargetKey" "$B"
grep -q "layoutRowState.set(rowId" "$B"
grep -q "activeStructureSelection={type:'row',id:" "$B"
grep -q "const rows=logicalRowNumbers().map" "$B"
grep -q "version:'1.3.51'" "$B"
grep -q "transactionStart" "$C"
grep -q "transactionCommit" "$C"
grep -q "transactionRollback" "$C"

# Ensure no child manifest remains at the superseded package version.
if grep -R --include='*.xml' -n '1\.3\.50' "$TMP/children" "$TMP/outer" | grep -v '/pkg_decaroforms_1.3.50.zip'; then
  echo 'Found stale 1.3.50 XML version reference' >&2
  exit 1
fi

# Rebuild canonical outer package.
(
  cd "$TMP/outer"
  zip -qr "$TARGET" .
)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

FEED="$ROOT/updates/pkg_decaroforms.xml"
python3 - "$FEED" "$NEW" "$SHA" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]);v=sys.argv[2];sha=sys.argv[3];s=p.read_text(encoding='utf-8')
s=re.sub(r'<version>[^<]+</version>',f'<version>{v}</version>',s,count=1)
s=re.sub(r'releases/[0-9.]+/pkg_decaroforms_[0-9.]+\.zip',f'releases/{v}/pkg_decaroforms_{v}.zip',s,count=1)
s=re.sub(r'<sha256>[^<]+</sha256>',f'<sha256>{sha}</sha256>',s,count=1)
p.write_text(s,encoding='utf-8')
PY

CHANGE="$ROOT/updates/changelog.xml"
python3 - "$CHANGE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')
if '<version>1.3.51</version>' not in s:
    entry='''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>1.3.51</version>\n\t\t<note>Release canonica della revisione Builder core: identità stabile delle Righe, stato accordion e metadata coerenti durante i drag, Righe vuote persistenti, slot VUOTO 50% realmente occupabili e salvataggio atomico tramite transazione database. Allineate anche le versioni interne dei pacchetti figli.</note>\n\t</changelog>'''
    pos=s.find('>')+1
    s=s[:pos]+entry+s[pos:]
    p.write_text(s,encoding='utf-8')
PY

cat > "$TARGET_DIR/README.md" <<EOF
# Forms $NEW

Canonical Builder core release:
- stable logical Row identity independent from numeric position;
- Row title/description/accordion/selection follow the Row during reorder;
- empty Rows persist and can be selected/deleted/duplicated;
- smart empty slots are real drop targets and are consumed into 50/50 layouts;
- Section duplication generates fresh Row identities;
- Builder form + field replacement save is atomic through a database transaction;
- child package versions aligned to $NEW;
- PHP and extracted JavaScript syntax checks passed during build.

SHA256: $SHA
EOF

echo "Built $TARGET"
echo "SHA256 $SHA"
