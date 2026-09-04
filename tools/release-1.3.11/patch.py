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

old_render = '''function renderEmailPickers(){document.querySelectorAll('[data-email-picker]').forEach(box=>{const audience=box.dataset.emailPicker,config=emailConfig[audience];if(config.template==='receipt')config.template='standard';box.innerHTML='';templateDefs.forEach(([key,label])=>{const card=document.createElement('div');const special=['custom','html','chatgpt'].includes(key);card.className='df-email-choice'+((config.template||'standard')===key?' is-active':'');card.dataset.special=special?'1':'0';card.dataset.template=key;card.innerHTML=`<button type="button" class="df-email-thumb" data-template="${key}" title="${esc(tr.preview)}" aria-label="${esc(tr.preview)}: ${esc(label)}"><span class="df-email-thumb-art"></span><span class="df-email-preview-label" aria-hidden="true">◉ ${esc(tr.preview)}</span></button><label class="df-email-choice-foot"><input type="radio" name="df-email-template-${audience}" value="${key}" ${(config.template||'standard')===key?'checked':''}><span>${esc(label)}</span></label>`;const openPreview=()=>showEmailPreview(audience,key);card.querySelector('.df-email-thumb').onclick=e=>{e.preventDefault();e.stopPropagation();openPreview();};card.onclick=e=>{if(e.target.closest('.df-email-choice-foot,input,label'))return;if(!e.target.closest('.df-email-thumb'))openPreview();};card.querySelector('input').onchange=()=>{config.template=key;renderEmailPickers();renderEmailSpecial(audience);sync();};box.appendChild(card);});renderEmailSpecial(audience);});}'''
new_render = '''function renderEmailPickers(){document.querySelectorAll('[data-email-picker]').forEach(box=>{const audience=box.dataset.emailPicker,config=emailConfig[audience];if(config.template==='receipt')config.template='standard';box.innerHTML='';templateDefs.forEach(([key,label])=>{const card=document.createElement('div');const special=['custom','html','chatgpt'].includes(key);card.className='df-email-choice'+((config.template||'standard')===key?' is-active':'');card.dataset.special=special?'1':'0';card.dataset.template=key;card.innerHTML=`<button type="button" class="df-email-thumb" data-email-preview-action data-audience="${audience}" data-template="${key}" title="${esc(tr.preview)}" aria-label="${esc(tr.preview)}: ${esc(label)}"><span class="df-email-thumb-art"></span><span class="df-email-preview-label" aria-hidden="true">◉ ${esc(tr.preview)}</span></button><div class="df-email-choice-foot"><label class="df-email-radio"><input type="radio" name="df-email-template-${audience}" value="${key}" ${(config.template||'standard')===key?'checked':''}><span>${esc(label)}</span></label><button type="button" class="df-email-preview-btn" data-email-preview-action data-audience="${audience}" data-template="${key}" aria-label="${esc(tr.preview)}: ${esc(label)}">◉ ${esc(tr.preview)}</button></div>`;card.querySelector('input').onchange=()=>{config.template=key;renderEmailPickers();renderEmailSpecial(audience);sync();};box.appendChild(card);});renderEmailSpecial(audience);});}'''
if old_render not in t:
    raise RuntimeError('renderEmailPickers 1.3.10 block not found')
t = t.replace(old_render, new_render, 1)

old_preview = '''const previewModal=document.getElementById('df-email-preview-modal');function closeEmailPreview(){if(!previewModal)return;previewModal.hidden=true;previewModal.setAttribute('hidden','');previewModal.classList.remove('is-open');document.body.style.overflow='';}function showEmailPreview(audience,template){if(!previewModal)return;document.getElementById('df-preview-title').textContent=templateDefs.find(x=>x[0]===template)?.[1]||template;document.getElementById('df-preview-subject').textContent=audience==='admin'?'Email amministrazione':'Email utente';document.getElementById('df-preview-canvas').innerHTML=emailPreviewHtml(audience,template);previewModal.hidden=false;previewModal.removeAttribute('hidden');previewModal.classList.add('is-open');document.body.style.overflow='hidden';requestAnimationFrame(()=>previewModal.querySelector('.df-preview-x')?.focus());}document.querySelectorAll('[data-preview-close]').forEach(x=>x.onclick=closeEmailPreview);document.addEventListener('keydown',e=>{if(e.key==='Escape'&&previewModal&&!previewModal.hidden)closeEmailPreview();});'''
new_preview = '''const previewModal=document.getElementById('df-email-preview-modal');if(previewModal&&previewModal.parentElement!==document.body)document.body.appendChild(previewModal);function closeEmailPreview(){if(!previewModal)return;previewModal.classList.remove('is-open');previewModal.hidden=true;previewModal.setAttribute('hidden','');previewModal.style.removeProperty('display');previewModal.style.removeProperty('z-index');document.body.style.overflow='';}function showEmailPreview(audience,template){if(!previewModal)return;const titleEl=previewModal.querySelector('#df-preview-title'),subjectEl=previewModal.querySelector('#df-preview-subject'),canvas=previewModal.querySelector('#df-preview-canvas');if(titleEl)titleEl.textContent=templateDefs.find(x=>x[0]===template)?.[1]||template;if(subjectEl)subjectEl.textContent=audience==='admin'?'Email amministrazione':'Email utente';if(canvas){try{canvas.innerHTML=emailPreviewHtml(audience,template);}catch(err){console.error('Forms email preview error',err);canvas.innerHTML='<div style="background:#fff;color:#1f2937;padding:24px;font-family:Arial,sans-serif"><h2 style="margin-top:0">Anteprima email</h2><p>Impossibile generare i dati di esempio, ma la finestra di anteprima funziona correttamente.</p></div>';}}previewModal.hidden=false;previewModal.removeAttribute('hidden');previewModal.classList.add('is-open');previewModal.style.setProperty('display','grid','important');previewModal.style.setProperty('z-index','2147483000','important');document.body.style.overflow='hidden';requestAnimationFrame(()=>previewModal.querySelector('.df-preview-x')?.focus());}document.addEventListener('click',e=>{const trigger=e.target.closest('[data-email-preview-action]');if(!trigger)return;e.preventDefault();e.stopPropagation();showEmailPreview(trigger.dataset.audience||'admin',trigger.dataset.template||'standard');});document.querySelectorAll('[data-preview-close]').forEach(x=>x.onclick=closeEmailPreview);document.addEventListener('keydown',e=>{if(e.key==='Escape'&&previewModal&&!previewModal.hidden)closeEmailPreview();});'''
if old_preview not in t:
    raise RuntimeError('showEmailPreview 1.3.10 block not found')
t = t.replace(old_preview, new_preview, 1)

css = r'''
/* Forms 1.3.11: explicit, delegated email facsimile preview controls. */
.df-builder .df-email-choice-foot{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-top:7px}
.df-builder .df-email-radio{display:flex;align-items:center;gap:7px;min-width:0;font-size:12px;font-weight:800}
.df-builder .df-email-preview-btn{border:0;background:transparent;color:var(--bs-link-color,#0d6efd);font-size:11px;font-weight:800;padding:3px 5px;border-radius:4px;cursor:pointer;white-space:nowrap}
.df-builder .df-email-preview-btn:hover,.df-builder .df-email-preview-btn:focus-visible{background:color-mix(in srgb,var(--bs-primary,#0d6efd) 10%,transparent);outline:none}
.df-builder .df-email-preview-label{opacity:.9;pointer-events:none}
.df-builder .df-email-thumb:hover .df-email-preview-label,.df-builder .df-email-thumb:focus-visible .df-email-preview-label{opacity:1}
.df-preview-modal.is-open{display:grid!important;z-index:2147483000!important}
@media(max-width:560px){.df-builder .df-email-choice-foot{align-items:flex-start;flex-direction:column}.df-builder .df-email-preview-btn{padding-left:0}}
'''
if '</style>' not in t:
    raise RuntimeError('builder style closing tag not found')
t = t.replace('</style>', css + '\n</style>', 1)

if "public const VERSION = '1.3.10'" not in h:
    raise RuntimeError('helper version 1.3.10 not found')
h = h.replace("public const VERSION = '1.3.10'", "public const VERSION = '1.3.11'", 1)
for p in (component_manifest, plugin_manifest):
    s = p.read_text()
    if '<version>1.3.10</version>' not in s:
        raise RuntimeError(f'1.3.10 version missing in {p.name}')
    p.write_text(s.replace('<version>1.3.10</version>', '<version>1.3.11</version>', 1))

builder.write_text(t)
helper.write_text(h)

final = builder.read_text()
checks = [
    'data-email-preview-action',
    'df-email-preview-btn',
    "document.body.appendChild(previewModal)",
    "previewModal.style.setProperty('display','grid','important')",
    "previewModal.style.setProperty('z-index','2147483000','important')",
    "const trigger=e.target.closest('[data-email-preview-action]')",
    "Forms email preview error",
]
for token in checks:
    if token not in final:
        raise RuntimeError('missing expected token: ' + token)
print('Forms 1.3.11 patch applied')
