#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.48"
NEW="1.3.49"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1349-builder.js' EXIT
mkdir -p "$TMP/outer" "$TMP/component" "$TARGET_DIR"
test -f "$BASE"
unzip -q "$BASE" -d "$TMP/outer"
COMP_OLD="$TMP/outer/com_decaroforms_$OLD.zip"
test -f "$COMP_OLD"
unzip -q "$COMP_OLD" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
test -f "$B"

python3 - "$B" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
old="activeFieldKey=field?.key||activeFieldKey;activeStructureSelection={type:'row',row:newRow};layoutRowState.set(newRow,true);return true;"
new="activeFieldKey=field?.key||activeFieldKey;activeStructureSelection={type:'row',row:newRow};return true;"
if old not in s:
    raise SystemExit('1.3.49: forced row-open anchor missing')
s=s.replace(old,new,1)
s=s.replace("version:'1.3.48'","version:'1.3.49'")
s=s.replace('version: "1.3.48"','version: "1.3.49"')
p.write_text(s,encoding='utf-8')
PY

find "$TMP/component" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.js' -o -name '*.json' \) -print0 | xargs -0 sed -i 's/1\.3\.48/1.3.49/g'
find "$TMP/outer" -maxdepth 1 -type f -name '*.xml' -print0 | xargs -0 sed -i 's/1\.3\.48/1.3.49/g'

php -l "$B"
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
js='\n'.join(m.group(1) for m in re.finditer(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I))
js=re.sub(r'<\?(?:php|=).*?\?>','null',js,flags=re.S|re.I)
Path('/tmp/forms-1349-builder.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1349-builder.js

grep -q "const openState=layoutRowState.has(rowNo)" "$B"
grep -q "nextRowState.forEach" "$B"
grep -q "activeStructureSelection={type:'row',row:newRow};return true;" "$B"
! grep -q "layoutRowState.set(newRow,true)" "$B"
grep -q "function smartMoveToSlot" "$B"
grep -q "offset_before" "$B"
grep -q "version:'1.3.49'" "$B"

rm -f "$TMP/outer/com_decaroforms_$OLD.zip"
(
 cd "$TMP/component"
 zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .
)
for f in "$TMP/outer"/*"$OLD"*.zip; do
 [ -e "$f" ] || continue
 mv "$f" "${f//$OLD/$NEW}"
done
(
 cd "$TMP/outer"
 zip -qr "$TARGET" .
)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

FEED="$ROOT/updates/pkg_decaroforms.xml"
python3 - "$FEED" "$NEW" "$SHA" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); v=sys.argv[2]; sha=sys.argv[3]; s=p.read_text(encoding='utf-8')
s=re.sub(r'<version>[^<]+</version>',f'<version>{v}</version>',s,count=1)
s=re.sub(r'releases/[0-9.]+/pkg_decaroforms_[0-9.]+\.zip',f'releases/{v}/pkg_decaroforms_{v}.zip',s,count=1)
s=re.sub(r'<sha256>[^<]+</sha256>',f'<sha256>{sha}</sha256>',s,count=1)
p.write_text(s,encoding='utf-8')
PY

CHANGE="$ROOT/updates/changelog.xml"
if [ -f "$CHANGE" ]; then
python3 - "$CHANGE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
if '<version>1.3.49</version>' not in s:
 entry='''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>1.3.49</version>\n\t\t<note>Builder: corretto lo stato accordion dopo il trascinamento di una Riga. La Riga mantiene il proprio stato aperto/chiuso invece di essere forzata aperta. I titoli automatici Riga N continuano a seguire la nuova posizione; eventuali titoli personalizzati seguono il blocco.</note>\n\t</changelog>'''
 pos=s.find('>')+1
 s=s[:pos]+entry+s[pos:]
 p.write_text(s,encoding='utf-8')
PY
fi

echo "Built $TARGET"
echo "SHA256 $SHA"
