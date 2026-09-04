#!/usr/bin/env python3
from pathlib import Path
import re, sys

if len(sys.argv) != 3:
    raise SystemExit('usage: patch.py COMPONENT_ROOT PLUGIN_ROOT')

comp=Path(sys.argv[1]); plug=Path(sys.argv[2])
builder=comp/'administrator/components/com_decaroforms/tmpl/builder/default.php'
helper=comp/'administrator/components/com_decaroforms/src/Helper/FormHelper.php'
component_manifest=comp/'com_decaroforms.xml'
plugin_manifest=plug/'decaroforms.xml'

def rep(text, old, new, label):
    if old not in text:
        raise RuntimeError(f'{label} not found')
    return text.replace(old,new,1)

def sub(text, pattern, new, label, flags=re.S):
    out,n=re.subn(pattern,new,text,count=1,flags=flags)
    if n != 1:
        raise RuntimeError(f'{label} replacement count={n}')
    return out

# Versions.
h=helper.read_text(); h=rep(h,"public const VERSION = '1.3.18';","public const VERSION = '1.3.19';",'helper version'); helper.write_text(h)
for m in (component_manifest,plugin_manifest):
    s=m.read_text(); s=rep(s,'<version>1.3.18</version>','<version>1.3.19</version>',str(m)); m.write_text(s)

t=builder.read_text()

# Replace the browser-native delete confirmation on the module itself with the shared modal.
old='''<a class="df-btn df-danger" href="<?php echo $this->deleteUrl; ?>" onclick="return confirm(<?php echo htmlspecialchars(json_encode(Text::_('COM_DECAROFORMS_DELETE_CONFIRM')), ENT_QUOTES, 'UTF-8'); ?>)"><?php echo Text::_('COM_DECAROFORMS_DELETE'); ?></a>'''
new='''<a class="df-btn df-danger" href="<?php echo $this->deleteUrl; ?>" data-confirm-delete-link data-delete-label="modulo"><?php echo Text::_('COM_DECAROFORMS_DELETE'); ?></a>'''
t=rep(t,old,new,'module delete link')

# Shared action modal used by every save/delete action in the Builder.
anchor="""const getDeep=(obj,path,def='')=>{let x=obj;for(const p of path.split('.')){if(x==null||typeof x!=='object'||!(p in x))return def;x=x[p];}return x??def;};"""
modal_js=r'''
let actionModal=null;
function closeActionModal(){if(!actionModal)return;actionModal.remove();actionModal=null;document.body.style.overflow='';}
function openActionModal({title='Conferma',message='',confirmLabel='Conferma',danger=false,inputLabel='',inputValue='',inputRequired=false,onConfirm=null}){
 closeActionModal();
 actionModal=document.createElement('div');actionModal.className='df-action-modal';
 const inputHtml=inputLabel?`<label class="df-action-input-label"><span>${esc(inputLabel)}</span><input class="df-action-input" value="${esc(inputValue)}" ${inputRequired?'required':''}></label>`:'';
 actionModal.innerHTML=`<div class="df-action-backdrop" data-action-close></div><div class="df-action-dialog" role="dialog" aria-modal="true" aria-labelledby="df-action-title"><div class="df-action-head"><strong id="df-action-title">${esc(title)}</strong><button type="button" class="df-action-x" data-action-close aria-label="Chiudi">×</button></div><div class="df-action-body"><p>${esc(message)}</p>${inputHtml}</div><div class="df-action-foot"><button type="button" class="df-btn" data-action-close>Annulla</button><button type="button" class="df-btn ${danger?'df-action-danger':'df-primary'}" data-action-confirm>${esc(confirmLabel)}</button></div></div>`;
 document.body.appendChild(actionModal);document.body.style.overflow='hidden';
 const input=actionModal.querySelector('.df-action-input'),confirm=actionModal.querySelector('[data-action-confirm]');
 const run=()=>{const value=input?input.value.trim():'';if(inputRequired&&!value){input?.focus();return;}closeActionModal();if(typeof onConfirm==='function')onConfirm(value);};
 actionModal.querySelectorAll('[data-action-close]').forEach(el=>el.addEventListener('click',closeActionModal));confirm.addEventListener('click',run);input?.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();run();}});
 requestAnimationFrame(()=>{(input||confirm)?.focus();input?.select();});
}
function confirmDelete(label,onConfirm){openActionModal({title:'Conferma eliminazione',message:`Vuoi davvero eliminare ${label}?`,confirmLabel:'Elimina',danger:true,onConfirm});}
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&actionModal)closeActionModal();});
'''
t=rep(t,anchor,anchor+modal_js,'shared action modal JS')

# Generic modal also covers the top module delete link.
anchor2="""document.addEventListener('click',e=>{const btn=e.target.closest('.df-info');if(btn){e.preventDefault();e.stopPropagation();const wrap=btn.closest('.df-info-wrap');document.querySelectorAll('.df-info-wrap.is-open').forEach(x=>{if(x!==wrap)x.classList.remove('is-open');});wrap?.classList.toggle('is-open');return;}if(!e.target.closest('.df-info-wrap'))document.querySelectorAll('.df-info-wrap.is-open').forEach(x=>x.classList.remove('is-open'));});"""
delete_link_js=r'''
document.addEventListener('click',e=>{const link=e.target.closest('[data-confirm-delete-link]');if(!link)return;e.preventDefault();e.stopPropagation();const href=link.href;confirmDelete('questo modulo',()=>{window.dfAllowDraftReload=true;location.assign(href);});});
'''
t=rep(t,anchor2,delete_link_js+anchor2,'module modal binding')

# Saved quick model: replace prompt() with a proper save modal.
pattern=r"function saveCurrentStructureAsQuickTemplate\(\)\{.*?\n\}\nfunction applySavedQuickTemplate"
new=r'''function saveQuickTemplateNamed(name){
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
function saveCurrentStructureAsQuickTemplate(){
 if(!selected.length){openActionModal({title:'Salva struttura',message:'Aggiungi almeno un campo prima di salvare la struttura.',confirmLabel:'Chiudi',onConfirm:()=>{}});return;}
 const suggested=(document.querySelector('[name="title"]')?.value||'Modello personalizzato').trim();
 openActionModal({title:'Salva struttura del modulo',message:'Salva questa struttura nei Modelli rapidi per riutilizzarla in altri moduli.',inputLabel:'Nome del modello',inputValue:suggested,inputRequired:true,confirmLabel:'Salva',onConfirm:saveQuickTemplateNamed});
}
function applySavedQuickTemplate'''
t=sub(t,pattern,new,'quick save modal')

# Saved quick model delete now asks confirmation.
old=""" if(del){e.preventDefault();e.stopPropagation();savedQuickTemplates=savedQuickTemplates.filter(x=>x.id!==del.dataset.savedQuickDelete);persistSavedQuickTemplates();renderSavedQuickTemplates();}"""
new=""" if(del){e.preventDefault();e.stopPropagation();const tpl=savedQuickTemplates.find(x=>x.id===del.dataset.savedQuickDelete);confirmDelete(`il modello salvato “${tpl?.name||'Modello personalizzato'}”`,()=>{savedQuickTemplates=savedQuickTemplates.filter(x=>x.id!==del.dataset.savedQuickDelete);persistSavedQuickTemplates();renderSavedQuickTemplates();});}"""
t=rep(t,old,new,'quick delete confirmation')

# Saved custom field delete confirmation.
old="""d.querySelector('.df-lib-delete')?.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();deleteSavedFieldPreset(x._savedPresetId);});"""
new="""d.querySelector('.df-lib-delete')?.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();confirmDelete(`il campo personalizzato “${x.label||'Campo'}”`,()=>deleteSavedFieldPreset(x._savedPresetId));});"""
t=rep(t,old,new,'saved field delete confirmation')

# Saving a custom field also gets a clear confirmation modal.
old="""d.querySelector('[data-act=\"save-preset\"]').onclick=e=>{e.preventDefault();e.stopPropagation();saveFieldPreset(x);const btn=e.currentTarget;btn.classList.add('is-saved');btn.title='Salvato nei campi personalizzati';setTimeout(()=>{btn.classList.remove('is-saved');btn.title='Salva come campo personalizzato';},1200);};"""
new="""d.querySelector('[data-act=\"save-preset\"]').onclick=e=>{e.preventDefault();e.stopPropagation();const btn=e.currentTarget;openActionModal({title:'Salva campo personalizzato',message:`Salvare “${x.label||'Campo'}” nella Libreria campi → Personalizzati?`,confirmLabel:'Salva',onConfirm:()=>{saveFieldPreset(x);btn.classList.add('is-saved');btn.title='Salvato nei campi personalizzati';setTimeout(()=>{btn.classList.remove('is-saved');btn.title='Salva come campo personalizzato';},1200);}});};"""
t=rep(t,old,new,'field preset save modal')

# Every destructive field/status/email/condition action uses the shared modal.
old="""d.querySelector('[data-act=\"remove\"]').onclick=()=>{const removedRow=Number(x.config.layout.row||1);openFieldKeys.delete(x.key);selected.splice(i,1);activeFieldKey=selected[Math.min(i,selected.length-1)]?.key||null;normalizeLayoutRows();distributeRow(removedRow);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();};"""
new="""d.querySelector('[data-act=\"remove\"]').onclick=()=>confirmDelete(`il campo “${x.label||'Campo'}”`,()=>{const removedRow=Number(x.config.layout.row||1);openFieldKeys.delete(x.key);selected.splice(i,1);activeFieldKey=selected[Math.min(i,selected.length-1)]?.key||null;normalizeLayoutRows();distributeRow(removedRow);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();sync();});"""
t=rep(t,old,new,'property field delete confirmation')
old="""d.querySelectorAll('[data-cond-remove]').forEach(el=>el.addEventListener('click',()=>{x.config.conditions.splice(Number(el.dataset.condRemove),1);renderSelected();}));"""
new="""d.querySelectorAll('[data-cond-remove]').forEach(el=>el.addEventListener('click',()=>confirmDelete('questa condizione',()=>{x.config.conditions.splice(Number(el.dataset.condRemove),1);renderSelected();sync();})));"""
t=rep(t,old,new,'condition delete confirmation')
old="""card.querySelector('[data-canvas-remove]').onclick=()=>removeCanvasField(i);"""
new="""card.querySelector('[data-canvas-remove]').onclick=()=>confirmDelete(`il campo “${f.label||'Campo'}”`,()=>removeCanvasField(i));"""
t=rep(t,old,new,'canvas field delete confirmation')
old="""r.querySelector('button').onclick=()=>{if(statuses.length>1){statuses.splice(i,1);renderStatuses();}};"""
new="""r.querySelector('button').onclick=()=>{if(statuses.length>1)confirmDelete(`lo stato “${st.label||'Stato'}”`,()=>{statuses.splice(i,1);renderStatuses();});};"""
t=rep(t,old,new,'status delete confirmation')
old="""d.querySelector('[data-a-remove]').onclick=()=>{additionalEmails.splice(i,1);renderAdditional();};"""
new="""d.querySelector('[data-a-remove]').onclick=()=>confirmDelete(`l’email aggiuntiva “${m.name||('Email #'+(i+1))}”`,()=>{additionalEmails.splice(i,1);renderAdditional();});"""
t=rep(t,old,new,'additional email delete confirmation')

# Performance: selection must render only the properties panel, not the full layout twice.
t=rep(t,"sel.appendChild(d);});sync();renderLayoutCanvas();}","sel.appendChild(d);});sync();}",'renderSelected no canvas rebuild')
t=rep(t,"function selectField(index){if(index==null||!selected[index])return;activeFieldKey=selected[index].key;openFieldKeys.clear();openFieldKeys.add(activeFieldKey);renderSelected();renderLayoutCanvas();}","function selectField(index){if(index==null||!selected[index])return;activeFieldKey=selected[index].key;openFieldKeys.clear();openFieldKeys.add(activeFieldKey);renderSelected();document.querySelectorAll('.df-layout-card').forEach(card=>card.classList.toggle('is-active',card.dataset.fieldKey===activeFieldKey));}",'fast field select')
t=rep(t,"scheduleHistory();queueMicrotask(applyLockState);","scheduleHistory();if(document.querySelector('.df-builder')?.classList.contains('is-locked'))queueMicrotask(applyLockState);",'avoid global lock scan while editing')
# Required badge still needs the small canvas refresh.
t=rep(t,"d.querySelectorAll('[data-k-check]').forEach(el=>el.addEventListener('change',()=>{x[el.dataset.kCheck]=el.checked;sync();renderSelected();}));","d.querySelectorAll('[data-k-check]').forEach(el=>el.addEventListener('change',()=>{x[el.dataset.kCheck]=el.checked;sync();renderSelected();renderLayoutCanvas();}));",'required badge canvas refresh')

# True two-dimensional layout: left/right = same row columns, centre = new row.
insert_anchor="""function moveFieldToRow(index,row,targetIndex=null){if(index==null||!selected[index])return;const field=selected[index],oldRow=Number(selected[index].config.layout.row||1);selected.splice(index,1);let insertAt=targetIndex==null?selected.length:Number(targetIndex);if(index<insertAt)insertAt--;insertAt=Math.max(0,Math.min(selected.length,insertAt));field.config.layout.row=row;selected.splice(insertAt,0,field);normalizeLayoutRows();distributeRow(oldRow);distributeRow(field.config.layout.row);activeFieldKey=field.key;sync();renderSelected();renderLayoutCanvas();}"""
extra_layout=r'''
function sortSelectedByLayout(){selected.sort((a,b)=>Number(a.config?.layout?.row||1)-Number(b.config?.layout?.row||1)||Number(a.config?.layout?.col||1)-Number(b.config?.layout?.col||1));}
function moveFieldBeside(index,targetIndex,position='after'){
 if(index==null||targetIndex==null||!selected[index]||!selected[targetIndex]||index===targetIndex)return;
 const field=selected[index],target=selected[targetIndex],oldRow=Number(field.config.layout.row||1),targetRow=Number(target.config.layout.row||1);
 if(fieldsInRow(targetRow).length>=4&&oldRow!==targetRow){moveFieldToNewRowAfter(index,targetRow);return;}
 selected.splice(index,1);const targetNow=selected.indexOf(target);field.config.layout.row=targetRow;selected.splice(targetNow+(position==='after'?1:0),0,field);
 normalizeLayoutRows();sortSelectedByLayout();distributeRow(oldRow);distributeRow(Number(field.config.layout.row||targetRow));activeFieldKey=field.key;sync();renderSelected();renderLayoutCanvas();
}
function moveFieldToNewRowAfter(index,afterRow){
 if(index==null||!selected[index])return;const field=selected[index],oldRow=Number(field.config.layout.row||1);selected.splice(index,1);
 selected.forEach(f=>{defaultFieldConfig(f);if(Number(f.config.layout.row)>Number(afterRow))f.config.layout.row=Number(f.config.layout.row)+1;});field.config.layout={...(field.config.layout||{}),row:Number(afterRow)+1,col:1,width:100};selected.push(field);normalizeLayoutRows();sortSelectedByLayout();distributeRow(oldRow);activeFieldKey=field.key;sync();renderSelected();renderLayoutCanvas();
}
'''
t=rep(t,insert_anchor,insert_anchor+extra_layout,'2d layout helpers')

pattern=r"function renderLayoutCanvas\(\)\{.*?\nlayoutNewRow\?\.addEventListener"
new_func=r'''function renderLayoutCanvas(){
 if(!layoutCanvas)return;normalizeLayoutRows();layoutCanvas.innerHTML='';
 if(!selected.length){layoutCanvas.innerHTML='<div class="df-layout-empty">Il modulo è vuoto. Premi “Aggiungi campo” per iniziare.</div>';return;}
 const rows=[...new Set(selected.map(f=>Number(f.config.layout.row||1)))].sort((a,b)=>a-b);
 rows.forEach(rowNo=>{
  const row=document.createElement('div');row.className='df-layout-row';row.dataset.row=String(rowNo);const rowItems=fieldsInRow(rowNo);row.style.gridTemplateColumns=rowItems.map(([f])=>Math.max(10,Number(f.config.layout.width||100))+'fr').join(' ');
  rowItems.forEach(([f,i])=>{
   const card=document.createElement('div');card.className='df-layout-card'+(f.key===activeFieldKey?' is-active':'');card.dataset.fieldKey=f.key;card.draggable=true;card.style.width='100%';const required=f.required?'<span class="df-required-badge">Obbligatorio</span>':'';
   card.innerHTML=`<span class="df-layout-handle" title="Trascina" aria-hidden="true">⋮⋮</span><strong>${esc(f.label)}</strong><span class="df-layout-meta"><span class="df-layout-type">${esc(tr.types[f.type]||f.type)}</span>${required}<select aria-label="Larghezza campo">${widthChoices(f.config.layout.width||100)}</select><span class="df-layout-actions"><button type="button" data-canvas-edit title="Modifica campo" aria-label="Modifica campo">✎</button><button type="button" data-canvas-duplicate title="Duplica campo" aria-label="Duplica campo">⧉</button><button type="button" data-canvas-remove class="df-canvas-remove" title="Elimina campo" aria-label="Elimina campo">🗑</button></span></span><div class="df-layout-drop-guide" aria-hidden="true"><span data-drop-side="before">← Stessa riga</span><span data-drop-newrow>Nuova riga ↓</span><span data-drop-side="after">Stessa riga →</span></div>`;
   card.addEventListener('click',e=>{if(e.target.closest('button,select,[data-drop-side],[data-drop-newrow]'))return;selectField(i);});
   card.addEventListener('dragstart',e=>{draggedFieldIndex=i;try{e.dataTransfer.effectAllowed='move';e.dataTransfer.setData('text/plain',f.key);}catch{}card.classList.add('dragging');document.querySelector('.df-builder-workspace')?.classList.add('is-dragging');});
   card.addEventListener('dragend',()=>{draggedFieldIndex=null;card.classList.remove('dragging');document.querySelector('.df-builder-workspace')?.classList.remove('is-dragging');document.querySelectorAll('.is-over').forEach(x=>x.classList.remove('is-over'));});
   card.querySelectorAll('[data-drop-side]').forEach(zone=>{zone.addEventListener('dragover',e=>{e.preventDefault();e.stopPropagation();zone.classList.add('is-over');});zone.addEventListener('dragleave',()=>zone.classList.remove('is-over'));zone.addEventListener('drop',e=>{e.preventDefault();e.stopPropagation();zone.classList.remove('is-over');moveFieldBeside(draggedFieldIndex,i,zone.dataset.dropSide);});});
   const newRowZone=card.querySelector('[data-drop-newrow]');newRowZone.addEventListener('dragover',e=>{e.preventDefault();e.stopPropagation();newRowZone.classList.add('is-over');});newRowZone.addEventListener('dragleave',()=>newRowZone.classList.remove('is-over'));newRowZone.addEventListener('drop',e=>{e.preventDefault();e.stopPropagation();newRowZone.classList.remove('is-over');moveFieldToNewRowAfter(draggedFieldIndex,rowNo);});
   card.addEventListener('dragover',e=>{e.preventDefault();e.stopPropagation();});
   card.querySelector('select').onchange=e=>setFieldWidth(i,Number(e.target.value));card.querySelector('[data-canvas-edit]').onclick=()=>selectField(i);card.querySelector('[data-canvas-duplicate]').onclick=()=>duplicateField(i);card.querySelector('[data-canvas-remove]').onclick=()=>confirmDelete(`il campo “${f.label||'Campo'}”`,()=>removeCanvasField(i));row.appendChild(card);
  });
  row.addEventListener('dragover',e=>{if(e.target.closest('.df-layout-card'))return;e.preventDefault();row.classList.add('is-over');});row.addEventListener('dragleave',e=>{if(!row.contains(e.relatedTarget))row.classList.remove('is-over');});row.addEventListener('drop',e=>{if(e.target.closest('.df-layout-card'))return;e.preventDefault();row.classList.remove('is-over');moveFieldToRow(draggedFieldIndex,rowNo);});layoutCanvas.appendChild(row);
 });sync();
}
layoutNewRow?.addEventListener'''
t=sub(t,pattern,new_func,'2d layout renderer')

# Email templates are always visible; heavy iframe contents are loaded only when section 6 opens.
pattern=r"function renderEmailPickers\(\)\{.*?\nfunction renderEmailSpecial"
new=r'''function renderEmailPickers(loadFrames=emailPickersRendered){document.querySelectorAll('[data-email-picker]').forEach(box=>{const audience=box.dataset.emailPicker,config=emailConfig[audience];box.innerHTML='';templateDefs.forEach(([key,label])=>{const card=document.createElement('div'),special=['custom','html','chatgpt'].includes(key);card.className='df-email-choice'+((config.template||'standard')===key?' is-active':'');card.dataset.special=special?'1':'0';card.dataset.template=key;card.innerHTML=`<button type="button" class="df-email-thumb" title="Apri anteprima" aria-label="Apri anteprima: ${esc(label)}"><iframe class="df-email-thumb-frame" title="" tabindex="-1" sandbox></iframe><span class="df-email-preview-label" aria-hidden="true">◉ Anteprima</span></button><div class="df-email-choice-foot"><label class="df-email-radio"><input type="radio" name="df-email-template-${audience}" value="${key}" ${(config.template||'standard')===key?'checked':''}><span>${esc(label)}</span></label><button type="button" class="df-email-preview-btn">◉ Anteprima</button></div>`;const openPreview=e=>{e.preventDefault();e.stopPropagation();showEmailPreview(audience,key);};card.querySelector('.df-email-thumb').onclick=openPreview;card.querySelector('.df-email-preview-btn').onclick=openPreview;card.querySelector('input').onchange=()=>{config.template=key;renderEmailPickers(emailPickersRendered);renderEmailSpecial(audience);sync();};box.appendChild(card);const frame=card.querySelector('iframe');if(loadFrames)requestAnimationFrame(()=>{try{frame.srcdoc=emailPreviewHtml(audience,key);}catch{frame.srcdoc='<div style="font-family:Arial;padding:20px">Anteprima non disponibile</div>';}});else frame.srcdoc='<div style="font-family:Arial;padding:18px;color:#667085">Anteprima</div>';});renderEmailSpecial(audience);});}
function renderEmailSpecial'''
t=sub(t,pattern,new,'email preview cards restore')

# Render lightweight email cards at startup; actual iframe previews remain lazy.
old="""renderSelected();renderLayout();renderTokens();renderUserEmailFields();renderAdditional();sync();historyReady=true;"""
new="""renderSelected();renderLayout();renderTokens();renderUserEmailFields();renderAdditional();renderEmailPickers(false);sync();historyReady=true;"""
t=rep(t,old,new,'initial lightweight email cards')
old="""const emailSection=[...document.querySelectorAll('[data-accordion]')][5];const ensureEmailPickers=()=>{if(emailPickersRendered)return;emailPickersRendered=true;renderEmailPickers();};"""
new="""const emailSection=[...document.querySelectorAll('[data-accordion]')][5];const ensureEmailPickers=()=>{if(emailPickersRendered)return;emailPickersRendered=true;renderEmailPickers(true);};"""
t=rep(t,old,new,'load email preview frames')

# Final CSS normalization and visual feedback.
css=r'''
/* Forms 1.3.19: unified buttons, action modals, fast properties and 2D layout. */
.df-builder .df-btn{background:var(--bs-body-bg,#fff)!important;color:var(--bs-body-color,#1f2937)!important;border-color:var(--bs-border-color,#d9dee5)!important}
.df-builder .df-btn:hover,.df-builder .df-btn:focus-visible{background:var(--bs-tertiary-bg,#f6f7f9)!important;border-color:#b9c2ce!important;color:var(--bs-body-color,#1f2937)!important}
.df-builder .df-btn.df-primary,.df-builder .df-save-structure,.df-builder .df-add{background:var(--df)!important;border-color:var(--df)!important;color:#fff!important}
.df-builder .df-btn.df-primary:hover,.df-builder .df-btn.df-primary:focus-visible,.df-builder .df-save-structure:hover,.df-builder .df-save-structure:focus-visible,.df-builder .df-add:hover{background:var(--df-dark)!important;border-color:var(--df-dark)!important;color:#fff!important}
.df-builder .df-btn.df-danger{background:#fff1f3!important;border-color:#e69aa7!important;color:#a4132d!important}.df-builder .df-btn.df-danger:hover{background:#dc3545!important;border-color:#dc3545!important;color:#fff!important}
.df-summary-chip{background:#eef1f4!important;border-color:#d5dbe3!important;color:#4b5563!important;font-weight:750}.df-summary-chip.df-required-badge,.df-required-badge{background:#fff0f4!important;border-color:#f1a7b9!important;color:#a4133c!important}
.df-selected-config details.full>summary,.df-main-settings>summary,.df-layout-settings>summary,.df-condition-details>summary,.df-tax-links>summary{min-height:40px!important;padding:8px 10px!important;font-size:14px!important;line-height:1.25!important}.df-main-settings-body,.df-layout-settings-body,.df-condition-body,.df-tax-links-body{padding:8px 10px 10px!important}.df-selected-config{gap:6px!important;padding:9px!important}.df-main-settings-grid,.df-condition-controls{gap:6px 8px!important}.df-selected-config-wrap{padding-top:5px!important}
.df-builder-workspace .df-layout-row{display:grid!important;align-items:stretch!important}.df-layout-card{overflow:visible}.df-layout-drop-guide{position:absolute;inset:3px;z-index:15;display:none;grid-template-columns:1fr 1fr 1fr;gap:4px;pointer-events:none}.df-builder-workspace.is-dragging .df-layout-card:not(.dragging) .df-layout-drop-guide{display:grid;pointer-events:auto}.df-layout-drop-guide span{display:flex;align-items:center;justify-content:center;text-align:center;padding:4px;border:1px dashed #4b8fe2;border-radius:5px;background:rgba(239,246,255,.94);color:#1d4f91;font-size:10px;font-weight:850;cursor:copy}.df-layout-drop-guide span.is-over{background:#dbeafe;border-style:solid;box-shadow:inset 0 0 0 1px #2563eb}.df-layout-drop-guide [data-drop-newrow]{background:rgba(238,242,255,.96);color:#4338ca;border-color:#818cf8}
.df-email-choice-foot{justify-content:space-between!important}.df-email-preview-btn{display:inline-flex!important;align-items:center!important;justify-content:center!important;border:0!important;background:transparent!important;color:#2869b2!important;font-size:11px!important;font-weight:800!important;padding:4px 6px!important;cursor:pointer!important}.df-email-preview-btn:hover{text-decoration:underline}.df-email-preview-label{opacity:.88!important}
.df-action-modal{position:fixed;inset:0;z-index:30000;display:grid;place-items:center;padding:16px}.df-action-backdrop{position:absolute;inset:0;background:rgba(15,23,42,.66);backdrop-filter:blur(2px)}.df-action-dialog{position:relative;z-index:1;width:min(520px,calc(100vw - 28px));background:var(--bs-body-bg,#fff);color:var(--bs-body-color,#1f2937);border:1px solid var(--bs-border-color,#d9dee5);border-radius:12px;box-shadow:0 24px 70px rgba(0,0,0,.3);overflow:hidden}.df-action-head,.df-action-foot{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:13px 15px;border-bottom:1px solid var(--bs-border-color,#d9dee5)}.df-action-head strong{font-size:17px}.df-action-body{padding:16px}.df-action-body p{margin:0 0 12px;line-height:1.5}.df-action-foot{justify-content:flex-end;border-top:1px solid var(--bs-border-color,#d9dee5);border-bottom:0}.df-action-x{width:34px;height:34px;border:1px solid var(--bs-border-color,#d9dee5);border-radius:7px;background:transparent;color:inherit;font-size:21px;cursor:pointer}.df-action-input-label{display:grid;gap:6px;font-weight:750}.df-action-input{width:100%;min-height:42px;border:1px solid var(--bs-border-color,#d5dbe3);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit;padding:9px 10px}.df-builder .df-action-danger,.df-action-modal .df-action-danger{background:#dc3545!important;border-color:#dc3545!important;color:#fff!important}.df-action-modal .df-action-danger:hover{background:#b4232f!important;border-color:#b4232f!important;color:#fff!important}
html[data-bs-theme="dark"] .df-summary-chip,body[data-bs-theme="dark"] .df-summary-chip,html[data-color-scheme="dark"] .df-summary-chip{background:#253140!important;border-color:#536174!important;color:#e5eaf0!important}html[data-bs-theme="dark"] .df-summary-chip.df-required-badge,body[data-bs-theme="dark"] .df-summary-chip.df-required-badge,html[data-color-scheme="dark"] .df-summary-chip.df-required-badge{background:#4a1e2b!important;border-color:#a94e68!important;color:#ffc0d0!important}html[data-bs-theme="dark"] .df-layout-drop-guide span,body[data-bs-theme="dark"] .df-layout-drop-guide span{background:rgba(25,43,66,.96);color:#c8ddff;border-color:#6ba3e8}html[data-bs-theme="dark"] .df-layout-drop-guide [data-drop-newrow],body[data-bs-theme="dark"] .df-layout-drop-guide [data-drop-newrow]{background:rgba(43,39,82,.97);color:#d9d5ff;border-color:#8b86e8}
@media(max-width:800px){.df-builder-workspace .df-layout-row{grid-template-columns:1fr!important}.df-layout-drop-guide{grid-template-columns:1fr 1fr 1fr}.df-layout-drop-guide span{font-size:9px}}
'''
t=rep(t,'</style>',css+'\n</style>','1.3.19 CSS')

builder.write_text(t)
