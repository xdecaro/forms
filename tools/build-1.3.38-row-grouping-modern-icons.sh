#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.37"
NEW="1.3.38"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1338-ai.js /tmp/forms-1338-icons.js' EXIT
mkdir -p "$TMP/outer" "$TMP/component" "$TARGET_DIR"
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

# 1) Smarter row packing: an HTML row token only forces a row when it really groups
#    two or more imported fields. Single-field wrappers no longer explode the form
#    into dozens of technical rows.
helper=r'''
function aiHtmlPackSectionRows(fields,startRow){
 const tokenCounts=new Map();
 fields.forEach(f=>{const t=f._rowToken;if(t)tokenCounts.set(t,(tokenCounts.get(t)||0)+1);});
 let row=startRow,current=[],sum=0,sharedToken=null;
 const flush=()=>{if(!current.length)return;current.forEach(f=>{f.row=row;});row++;current=[];sum=0;sharedToken=null;};
 for(const f of fields){
  const width=Math.max(1,Math.min(100,Number(f.width||100))),token=f._rowToken,tokenShared=!!token&&(tokenCounts.get(token)||0)>1;
  let breakBefore=false;
  if(current.length){
   if(width>=100||sum+width>100)breakBefore=true;
   if(sharedToken&&(!tokenShared||token!==sharedToken))breakBefore=true;
   if(!sharedToken&&tokenShared)breakBefore=true;
  }
  if(breakBefore)flush();
  current.push(f);sum+=width;if(tokenShared)sharedToken=token;
  if(width>=100||sum>=99)flush();
 }
 flush();return row;
}
'''
anchor='function aiHtmlParsePage(html,assets={}){'
if anchor not in s: raise SystemExit('1.3.38: parser anchor missing')
if 'function aiHtmlPackSectionRows(' not in s:s=s.replace(anchor,helper+'\n'+anchor,1)

old_re=r"const out=\[\];let row=1,sum=0,lastToken=null,lastSection='';let sectionCounter=0;for\(const f of raw\)\{.*?return out\.slice\(0,100\);\}"
m=re.search(old_re,s,re.S)
if not m: raise SystemExit('1.3.38: old row grouping block missing')
new=r'''const sectionGroups=[];let currentGroup=null;
 for(const f of raw){const sec=f._section||null,secId=sec?.id||'';if(!currentGroup||currentGroup.id!==secId){currentGroup={id:secId,section:sec,fields:[]};sectionGroups.push(currentGroup);}currentGroup.fields.push(f);}
 const out=[];let row=1,sectionCounter=0;
 for(const group of sectionGroups){
  if(group.section){const sec=group.section;out.push({label:sec.title,key:`section_${aiSlug(sec.title)}_${++sectionCounter}`,type:'heading',required:false,width:100,row,placeholder:'',options:[],config:{builder_role:'section',content:''},conditions:[],condition_logic:'all',condition_action:'show',confidence:sec.confidence||'high',warning:''});row++;}
  row=aiHtmlPackSectionRows(group.fields,row);
  group.fields.forEach(f=>{out.push(f);delete f._rowToken;delete f._disabled;delete f._node;delete f._section;});
 }
 out.sort((a,b)=>Number(a.row||0)-Number(b.row||0));return out.slice(0,100);}'''
s=s[:m.start()]+new+s[m.end():]

# 2) Modern, uniform UI icons. Keep existing uiIcon as fallback for unrelated names.
modern=r'''
const modernUiIcon=name=>{const common='viewBox="0 0 24 24" aria-hidden="true" focusable="false" class="df-modern-ui-icon"';const icons={
 edit:`<svg ${common}><path d="M4 20h4L19 9a2.8 2.8 0 0 0-4-4L4 16v4Z"/><path d="m13.5 6.5 4 4"/></svg>`,
 copy:`<svg ${common}><rect x="9" y="9" width="11" height="11" rx="2"/><rect x="4" y="4" width="11" height="11" rx="2"/></svg>`,
 trash:`<svg ${common}><path d="M4 7h16"/><path d="M9 7V4h6v3"/><path d="m6 7 1 13h10l1-13"/><path d="M10 11v5M14 11v5"/></svg>`,
 grip:`<svg ${common}><circle cx="9" cy="6" r="1"/><circle cx="15" cy="6" r="1"/><circle cx="9" cy="12" r="1"/><circle cx="15" cy="12" r="1"/><circle cx="9" cy="18" r="1"/><circle cx="15" cy="18" r="1"/></svg>`
};return icons[name]||uiIcon(name);};
'''
icon_anchor='const aiAllowedTypes='
if icon_anchor not in s: raise SystemExit('1.3.38: icon insertion anchor missing')
if 'const modernUiIcon=' not in s:s=s.replace(icon_anchor,modern+'\n'+icon_anchor,1)
for name in ('edit','copy','trash'):
    s=s.replace(f"uiIcon('{name}')",f"modernUiIcon('{name}')")
# Modern grip for field/row/section handles generated inside JS template strings.
s=s.replace('>☰</span>',">${modernUiIcon('grip')}</span>")

# 3) Remove the old boxed icon-button look. Delete stays visually destructive on hover/focus.
css=r'''
/* Forms 1.3.38: modern, borderless Builder icon actions. */
.df-icon-only{width:34px;height:34px;min-width:34px;display:inline-grid;place-items:center;padding:0!important;border:0!important;background:transparent!important;box-shadow:none!important;border-radius:8px;color:var(--bs-secondary-color,#59636f);cursor:pointer;transition:background .15s ease,color .15s ease,transform .15s ease}
.df-icon-only:hover,.df-icon-only:focus-visible{background:color-mix(in srgb,#7c3aed 9%,transparent)!important;color:#6d28d9;outline:none}
.df-icon-only:active{transform:scale(.94)}
.df-modern-ui-icon{width:18px;height:18px;display:block;fill:none;stroke:currentColor;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round;pointer-events:none}
.df-layout-structure-handle .df-modern-ui-icon,.df-layout-handle .df-modern-ui-icon{width:17px;height:17px;stroke-width:1.7}
.df-canvas-remove:hover,.df-canvas-remove:focus-visible,[data-section-remove]:hover,[data-section-remove]:focus-visible,[data-structure-remove]:hover,[data-structure-remove]:focus-visible,.df-ai-ui-delete:hover,.df-ai-ui-delete:focus-visible,.df-lib-delete:hover,.df-lib-delete:focus-visible,.df-saved-quick-delete:hover,.df-saved-quick-delete:focus-visible{color:#dc3545!important;background:color-mix(in srgb,#dc3545 9%,transparent)!important}
.df-layout-actions,.df-layout-section-actions,.df-mini-actions{align-items:center;gap:2px}
'''
if '</style>' not in s: raise SystemExit('1.3.38: style anchor missing')
s=s.replace('</style>',css+'</style>',1)

# 4) Runtime version.
s=s.replace("window.dfBuilderRuntime={version:'1.3.37'","window.dfBuilderRuntime={version:'1.3.38'",1)

# Guardrails.
checks=['function aiHtmlPackSectionRows','const sectionGroups=[]','const modernUiIcon=',"modernUiIcon('trash')",'df-modern-ui-icon',"version:'1.3.38'"]
for c in checks:
    if c not in s: raise SystemExit('1.3.38 missing '+c)
p.write_text(s,encoding='utf-8')
PY

# Version metadata inside the component.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)
php -l "$B" >/dev/null

# JS syntax check for AI parser region.
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
a=s.index('const aiAllowedTypes=');b=s.index('/* Forms 1.3.6: bind quick templates',a)
js=s[a:b];js=re.sub(r"<\?php.*?\?>","X",js,flags=re.S)
Path('/tmp/forms-1338-ai.js').write_text(js,encoding='utf-8')
# Check modern icon declaration separately with a harmless uiIcon fallback.
m=re.search(r"const modernUiIcon=name=>\{.*?\};",s,re.S)
if not m: raise SystemExit('modern icon JS missing')
Path('/tmp/forms-1338-icons.js').write_text("const uiIcon=()=>'';\n"+m.group(0)+"\n",encoding='utf-8')
PY
node --check /tmp/forms-1338-ai.js >/dev/null
node --check /tmp/forms-1338-icons.js >/dev/null

# Rebuild the component ZIP.
rm -f "$COMP_OLD"
(cd "$TMP/component" && zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .)

# Rebuild any other nested extension ZIPs so their internal version remains coherent.
for z in "$TMP/outer"/*_"$OLD".zip; do
  [ -e "$z" ] || continue
  work="$TMP/sub-$(basename "$z" .zip)"; mkdir -p "$work"; unzip -q "$z" -d "$work"
  while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$work" || true)
  newz="${z/$OLD/$NEW}"; rm -f "$newz"; (cd "$work" && zip -qr "$newz" .); rm -f "$z"
done
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -Il -- "$OLD" "$TMP/outer"/* 2>/dev/null || true)

rm -f "$TARGET"; (cd "$TMP/outer" && zip -qr "$TARGET" .); unzip -tq "$TARGET" >/dev/null
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update><name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description><element>pkg_decaroforms</element><type>package</type><client>site</client><version>$NEW</version><downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/$NEW/pkg_decaroforms_$NEW.zip</downloadurl></downloads><changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags><maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl><targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256></update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog><element>pkg_decaroforms</element><type>package</type><version>$NEW</version><fix>Importazione HTML/ZIP: i wrapper tecnici con un solo campo non generano più una riga separata.</fix><improvement>Ogni sezione può contenere più righe reali; i campi vengono raggruppati per larghezza in combinazioni come 50+50, 75+25, 66+33 e 33+33+33.</improvement><improvement>I contenitori HTML di riga vengono rispettati quando raggruppano davvero più campi, altrimenti Forms usa il layout visivo.</improvement><improvement>Icone Builder moderne e uniformi per modifica, duplica, trascina ed elimina, con pulsanti senza riquadro pesante.</improvement><improvement>L'azione Elimina resta chiaramente riconoscibile con stato rosso in hover e focus.</improvement><note>Mantenute tutte le funzioni di 1.3.37: sezioni HTML/ZIP, Upload, drag campo/riga/sezione, traduzioni e pannelli impostazioni.</note><language>it-IT</language></changelog></changelogs>
EOF
rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
