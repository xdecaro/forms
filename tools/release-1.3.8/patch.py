#!/usr/bin/env python3
from pathlib import Path
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

# 1) Saved custom field presets, reusable from Libreria > Personalizzati.
library_anchor = "const library=<?php echo json_encode(FormHelper::fieldLibrary(), JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;"
if library_anchor not in t:
    raise RuntimeError('library anchor not found')
preset_js = r'''
/* Forms 1.3.8: reusable saved field presets. */
const savedPresetStorageKey='decaroforms_saved_field_presets_v1';
function loadSavedFieldPresets(){
 try{
  const parsed=JSON.parse(localStorage.getItem(savedPresetStorageKey)||'[]');
  return Array.isArray(parsed)?parsed.filter(x=>x&&typeof x==='object'&&x.label&&x.type).slice(0,100):[];
 }catch(e){console.warn('Forms saved field presets could not be loaded',e);return [];}
}
function persistSavedFieldPresets(){
 try{localStorage.setItem(savedPresetStorageKey,JSON.stringify(savedFieldPresets));}
 catch(e){console.warn('Forms saved field presets could not be saved',e);}
}
let savedFieldPresets=loadSavedFieldPresets();
savedFieldPresets.forEach(p=>library.push({...p,category:'custom',_savedPresetId:p._savedPresetId||p.id||''}));
function saveFieldPreset(field){
 const copy=JSON.parse(JSON.stringify(field||{}));
 copy.category='custom';
 copy.options=Array.isArray(copy.options)?copy.options:[];
 const existing=savedFieldPresets.find(p=>String(p.key||'')===String(copy.key||'')&&String(p.label||'')===String(copy.label||''));
 copy._savedPresetId=existing?existing._savedPresetId:('saved_'+Date.now().toString(36)+'_'+Math.random().toString(36).slice(2,7));
 const idx=savedFieldPresets.findIndex(p=>p._savedPresetId===copy._savedPresetId);
 if(idx>=0)savedFieldPresets[idx]=copy;else savedFieldPresets.push(copy);
 persistSavedFieldPresets();
 const libIdx=library.findIndex(p=>p._savedPresetId===copy._savedPresetId);
 if(libIdx>=0)library[libIdx]=copy;else library.push(copy);
 renderLibrary();
 return copy._savedPresetId;
}
function deleteSavedFieldPreset(id){
 savedFieldPresets=savedFieldPresets.filter(p=>p._savedPresetId!==id);
 persistSavedFieldPresets();
 for(let i=library.length-1;i>=0;i--)if(library[i]._savedPresetId===id)library.splice(i,1);
 renderLibrary();
}
'''
t = t.replace(library_anchor, library_anchor + '\n' + preset_js, 1)

# 2) Add save icon to each selected field card.
actions_anchor = '<div class="df-mini-actions"><button type="button" data-act="up"'
if actions_anchor not in t:
    raise RuntimeError('selected field action anchor not found')
save_button = '<div class="df-mini-actions"><button type="button" data-act="save-preset" class="df-save-preset" title="Salva come campo personalizzato" aria-label="Salva come campo personalizzato"><svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M5 3h11l3 3v15H5V3zm2 2v5h9V5H7zm0 14h10v-6H7v6z" fill="currentColor"/></svg></button><button type="button" data-act="up"'
t = t.replace(actions_anchor, save_button, 1)

handler_anchor = " d.querySelector('[data-act=\"up\"]').onclick=()=>{if(i>0){[selected[i-1],selected[i]]=[selected[i],selected[i-1]];renderSelected();renderLayoutCanvas();}};"
if handler_anchor not in t:
    raise RuntimeError('selected field up handler anchor not found')
save_handler = " d.querySelector('[data-act=\"save-preset\"]').onclick=e=>{e.preventDefault();e.stopPropagation();saveFieldPreset(x);const btn=e.currentTarget;btn.classList.add('is-saved');btn.title='Salvato nei campi personalizzati';setTimeout(()=>{btn.classList.remove('is-saved');btn.title='Salva come campo personalizzato';},1200);};"
t = t.replace(handler_anchor, save_handler + handler_anchor, 1)

# 3) Saved presets get a remove action in the Personalizzati library.
old_library_item = " items.forEach(x=>{const d=document.createElement('div');d.className='df-lib-item';d.innerHTML=`<div><strong>${esc(x.label)}</strong><small>${esc(tr.cats[x.category]||x.category)} · ${esc(tr.types[x.type]||x.type)}</small></div><button class=\"df-add\" type=\"button\">${esc(tr.add)}</button>`;d.querySelector('button').onclick=()=>add(x);grid.appendChild(d);});lib.appendChild(grid);"
if old_library_item not in t:
    raise RuntimeError('library item renderer not found')
new_library_item = " items.forEach(x=>{const d=document.createElement('div');d.className='df-lib-item';const saved=!!x._savedPresetId;d.innerHTML=`<div><strong>${esc(x.label)}</strong><small>${esc(tr.cats[x.category]||x.category)} · ${esc(tr.types[x.type]||x.type)}${saved?' · Salvato':''}</small></div><div class=\"df-lib-actions\"><button class=\"df-add\" type=\"button\">${esc(tr.add)}</button>${saved?`<button class=\"df-lib-delete\" type=\"button\" title=\"${esc(tr.remove)}\" aria-label=\"${esc(tr.remove)}\">×</button>`:''}</div>`;d.querySelector('.df-add').onclick=()=>add(x);d.querySelector('.df-lib-delete')?.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();deleteSavedFieldPreset(x._savedPresetId);});grid.appendChild(d);});lib.appendChild(grid);"
t = t.replace(old_library_item, new_library_item, 1)

# 4) The 10 email template choices existed but were never rendered during initialization.
init_anchor = "filter.innerHTML='';filter.hidden=true;search.addEventListener('input',renderLibrary);renderLibrary();"
if init_anchor not in t:
    raise RuntimeError('library initialization anchor not found')
t = t.replace(init_anchor, init_anchor + "renderEmailPickers();", 1)
# A custom template may only inherit from the seven fixed templates, not from itself.
t = t.replace("templateDefs.slice(0,8).map", "templateDefs.slice(0,7).map", 1)

# 5) Light accordion styling selected by the user; keep existing dark mode overrides.
css = r'''
/* Forms 1.3.8 light accordion + saved-field controls */
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle{
  background:#f6f7f9!important;
  color:#1f2937!important;
  border-color:#d9dee5!important;
}
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle:hover{
  background:#eef1f4!important;
}
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section.is-open>.df-section-toggle{
  background:#f1f4f8!important;
}
.df-builder .df-save-preset svg{width:16px;height:16px;display:block}
.df-builder .df-save-preset.is-saved{
  border-color:#198754!important;
  color:#198754!important;
  box-shadow:0 0 0 2px color-mix(in srgb,#198754 14%,transparent)!important;
}
.df-builder .df-lib-actions{display:flex;align-items:center;gap:6px}
.df-builder .df-lib-delete{
  min-width:34px;height:34px;border:1px solid #dc3545;border-radius:5px;background:transparent;color:#b42332;font-weight:900;cursor:pointer;
}
.df-builder .df-lib-delete:hover,.df-builder .df-lib-delete:focus-visible{background:#dc3545;color:#fff}
@media(max-width:560px){
 .df-builder .df-mini-actions{flex-wrap:wrap}
 .df-builder .df-save-preset{order:-1}
}
'''
if '</style>' not in t:
    raise RuntimeError('builder style closing tag not found')
t = t.replace('</style>', css + '\n</style>', 1)

# Version bump.
if "public const VERSION = '1.3.7'" not in h:
    raise RuntimeError('helper version 1.3.7 not found')
h = h.replace("public const VERSION = '1.3.7'", "public const VERSION = '1.3.8'", 1)
for p in (component_manifest, plugin_manifest):
    s = p.read_text()
    if '<version>1.3.7</version>' not in s:
        raise RuntimeError(f'1.3.7 version missing in {p.name}')
    p.write_text(s.replace('<version>1.3.7</version>', '<version>1.3.8</version>', 1))

builder.write_text(t)
helper.write_text(h)

final = builder.read_text()
checks = [
    "savedPresetStorageKey='decaroforms_saved_field_presets_v1'",
    'data-act="save-preset"',
    'saveFieldPreset(x)',
    'df-lib-delete',
    'renderEmailPickers();',
    'templateDefs.slice(0,7).map',
    'background:#f6f7f9!important',
]
for token in checks:
    if token not in final:
        raise RuntimeError('missing expected token: ' + token)
print('Forms 1.3.8 patch applied')
