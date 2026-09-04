#!/usr/bin/env python3
from pathlib import Path
import re
import sys

if len(sys.argv) != 3:
    raise SystemExit('usage: patch.py COMPONENT_ROOT PLUGIN_ROOT')

comp = Path(sys.argv[1])
plug = Path(sys.argv[2])
builder = comp / 'administrator/components/com_decaroforms/tmpl/builder/default.php'
helper = comp / 'administrator/components/com_decaroforms/src/Helper/FormHelper.php'
component_manifest = comp / 'com_decaroforms.xml'
plugin_manifest = plug / 'decaroforms.xml'

t = builder.read_text()
h = helper.read_text()

old_sections = '''    <section class="df-section" data-accordion>
      <button class="df-section-toggle" type="button" aria-expanded="false"><strong>3. <?php echo Text::_('COM_DECAROFORMS_SECTION_SELECTED'); ?></strong><span class="df-section-chevron">⌄</span></button>
      <div class="df-section-body-wrap"><div class="df-section-body-inner"><div class="df-section-body"><div class="df-selected" id="df-selected"></div></div></div></div>
    </section>

    <section class="df-section" data-accordion>
      <button class="df-section-toggle" type="button" aria-expanded="false"><strong>4. <?php echo Text::_('COM_DECAROFORMS_SECTION_LAYOUT'); ?></strong><span class="df-section-chevron">⌄</span></button>
      <div class="df-section-body-wrap"><div class="df-section-body-inner"><div class="df-section-body">
        <div class="df-layout-visual-head"><div><strong>Layout visuale</strong><div class="df-note">Trascina i campi tra le righe e scegli rapidamente la larghezza.</div></div><label class="df-switch"><input type="checkbox" id="df-layout-mobile-stack"><span class="df-switch-ui" aria-hidden="true"></span><span><?php echo Text::_('COM_DECAROFORMS_LAYOUT_MOBILE_STACK'); ?></span></label></div>
        <div class="df-layout-canvas" id="df-layout-canvas"></div>
        <div class="df-layout-newrow" id="df-layout-newrow">Trascina qui un campo per creare una nuova riga</div>
        <details class="df-layout-advanced-box"><summary><strong>Impostazioni layout avanzate</strong></summary><div style="padding-top:10px"><div class="df-grid"><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_LAYOUT_COLUMNS'); ?></label><select id="df-layout-columns"><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option></select></div><div class="df-field"><span class="df-layout-total" id="df-layout-total"></span></div></div><div class="df-layout-widths" id="df-layout-widths"></div><div class="df-spread" style="margin-top:8px"><div class="df-presets"><button class="df-preset" type="button" data-layout-preset="100">100%</button><button class="df-preset" type="button" data-layout-preset="50,50">50 / 50</button><button class="df-preset" type="button" data-layout-preset="30,70">30 / 70</button><button class="df-preset" type="button" data-layout-preset="70,30">70 / 30</button><button class="df-preset" type="button" data-layout-preset="33,33,34">33 / 33 / 34</button><button class="df-preset" type="button" data-layout-preset="25,25,25,25">25 / 25 / 25 / 25</button></div><button class="df-btn df-small" type="button" id="df-layout-apply"><?php echo Text::_('COM_DECAROFORMS_LAYOUT_APPLY_FIELDS'); ?></button></div></div></details>
      </div></div></div>
    </section>'''

new_section = '''    <section class="df-section" data-accordion>
      <button class="df-section-toggle" type="button" aria-expanded="false"><strong>3. Campi del modulo</strong><span class="df-section-chevron">⌄</span></button>
      <div class="df-section-body-wrap"><div class="df-section-body-inner"><div class="df-section-body">
        <div class="df-builder-workspace">
          <div class="df-form-canvas-panel">
            <div class="df-layout-visual-head"><div><strong>Struttura del modulo</strong><div class="df-note">Trascina i campi per cambiare ordine o riga. La linea blu appare nel punto di rilascio.</div></div><label class="df-switch"><input type="checkbox" id="df-layout-mobile-stack"><span class="df-switch-ui" aria-hidden="true"></span><span><?php echo Text::_('COM_DECAROFORMS_LAYOUT_MOBILE_STACK'); ?></span></label></div>
            <div class="df-layout-canvas" id="df-layout-canvas"></div>
            <div class="df-layout-newrow" id="df-layout-newrow">Rilascia qui per creare una nuova riga</div>
            <button class="df-add-field-main" type="button" id="df-open-library"><span aria-hidden="true">＋</span> Aggiungi campo</button>
            <details class="df-layout-advanced-box"><summary><strong>Impostazioni layout avanzate</strong></summary><div style="padding-top:10px"><div class="df-grid"><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_LAYOUT_COLUMNS'); ?></label><select id="df-layout-columns"><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option></select></div><div class="df-field"><span class="df-layout-total" id="df-layout-total"></span></div></div><div class="df-layout-widths" id="df-layout-widths"></div><div class="df-spread" style="margin-top:8px"><div class="df-presets"><button class="df-preset" type="button" data-layout-preset="100">100%</button><button class="df-preset" type="button" data-layout-preset="50,50">50 / 50</button><button class="df-preset" type="button" data-layout-preset="30,70">30 / 70</button><button class="df-preset" type="button" data-layout-preset="70,30">70 / 30</button><button class="df-preset" type="button" data-layout-preset="33,33,34">33 / 33 / 34</button><button class="df-preset" type="button" data-layout-preset="25,25,25,25">25 / 25 / 25 / 25</button></div><button class="df-btn df-small" type="button" id="df-layout-apply"><?php echo Text::_('COM_DECAROFORMS_LAYOUT_APPLY_FIELDS'); ?></button></div></div></details>
          </div>
          <aside class="df-properties-panel" aria-live="polite">
            <div class="df-properties-title"><div><strong>Impostazioni campo</strong><span>Seleziona un campo per modificarlo</span></div></div>
            <div class="df-selected" id="df-selected"></div>
          </aside>
        </div>
      </div></div></div>
    </section>'''

if old_sections not in t:
    raise RuntimeError('1.3.12 selected/layout sections not found')
t = t.replace(old_sections, new_section, 1)

for old, new in [('5.', '4.'), ('6.', '5.'), ('7.', '6.'), ('8.', '7.'), ('9.', '8.'), ('10.', '9.')]:
    t = t.replace(f'<strong>{old} <?php', f'<strong>{new} <?php', 1)

css = r'''
/* Forms 1.3.13: compact visual field builder. */
.df-builder-workspace{display:grid;grid-template-columns:minmax(0,1fr) minmax(300px,360px);gap:14px;align-items:start}
.df-form-canvas-panel,.df-properties-panel{min-width:0;border:1px solid var(--df-border);border-radius:8px;background:var(--bs-body-bg,#fff)}
.df-form-canvas-panel{padding:14px}.df-properties-panel{position:sticky;top:12px;max-height:calc(100vh - 32px);overflow:auto}
.df-properties-title{padding:13px 14px;border-bottom:1px solid var(--df-border);background:var(--bs-tertiary-bg,#f7f8fa)}
.df-properties-title strong,.df-properties-title span{display:block}.df-properties-title span{margin-top:2px;color:var(--bs-secondary-color,#667085);font-size:11px}
.df-builder-workspace .df-layout-canvas{gap:7px}.df-builder-workspace .df-layout-row{position:relative;min-height:54px;padding:5px;gap:6px;border-style:solid;background:color-mix(in srgb,var(--bs-tertiary-bg,#f7f8fa) 38%,transparent)}
.df-builder-workspace .df-layout-row.is-over{border-color:var(--df);box-shadow:inset 0 0 0 1px var(--df)}
.df-builder-workspace .df-layout-card{min-width:110px;min-height:42px;padding:5px 7px;gap:7px;border-radius:6px;box-shadow:none;transition:border-color .16s,box-shadow .16s,background .16s}
.df-builder-workspace .df-layout-card:hover,.df-builder-workspace .df-layout-card.is-active{border-color:var(--df);box-shadow:0 0 0 2px color-mix(in srgb,var(--df) 12%,transparent)}
.df-builder-workspace .df-layout-card strong{font-size:13px}.df-builder-workspace .df-layout-handle{cursor:grab;font-size:16px;line-height:1;letter-spacing:-3px;padding:7px 3px}
.df-layout-meta{display:flex;align-items:center;gap:4px;margin-left:auto}.df-layout-type{max-width:92px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;padding:3px 6px;border-radius:999px;background:color-mix(in srgb,var(--df) 9%,transparent);color:var(--df);font-size:10px;font-weight:800}
.df-builder-workspace .df-layout-card select{min-width:62px;min-height:29px;height:29px;padding:2px 5px;font-size:11px}
.df-layout-actions{display:flex;align-items:center;gap:2px}.df-layout-actions button{width:29px;height:29px;padding:0;border:0;border-radius:5px;background:transparent;color:inherit;cursor:pointer;font-size:14px}.df-layout-actions button:hover{background:var(--bs-tertiary-bg,#eef1f5);color:var(--df)}.df-layout-actions .df-canvas-remove:hover{color:#b42318}
.df-builder-workspace .df-layout-newrow{display:none;min-height:34px;margin-top:7px;border-color:var(--df);color:var(--df);background:color-mix(in srgb,var(--df) 6%,transparent);font-weight:800}.df-builder-workspace.is-dragging .df-layout-newrow{display:flex}
.df-add-field-main{width:100%;min-height:38px;margin-top:9px;border:1px dashed color-mix(in srgb,var(--df) 70%,var(--df-border));border-radius:7px;background:color-mix(in srgb,var(--df) 4%,var(--bs-body-bg,#fff));color:var(--df);font-weight:850;cursor:pointer}.df-add-field-main:hover{background:color-mix(in srgb,var(--df) 9%,var(--bs-body-bg,#fff));border-style:solid}
.df-properties-panel .df-selected-empty{margin:12px;padding:20px 12px}.df-properties-panel .df-selected-item{display:none;border:0;border-radius:0}.df-properties-panel .df-selected-item.is-open{display:block}.df-properties-panel .df-selected-top{padding:9px 11px}.df-properties-panel .df-field-toggle{pointer-events:none}.df-properties-panel .df-field-chevron{display:none}.df-properties-panel .df-selected-config{grid-template-columns:1fr;gap:8px;padding:11px}.df-properties-panel .df-selected-config .full,.df-properties-panel .df-config-panel,.df-properties-panel .df-condition-details,.df-properties-panel .df-field-advanced{grid-column:auto}.df-properties-panel .df-selected-config input:not([type=checkbox]):not([type=radio]),.df-properties-panel .df-selected-config select{min-height:35px;padding:6px 8px}.df-properties-panel .df-mini-actions button[data-act="up"],.df-properties-panel .df-mini-actions button[data-act="down"]{display:none}
.df-field-width-pills{display:grid;grid-template-columns:repeat(3,1fr);gap:5px}.df-field-width-pills button{min-height:31px;border:1px solid var(--df-border);border-radius:5px;background:var(--bs-body-bg,#fff);color:inherit;font-size:11px;font-weight:800;cursor:pointer}.df-field-width-pills button.is-active{border-color:var(--df);background:color-mix(in srgb,var(--df) 10%,var(--bs-body-bg,#fff));color:var(--df)}
@media(max-width:1050px){.df-builder-workspace{grid-template-columns:1fr}.df-properties-panel{position:static;max-height:none}}
@media(max-width:800px){.df-builder-workspace .df-layout-row{flex-direction:row;flex-wrap:wrap}.df-builder-workspace .df-layout-card{width:100%!important}.df-layout-type{display:none}}
@media(max-width:560px){.df-form-canvas-panel{padding:10px}.df-builder-workspace .df-layout-card{min-height:46px}.df-layout-actions button{width:32px;height:32px}.df-builder-workspace .df-layout-card select{min-width:58px}.df-layout-visual-head .df-switch{width:100%}}
'''
if '</style>' not in t:
    raise RuntimeError('style closing tag missing')
t = t.replace('</style>', css + '\n</style>', 1)

t = t.replace(
    "const openFieldKeys=new Set(selected.slice(0,1).map(x=>x.key));",
    "const openFieldKeys=new Set(selected.slice(0,1).map(x=>x.key));let activeFieldKey=selected[0]?.key||null;",
    1,
)

old_add = "function add(item){const x=defaultFieldConfig(clone(item));x.key=uniqueKey(x.key);x.options=Array.isArray(x.options)?x.options:[];selected.push(x);openFieldKeys.add(x.key);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();const selectedSection=[...document.querySelectorAll('[data-accordion]')][2];if(selectedSection){selectedSection.classList.add('is-open');selectedSection.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','true');}setTimeout(()=>{if(selectedSection){selectedSection.classList.add('is-open');selectedSection.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','true');}const cards=sel.querySelectorAll('.df-selected-item');const card=cards[cards.length-1];if(card){card.classList.add('is-open');card.scrollIntoView({behavior:'smooth',block:'center'});}},140);}"
new_add = "function add(item){const x=defaultFieldConfig(clone(item));x.key=uniqueKey(x.key);x.options=Array.isArray(x.options)?x.options:[];const maxRow=Math.max(0,...selected.map(f=>Number(f.config?.layout?.row||0)));x.config.layout={row:maxRow+1,col:1,width:100};selected.push(x);activeFieldKey=x.key;openFieldKeys.clear();openFieldKeys.add(x.key);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();const selectedSection=[...document.querySelectorAll('[data-accordion]')][2];if(selectedSection){selectedSection.classList.add('is-open');selectedSection.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','true');}setTimeout(()=>{sel.querySelector('.df-selected-item.is-open')?.scrollIntoView({behavior:'smooth',block:'nearest'});},100);}"
if old_add not in t:
    raise RuntimeError('1.3.12 add() function not found')
t = t.replace(old_add, new_add, 1)

t = t.replace(
    "openFieldKeys.clear();\n  if(selected[0])openFieldKeys.add(selected[0].key);",
    "openFieldKeys.clear();\n  activeFieldKey=selected[0]?.key||null;\n  if(activeFieldKey)openFieldKeys.add(activeFieldKey);",
    1,
)

old_render_start = "function renderSelected(){sel.innerHTML='';if(!selected.length){sel.innerHTML=`<div class=\"df-selected-empty\">${esc(tr.empty)}</div>`;sync();renderLayoutCanvas();return;}selected.forEach((x,i)=>{defaultFieldConfig(x);const d=document.createElement('div');d.className='df-selected-item'+(openFieldKeys.has(x.key)?' is-open':'');"
new_render_start = "function renderSelected(){sel.innerHTML='';if(!selected.length){activeFieldKey=null;openFieldKeys.clear();sel.innerHTML='<div class=\"df-selected-empty\">Seleziona o aggiungi un campo per modificarne le impostazioni.</div>';sync();renderLayoutCanvas();return;}if(!selected.some(x=>x.key===activeFieldKey))activeFieldKey=selected[0].key;openFieldKeys.clear();openFieldKeys.add(activeFieldKey);selected.forEach((x,i)=>{defaultFieldConfig(x);const d=document.createElement('div');d.className='df-selected-item'+(x.key===activeFieldKey?' is-open':'');"
if old_render_start not in t:
    raise RuntimeError('renderSelected start not found')
t = t.replace(old_render_start, new_render_start, 1)

t = t.replace(
    "${configHtml(x)}<details class=\"df-field-advanced\">",
    "<div class=\"full\"><label>Larghezza</label><div class=\"df-field-width-pills\">${[100,75,66,50,33,25].map(w=>`<button type=\"button\" data-field-width=\"${w}\" class=\"${Number(x.config.layout.width||100)===w?'is-active':''}\">${w}%</button>`).join('')}</div></div>${configHtml(x)}<details class=\"df-field-advanced\">",
    1,
)

t = t.replace(
    " d.querySelector('[data-field-toggle]').onclick=()=>{openFieldKeys.has(x.key)?openFieldKeys.delete(x.key):openFieldKeys.add(x.key);d.classList.toggle('is-open',openFieldKeys.has(x.key));};",
    " d.querySelector('[data-field-toggle]').onclick=()=>{};d.querySelectorAll('[data-field-width]').forEach(btn=>btn.onclick=()=>{x.config.layout.width=Number(btn.dataset.fieldWidth);sync();renderSelected();renderLayoutCanvas();});",
    1,
)

t = t.replace(
    "d.querySelector('[data-act=\"remove\"]').onclick=()=>{openFieldKeys.delete(x.key);selected.splice(i,1);normalizeLayoutRows();renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();};",
    "d.querySelector('[data-act=\"remove\"]').onclick=()=>{openFieldKeys.delete(x.key);selected.splice(i,1);activeFieldKey=selected[Math.min(i,selected.length-1)]?.key||null;normalizeLayoutRows();renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();};",
    1,
)

layout_pattern = re.compile(r"function widthChoices\(current\)\{.*?layoutNewRow\?\.addEventListener\('drop',e=>\{.*?\}\);", re.S)
layout_match = layout_pattern.search(t)
if not layout_match:
    raise RuntimeError('1.3.12 visual layout block not found')
new_layout = r'''function widthChoices(current){const vals=[100,75,66,50,33,25];if(!vals.includes(Number(current)))vals.push(Number(current)||100);return vals.map(v=>`<option value="${v}" ${Number(current)===v?'selected':''}>${v}%</option>`).join('');}
function selectField(index){if(index==null||!selected[index])return;activeFieldKey=selected[index].key;openFieldKeys.clear();openFieldKeys.add(activeFieldKey);renderSelected();renderLayoutCanvas();}
function duplicateField(index){if(index==null||!selected[index])return;const copy=clone(selected[index]);copy.key=uniqueKey(copy.key);copy.label=`${copy.label} copia`;defaultFieldConfig(copy);selected.splice(index+1,0,copy);activeFieldKey=copy.key;openFieldKeys.clear();openFieldKeys.add(copy.key);normalizeLayoutRows();renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();}
function removeCanvasField(index){if(index==null||!selected[index])return;const old=selected[index].key;selected.splice(index,1);openFieldKeys.delete(old);activeFieldKey=selected[Math.min(index,selected.length-1)]?.key||null;normalizeLayoutRows();renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();sync();}
function moveFieldToRow(index,row,targetIndex=null){if(index==null||!selected[index])return;const field=selected[index];selected.splice(index,1);let insertAt=targetIndex==null?selected.length:Number(targetIndex);if(index<insertAt)insertAt--;insertAt=Math.max(0,Math.min(selected.length,insertAt));field.config.layout.row=row;selected.splice(insertAt,0,field);normalizeLayoutRows();activeFieldKey=field.key;sync();renderSelected();renderLayoutCanvas();}
function renderLayoutCanvas(){if(!layoutCanvas)return;normalizeLayoutRows();layoutCanvas.innerHTML='';if(!selected.length){layoutCanvas.innerHTML='<div class="df-layout-empty">Il modulo è vuoto. Premi “Aggiungi campo” per iniziare.</div>';return;}const rows=[...new Set(selected.map(f=>Number(f.config.layout.row||1)))].sort((a,b)=>a-b);rows.forEach(rowNo=>{const row=document.createElement('div');row.className='df-layout-row';row.dataset.row=String(rowNo);selected.map((f,i)=>[f,i]).filter(([f])=>Number(f.config.layout.row||1)===rowNo).sort(([a],[b])=>(a.config.layout.col||1)-(b.config.layout.col||1)).forEach(([f,i])=>{const card=document.createElement('div');card.className='df-layout-card'+(f.key===activeFieldKey?' is-active':'');card.draggable=true;card.style.width=`${Math.max(10,Math.min(100,Number(f.config.layout.width||100)))}%`;const required=f.required?' *':'';card.innerHTML=`<span class="df-layout-handle" title="Trascina" aria-hidden="true">⋮⋮</span><strong>${esc(f.label)}${required}</strong><span class="df-layout-meta"><span class="df-layout-type">${esc(tr.types[f.type]||f.type)}</span><select aria-label="Larghezza campo">${widthChoices(f.config.layout.width||100)}</select><span class="df-layout-actions"><button type="button" data-canvas-edit title="Modifica" aria-label="Modifica">✎</button><button type="button" data-canvas-duplicate title="Duplica" aria-label="Duplica">⧉</button><button type="button" data-canvas-remove class="df-canvas-remove" title="Elimina" aria-label="Elimina">×</button></span></span>`;card.addEventListener('click',e=>{if(e.target.closest('button,select'))return;selectField(i);});card.addEventListener('dragstart',()=>{draggedFieldIndex=i;card.classList.add('dragging');document.querySelector('.df-builder-workspace')?.classList.add('is-dragging');});card.addEventListener('dragend',()=>{draggedFieldIndex=null;card.classList.remove('dragging');document.querySelector('.df-builder-workspace')?.classList.remove('is-dragging');document.querySelectorAll('.is-over').forEach(x=>x.classList.remove('is-over'));});card.addEventListener('dragover',e=>{e.preventDefault();e.stopPropagation();card.classList.add('is-over');});card.addEventListener('dragleave',()=>card.classList.remove('is-over'));card.addEventListener('drop',e=>{e.preventDefault();e.stopPropagation();card.classList.remove('is-over');moveFieldToRow(draggedFieldIndex,rowNo,i);});card.querySelector('select').onchange=e=>{f.config.layout.width=Number(e.target.value);sync();renderLayoutCanvas();renderSelected();};card.querySelector('[data-canvas-edit]').onclick=()=>selectField(i);card.querySelector('[data-canvas-duplicate]').onclick=()=>duplicateField(i);card.querySelector('[data-canvas-remove]').onclick=()=>removeCanvasField(i);row.appendChild(card);});row.addEventListener('dragover',e=>{e.preventDefault();row.classList.add('is-over');});row.addEventListener('dragleave',e=>{if(!row.contains(e.relatedTarget))row.classList.remove('is-over');});row.addEventListener('drop',e=>{if(e.target.closest('.df-layout-card'))return;e.preventDefault();row.classList.remove('is-over');moveFieldToRow(draggedFieldIndex,rowNo);});layoutCanvas.appendChild(row);});sync();}
layoutNewRow?.addEventListener('dragover',e=>{e.preventDefault();layoutNewRow.classList.add('is-over');});layoutNewRow?.addEventListener('dragleave',()=>layoutNewRow.classList.remove('is-over'));layoutNewRow?.addEventListener('drop',e=>{e.preventDefault();layoutNewRow.classList.remove('is-over');const max=Math.max(0,...selected.map(f=>Number(f.config?.layout?.row||1)));moveFieldToRow(draggedFieldIndex,max+1);});
document.getElementById('df-open-library')?.addEventListener('click',()=>openBuilderSection(3,true));'''
t = t[:layout_match.start()] + new_layout + t[layout_match.end():]

t = t.replace("document.querySelectorAll('[data-accordion]')[3]?.classList.add('is-open');", "document.querySelectorAll('[data-accordion]')[2]?.classList.add('is-open');", 1)

if "public const VERSION = '1.3.12'" not in h:
    raise RuntimeError('helper version 1.3.12 not found')
h = h.replace("public const VERSION = '1.3.12'", "public const VERSION = '1.3.13'", 1)
for p in (component_manifest, plugin_manifest):
    s = p.read_text()
    if '<version>1.3.12</version>' not in s:
        raise RuntimeError(f'1.3.12 version missing in {p.name}')
    p.write_text(s.replace('<version>1.3.12</version>', '<version>1.3.13</version>', 1))

builder.write_text(t)
helper.write_text(h)

final = builder.read_text()
for token in ['df-builder-workspace', 'Campi del modulo', 'df-field-width-pills', 'duplicateField(index)', "openBuilderSection(3,true)"]:
    if token not in final:
        raise RuntimeError('missing expected token: ' + token)
if '4. <?php echo Text_(\'COM_DECAROFORMS_SECTION_LAYOUT\')' in final:
    raise RuntimeError('old separate layout section still present')
print('Forms 1.3.13 compact builder patch applied')
