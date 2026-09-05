#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.38"
NEW="1.3.39"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1339-ai.js /tmp/forms-1339-smart.js' EXIT
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

# 1) Preserve valid manual row widths, but repair rows automatically whenever the
#    number of fields changes or an invalid 100%+100% combination is created.
distribute="function distributeRow(row){const items=fieldsInRow(row),n=items.length;if(!n)return;const widths=smartAutoWidths(n);items.forEach(([f],i)=>{f.config.layout.width=widths[i]??100;f.config.layout.col=i+1;});}"
if distribute not in s: raise SystemExit('1.3.39: distributeRow anchor missing')
smart_fit=distribute+"\n"+r'''function smartFitRow(row){const items=fieldsInRow(row),n=items.length;if(!n)return;if(n===1){items[0][0].config.layout.width=100;items[0][0].config.layout.col=1;return;}const widths=items.map(([f])=>Number(f.config?.layout?.width||0)),total=widths.reduce((a,b)=>a+b,0),valid=total>=99&&total<=101&&widths.every(w=>Number.isFinite(w)&&w>0&&w<100);if(!valid){distributeRow(row);return;}items.forEach(([f],i)=>{f.config.layout.col=i+1;});}'''
s=s.replace(distribute,smart_fit,1)

old_repair="function repairInvalidRows(){[...new Set(selected.map(f=>Number(f.config.layout.row||1)))].forEach(row=>{const items=fieldsInRow(row),total=items.reduce((sum,[f])=>sum+Number(f.config.layout.width||0),0);if(total!==100)distributeRow(row);});}"
new_repair="function repairInvalidRows(){[...new Set(selected.map(f=>Number(f.config.layout.row||1)))].forEach(row=>{const items=fieldsInRow(row),total=items.reduce((sum,[f])=>sum+Number(f.config.layout.width||0),0),invalid=items.length===1?Number(items[0][0].config.layout.width||0)!==100:total<99||total>101||items.some(([f])=>Number(f.config.layout.width||0)>=100);if(invalid)smartFitRow(row);});}"
if old_repair not in s: raise SystemExit('1.3.39: repairInvalidRows anchor missing')
s=s.replace(old_repair,new_repair,1)

# 2) Adding a field now respects the active field/row. It joins the row when there
#    is room, otherwise a new row is inserted immediately after the active row.
old_add=re.search(r"function add\(item\)\{.*?setTimeout\(\(\)=>\{sel\.querySelector\('\.df-selected-item\.is-open'\)\?\.scrollIntoView\(\{behavior:'smooth',block:'nearest'\}\);\},100\);\}",s,re.S)
if not old_add: raise SystemExit('1.3.39: add function missing')
new_add=r'''function add(item){
 const x=defaultFieldConfig(clone(item));x.key=uniqueKey(x.key);x.options=Array.isArray(x.options)?x.options:[];
 const structural=['heading','fieldset','separator'].includes(String(x.type||''));let preferredRow=null,insertAt=selected.length;
 if(activeStructureSelection?.type==='row'){preferredRow=Math.max(1,Number(activeStructureSelection.row)||1);const rowItems=fieldsInRow(preferredRow);if(rowItems.length)insertAt=Math.max(...rowItems.map(([,i])=>i))+1;}
 else if(activeFieldKey){const ai=selected.findIndex(f=>f.key===activeFieldKey);if(ai>=0){preferredRow=Number(selected[ai].config?.layout?.row||1);insertAt=ai+1;}}
 const currentItems=preferredRow!=null?fieldsInRow(preferredRow):[],rowHasStructure=currentItems.some(([f])=>['heading','fieldset','separator'].includes(String(f.type||''))),canJoin=preferredRow!=null&&!structural&&!rowHasStructure&&currentItems.length<4;
 if(canJoin){x.config.layout={row:preferredRow,col:currentItems.length+1,width:100};selected.splice(Math.max(0,Math.min(selected.length,insertAt)),0,x);normalizeLayoutRows();sortSelectedByLayout();smartFitRow(Number(x.config.layout.row||preferredRow));}
 else if(preferredRow!=null){const insertRow=preferredRow+1;smartShiftRowMeta(insertRow);selected.forEach(f=>{defaultFieldConfig(f);if(Number(f.config.layout.row||1)>=insertRow)f.config.layout.row=Number(f.config.layout.row)+1;});x.config.layout={row:insertRow,col:1,width:100};selected.push(x);normalizeLayoutRows();sortSelectedByLayout();smartFitRow(Number(x.config.layout.row||insertRow));}
 else{const maxRow=Math.max(0,...selected.map(f=>Number(f.config?.layout?.row||0)));x.config.layout={row:maxRow+1,col:1,width:100};selected.push(x);normalizeLayoutRows();sortSelectedByLayout();}
 activeStructureSelection=null;activeFieldKey=x.key;openFieldKeys.clear();openFieldKeys.add(x.key);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();const selectedSection=[...document.querySelectorAll('[data-accordion]')][2];if(selectedSection){selectedSection.classList.add('is-open');selectedSection.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','true');}setTimeout(()=>{sel.querySelector('.df-selected-item.is-open')?.scrollIntoView({behavior:'smooth',block:'nearest'});},100);
}'''
s=s[:old_add.start()]+new_add+s[old_add.end():]

# 3) Use smart row fitting in edit/drag/remove flows. Valid manual splits such as
#    75+25 remain untouched; invalid layouts caused by adding/removing are repaired.
repls={
"normalizeLayoutRows();distributeRow(copy.config.layout.row);renderSelected()":"normalizeLayoutRows();smartFitRow(copy.config.layout.row);renderSelected()",
"normalizeLayoutRows();distributeRow(oldRow);renderSelected()":"normalizeLayoutRows();smartFitRow(oldRow);renderSelected()",
"normalizeLayoutRows();distributeRow(oldRow);distributeRow(field.config.layout.row);activeFieldKey":"normalizeLayoutRows();smartFitRow(oldRow);smartFitRow(field.config.layout.row);activeFieldKey",
"normalizeLayoutRows();sortSelectedByLayout();distributeRow(oldRow);distributeRow(Number(field.config.layout.row||targetRow));activeFieldKey":"normalizeLayoutRows();sortSelectedByLayout();smartFitRow(oldRow);smartFitRow(Number(field.config.layout.row||targetRow));activeFieldKey",
"if(!same){if(oldNeighbors.length)distributeRow(Number(oldNeighbors[0].config.layout.row||1));distributeRow(Number(field.config.layout.row||1));}activeStructureSelection":"if(!same&&oldNeighbors.length)smartFitRow(Number(oldNeighbors[0].config.layout.row||1));smartFitRow(Number(field.config.layout.row||targetRow));activeStructureSelection",
"if(oldNeighbors.length)distributeRow(Number(oldNeighbors[0].config.layout.row||1));distributeRow(Number(field.config.layout.row||1));activeStructureSelection":"if(oldNeighbors.length)smartFitRow(Number(oldNeighbors[0].config.layout.row||1));smartFitRow(Number(field.config.layout.row||1));activeStructureSelection",
}
for a,b in repls.items():
    if a in s:s=s.replace(a,b)

# 4) Preview quick filters: keep existing selection buttons and add non-destructive
#    filters for uncertain fields and duplicates, with live counters.
old_toolbar='<button class="df-btn df-small" type="button" id="df-ai-select-safe">Solo sicuri</button><label><span class="df-note">Posizione</span>'
new_toolbar='<button class="df-btn df-small" type="button" id="df-ai-select-safe">Solo sicuri</button><button class="df-btn df-small df-ai-filter-btn" type="button" id="df-ai-filter-review">Da controllare (0)</button><button class="df-btn df-small df-ai-filter-btn" type="button" id="df-ai-filter-duplicates">Duplicati (0)</button><label><span class="df-note">Posizione</span>'
count=s.count(old_toolbar)
if count<2: raise SystemExit(f'1.3.39: expected two AI toolbar anchors, found {count}')
s=s.replace(old_toolbar,new_toolbar)

old_state="let aiDraftFields=[];let aiLoadedJson='';"
if old_state not in s: raise SystemExit('1.3.39: AI state anchor missing')
s=s.replace(old_state,"let aiDraftFields=[];let aiLoadedJson='';let aiPreviewFilter='all';",1)

helper_anchor='function aiPrepare(fields){'
if helper_anchor not in s: raise SystemExit('1.3.39: aiPrepare anchor missing')
filter_helpers=r'''function aiNeedsReview(f){return f?.confidence==='medium'||f?.confidence==='low';}
function aiMatchesPreviewFilter(f){if(aiPreviewFilter==='review')return aiNeedsReview(f);if(aiPreviewFilter==='duplicates')return!!f?._duplicate;return true;}
function aiUpdatePreviewFilterButtons(){const review=aiDraftFields.filter(aiNeedsReview).length,dup=aiDraftFields.filter(f=>f._duplicate).length,rb=document.getElementById('df-ai-filter-review'),db=document.getElementById('df-ai-filter-duplicates');if(rb){rb.textContent=`Da controllare (${review})`;rb.classList.toggle('is-active',aiPreviewFilter==='review');rb.setAttribute('aria-pressed',aiPreviewFilter==='review'?'true':'false');rb.disabled=review===0;}if(db){db.textContent=`Duplicati (${dup})`;db.classList.toggle('is-active',aiPreviewFilter==='duplicates');db.setAttribute('aria-pressed',aiPreviewFilter==='duplicates'?'true':'false');db.disabled=dup===0;}}
function aiSetPreviewFilter(filter){filter=['review','duplicates'].includes(filter)?filter:'all';aiPreviewFilter=aiPreviewFilter===filter?'all':filter;aiRenderPreview();}
'''
s=s.replace(helper_anchor,filter_helpers+helper_anchor,1)

old_prepare="function aiPrepare(fields){const ignored=fields.length;aiDraftFields=fields.map(aiNormalizeField).filter(Boolean);const skipped=ignored-aiDraftFields.length;if(!aiDraftFields.length)throw new Error('Non ho trovato campi importabili nel risultato.');aiDraftFields.forEach(f=>{f._duplicate=aiFindDuplicate(f);});aiRenderPreview(skipped);}"
new_prepare="function aiPrepare(fields){const ignored=fields.length;aiPreviewFilter='all';aiDraftFields=fields.map(aiNormalizeField).filter(Boolean);const skipped=ignored-aiDraftFields.length;if(!aiDraftFields.length)throw new Error('Non ho trovato campi importabili nel risultato.');aiDraftFields.forEach(f=>{f._duplicate=aiFindDuplicate(f);});aiRenderPreview(skipped);}"
if old_prepare not in s: raise SystemExit('1.3.39: aiPrepare exact anchor missing')
s=s.replace(old_prepare,new_prepare,1)

old_count=re.search(r"function aiUpdateImportCount\(\)\{.*?\}\nfunction aiRenderPreview",s,re.S)
if not old_count: raise SystemExit('1.3.39: aiUpdateImportCount block missing')
new_count=r'''function aiUpdateImportCount(){const n=aiDraftFields.filter(f=>f._include).length;if(aiImportCount)aiImportCount.textContent=`· ${n} camp${n===1?'o':'i'}`;if(aiImportButton)aiImportButton.disabled=n===0;const dup=aiDraftFields.filter(f=>f._duplicate).length,review=aiDraftFields.filter(aiNeedsReview).length;const summary=document.getElementById('df-ai-preview-summary');if(summary)summary.textContent=`${aiDraftFields.length} campi riconosciuti · ${dup} duplicat${dup===1?'o':'i'} · ${review} da controllare`;aiUpdatePreviewFilterButtons();}
function aiRenderPreview'''
s=s[:old_count.start()]+new_count+s[old_count.end():]

old_render_start="function aiRenderPreview(skipped=0){aiRefreshDuplicates();aiPreview.hidden=false;aiPreviewList.innerHTML='';aiDraftFields.forEach((f,i)=>{"
new_render_start="function aiRenderPreview(skipped=0){aiRefreshDuplicates();aiPreview.hidden=false;aiPreviewList.innerHTML='';let visible=0;aiDraftFields.forEach((f,i)=>{if(!aiMatchesPreviewFilter(f))return;visible++;"
if old_render_start not in s: raise SystemExit('1.3.39: aiRenderPreview start missing')
s=s.replace(old_render_start,new_render_start,1)
needle="aiPreviewList.appendChild(row);});if(skipped){const note=document.createElement('div');"
replacement="aiPreviewList.appendChild(row);});if(!visible){const empty=document.createElement('div');empty.className='df-note df-ai-filter-empty';empty.textContent=aiPreviewFilter==='review'?'Nessun campo da controllare.':aiPreviewFilter==='duplicates'?'Nessun duplicato rilevato.':'Nessun campo da mostrare.';aiPreviewList.appendChild(empty);}if(skipped){const note=document.createElement('div');"
if needle not in s: raise SystemExit('1.3.39: aiRenderPreview end anchor missing')
s=s.replace(needle,replacement,1)

old_listeners="document.getElementById('df-ai-select-all')?.addEventListener('click',()=>{aiDraftFields.forEach(f=>f._include=true);aiRenderPreview();});document.getElementById('df-ai-select-safe')?.addEventListener('click',()=>{aiDraftFields.forEach(f=>f._include=!f._duplicate&&f.confidence==='high');aiRenderPreview();});"
new_listeners="document.getElementById('df-ai-select-all')?.addEventListener('click',()=>{aiPreviewFilter='all';aiDraftFields.forEach(f=>f._include=true);aiRenderPreview();});document.getElementById('df-ai-select-safe')?.addEventListener('click',()=>{aiPreviewFilter='all';aiDraftFields.forEach(f=>f._include=!f._duplicate&&f.confidence==='high');aiRenderPreview();});document.getElementById('df-ai-filter-review')?.addEventListener('click',()=>aiSetPreviewFilter('review'));document.getElementById('df-ai-filter-duplicates')?.addEventListener('click',()=>aiSetPreviewFilter('duplicates'));"
if old_listeners not in s: raise SystemExit('1.3.39: AI listener anchor missing')
s=s.replace(old_listeners,new_listeners,1)

# Reset active filter whenever the prepared draft is cleared/imported.
s=s.replace("function aiResetAfterImport(){aiDraftFields=[];", "function aiResetAfterImport(){aiDraftFields=[];aiPreviewFilter='all';",1)
s=s.replace("function aiClearPreparedPreview(){aiDraftFields=[];", "function aiClearPreparedPreview(){aiDraftFields=[];aiPreviewFilter='all';",1)

css=r'''
/* Forms 1.3.39: AI preview filter states. */
.df-ai-filter-btn{white-space:nowrap}.df-ai-filter-btn.is-active{border-color:#7c3aed!important;background:color-mix(in srgb,#7c3aed 10%,var(--bs-body-bg,#fff))!important;color:#6d28d9}.df-ai-filter-btn:disabled{opacity:.42;cursor:not-allowed}.df-ai-filter-empty{padding:18px;border:1px dashed var(--df-border);border-radius:9px;text-align:center}
'''
if '</style>' not in s: raise SystemExit('1.3.39: style anchor missing')
s=s.replace('</style>',css+'</style>',1)

# Runtime marker.
s=s.replace("window.dfBuilderRuntime={version:'1.3.38'","window.dfBuilderRuntime={version:'1.3.39'",1)

checks=['function smartFitRow','function aiNeedsReview','df-ai-filter-review','df-ai-filter-duplicates',"version:'1.3.39'",'canJoin=preferredRow!=null']
for c in checks:
    if c not in s: raise SystemExit('1.3.39 missing '+c)
p.write_text(s,encoding='utf-8')
PY

# Version metadata inside component.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)
php -l "$B" >/dev/null

# Syntax-check AI region and the modified Builder row/add helpers.
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
a=s.index('const aiAllowedTypes=');b=s.index('/* Forms 1.3.6: bind quick templates',a)
ai=re.sub(r"<\?php.*?\?>","X",s[a:b],flags=re.S)
Path('/tmp/forms-1339-ai.js').write_text(ai,encoding='utf-8')
a=s.index('function fieldsInRow(');b=s.index('/* Forms 1.3.38: AI mode selector',a)
smart=s[a:b]
# Provide harmless bindings for references resolved elsewhere in the full Builder.
prefix="let selected=[],builderConfig={},activeStructureSelection=null,activeFieldKey=null;const openFieldKeys=new Set();const clone=x=>x,uniqueKey=x=>x,defaultFieldConfig=x=>x,isLayoutSectionField=()=>false,renderSelected=()=>{},renderLayoutCanvas=()=>{},renderColumns=()=>{},renderTokens=()=>{},renderUserEmailFields=()=>{},sync=()=>{};\n"
Path('/tmp/forms-1339-smart.js').write_text(prefix+smart,encoding='utf-8')
PY
node --check /tmp/forms-1339-ai.js >/dev/null
node --check /tmp/forms-1339-smart.js >/dev/null

# Rebuild component and nested packages.
rm -f "$COMP_OLD"
(cd "$TMP/component" && zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .)
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
<changelogs><changelog><element>pkg_decaroforms</element><type>package</type><version>$NEW</version><feature>Anteprima Importa con AI: aggiunti filtri rapidi Da controllare e Duplicati con contatori aggiornati in tempo reale.</feature><improvement>Aggiungi campo inserisce il nuovo campo nella riga attiva o accanto al campo selezionato quando la riga ha spazio.</improvement><improvement>Se la riga attiva è piena o strutturale, il nuovo campo viene creato subito nella riga successiva, mantenendo l'ordine della sezione.</improvement><improvement>Drag intelligente: due campi incompatibili a 100% vengono adattati automaticamente a 50% + 50%; tre e quattro campi vengono distribuiti automaticamente.</improvement><improvement>Le combinazioni manuali valide, per esempio 75% + 25%, vengono mantenute quando il numero di campi della riga non cambia.</improvement><improvement>Quando da una riga rimane un solo campo, la larghezza torna automaticamente a 100%.</improvement><note>Mantenute le funzioni delle versioni precedenti: sezioni e righe accordion, drag campo/riga/sezione, HTML/ZIP, Upload, icone UI moderne e traduzioni.</note><language>it-IT</language></changelog></changelogs>
EOF
rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
