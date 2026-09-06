#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.47"
NEW="1.3.48"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1348-builder.js' EXIT
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
import re,sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')

row_blocks=r'''function structureRowBlocks(){
 normalizeLayoutRows();
 const meta=builderConfig?.layout?.row_meta&&typeof builderConfig.layout.row_meta==='object'?builderConfig.layout.row_meta:{};
 return [...new Set(selected.map(f=>Number(f.config?.layout?.row||1)))].sort((a,b)=>a-b).map(rowNo=>{
  const fields=fieldsInRow(rowNo).map(([f])=>f);
  const storedMeta=meta[String(rowNo)]&&typeof meta[String(rowNo)]==='object'?clone(meta[String(rowNo)]):null;
  const openState=layoutRowState.has(rowNo)?!!layoutRowState.get(rowNo):null;
  return{rowNo,fields,meta:storedMeta,sectionKey:fields.find(isLayoutSectionField)?.key||null,openState};
 });
}
'''
apply_blocks=r'''function structureApplyBlocks(blocks){
 builderConfig=builderConfig&&typeof builderConfig==='object'?builderConfig:{};
 builderConfig.layout=builderConfig.layout&&typeof builderConfig.layout==='object'?builderConfig.layout:{};
 const nextMeta={},ordered=[],nextRowState=new Map();
 blocks.forEach((block,bi)=>{
  const row=bi+1;
  if(block.meta&&typeof block.meta==='object')nextMeta[String(row)]=clone(block.meta);
  if(block.openState!==null&&block.openState!==undefined)nextRowState.set(row,!!block.openState);
  block.fields.forEach((f,ci)=>{
   defaultFieldConfig(f);
   f.config.layout={...(f.config.layout||{}),row,col:ci+1};
   ordered.push(f);
  });
 });
 builderConfig.layout.row_meta=nextMeta;
 layoutRowState.clear();
 nextRowState.forEach((value,row)=>layoutRowState.set(Number(row),value));
 selected.splice(0,selected.length,...ordered);
 sortSelectedByLayout();
}
'''

pat1=re.compile(r'function structureRowBlocks\(\)\{.*?\n\}\n(?=function structureApplyBlocks)',re.S)
if not pat1.search(s): raise SystemExit('1.3.48: structureRowBlocks not found')
s=pat1.sub(row_blocks,s,count=1)
pat2=re.compile(r'function structureApplyBlocks\(blocks\)\{.*?\n\}\n(?=function structureSectionRange)',re.S)
if not pat2.search(s): raise SystemExit('1.3.48: structureApplyBlocks not found')
s=pat2.sub(apply_blocks,s,count=1)

# Runtime version only; preserve all 1.3.47 functionality.
s=s.replace("version:'1.3.47'","version:'1.3.48'")
s=s.replace('version: "1.3.47"','version: "1.3.48"')
p.write_text(s,encoding='utf-8')
PY

# Update package/component version strings.
find "$TMP/component" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.js' -o -name '*.json' \) -print0 | xargs -0 sed -i 's/1\.3\.47/1.3.48/g'
find "$TMP/outer" -maxdepth 1 -type f -name '*.xml' -print0 | xargs -0 sed -i 's/1\.3\.47/1.3.48/g'

# Syntax and regression checks.
php -l "$B"
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
js='\n'.join(m.group(1) for m in re.finditer(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I))
js=re.sub(r'<\?(?:php|=).*?\?>','null',js,flags=re.S|re.I)
Path('/tmp/forms-1348-builder.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1348-builder.js

grep -q "const openState=layoutRowState.has(rowNo)" "$B"
grep -q "if(block.meta&&typeof block.meta==='object')nextMeta" "$B"
grep -q "nextRowState.forEach" "$B"
grep -q "function structureMoveRow" "$B"
grep -q "function smartMoveToSlot" "$B"
grep -q "offset_before" "$B"
grep -q "data-row-copy" "$B"
grep -q "data-row-remove" "$B"
grep -q "version:'1.3.48'" "$B"

# Rebuild component nested ZIP.
rm -f "$TMP/outer/com_decaroforms_$OLD.zip"
(
 cd "$TMP/component"
 zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .
)

# Rename other versioned nested ZIPs without modifying their contents.
for f in "$TMP/outer"/*"$OLD"*.zip; do
 [ -e "$f" ] || continue
 nf="${f//$OLD/$NEW}"
 mv "$f" "$nf"
done

(
 cd "$TMP/outer"
 zip -qr "$TARGET" .
)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

# Joomla update feed.
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
if '<version>1.3.48</version>' not in s:
 entry='''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>1.3.48</version>\n\t\t<note>Builder: trascinamento Riga stabilizzato. Titolo, descrizione, metadati e stato accordion seguono sempre la riga spostata; campi e layout restano invariati.</note>\n\t</changelog>'''
 pos=s.find('>')+1
 s=s[:pos]+entry+s[pos:]
 p.write_text(s,encoding='utf-8')
PY
fi

echo "Built $TARGET"
echo "SHA256 $SHA"
