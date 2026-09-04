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

old_render = '''function renderEmailPickers(){document.querySelectorAll('[data-email-picker]').forEach(box=>{const audience=box.dataset.emailPicker,config=emailConfig[audience];if(config.template==='receipt')config.template='standard';box.innerHTML='';templateDefs.forEach(([key,label])=>{const card=document.createElement('div');const special=['custom','html','chatgpt'].includes(key);card.className='df-email-choice'+((config.template||'standard')===key?' is-active':'');card.dataset.special=special?'1':'0';card.dataset.template=key;card.innerHTML=`<button type="button" class="df-email-thumb" data-email-preview-action data-audience="${audience}" data-template="${key}" title="${esc(tr.preview)}" aria-label="${esc(tr.preview)}: ${esc(label)}"><span class="df-email-thumb-art"></span><span class="df-email-preview-label" aria-hidden="true">◉ ${esc(tr.preview)}</span></button><div class="df-email-choice-foot"><label class="df-email-radio"><input type="radio" name="df-email-template-${audience}" value="${key}" ${(config.template||'standard')===key?'checked':''}><span>${esc(label)}</span></label><button type="button" class="df-email-preview-btn" data-email-preview-action data-audience="${audience}" data-template="${key}" aria-label="${esc(tr.preview)}: ${esc(label)}">◉ ${esc(tr.preview)}</button></div>`;card.querySelector('input').onchange=()=>{config.template=key;renderEmailPickers();renderEmailSpecial(audience);sync();};box.appendChild(card);});renderEmailSpecial(audience);});}'''
new_render = '''function renderEmailPickers(){document.querySelectorAll('[data-email-picker]').forEach(box=>{const audience=box.dataset.emailPicker,config=emailConfig[audience];if(config.template==='receipt')config.template='standard';box.innerHTML='';templateDefs.forEach(([key,label])=>{const card=document.createElement('div');const special=['custom','html','chatgpt'].includes(key);card.className='df-email-choice'+((config.template||'standard')===key?' is-active':'');card.dataset.special=special?'1':'0';card.dataset.template=key;card.innerHTML=`<button type="button" class="df-email-thumb" title="${esc(tr.preview)}" aria-label="${esc(tr.preview)}: ${esc(label)}"><span class="df-email-thumb-art"></span><span class="df-email-preview-label" aria-hidden="true">◉ ${esc(tr.preview)}</span></button><div class="df-email-choice-foot"><label class="df-email-radio"><input type="radio" name="df-email-template-${audience}" value="${key}" ${(config.template||'standard')===key?'checked':''}><span>${esc(label)}</span></label><button type="button" class="df-email-preview-btn" aria-label="${esc(tr.preview)}: ${esc(label)}">◉ ${esc(tr.preview)}</button></div>`;const open=e=>{e?.preventDefault?.();e?.stopPropagation?.();showEmailPreview(audience,key);};card.querySelector('.df-email-thumb').addEventListener('click',open);card.querySelector('.df-email-preview-btn').addEventListener('click',open);card.querySelector('input').onchange=()=>{config.template=key;renderEmailPickers();renderEmailSpecial(audience);sync();};box.appendChild(card);});renderEmailSpecial(audience);});}'''
if old_render not in t:
    raise RuntimeError('renderEmailPickers 1.3.11 block not found')
t = t.replace(old_render, new_render, 1)

start = t.find("const previewModal=document.getElementById('df-email-preview-modal');")
end_marker = "document.addEventListener('keydown',e=>{if(e.key==='Escape'&&previewModal&&!previewModal.hidden)closeEmailPreview();});"
end = t.find(end_marker, start)
if start < 0 or end < 0:
    raise RuntimeError('1.3.11 preview block not found')
end += len(end_marker)
new_preview = '''let previewModal=null;function closeEmailPreview(){if(!previewModal)return;previewModal.remove();previewModal=null;document.body.style.overflow='';}function showEmailPreview(audience,template){closeEmailPreview();let html='';try{html=emailPreviewHtml(audience,template);}catch(err){console.error('Forms email preview error',err);html='<div style="background:#fff;color:#1f2937;padding:24px;font-family:Arial,sans-serif"><h2 style="margin-top:0">Anteprima email</h2><p>Impossibile generare i dati di esempio.</p></div>';}const label=templateDefs.find(x=>x[0]===template)?.[1]||template;previewModal=document.createElement('div');previewModal.className='df-live-preview-modal';previewModal.innerHTML=`<div class="df-live-preview-backdrop"></div><div class="df-live-preview-dialog" role="dialog" aria-modal="true" aria-label="Anteprima ${esc(label)}"><div class="df-live-preview-head"><div><strong>${esc(label)}</strong><div class="df-note">${audience==='admin'?'Email amministrazione':'Email utente'}</div></div><button type="button" class="df-live-preview-close" aria-label="Chiudi">×</button></div><div class="df-live-preview-body">${html}</div><div class="df-live-preview-foot"><button type="button" class="df-btn df-live-preview-close">Chiudi</button></div></div>`;document.body.appendChild(previewModal);document.body.style.overflow='hidden';previewModal.querySelectorAll('.df-live-preview-close,.df-live-preview-backdrop').forEach(el=>el.addEventListener('click',closeEmailPreview));requestAnimationFrame(()=>previewModal.querySelector('.df-live-preview-close')?.focus());}document.addEventListener('keydown',e=>{if(e.key==='Escape'&&previewModal)closeEmailPreview();});'''
t = t[:start] + new_preview + t[end:]

css = r'''
/* Forms 1.3.12: self-contained live email preview modal. */
.df-live-preview-modal{position:fixed;inset:0;z-index:2147483647;display:grid;place-items:center;padding:20px;pointer-events:auto}
.df-live-preview-backdrop{position:absolute;inset:0;background:rgba(15,23,42,.68);backdrop-filter:blur(2px)}
.df-live-preview-dialog{position:relative;z-index:1;width:min(860px,calc(100vw - 32px));max-height:calc(100vh - 32px);display:flex;flex-direction:column;background:var(--bs-body-bg,#fff);color:var(--bs-body-color,#1f2937);border:1px solid var(--bs-border-color,#d9dee5);border-radius:14px;box-shadow:0 24px 70px rgba(0,0,0,.28);overflow:hidden}
.df-live-preview-head,.df-live-preview-foot{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:14px 16px;background:var(--bs-tertiary-bg,#f6f7f9);border-bottom:1px solid var(--bs-border-color,#d9dee5)}
.df-live-preview-foot{justify-content:flex-end;border-top:1px solid var(--bs-border-color,#d9dee5);border-bottom:0}
.df-live-preview-body{padding:18px;overflow:auto;background:var(--bs-body-bg,#fff)}
.df-live-preview-close{cursor:pointer}
button.df-live-preview-close{min-width:38px;min-height:38px;border:1px solid var(--bs-border-color,#d9dee5);border-radius:8px;background:var(--bs-body-bg,#fff);color:inherit;font-weight:800}
@media(max-width:560px){.df-live-preview-modal{padding:10px}.df-live-preview-dialog{width:calc(100vw - 20px);max-height:calc(100vh - 20px)}.df-live-preview-body{padding:12px}}
'''
if '</style>' not in t:
    raise RuntimeError('style closing tag missing')
t = t.replace('</style>', css + '\n</style>', 1)

if "public const VERSION = '1.3.11'" not in h:
    raise RuntimeError('helper version 1.3.11 not found')
h = h.replace("public const VERSION = '1.3.11'", "public const VERSION = '1.3.12'", 1)
for p in (component_manifest, plugin_manifest):
    s = p.read_text()
    if '<version>1.3.11</version>' not in s:
        raise RuntimeError(f'1.3.11 version missing in {p.name}')
    p.write_text(s.replace('<version>1.3.11</version>', '<version>1.3.12</version>', 1))

builder.write_text(t)
helper.write_text(h)

final = builder.read_text()
for token in ['df-live-preview-modal','document.createElement(\'div\')','card.querySelector(\'.df-email-thumb\').addEventListener(\'click\',open)','document.body.appendChild(previewModal)']:
    if token not in final:
        raise RuntimeError('missing expected token: ' + token)
print('Forms 1.3.12 patch applied')
