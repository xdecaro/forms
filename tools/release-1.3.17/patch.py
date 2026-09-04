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

def replace_once(text, old, new, label):
    if old not in text:
        raise RuntimeError(f'{label} not found')
    return text.replace(old, new, 1)

# Versions.
h = helper.read_text()
h = replace_once(h, "public const VERSION = '1.3.16';", "public const VERSION = '1.3.17';", 'helper version')
helper.write_text(h)
for manifest in (component_manifest, plugin_manifest):
    value = manifest.read_text()
    value = replace_once(value, '<version>1.3.16</version>', '<version>1.3.17</version>', str(manifest))
    manifest.write_text(value)

t = builder.read_text()

# Give the built-in quick models a destination for reusable user-created structures.
old_quick = '''<div class="df-section-body-wrap"><div class="df-section-body-inner"><div class="df-section-body"><div class="df-template-row"><button type="button" data-form-template="contact"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_CONTACT'); ?></button><button type="button" data-form-template="registration"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_REGISTRATION'); ?></button><button type="button" data-form-template="event"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_EVENT'); ?></button><button type="button" data-form-template="membership"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_MEMBERSHIP'); ?></button><button type="button" data-form-template="reservation"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_RESERVATION'); ?></button><button type="button" data-form-template="blank"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_BLANK'); ?></button></div><p class="df-note"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_NOTE'); ?></p></div></div></div>'''
new_quick = '''<div class="df-section-body-wrap"><div class="df-section-body-inner"><div class="df-section-body"><div class="df-template-row"><button type="button" data-form-template="contact"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_CONTACT'); ?></button><button type="button" data-form-template="registration"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_REGISTRATION'); ?></button><button type="button" data-form-template="event"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_EVENT'); ?></button><button type="button" data-form-template="membership"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_MEMBERSHIP'); ?></button><button type="button" data-form-template="reservation"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_RESERVATION'); ?></button><button type="button" data-form-template="blank"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_BLANK'); ?></button></div><div class="df-saved-quick-heading" id="df-saved-quick-heading" hidden>Modelli salvati</div><div class="df-template-row df-saved-quick-row" id="df-saved-quick-templates"></div><p class="df-note"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_NOTE'); ?></p></div></div></div>'''
t = replace_once(t, old_quick, new_quick, 'quick templates area')

# Add Save structure next to the layout/mobile controls.
old_layout_head = '''<div class="df-layout-visual-head"><div><strong>Struttura del modulo</strong><div class="df-note">Trascina i campi per cambiare ordine o riga. La linea blu appare nel punto di rilascio.</div></div><label class="df-switch"><input type="checkbox" id="df-layout-mobile-stack"><span class="df-switch-ui" aria-hidden="true"></span><span><?php echo Text::_('COM_DECAROFORMS_LAYOUT_MOBILE_STACK'); ?></span></label></div>'''
new_layout_head = '''<div class="df-layout-visual-head"><div><strong>Struttura del modulo</strong><div class="df-note">Trascina i campi per cambiare ordine o riga. La linea blu appare nel punto di rilascio.</div></div><div class="df-layout-head-actions"><button class="df-btn df-small df-save-structure" type="button" id="df-save-structure" title="Salva questa struttura nei Modelli rapidi">💾 Salva struttura</button><label class="df-switch"><input type="checkbox" id="df-layout-mobile-stack"><span class="df-switch-ui" aria-hidden="true"></span><span><?php echo Text::_('COM_DECAROFORMS_LAYOUT_MOBILE_STACK'); ?></span></label></div></div>'''
t = replace_once(t, old_layout_head, new_layout_head, 'layout head')

# Saved quick-model logic. Stored like the existing reusable field presets, so it is available to future modules in this browser.
anchor = '''document.addEventListener('click',e=>{const button=e.target.closest('[data-form-template]');if(!button)return;e.preventDefault();e.stopPropagation();applyQuickTemplate(button);});'''
quick_js = r'''

/* Forms 1.3.17: reusable quick models saved from the current module structure. */
const savedQuickTemplateStorageKey='decaroforms_saved_quick_templates_v1';
function loadSavedQuickTemplates(){
 try{const parsed=JSON.parse(localStorage.getItem(savedQuickTemplateStorageKey)||'[]');return Array.isArray(parsed)?parsed:[];}
 catch(e){console.warn('Forms saved quick models could not be loaded',e);return [];}
}
function persistSavedQuickTemplates(){
 try{localStorage.setItem(savedQuickTemplateStorageKey,JSON.stringify(savedQuickTemplates));}
 catch(e){console.warn('Forms saved quick models could not be saved',e);}
}
let savedQuickTemplates=loadSavedQuickTemplates();
function renderSavedQuickTemplates(){
 const box=document.getElementById('df-saved-quick-templates'),heading=document.getElementById('df-saved-quick-heading');
 if(!box)return;
 box.innerHTML='';
 if(heading)heading.hidden=!savedQuickTemplates.length;
 savedQuickTemplates.forEach(tpl=>{
  const wrap=document.createElement('span');wrap.className='df-saved-quick-item';
  wrap.innerHTML=`<button type="button" class="df-saved-quick-use" data-saved-quick="${esc(tpl.id)}" title="Carica modello rapido">${esc(tpl.name)}</button><button type="button" class="df-saved-quick-delete" data-saved-quick-delete="${esc(tpl.id)}" title="Elimina modello salvato" aria-label="Elimina modello salvato">×</button>`;
  box.appendChild(wrap);
 });
}
function saveCurrentStructureAsQuickTemplate(){
 if(!selected.length){alert('Aggiungi almeno un campo prima di salvare la struttura.');return;}
 const suggested=(document.querySelector('[name="title"]')?.value||'Modello personalizzato').trim();
 const name=(prompt('Nome del modello rapido:',suggested)||'').trim();
 if(!name)return;
 const fields=clone(selected);
 const existing=savedQuickTemplates.find(x=>String(x.name).toLowerCase()===name.toLowerCase());
 const entry={id:existing?.id||('quick_'+Date.now().toString(36)+'_'+Math.random().toString(36).slice(2,7)),name,fields};
 const idx=savedQuickTemplates.findIndex(x=>x.id===entry.id);
 if(idx>=0)savedQuickTemplates[idx]=entry;else savedQuickTemplates.push(entry);
 persistSavedQuickTemplates();renderSavedQuickTemplates();
 const quick=[...document.querySelectorAll('[data-accordion]')][1];
 quick?.classList.add('is-open');quick?.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','true');
 document.getElementById('df-saved-quick-heading')?.scrollIntoView({behavior:'smooth',block:'nearest'});
}
function applySavedQuickTemplate(id,button){
 const tpl=savedQuickTemplates.find(x=>x.id===id);if(!tpl)return;
 const next=(Array.isArray(tpl.fields)?tpl.fields:[]).map(f=>defaultFieldConfig(clone(f)));
 selected.splice(0,selected.length,...next);
 activeFieldKey=selected[0]?.key||null;
 normalizeLayoutRows();renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();sync();
 document.querySelectorAll('[data-form-template],.df-saved-quick-use').forEach(x=>x.classList.toggle('is-active',x===button));
 const quick=[...document.querySelectorAll('[data-accordion]')][1];
 quick?.classList.remove('is-open');quick?.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','false');
 const fieldsSection=[...document.querySelectorAll('[data-accordion]')][2];
 fieldsSection?.classList.add('is-open');fieldsSection?.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','true');
}
document.getElementById('df-save-structure')?.addEventListener('click',saveCurrentStructureAsQuickTemplate);
document.addEventListener('click',e=>{
 const use=e.target.closest('[data-saved-quick]');
 if(use){e.preventDefault();e.stopPropagation();applySavedQuickTemplate(use.dataset.savedQuick,use);return;}
 const del=e.target.closest('[data-saved-quick-delete]');
 if(del){e.preventDefault();e.stopPropagation();savedQuickTemplates=savedQuickTemplates.filter(x=>x.id!==del.dataset.savedQuickDelete);persistSavedQuickTemplates();renderSavedQuickTemplates();}
});
renderSavedQuickTemplates();
'''
t = replace_once(t, anchor, anchor + quick_js, 'saved quick template JS')

css = r'''
/* Forms 1.3.17: quick-model save action and light/dark contrast fixes. */
.df-layout-head-actions{display:flex;align-items:center;justify-content:flex-end;gap:12px;flex-wrap:wrap}
.df-save-structure{white-space:nowrap}
.df-saved-quick-heading{margin:13px 0 7px;font-size:12px;font-weight:850;color:var(--bs-secondary-color,#667085);text-transform:uppercase;letter-spacing:.04em}
.df-saved-quick-row{margin-bottom:8px}
.df-saved-quick-item{display:inline-flex;align-items:stretch;border:1px solid var(--df-border);border-radius:6px;overflow:hidden;background:var(--bs-body-bg,#fff)}
.df-saved-quick-item button{border:0!important;border-radius:0!important;box-shadow:none!important}
.df-saved-quick-use{background:var(--bs-body-bg,#fff)!important;color:inherit!important}
.df-saved-quick-use.is-active{color:var(--df)!important;background:color-mix(in srgb,var(--df) 7%,var(--bs-body-bg,#fff))!important}
.df-saved-quick-delete{min-width:34px!important;padding:0 8px!important;background:transparent!important;color:#b42318!important;border-left:1px solid var(--df-border)!important}
.df-saved-quick-delete:hover{background:#fff1f3!important;color:#a40024!important}

/* Library category pills: neutral by default, red only as a selection accent. */
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-library-tab,
html[data-bs-theme="light"] .df-builder .df-library-tab{
 background:#f6f7f9!important;color:#1f2937!important;border-color:#d9dee5!important;box-shadow:none!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-library-tab:hover,
html[data-bs-theme="light"] .df-builder .df-library-tab:hover{
 background:#eef1f4!important;color:#1f2937!important;border-color:#cfd6df!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-library-tab.is-active,
html[data-bs-theme="light"] .df-builder .df-library-tab.is-active{
 background:#fff!important;color:var(--df)!important;border-color:var(--df)!important;box-shadow:0 0 0 2px color-mix(in srgb,var(--df) 10%,transparent)!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-library-tab-count,
html[data-bs-theme="light"] .df-builder .df-library-tab-count{
 background:#e7ebf0!important;color:#344054!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-library-tab.is-active .df-library-tab-count,
html[data-bs-theme="light"] .df-builder .df-library-tab.is-active .df-library-tab-count{
 background:#ffe5ec!important;color:var(--df)!important;
}

/* Columns list: never inherit white text while Joomla is in light mode. */
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-column-item,
html[data-bs-theme="light"] .df-builder .df-column-item{
 background:#fff!important;color:#1f2937!important;border-color:#d9dee5!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-column-item *,
html[data-bs-theme="light"] .df-builder .df-column-item *{color:#1f2937!important;opacity:1!important}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-column-item:has(input:checked),
html[data-bs-theme="light"] .df-builder .df-column-item:has(input:checked){background:#f8fafc!important}

/* Status delete is destructive: filled red removes ambiguity. */
.df-builder .df-status-remove{background:#dc3545!important;border-color:#dc3545!important;color:#fff!important;font-weight:850;cursor:pointer}
.df-builder .df-status-remove:hover,.df-builder .df-status-remove:focus-visible{background:#b4232f!important;border-color:#b4232f!important;color:#fff!important}

html[data-bs-theme="dark"] .df-builder .df-library-tab,
body[data-bs-theme="dark"] .df-builder .df-library-tab,
html[data-color-scheme="dark"] .df-builder .df-library-tab{background:#1f2937!important;color:#f8fafc!important;border-color:#475569!important}
html[data-bs-theme="dark"] .df-builder .df-library-tab.is-active,
body[data-bs-theme="dark"] .df-builder .df-library-tab.is-active,
html[data-color-scheme="dark"] .df-builder .df-library-tab.is-active{background:#111827!important;color:#ff91ad!important;border-color:#e60046!important;box-shadow:0 0 0 2px rgba(230,0,70,.16)!important}
html[data-bs-theme="dark"] .df-builder .df-library-tab-count,
body[data-bs-theme="dark"] .df-builder .df-library-tab-count,
html[data-color-scheme="dark"] .df-builder .df-library-tab-count{background:#334155!important;color:#f8fafc!important}
html[data-bs-theme="dark"] .df-builder .df-column-item,
body[data-bs-theme="dark"] .df-builder .df-column-item,
html[data-color-scheme="dark"] .df-builder .df-column-item{background:#111827!important;color:#f8fafc!important;border-color:#475569!important}
html[data-bs-theme="dark"] .df-builder .df-column-item *,
body[data-bs-theme="dark"] .df-builder .df-column-item *,
html[data-color-scheme="dark"] .df-builder .df-column-item *{color:#f8fafc!important;opacity:1!important}
@media(max-width:800px){.df-layout-head-actions{width:100%;justify-content:flex-start}.df-save-structure{order:2}}
'''
if '</style>' not in t:
    raise RuntimeError('builder style closing tag not found')
t = t.replace('</style>', css + '\n</style>', 1)

builder.write_text(t)

final = builder.read_text()
for token in ['df-save-structure','df-saved-quick-templates','decaroforms_saved_quick_templates_v1','background:#f6f7f9!important','df-status-remove{background:#dc3545']:
    if token not in final:
        raise RuntimeError('missing expected token: ' + token)
print('Forms 1.3.17 patch applied')
