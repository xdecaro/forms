#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.32"
NEW="1.3.33"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-structure-1333-check.js' EXIT
mkdir -p "$TMP/outer" "$TMP/component" "$TARGET_DIR"
unzip -q "$BASE" -d "$TMP/outer"
COMP_OLD="$TMP/outer/com_decaroforms_$OLD.zip"
test -f "$COMP_OLD"
unzip -q "$COMP_OLD" -d "$TMP/component"
BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
test -f "$BUILDER" && test -f "$HELPER"

python3 - "$BUILDER" "$HELPER" "$TMP/component" <<'PY'
from pathlib import Path
import sys,re
builder=Path(sys.argv[1]); helper=Path(sys.argv[2]); root=Path(sys.argv[3])
s=builder.read_text(encoding='utf-8')
h=helper.read_text(encoding='utf-8')

# Add explicit structural presets using existing, already-supported field types.
anchor="            ['key'=>'section_heading','type'=>'heading','category'=>'structure','label'=>Text::_('COM_DECAROFORMS_FIELD_HEADING'),'placeholder'=>'','required'=>false,'config'=>['content'=>'']],"
insert=anchor+"\n            ['key'=>'empty_section','type'=>'fieldset','category'=>'structure','label'=>Text::_('COM_DECAROFORMS_FIELD_EMPTY_SECTION'),'placeholder'=>'','required'=>false,'config'=>['content'=>'','builder_role'=>'section']],\n            ['key'=>'empty_row','type'=>'separator','category'=>'structure','label'=>Text::_('COM_DECAROFORMS_FIELD_EMPTY_ROW'),'placeholder'=>'','required'=>false,'config'=>['color'=>'#dfe3e7','border_width'=>0,'border_style'=>'solid','line_width'=>100,'margin'=>32,'builder_role'=>'spacer']],\n            ['key'=>'divider_line','type'=>'separator','category'=>'structure','label'=>Text::_('COM_DECAROFORMS_FIELD_DIVIDER_LINE'),'placeholder'=>'','required'=>false,'config'=>['color'=>'#dfe3e7','border_width'=>1,'border_style'=>'solid','line_width'=>100,'margin'=>20,'builder_role'=>'divider']],"
if anchor not in h: raise SystemExit('1.3.33: field library structure anchor missing')
h=h.replace(anchor,insert,1)
helper.write_text(h,encoding='utf-8')

# Localized UI strings for the new structure canvas.
lib_anchor="const library=<?php echo json_encode(FormHelper::fieldLibrary(), JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;"
ui="const structureUi={expandAll:'<?php echo addslashes(Text::_('COM_DECAROFORMS_EXPAND_ALL')); ?>',collapseAll:'<?php echo addslashes(Text::_('COM_DECAROFORMS_COLLAPSE_ALL')); ?>',general:'<?php echo addslashes(Text::_('COM_DECAROFORMS_GENERAL_SECTION')); ?>',section:'<?php echo addslashes(Text::_('COM_DECAROFORMS_SECTION')); ?>',row:'<?php echo addslashes(Text::_('COM_DECAROFORMS_ROW')); ?>',fields:'<?php echo addslashes(Text::_('COM_DECAROFORMS_FIELDS')); ?>',rows:'<?php echo addslashes(Text::_('COM_DECAROFORMS_ROWS')); ?>'};\n"+lib_anchor
if lib_anchor not in s: raise SystemExit('1.3.33: library JS anchor missing')
s=s.replace(lib_anchor,ui,1)

# Premium compact accordion styling for the structure canvas.
style_anchor='</style>'
css=r'''

/* Forms 1.3.33: section + row accordions in Struttura del modulo. */
.df-layout-accordion-toolbar{display:flex;justify-content:flex-end;gap:8px;margin:0 0 10px;flex-wrap:wrap}
.df-layout-accordion-toolbar .df-btn{min-height:34px;padding:6px 11px;font-size:12px}
.df-layout-section-group{border:1px solid var(--df-border);border-radius:12px;background:var(--bs-body-bg,#fff);overflow:hidden;margin:0 0 10px}
.df-layout-section-head{display:flex;align-items:center;gap:10px;min-height:48px;padding:8px 10px;background:color-mix(in srgb,var(--bs-secondary-bg,#f4f6f8) 82%,transparent);border:0;width:100%;text-align:left;color:inherit}
.df-layout-section-head:hover{background:color-mix(in srgb,var(--bs-secondary-bg,#eef1f4) 94%,transparent)}
.df-layout-section-chevron{width:20px;flex:0 0 20px;font-weight:900;transition:transform .16s ease}.df-layout-section-group.is-open>.df-layout-section-head .df-layout-section-chevron{transform:rotate(90deg)}
.df-layout-section-title{min-width:0;flex:1;display:flex;align-items:center;gap:9px;flex-wrap:wrap}.df-layout-section-title strong{font-size:13px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:min(480px,55vw)}
.df-layout-section-summary{font-size:11px;color:var(--bs-secondary-color,#667085);font-weight:650}.df-layout-section-actions{display:flex;align-items:center;gap:4px;flex:0 0 auto}
.df-layout-section-body{display:none;padding:9px}.df-layout-section-group.is-open>.df-layout-section-body{display:block}
.df-layout-row-group{border:1px solid color-mix(in srgb,var(--df-border) 82%,transparent);border-radius:9px;overflow:hidden;margin:0 0 8px}.df-layout-row-group:last-child{margin-bottom:0}
.df-layout-row-head{display:flex;align-items:center;gap:8px;width:100%;border:0;background:color-mix(in srgb,var(--bs-body-bg,#fff) 94%,var(--bs-secondary-bg,#f3f4f6));padding:7px 9px;min-height:38px;color:inherit;text-align:left}
.df-layout-row-head:hover{background:var(--bs-secondary-bg,#f4f5f7)}.df-layout-row-chevron{width:18px;flex:0 0 18px;font-weight:900;transition:transform .16s ease}.df-layout-row-group.is-open>.df-layout-row-head .df-layout-row-chevron{transform:rotate(90deg)}
.df-layout-row-label{font-size:12px;font-weight:800}.df-layout-row-summary{font-size:11px;color:var(--bs-secondary-color,#667085);margin-left:auto}.df-layout-row-body{display:none;padding:7px}.df-layout-row-group.is-open>.df-layout-row-body{display:block}
.df-layout-row-body>.df-layout-row{margin:0}.df-layout-section-empty{padding:9px 10px;font-size:12px;color:var(--bs-secondary-color,#667085)}
.df-layout-section-head.is-over,.df-layout-row-head.is-over{box-shadow:inset 0 0 0 2px #0d6efd}
@media(max-width:720px){.df-layout-section-summary,.df-layout-row-summary{display:none}.df-layout-section-head{padding:8px}.df-layout-section-title strong{max-width:48vw}}
'''
if style_anchor not in s: raise SystemExit('1.3.33: style anchor missing')
s=s.replace(style_anchor,css+style_anchor,1)

# Replace the existing flat canvas with section + row accordion rendering while preserving field actions and DnD.
start=s.find('function renderLayoutCanvas(){')
end=s.find('function ensureInitialFieldWorkspace(){',start)
if start<0 or end<0: raise SystemExit('1.3.33: renderLayoutCanvas block missing')
new_js=r'''const layoutSectionState=new Map(),layoutRowState=new Map();
function isLayoutSectionField(f){return !!f&&(f.type==='heading'||(f.type==='fieldset'&&f.config?.builder_role==='section'));}
function layoutSectionTitle(f){if(!f)return structureUi.general;return String(f.label||f.config?.content||structureUi.section).trim()||structureUi.section;}
function layoutFieldCount(rows){return rows.reduce((n,r)=>n+r.items.filter(([f])=>!isLayoutSectionField(f)).length,0);}
function renderLayoutFieldCard(f,i,rowNo,row){
 const card=document.createElement('div');card.className='df-layout-card'+(f.key===activeFieldKey?' is-active':'');card.dataset.fieldKey=f.key;card.draggable=true;card.style.width='100%';const required=f.required?'<span class="df-required-badge">Obbligatorio</span>':'';
 card.innerHTML=`<span class="df-layout-handle" title="Trascina" aria-hidden="true">⋮⋮</span><strong>${esc(f.label)}</strong><span class="df-layout-meta"><span class="df-layout-type">${esc(tr.types[f.type]||f.type)}</span>${required}<select aria-label="Larghezza campo">${widthChoices(f.config.layout.width||100)}</select><span class="df-layout-actions"><button type="button" data-canvas-edit class="df-icon-only" title="Modifica campo" aria-label="Modifica campo">${uiIcon('edit')}</button><button type="button" data-canvas-duplicate class="df-icon-only" title="Duplica campo" aria-label="Duplica campo">${uiIcon('copy')}</button><button type="button" data-canvas-remove class="df-canvas-remove df-icon-only" title="Elimina campo" aria-label="Elimina campo">${uiIcon('trash')}</button></span></span><div class="df-layout-drop-guide" aria-hidden="true"><span data-drop-side="before">← Stessa riga</span><span data-drop-newrow>Nuova riga ↓</span><span data-drop-side="after">Stessa riga →</span></div>`;
 card.addEventListener('click',e=>{if(e.target.closest('button,select,[data-drop-side],[data-drop-newrow]'))return;selectField(i);});
 card.addEventListener('dragstart',e=>{draggedFieldIndex=i;try{e.dataTransfer.effectAllowed='move';e.dataTransfer.setData('text/plain',f.key);}catch{}card.classList.add('dragging');document.querySelector('.df-builder-workspace')?.classList.add('is-dragging');});
 card.addEventListener('dragend',()=>{draggedFieldIndex=null;card.classList.remove('dragging');document.querySelector('.df-builder-workspace')?.classList.remove('is-dragging');document.querySelectorAll('.is-over').forEach(x=>x.classList.remove('is-over'));});
 card.querySelectorAll('[data-drop-side]').forEach(zone=>{zone.addEventListener('dragover',e=>{e.preventDefault();e.stopPropagation();zone.classList.add('is-over');});zone.addEventListener('dragleave',()=>zone.classList.remove('is-over'));zone.addEventListener('drop',e=>{e.preventDefault();e.stopPropagation();zone.classList.remove('is-over');moveFieldBeside(draggedFieldIndex,i,zone.dataset.dropSide);});});
 const newRowZone=card.querySelector('[data-drop-newrow]');newRowZone.addEventListener('dragover',e=>{e.preventDefault();e.stopPropagation();newRowZone.classList.add('is-over');});newRowZone.addEventListener('dragleave',()=>newRowZone.classList.remove('is-over'));newRowZone.addEventListener('drop',e=>{e.preventDefault();e.stopPropagation();newRowZone.classList.remove('is-over');moveFieldToNewRowAfter(draggedFieldIndex,rowNo);});
 card.addEventListener('dragover',e=>{e.preventDefault();e.stopPropagation();});
 card.querySelector('select').onchange=e=>setFieldWidth(i,Number(e.target.value));card.querySelector('[data-canvas-edit]').onclick=()=>selectField(i);card.querySelector('[data-canvas-duplicate]').onclick=()=>duplicateField(i);card.querySelector('[data-canvas-remove]').onclick=()=>confirmDelete(`il campo “${f.label||'Campo'}”`,()=>removeCanvasField(i));row.appendChild(card);
}
function layoutGroups(){
 const rows=[...new Set(selected.map(f=>Number(f.config.layout.row||1)))].sort((a,b)=>a-b).map(rowNo=>({rowNo,items:fieldsInRow(rowNo)}));
 const groups=[];let current={id:'general',sectionField:null,title:structureUi.general,rows:[]};
 rows.forEach(model=>{const marker=model.items.find(([f])=>isLayoutSectionField(f));if(marker){if(current.rows.length||current.sectionField)groups.push(current);const [sf,si]=marker;current={id:'section:'+sf.key,sectionField:marker,title:layoutSectionTitle(sf),rows:[]};const rest=model.items.filter(x=>x!==marker);if(rest.length)current.rows.push({rowNo:model.rowNo,items:rest});}else current.rows.push(model);});
 if(current.rows.length||current.sectionField||!groups.length)groups.push(current);return groups;
}
function renderLayoutCanvas(){
 if(!layoutCanvas)return;normalizeLayoutRows();layoutCanvas.innerHTML='';
 if(!selected.length){layoutCanvas.innerHTML='<div class="df-layout-empty">Il modulo è vuoto. Premi “Aggiungi campo” per iniziare.</div>';return;}
 const groups=layoutGroups();
 const toolbar=document.createElement('div');toolbar.className='df-layout-accordion-toolbar';toolbar.innerHTML=`<button type="button" class="df-btn df-small" data-layout-expand>${esc(structureUi.expandAll)}</button><button type="button" class="df-btn df-small" data-layout-collapse>${esc(structureUi.collapseAll)}</button>`;layoutCanvas.appendChild(toolbar);
 toolbar.querySelector('[data-layout-expand]').onclick=()=>{groups.forEach(g=>{layoutSectionState.set(g.id,true);g.rows.forEach(r=>layoutRowState.set(r.rowNo,true));});renderLayoutCanvas();};
 toolbar.querySelector('[data-layout-collapse]').onclick=()=>{groups.forEach(g=>{layoutSectionState.set(g.id,false);g.rows.forEach(r=>layoutRowState.set(r.rowNo,false));});renderLayoutCanvas();};
 groups.forEach((group,gi)=>{
  const activeInGroup=(group.sectionField?.[0]?.key===activeFieldKey)||group.rows.some(r=>r.items.some(([f])=>f.key===activeFieldKey));const sectionOpen=layoutSectionState.has(group.id)?layoutSectionState.get(group.id):(activeInGroup||groups.length===1||(gi===0&&!activeFieldKey));
  const wrap=document.createElement('div');wrap.className='df-layout-section-group'+(sectionOpen?' is-open':'');wrap.dataset.sectionId=group.id;
  const head=document.createElement('div');head.className='df-layout-section-head';head.setAttribute('role','button');head.tabIndex=0;const count=layoutFieldCount(group.rows),rowCount=group.rows.length;const sectionActions=group.sectionField?`<span class="df-layout-section-actions"><button type="button" data-section-edit class="df-icon-only" title="Modifica sezione" aria-label="Modifica sezione">${uiIcon('edit')}</button><button type="button" data-section-copy class="df-icon-only" title="Duplica sezione" aria-label="Duplica sezione">${uiIcon('copy')}</button><button type="button" data-section-remove class="df-icon-only" title="Elimina sezione" aria-label="Elimina sezione">${uiIcon('trash')}</button></span>`:'';
  head.innerHTML=`<span class="df-layout-section-chevron">›</span><span class="df-layout-section-title"><strong>${esc(group.title)}</strong><span class="df-layout-section-summary">${count} ${esc(structureUi.fields)} · ${rowCount} ${esc(structureUi.rows)}</span></span>${sectionActions}`;
  const toggleSection=()=>{layoutSectionState.set(group.id,!wrap.classList.contains('is-open'));renderLayoutCanvas();};head.addEventListener('click',e=>{if(e.target.closest('button'))return;toggleSection();});head.addEventListener('keydown',e=>{if((e.key==='Enter'||e.key===' ')&&!e.target.closest('button')){e.preventDefault();toggleSection();}});
  if(group.sectionField){const [sf,si]=group.sectionField;head.querySelector('[data-section-edit]').onclick=e=>{e.stopPropagation();selectField(si);layoutSectionState.set(group.id,true);renderLayoutCanvas();};head.querySelector('[data-section-copy]').onclick=e=>{e.stopPropagation();duplicateField(si);};head.querySelector('[data-section-remove]').onclick=e=>{e.stopPropagation();confirmDelete(`la sezione “${sf.label||structureUi.section}”`,()=>removeCanvasField(si));};}
  const targetRow=group.rows[0]?.rowNo||(group.sectionField?Number(group.sectionField[0].config.layout.row||1)+1:1);head.addEventListener('dragover',e=>{if(draggedFieldIndex==null)return;e.preventDefault();head.classList.add('is-over');});head.addEventListener('dragleave',()=>head.classList.remove('is-over'));head.addEventListener('drop',e=>{if(draggedFieldIndex==null)return;e.preventDefault();head.classList.remove('is-over');moveFieldToRow(draggedFieldIndex,targetRow);});
  const body=document.createElement('div');body.className='df-layout-section-body';
  if(!group.rows.length){const empty=document.createElement('div');empty.className='df-layout-section-empty';empty.textContent='Sezione vuota';body.appendChild(empty);}
  group.rows.forEach((model,ri)=>{const rowActive=model.items.some(([f])=>f.key===activeFieldKey),rowOpen=layoutRowState.has(model.rowNo)?layoutRowState.get(model.rowNo):(rowActive||(sectionOpen&&group.rows.length===1));const rowGroup=document.createElement('div');rowGroup.className='df-layout-row-group'+(rowOpen?' is-open':'');const rowHead=document.createElement('div');rowHead.className='df-layout-row-head';rowHead.setAttribute('role','button');rowHead.tabIndex=0;const widths=model.items.map(([f])=>Number(f.config.layout.width||100)+'%').join(' + ');rowHead.innerHTML=`<span class="df-layout-row-chevron">›</span><span class="df-layout-row-label">${esc(structureUi.row)} ${model.rowNo}</span><span class="df-layout-row-summary">${model.items.length} ${esc(structureUi.fields)} · ${esc(widths)}</span>`;const toggleRow=()=>{layoutRowState.set(model.rowNo,!rowGroup.classList.contains('is-open'));renderLayoutCanvas();};rowHead.onclick=toggleRow;rowHead.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();toggleRow();}};rowHead.addEventListener('dragover',e=>{if(draggedFieldIndex==null)return;e.preventDefault();rowHead.classList.add('is-over');});rowHead.addEventListener('dragleave',()=>rowHead.classList.remove('is-over'));rowHead.addEventListener('drop',e=>{if(draggedFieldIndex==null)return;e.preventDefault();rowHead.classList.remove('is-over');moveFieldToRow(draggedFieldIndex,model.rowNo);});
   const rowBody=document.createElement('div');rowBody.className='df-layout-row-body';const row=document.createElement('div');row.className='df-layout-row';row.dataset.row=String(model.rowNo);row.style.gridTemplateColumns=model.items.map(([f])=>Math.max(10,Number(f.config.layout.width||100))+'fr').join(' ');model.items.forEach(([f,i])=>renderLayoutFieldCard(f,i,model.rowNo,row));row.addEventListener('dragover',e=>{if(e.target.closest('.df-layout-card'))return;e.preventDefault();row.classList.add('is-over');});row.addEventListener('dragleave',e=>{if(!row.contains(e.relatedTarget))row.classList.remove('is-over');});row.addEventListener('drop',e=>{if(e.target.closest('.df-layout-card'))return;e.preventDefault();row.classList.remove('is-over');moveFieldToRow(draggedFieldIndex,model.rowNo);});rowBody.appendChild(row);rowGroup.append(rowHead,rowBody);body.appendChild(rowGroup);
  });
  wrap.append(head,body);layoutCanvas.appendChild(wrap);
 });sync();
}
'''
s=s[:start]+new_js+s[end:]

# Runtime version marker.
s=s.replace("window.dfBuilderRuntime={version:'1.3.32'","window.dfBuilderRuntime={version:'1.3.33'",1)

# Add translations in administrator language files.
translations={
'it-IT':{'COM_DECAROFORMS_FIELD_EMPTY_SECTION':'Sezione vuota','COM_DECAROFORMS_FIELD_EMPTY_ROW':'Riga vuota / Spazio','COM_DECAROFORMS_FIELD_DIVIDER_LINE':'Divisore linea','COM_DECAROFORMS_EXPAND_ALL':'Espandi tutto','COM_DECAROFORMS_COLLAPSE_ALL':'Comprimi tutto','COM_DECAROFORMS_GENERAL_SECTION':'Generale','COM_DECAROFORMS_SECTION':'Sezione','COM_DECAROFORMS_ROW':'Riga','COM_DECAROFORMS_FIELDS':'campi','COM_DECAROFORMS_ROWS':'righe'},
'en-GB':{'COM_DECAROFORMS_FIELD_EMPTY_SECTION':'Empty section','COM_DECAROFORMS_FIELD_EMPTY_ROW':'Empty row / Spacer','COM_DECAROFORMS_FIELD_DIVIDER_LINE':'Divider line','COM_DECAROFORMS_EXPAND_ALL':'Expand all','COM_DECAROFORMS_COLLAPSE_ALL':'Collapse all','COM_DECAROFORMS_GENERAL_SECTION':'General','COM_DECAROFORMS_SECTION':'Section','COM_DECAROFORMS_ROW':'Row','COM_DECAROFORMS_FIELDS':'fields','COM_DECAROFORMS_ROWS':'rows'},
'fr-FR':{'COM_DECAROFORMS_FIELD_EMPTY_SECTION':'Section vide','COM_DECAROFORMS_FIELD_EMPTY_ROW':'Ligne vide / Espace','COM_DECAROFORMS_FIELD_DIVIDER_LINE':'Ligne de séparation','COM_DECAROFORMS_EXPAND_ALL':'Tout développer','COM_DECAROFORMS_COLLAPSE_ALL':'Tout réduire','COM_DECAROFORMS_GENERAL_SECTION':'Général','COM_DECAROFORMS_SECTION':'Section','COM_DECAROFORMS_ROW':'Ligne','COM_DECAROFORMS_FIELDS':'champs','COM_DECAROFORMS_ROWS':'lignes'}}
for lang,vals in translations.items():
    p=root/'administrator/components/com_decaroforms/language'/lang/'com_decaroforms.ini'
    if not p.exists(): continue
    t=p.read_text(encoding='utf-8')
    for k,v in vals.items():
        if k not in t: t+=f'\n{k}="{v}"'
    p.write_text(t+'\n' if not t.endswith('\n') else t,encoding='utf-8')

# Assertions.
assert "['key'=>'empty_section'" in h
assert "['key'=>'empty_row'" in h
assert "['key'=>'divider_line'" in h
assert 'function layoutGroups()' in s
assert 'df-layout-section-group' in s
assert 'df-layout-row-group' in s
assert 'data-layout-expand' in s and 'data-layout-collapse' in s
assert "version:'1.3.33'" in s
builder.write_text(s,encoding='utf-8')
PY

# Update component metadata/version strings.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)

php -l "$BUILDER" >/dev/null
php -l "$HELPER" >/dev/null
python3 - "$BUILDER" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
assert 'function layoutGroups()' in s
assert 'df-layout-section-group' in s
assert 'df-layout-row-group' in s
# Syntax-check the main Builder JS region.
a=s.index('const layoutSectionState=')
b=s.index('function ensureInitialFieldWorkspace(){',a)
Path('/tmp/forms-structure-1333-check.js').write_text(s[a:b],encoding='utf-8')
PY
node --check /tmp/forms-structure-1333-check.js >/dev/null

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
<changelogs><changelog><element>pkg_decaroforms</element><type>package</type><version>$NEW</version><feature>Struttura del modulo: sezioni e righe ora possono essere aperte e chiuse come accordion.</feature><feature>Aggiunti Espandi tutto e Comprimi tutto per moduli lunghi.</feature><feature>Aggiunti nella Libreria Struttura: Sezione vuota, Riga vuota / Spazio e Divisore linea.</feature><improvement>Le sezioni chiuse mostrano un riepilogo compatto con numero di campi e righe; le righe mostrano numero campi e larghezze.</improvement><improvement>Drag &amp; drop supportato anche sulle intestazioni di sezione e riga.</improvement><note>I nuovi elementi strutturali usano tipi già supportati e non diventano colonne/dati negli invii.</note><language>it-IT</language></changelog></changelogs>
EOF
rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
