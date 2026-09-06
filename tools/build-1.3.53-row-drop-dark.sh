#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.52"
NEW="1.3.53"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1353-builder.js' EXIT
mkdir -p "$TMP/outer" "$TMP/children" "$TARGET_DIR"
test -f "$BASE"
unzip -q "$BASE" -d "$TMP/outer"
idx=0
BUILDER=""
for ZIP in "$TMP/outer"/*.zip; do
  [ -e "$ZIP" ] || continue
  idx=$((idx+1))
  NAME="$(basename "$ZIP")"
  NEWNAME="${NAME//$OLD/$NEW}"
  CHILD="$TMP/children/$idx"
  mkdir -p "$CHILD"
  unzip -q "$ZIP" -d "$CHILD"
  find "$CHILD" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.js' -o -name '*.json' -o -name '*.css' -o -name '*.txt' -o -name '*.md' \) -print0 | xargs -0 -r sed -i 's/1\.3\.52/1.3.53/g'
  CANDIDATE="$CHILD/administrator/components/com_decaroforms/tmpl/builder/default.php"
  if [ -f "$CANDIDATE" ]; then BUILDER="$CANDIDATE"; fi
done
test -n "$BUILDER" && test -f "$BUILDER"
python3 - "$BUILDER" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')
old='[data-bs-theme="dark"] body.df-structure-drag-active .df-layout-row-group.is-row-drop-before::before,[data-bs-theme="dark"] body.df-structure-drag-active .df-layout-row-group.is-row-drop-after::after'
new='[data-bs-theme="dark"] .df-layout-row-group.is-row-drop-before::before,[data-bs-theme="dark"] .df-layout-row-group.is-row-drop-after::after'
if old not in s: raise SystemExit('1.3.53 dark selector anchor missing')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
PY
idx=0
for ZIP in "$TMP/outer"/*.zip; do
  [ -e "$ZIP" ] || continue
  idx=$((idx+1))
  NAME="$(basename "$ZIP")"
  NEWNAME="${NAME//$OLD/$NEW}"
  CHILD="$TMP/children/$idx"
  while IFS= read -r -d '' PHP; do php -l "$PHP" >/dev/null; done < <(find "$CHILD" -type f -name '*.php' -print0)
  rm -f "$ZIP"
  (cd "$CHILD" && zip -qr "$TMP/outer/$NEWNAME" .)
done
find "$TMP/outer" -maxdepth 1 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.json' -o -name '*.txt' -o -name '*.md' \) -print0 | xargs -0 -r sed -i 's/1\.3\.52/1.3.53/g'
php -l "$BUILDER"
python3 - "$BUILDER" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
js='\n'.join(m.group(1) for m in re.finditer(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I))
js=re.sub(r'<\?(?:php|=).*?\?>','null',js,flags=re.S|re.I)
Path('/tmp/forms-1353-builder.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1353-builder.js
grep -q "function structureRowDropSpec" "$BUILDER"
grep -q "dist<=40" "$BUILDER"
grep -q '\[data-bs-theme="dark"\] .df-layout-row-group.is-row-drop-before::before' "$BUILDER"
grep -q "version:'1.3.53'" "$BUILDER"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
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
if '<version>1.3.53</version>' not in s:
    entry='''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>1.3.53</version>\n\t\t<note>Consolidamento del nuovo drag Righe 50/50 introdotto in 1.3.52: corretto il selettore dark mode dell’overlay SOPRA/SOTTO per funzionare indipendentemente dal nodo su cui Joomla applica data-bs-theme. Nessuna modifica al modello dati o alla logica di riordino.</note>\n\t</changelog>'''
    pos=s.find('>')+1;s=s[:pos]+entry+s[pos:];p.write_text(s,encoding='utf-8')
PY
cat > "$TARGET_DIR/README.md" <<EOF
# Forms $NEW

Row drag UX consolidated release:
- full 50/50 Row drop surface preserved;
- upper half = SOPRA, lower half = SOTTO;
- centre hysteresis and 40px gap tolerance preserved;
- dark-mode target overlay selector made robust for Joomla theme placement;
- stable Row IDs and all 1.3.51/1.3.52 behavior preserved;
- PHP and extracted JavaScript syntax checks passed.

SHA256: $SHA
EOF
echo "Built $TARGET"
echo "SHA256 $SHA"
