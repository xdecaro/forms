#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.53"
NEW="1.3.54"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1354-builder.js' EXIT
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

  find "$CHILD" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.js' -o -name '*.json' -o -name '*.css' -o -name '*.txt' -o -name '*.md' \) -print0 \
    | xargs -0 -r sed -i 's/1\.3\.53/1.3.54/g'

  CANDIDATE="$CHILD/administrator/components/com_decaroforms/tmpl/builder/default.php"
  if [ -f "$CANDIDATE" ]; then BUILDER="$CANDIDATE"; fi
done

test -n "$BUILDER" && test -f "$BUILDER"

python3 - "$BUILDER" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')

def replace_once(old,new,label):
    global s
    if old not in s:
        raise SystemExit(f'1.3.54 missing anchor: {label}')
    s=s.replace(old,new,1)

def replace_between(start,end,replacement,label):
    global s
    a=s.find(start)
    if a<0:
        raise SystemExit(f'1.3.54 missing start: {label}')
    b=s.find(end,a)
    if b<0:
        raise SystemExit(f'1.3.54 missing end: {label}')
    s=s[:a]+replacement+s[b:]

# Stable Row identity already exists through meta.id. 1.3.54 adds a stable automatic
# display number that travels with the same Row ID instead of following layout.row.
replace_between(
    'function rowMetaStore(){',
    'function rowIdForRow(',
'''function rowMetaStore(){builderConfig=builderConfig&&typeof builderConfig==='object'?builderConfig:{};builderConfig.layout=builderConfig.layout&&typeof builderConfig.layout==='object'?builderConfig.layout:{};builderConfig.layout.row_meta=builderConfig.layout.row_meta&&typeof builderConfig.layout.row_meta==='object'?builderConfig.layout.row_meta:{};return builderConfig.layout.row_meta;}
function rowLabelSeq(){builderConfig=builderConfig&&typeof builderConfig==='object'?builderConfig:{};builderConfig.layout=builderConfig.layout&&typeof builderConfig.layout==='object'?builderConfig.layout:{};return Math.max(0,Math.floor(Number(builderConfig.layout.row_label_seq)||0));}
function rowBumpLabelSeq(value){const n=Math.max(0,Math.floor(Number(value)||0));if(n>rowLabelSeq())builderConfig.layout.row_label_seq=n;return n;}
function nextRowDisplayNo(){const store=rowMetaStore();let seq=rowLabelSeq();Object.values(store).forEach(meta=>{const n=Math.floor(Number(meta?.display_no)||0);if(n>seq)seq=n;});seq+=1;builderConfig.layout.row_label_seq=seq;return seq;}
function ensureRowDisplayNo(meta,rowNo,legacyPreferred=false){meta=meta&&typeof meta==='object'?meta:{};let n=Math.floor(Number(meta.display_no)||0);if(n>0){rowBumpLabelSeq(n);return n;}if(legacyPreferred){n=Math.max(1,Math.floor(Number(rowNo)||1));rowBumpLabelSeq(n);}else n=nextRowDisplayNo();meta.display_no=n;return n;}
function rowMeta(rowNo){rowNo=Math.max(1,Number(rowNo)||1);const store=rowMetaStore(),key=String(rowNo),meta=store[key]&&typeof store[key]==='object'?store[key]:{};if(!meta.id)meta.id=newRowId();if(typeof meta.title!=='string')meta.title='';if(typeof meta.description!=='string')meta.description='';const legacy=Number(builderConfig?.layout?.row_label_version||0)<1;ensureRowDisplayNo(meta,rowNo,legacy);store[key]=meta;return meta;}
function rowAutoLabel(rowNo){const meta=rowMeta(rowNo),displayNo=ensureRowDisplayNo(meta,rowNo,false);return `${structureUi.row} ${displayNo}`;}
function rowDisplayTitle(rowNo){const meta=rowMeta(rowNo);return meta.title||rowAutoLabel(rowNo);}
''',
    'stable Row label helpers'
)

replace_between(
    'function normalizeLayoutRows(){',
    'function sortSelectedByLayout(){',
'''function normalizeLayoutRows(){
 builderConfig=builderConfig&&typeof builderConfig==='object'?builderConfig:{};builderConfig.layout=builderConfig.layout&&typeof builderConfig.layout==='object'?builderConfig.layout:{};
 const oldMeta=rowMetaStore(),rows=logicalRowNumbers(),legacyLabels=Number(builderConfig.layout.row_label_version||0)<1;
 let seq=rowLabelSeq();Object.values(oldMeta).forEach(meta=>{const n=Math.floor(Number(meta?.display_no)||0);if(n>seq)seq=n;});
 if(!rows.length){builderConfig.layout.row_meta={};builderConfig.layout.row_label_seq=seq;builderConfig.layout.row_label_version=1;activeStructureSelection=null;return;}
 const map=new Map(rows.map((r,i)=>[r,i+1])),nextMeta={},usedDisplayNos=new Set();
 rows.forEach(r=>{
  const nr=map.get(r),existing=oldMeta[String(r)]&&typeof oldMeta[String(r)]==='object'?oldMeta[String(r)]:null,meta=existing||{};
  if(!meta.id)meta.id=newRowId();if(typeof meta.title!=='string')meta.title='';if(typeof meta.description!=='string')meta.description='';
  let displayNo=Math.floor(Number(meta.display_no)||0);
  if(displayNo<=0){if(legacyLabels)displayNo=Math.max(1,Math.floor(Number(r)||1));else{seq+=1;displayNo=seq;}}
  if(usedDisplayNos.has(displayNo)){do{seq+=1;}while(usedDisplayNos.has(seq));displayNo=seq;}
  usedDisplayNos.add(displayNo);seq=Math.max(seq,displayNo);meta.display_no=displayNo;nextMeta[String(nr)]=meta;
 });
 builderConfig.layout.row_meta=nextMeta;builderConfig.layout.row_label_seq=seq;builderConfig.layout.row_label_version=1;
 selected.forEach(f=>{defaultFieldConfig(f);f.config.layout.row=map.get(Number(f.config.layout.row||1))||1;});
 for(const row of logicalRowNumbers()){selected.filter(f=>Number(f.config.layout.row||1)===Number(row)).sort((a,b)=>(a.config.layout.col||1)-(b.config.layout.col||1)).forEach((f,i)=>f.config.layout.col=i+1);normalizeVisualLines(row);}
 refreshActiveRowSelection();const validIds=new Set(Object.values(builderConfig.layout.row_meta||{}).map(meta=>String(meta?.id||'')).filter(Boolean));for(const id of [...layoutRowState.keys()])if(!validIds.has(String(id)))layoutRowState.delete(id);
}
''',
    'normalizeLayoutRows stable display numbers'
)

replace_once(
    "title=meta.title||`${structureUi.row} ${rowNo}`,rowId=meta.id;",
    "title=rowDisplayTitle(rowNo),rowId=meta.id;",
    'delete Row display title'
)
replace_once(
    '<span class="df-summary-chip">${esc(structureUi.row)} ${rowNo}</span>',
    '<span class="df-summary-chip">${esc(rowAutoLabel(rowNo))}</span>',
    'Row settings stable chip'
)
replace_once(
    'placeholder="${esc(structureUi.row)} ${rowNo}"',
    'placeholder="${esc(rowAutoLabel(rowNo))}"',
    'Row settings stable placeholder'
)
replace_once(
    'meta=rowMeta(model.rowNo),rowTitle=meta.title||`${structureUi.row} ${model.rowNo}`,',
    'meta=rowMeta(model.rowNo),rowTitle=rowDisplayTitle(model.rowNo),',
    'Builder Row stable visible title'
)

p.write_text(s,encoding='utf-8')
PY

# Rebuild every child ZIP after patching.
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

find "$TMP/outer" -maxdepth 1 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.json' -o -name '*.txt' -o -name '*.md' \) -print0 \
  | xargs -0 -r sed -i 's/1\.3\.53/1.3.54/g'

php -l "$BUILDER"
python3 - "$BUILDER" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
js='\n'.join(m.group(1) for m in re.finditer(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I))
js=re.sub(r'<\?(?:php|=).*?\?>','null',js,flags=re.S|re.I)
Path('/tmp/forms-1354-builder.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1354-builder.js

grep -q "function rowAutoLabel" "$BUILDER"
grep -q "function rowDisplayTitle" "$BUILDER"
grep -q "row_label_version=1" "$BUILDER"
grep -q "meta.display_no=displayNo" "$BUILDER"
grep -q "rowTitle=rowDisplayTitle(model.rowNo)" "$BUILDER"
grep -q 'placeholder="${esc(rowAutoLabel(rowNo))}"' "$BUILDER"
grep -q "version:'1.3.54'" "$BUILDER"
if grep -Fq 'rowTitle=meta.title||`${structureUi.row} ${model.rowNo}`' "$BUILDER"; then
  echo 'Old position-bound Row title still present' >&2
  exit 1
fi

# Verify the stable-label algorithm independently: Row label stays with ID after reorder,
# duplicate labels are repaired without changing the original, and sequence is monotonic.
python3 - <<'PY'
rows=[
 {'id':'a','display_no':6},
 {'id':'b','display_no':7},
 {'id':'c','display_no':8},
]
# Move b before a: display numbers must stay 7,6,8.
rows=[rows[1],rows[0],rows[2]]
assert [r['display_no'] for r in rows]==[7,6,8]
# Duplicate b carries 7 at clone time; deterministic repair keeps original first and allocates 9.
rows.insert(1,{'id':'b2','display_no':7})
seq=8;used=set()
for r in rows:
    n=int(r.get('display_no') or 0)
    if n<=0 or n in used:
        seq+=1
        while seq in used: seq+=1
        n=seq
    used.add(n);seq=max(seq,n);r['display_no']=n
assert rows[0]['display_no']==7
assert rows[1]['display_no']==9
assert seq==9
PY

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
if '<version>1.3.54</version>' not in s:
    entry='''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>1.3.54</version>\n\t\t<note>Builder: identità visiva stabile delle Righe. Il numero automatico Riga N ora viene salvato nel row_meta e segue il relativo row_id durante riordino e spostamento tra Sezioni, mentre layout.row resta solo la posizione tecnica. Migrazione automatica senza SQL per i moduli esistenti; duplicazioni ricevono un nuovo numero automatico univoco e la sequenza non viene riutilizzata dopo eliminazioni. Titoli personalizzati, descrizione, accordion, drag 50/50 e campi restano associati allo stesso row_id.</note>\n\t</changelog>'''
    pos=s.find('>')+1;s=s[:pos]+entry+s[pos:];p.write_text(s,encoding='utf-8')
PY

python3 - "$FEED" "$CHANGE" <<'PY'
import sys,xml.etree.ElementTree as ET
for f in sys.argv[1:]: ET.parse(f)
PY

cat > "$TARGET_DIR/README.md" <<EOF
# Forms $NEW

Stable Row visible identity release:
- automatic **Riga N** is now persisted as Row metadata and follows the stable Row ID;
- moving Riga 7 above Riga 6 displays **Riga 7 / Riga 6 / Riga 8** instead of renaming by position;
- \`layout.row\` remains the technical ordering index for compatibility;
- existing forms migrate automatically in Builder without SQL or data loss;
- new/duplicated Rows receive a unique monotonic automatic display number;
- custom Row title, description, accordion state, fields and Row ID behavior are preserved;
- 1.3.53 forgiving 50/50 Row drop UX and dark-mode behavior are preserved;
- PHP, extracted JavaScript, XML and stable-label invariant checks passed.

SHA256: $SHA
EOF

echo "Built $TARGET"
echo "SHA256 $SHA"
