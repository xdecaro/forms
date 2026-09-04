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

old_render = '''function renderEmailPickers(){document.querySelectorAll('[data-email-picker]').forEach(box=>{const audience=box.dataset.emailPicker,config=emailConfig[audience];if(config.template==='receipt')config.template='standard';box.innerHTML='';templateDefs.forEach(([key,label])=>{const card=document.createElement('div');const special=['custom','html','chatgpt'].includes(key);card.className='df-email-choice'+((config.template||'standard')===key?' is-active':'');card.dataset.special=special?'1':'0';card.innerHTML=`<button type="button" class="df-email-thumb" data-template="${key}" title="${esc(tr.preview)}"><span></span></button><label class="df-email-choice-foot"><input type="radio" name="df-email-template-${audience}" value="${key}" ${(config.template||'standard')===key?'checked':''}><span>${esc(label)}</span></label>`;card.querySelector('.df-email-thumb').onclick=()=>showEmailPreview(audience,key);card.querySelector('input').onchange=()=>{config.template=key;renderEmailPickers();renderEmailSpecial(audience);sync();};box.appendChild(card);});renderEmailSpecial(audience);});}'''
new_render = '''function renderEmailPickers(){document.querySelectorAll('[data-email-picker]').forEach(box=>{const audience=box.dataset.emailPicker,config=emailConfig[audience];if(config.template==='receipt')config.template='standard';box.innerHTML='';templateDefs.forEach(([key,label])=>{const card=document.createElement('div');const special=['custom','html','chatgpt'].includes(key);card.className='df-email-choice'+((config.template||'standard')===key?' is-active':'');card.dataset.special=special?'1':'0';card.dataset.template=key;card.innerHTML=`<button type="button" class="df-email-thumb" data-template="${key}" title="${esc(tr.preview)}" aria-label="${esc(tr.preview)}: ${esc(label)}"><span class="df-email-thumb-art"></span><span class="df-email-preview-label" aria-hidden="true">◉ ${esc(tr.preview)}</span></button><label class="df-email-choice-foot"><input type="radio" name="df-email-template-${audience}" value="${key}" ${(config.template||'standard')===key?'checked':''}><span>${esc(label)}</span></label>`;const openPreview=()=>showEmailPreview(audience,key);card.querySelector('.df-email-thumb').onclick=e=>{e.preventDefault();e.stopPropagation();openPreview();};card.onclick=e=>{if(e.target.closest('.df-email-choice-foot,input,label'))return;if(!e.target.closest('.df-email-thumb'))openPreview();};card.querySelector('input').onchange=()=>{config.template=key;renderEmailPickers();renderEmailSpecial(audience);sync();};box.appendChild(card);});renderEmailSpecial(audience);});}'''
if old_render not in t:
    raise RuntimeError('renderEmailPickers 1.3.9 block not found')
t = t.replace(old_render, new_render, 1)

old_preview = '''const previewModal=document.getElementById('df-email-preview-modal');function showEmailPreview(audience,template){document.getElementById('df-preview-title').textContent=templateDefs.find(x=>x[0]===template)?.[1]||template;document.getElementById('df-preview-subject').textContent=audience==='admin'?'Email amministrazione':'Email utente';document.getElementById('df-preview-canvas').innerHTML=emailPreviewHtml(audience,template);previewModal.hidden=false;document.body.style.overflow='hidden';}document.querySelectorAll('[data-preview-close]').forEach(x=>x.onclick=()=>{previewModal.hidden=true;document.body.style.overflow='';});document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!previewModal.hidden){previewModal.hidden=true;document.body.style.overflow='';}});'''
new_preview = '''const previewModal=document.getElementById('df-email-preview-modal');function closeEmailPreview(){if(!previewModal)return;previewModal.hidden=true;previewModal.setAttribute('hidden','');previewModal.classList.remove('is-open');document.body.style.overflow='';}function showEmailPreview(audience,template){if(!previewModal)return;document.getElementById('df-preview-title').textContent=templateDefs.find(x=>x[0]===template)?.[1]||template;document.getElementById('df-preview-subject').textContent=audience==='admin'?'Email amministrazione':'Email utente';document.getElementById('df-preview-canvas').innerHTML=emailPreviewHtml(audience,template);previewModal.hidden=false;previewModal.removeAttribute('hidden');previewModal.classList.add('is-open');document.body.style.overflow='hidden';requestAnimationFrame(()=>previewModal.querySelector('.df-preview-x')?.focus());}document.querySelectorAll('[data-preview-close]').forEach(x=>x.onclick=closeEmailPreview);document.addEventListener('keydown',e=>{if(e.key==='Escape'&&previewModal&&!previewModal.hidden)closeEmailPreview();});'''
if old_preview not in t:
    raise RuntimeError('showEmailPreview 1.3.9 block not found')
t = t.replace(old_preview, new_preview, 1)

css = r'''
/* Forms 1.3.10: template cards have an explicit facsimile-preview action. */
.df-builder .df-email-choice{position:relative;cursor:pointer;transition:border-color .16s ease,box-shadow .16s ease,transform .16s ease}
.df-builder .df-email-choice:hover{border-color:#9aa7b8;box-shadow:0 4px 14px rgba(15,23,42,.08)}
.df-builder .df-email-thumb{position:relative;overflow:hidden;cursor:pointer}
.df-builder .df-email-thumb-art{display:block;width:100%;height:100%}
.df-builder .df-email-preview-label{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);display:inline-flex;align-items:center;gap:5px;padding:5px 9px;border-radius:999px;background:rgba(31,41,55,.9);color:#fff;font-size:11px;font-weight:800;white-space:nowrap;opacity:0;transition:opacity .16s ease,transform .16s ease;pointer-events:none}
.df-builder .df-email-thumb:hover .df-email-preview-label,.df-builder .df-email-thumb:focus-visible .df-email-preview-label{opacity:1;transform:translate(-50%,-50%) scale(1.02)}
.df-builder .df-email-thumb:focus-visible{outline:2px solid var(--bs-primary,#0d6efd);outline-offset:2px}
.df-builder .df-preview-modal.is-open{display:grid!important}
@media(max-width:560px){.df-builder .df-email-preview-label{opacity:.88;font-size:10px;padding:4px 7px}}
@media(prefers-reduced-motion:reduce){.df-builder .df-email-choice,.df-builder .df-email-preview-label{transition:none}}
'''
if '</style>' not in t:
    raise RuntimeError('builder style closing tag not found')
t = t.replace('</style>', css + '\n</style>', 1)

if "public const VERSION = '1.3.9'" not in h:
    raise RuntimeError('helper version 1.3.9 not found')
h = h.replace("public const VERSION = '1.3.9'", "public const VERSION = '1.3.10'", 1)
for p in (component_manifest, plugin_manifest):
    s = p.read_text()
    if '<version>1.3.9</version>' not in s:
        raise RuntimeError(f'1.3.9 version missing in {p.name}')
    p.write_text(s.replace('<version>1.3.9</version>', '<version>1.3.10</version>', 1))

builder.write_text(t)
helper.write_text(h)

final = builder.read_text()
checks = [
    'df-email-preview-label',
    'card.onclick=e=>',
    'function closeEmailPreview()',
    "previewModal.removeAttribute('hidden')",
    "previewModal.classList.add('is-open')",
    'Forms 1.3.10: template cards have an explicit facsimile-preview action',
]
for token in checks:
    if token not in final:
        raise RuntimeError('missing expected token: ' + token)
print('Forms 1.3.10 patch applied')
