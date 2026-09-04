#!/usr/bin/env python3
from pathlib import Path
import re, sys

if len(sys.argv) != 3:
    raise SystemExit('usage: patch.py COMPONENT_ROOT PLUGIN_ROOT')

comp=Path(sys.argv[1]); plug=Path(sys.argv[2])
builder=comp/'administrator/components/com_decaroforms/tmpl/builder/default.php'
controller=comp/'administrator/components/com_decaroforms/src/Controller/BuilderController.php'
helper=comp/'administrator/components/com_decaroforms/src/Helper/FormHelper.php'
component_manifest=comp/'com_decaroforms.xml'
plugin_manifest=plug/'decaroforms.xml'
plugin=plug/'src/Extension/FormsPlugin.php'

def rep(text, old, new, label):
    if old not in text:
        raise RuntimeError(f'{label} not found')
    return text.replace(old,new,1)

# Versions
h=helper.read_text(); h=rep(h,"public const VERSION = '1.3.17';","public const VERSION = '1.3.18';",'helper version'); helper.write_text(h)
for m in (component_manifest,plugin_manifest):
    s=m.read_text(); s=rep(s,'<version>1.3.17</version>','<version>1.3.18</version>',str(m)); m.write_text(s)

# Controller: distinguish expired token from permissions, use correct permission for edit/create,
# support an explicit JSON save response for the Builder and preserve HTML confirmation content.
c=controller.read_text()
c=rep(c,'use Joomla\\CMS\\Router\\Route;\nuse Joomla\\CMS\\Session\\Session;', 'use Joomla\\CMS\\Router\\Route;\nuse Joomla\\CMS\\Response\\JsonResponse;\nuse Joomla\\CMS\\Session\\Session;', 'JsonResponse import')
old='''        $app = Factory::getApplication();
        if (!Session::checkToken('post') || !$app->getIdentity()->authorise('core.create', 'com_decaroforms')) {
            throw new \\RuntimeException(Text::_('COM_DECAROFORMS_ERR_TOKEN_PERMISSIONS'), 403);
        }

        $input = $app->getInput();
        $id = $input->post->getInt('id', 0);
        $title = trim($input->post->getString('title', ''));'''
new='''        $app = Factory::getApplication();
        $input = $app->getInput();
        $isAjax = strtolower($input->server->getString('HTTP_X_REQUESTED_WITH', '')) === 'xmlhttprequest';

        if (!Session::checkToken('post')) {
            if ($isAjax) {
                echo new JsonResponse(null, 'La sessione è scaduta. Ricarica la pagina: la bozza del modulo resta disponibile.', true);
                $app->close();
                return;
            }
            throw new \\RuntimeException(Text::_('JINVALID_TOKEN'), 403);
        }

        $id = $input->post->getInt('id', 0);
        $permission = $id > 0 ? 'core.edit' : 'core.create';
        if (!$app->getIdentity()->authorise($permission, 'com_decaroforms')) {
            if ($isAjax) {
                echo new JsonResponse(null, 'Non hai le autorizzazioni necessarie per salvare questo modulo.', true);
                $app->close();
                return;
            }
            throw new \\RuntimeException(Text::_('JERROR_ALERTNOAUTHOR'), 403);
        }

        $title = trim($input->post->getString('title', ''));'''
c=rep(c,old,new,'save auth block')
old='''        if ($title === '') {
            $app->enqueueMessage(Text::_('COM_DECAROFORMS_ERR_TITLE_REQUIRED'), 'error');
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=builder&id=' . $id, false));
            return;
        }'''
new='''        if ($title === '') {
            if ($isAjax) {
                echo new JsonResponse(null, Text::_('COM_DECAROFORMS_ERR_TITLE_REQUIRED'), true);
                $app->close();
                return;
            }
            $app->enqueueMessage(Text::_('COM_DECAROFORMS_ERR_TITLE_REQUIRED'), 'error');
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=builder&id=' . $id, false));
            return;
        }'''
c=rep(c,old,new,'ajax title validation')
c=rep(c,"'success_message' => trim($input->post->getString('success_message', Text::_('COM_DECAROFORMS_SUCCESS_DEFAULT'))),","'success_message' => trim((string) $input->post->get('success_message', Text::_('COM_DECAROFORMS_SUCCESS_DEFAULT'), 'raw')),",'raw confirmation message')
old="$app->enqueueMessage(Text::_('COM_DECAROFORMS_MSG_FORM_SAVED'), 'message');"
new="""if ($isAjax) {
            echo new JsonResponse(
                ['id' => $id, 'redirect' => Route::_('index.php?option=com_decaroforms&view=forms', false)],
                Text::_('COM_DECAROFORMS_MSG_FORM_SAVED')
            );
            $app->close();
            return;
        }

        $app->enqueueMessage(Text::_('COM_DECAROFORMS_MSG_FORM_SAVED'), 'message');"""
c=rep(c,old,new,'ajax success response')
controller.write_text(c)

# Builder UI and save reliability.
t=builder.read_text()
# Save / draft notices directly below toolbar.
old='''  </div>

  <form method="post" action="<?php echo $this->saveUrl; ?>" id="df-builder-form">'''
new='''  </div>
  <div class="df-save-notice" id="df-save-notice" hidden role="status" aria-live="polite"></div>
  <div class="df-draft-banner" id="df-draft-banner" hidden>
    <div><strong>Bozza non salvata disponibile</strong><span id="df-draft-time"></span></div>
    <div class="df-draft-actions"><button type="button" class="df-btn df-small df-primary" id="df-draft-restore">Ripristina bozza</button><button type="button" class="df-btn df-small" id="df-draft-discard">Ignora</button></div>
  </div>

  <form method="post" action="<?php echo $this->saveUrl; ?>" id="df-builder-form">'''
t=rep(t,old,new,'save draft notices')

# Confirmation editor + quick format/modal controls.
old='''        <div class="df-field df-field-full"><label><?php echo Text::_('COM_DECAROFORMS_SUCCESS_MESSAGE'); ?></label><input name="success_message" value="<?php echo $val('success_message', Text::_('COM_DECAROFORMS_SUCCESS_DEFAULT')); ?>"><span class="df-note"><?php echo Text::_('COM_DECAROFORMS_SUCCESS_BELOW_NOTE'); ?></span></div>'''
new='''        <div class="df-field df-field-full df-success-message-block"><label><?php echo Text::_('COM_DECAROFORMS_SUCCESS_MESSAGE'); ?></label><textarea class="df-success-editor" name="success_message" rows="2"><?php echo $val('success_message', Text::_('COM_DECAROFORMS_SUCCESS_DEFAULT')); ?></textarea><div class="df-success-options"><label><span>Formato messaggio</span><select id="df-success-format"><option value="text">Testo semplice</option><option value="html">HTML</option></select></label><label class="df-switch df-success-modal-switch"><input type="checkbox" id="df-success-modal"><span class="df-switch-ui" aria-hidden="true"></span><span>Mostra in finestra modal</span></label></div><span class="df-note">La posizione completa del messaggio può essere regolata anche in “Validazione e conferma”.</span></div>'''
t=rep(t,old,new,'confirmation editor')

# Only the active field is rendered in the right properties panel: huge speed-up when many fields exist.
t=rep(t,'selected.forEach((x,i)=>{defaultFieldConfig(x);const d=document.createElement(\'div\');d.className=\'df-selected-item\'+(x.key===activeFieldKey?\' is-open\':\'\');',"selected.map((x,i)=>[x,i]).filter(([x])=>x.key===activeFieldKey).forEach(([x,i])=>{defaultFieldConfig(x);const d=document.createElement('div');d.className='df-selected-item is-open';",'active field only')

# Defer expensive email iframe thumbnails until the email accordion is actually opened.
t=rep(t,"filter.innerHTML='';filter.hidden=true;search.addEventListener('input',renderLibrary);renderLibrary();renderEmailPickers();","filter.innerHTML='';filter.hidden=true;search.addEventListener('input',renderLibrary);renderLibrary();",'remove eager email render')
t=rep(t,'renderTokens();renderUserEmailFields();renderEmailPickers();renderAdditional();const controls=', 'renderTokens();renderUserEmailFields();if(emailPickersRendered)renderEmailPickers();renderAdditional();const controls=', 'history lazy emails')

# Confirmation defaults include format.
t=rep(t,"builderConfig.confirmation={enabled:true,position:'below',scroll:false,continue:false,continue_label:'<?php echo addslashes(Text::_('COM_DECAROFORMS_CONTINUE')); ?>',continue_url:'',...(builderConfig.confirmation||{})};","builderConfig.confirmation={enabled:true,position:'below',format:'text',scroll:false,continue:false,continue_label:'<?php echo addslashes(Text::_('COM_DECAROFORMS_CONTINUE')); ?>',continue_url:'',...(builderConfig.confirmation||{})};",'confirmation format default')

# Confirmation controls: top format/modal stay synchronized with section 7.
old="""const conf={enabled:document.getElementById('df-confirm-enabled'),position:document.getElementById('df-confirm-position'),scroll:document.getElementById('df-confirm-scroll'),cont:document.getElementById('df-confirm-continue'),label:document.getElementById('df-confirm-continue-label'),url:document.getElementById('df-confirm-continue-url')};conf.enabled.checked=builderConfig.confirmation.enabled!==false;conf.position.value=builderConfig.confirmation.position||'below';conf.scroll.checked=!!builderConfig.confirmation.scroll;conf.cont.checked=!!builderConfig.confirmation.continue;conf.label.value=builderConfig.confirmation.continue_label||'Continua';conf.url.value=builderConfig.confirmation.continue_url||'';conf.enabled.onchange=e=>{builderConfig.confirmation.enabled=e.target.checked;sync();};conf.position.onchange=e=>{builderConfig.confirmation.position=e.target.value;sync();};conf.scroll.onchange=e=>{builderConfig.confirmation.scroll=e.target.checked;sync();};conf.cont.onchange=e=>{builderConfig.confirmation.continue=e.target.checked;sync();};conf.label.oninput=e=>{builderConfig.confirmation.continue_label=e.target.value;sync();};conf.url.oninput=e=>{builderConfig.confirmation.continue_url=e.target.value;sync();};"""
new="""const conf={enabled:document.getElementById('df-confirm-enabled'),position:document.getElementById('df-confirm-position'),scroll:document.getElementById('df-confirm-scroll'),cont:document.getElementById('df-confirm-continue'),label:document.getElementById('df-confirm-continue-label'),url:document.getElementById('df-confirm-continue-url')};const successFormat=document.getElementById('df-success-format'),successModal=document.getElementById('df-success-modal');conf.enabled.checked=builderConfig.confirmation.enabled!==false;conf.position.value=builderConfig.confirmation.position||'below';successFormat.value=builderConfig.confirmation.format==='html'?'html':'text';successModal.checked=conf.position.value==='modal';conf.scroll.checked=!!builderConfig.confirmation.scroll;conf.cont.checked=!!builderConfig.confirmation.continue;conf.label.value=builderConfig.confirmation.continue_label||'Continua';conf.url.value=builderConfig.confirmation.continue_url||'';conf.enabled.onchange=e=>{builderConfig.confirmation.enabled=e.target.checked;sync();};conf.position.onchange=e=>{builderConfig.confirmation.position=e.target.value;successModal.checked=e.target.value==='modal';sync();};successFormat.onchange=e=>{builderConfig.confirmation.format=e.target.value==='html'?'html':'text';sync();};successModal.onchange=e=>{builderConfig.confirmation.position=e.target.checked?'modal':(builderConfig.confirmation.position==='modal'?'below':builderConfig.confirmation.position);conf.position.value=builderConfig.confirmation.position;sync();};conf.scroll.onchange=e=>{builderConfig.confirmation.scroll=e.target.checked;sync();};conf.cont.onchange=e=>{builderConfig.confirmation.continue=e.target.checked;sync();};conf.label.oninput=e=>{builderConfig.confirmation.continue_label=e.target.value;sync();};conf.url.oninput=e=>{builderConfig.confirmation.continue_url=e.target.value;sync();};"""
t=rep(t,old,new,'confirmation controls sync')

# Closed-reason block appears only when the form is disabled.
anchor="const minSeconds=document.getElementById('df-min-seconds'),rateSeconds=document.getElementById('df-rate-seconds');"
closed_js="""const enabledToggle=document.querySelector('[name=\"enabled\"]'),closedBox=document.querySelector('.df-closed-box');function syncClosedBox(){if(closedBox)closedBox.hidden=!!enabledToggle?.checked;}enabledToggle?.addEventListener('change',syncClosedBox);syncClosedBox();
"""
t=rep(t,anchor,closed_js+anchor,'closed visibility JS')

# Autosaved draft + AJAX save. The draft is cleared only after a positive JSON response from Joomla.
old="""// Submit guard: duplicate status names must be resolved before saving.
document.getElementById('df-builder-form').addEventListener('submit',e=>{if(statusConflicts().size){e.preventDefault();openBuilderSection(4,true);renderStatuses();return;}sync();initialHistorySignature=historySignature(captureHistoryState());});"""
new=r'''// Draft recovery and robust AJAX save.
const draftStorageKey='decaroforms_builder_draft_v2_<?php echo (int) $id; ?>';let draftReady=false,draftTimer=null,emailPickersRendered=false;
function readDraft(){try{const d=JSON.parse(localStorage.getItem(draftStorageKey)||'null');return d&&d.state?d:null;}catch{return null;}}
function clearDraft(){try{localStorage.removeItem(draftStorageKey);}catch{}document.getElementById('df-draft-banner')?.setAttribute('hidden','');}
function saveDraftNow(){if(!draftReady)return;try{localStorage.setItem(draftStorageKey,JSON.stringify({savedAt:Date.now(),state:captureHistoryState()}));}catch(e){console.warn('Forms draft save failed',e);}}
function scheduleDraft(){if(!draftReady)return;clearTimeout(draftTimer);draftTimer=setTimeout(saveDraftNow,350);}
function applyDraftState(s){historyApplying=true;selected=clone(s.selected||[]);statuses=clone(s.statuses||[]);columns=clone(s.columns||[]);builderConfig=clone(s.builderConfig||{});emailConfig=clone(s.emailConfig||{});additionalEmails=clone(s.additionalEmails||[]);integrations=clone(s.integrations||{});activeFieldKey=s.activeFieldKey||selected[0]?.key||null;renderSelected();renderLayout();renderStatuses();renderColumns();renderTokens();renderUserEmailFields();if(emailPickersRendered)renderEmailPickers();renderAdditional();const controls=[...document.querySelectorAll('#df-builder-form [name]:not([type="hidden"])')];(s.form||[]).forEach((v,i)=>{const el=controls[i];if(el&&el.name===v.name){if(el.type==='checkbox'||el.type==='radio')el.checked=!!v.value;else el.value=v.value;}});syncClosedBox();successFormat.value=builderConfig.confirmation?.format==='html'?'html':'text';conf.position.value=builderConfig.confirmation?.position||'below';successModal.checked=conf.position.value==='modal';historyApplying=false;historyStates=[captureHistoryState()];historyIndex=0;sync();applyLockState();updateHistoryButtons();}
function showDraftBanner(){const d=readDraft(),bar=document.getElementById('df-draft-banner');if(!d||!bar)return false;if(Date.now()-Number(d.savedAt||0)>1000*60*60*24*14){clearDraft();return false;}if(historySignature(d.state)===historySignature(captureHistoryState())){clearDraft();return false;}bar.hidden=false;const tm=document.getElementById('df-draft-time');if(tm)tm.textContent=' · '+new Date(d.savedAt).toLocaleString();document.getElementById('df-draft-restore').onclick=()=>{applyDraftState(d.state);bar.hidden=true;draftReady=true;saveDraftNow();};document.getElementById('df-draft-discard').onclick=()=>{clearDraft();draftReady=true;};return true;}
function setSaveNotice(message,type='info',reload=false){const box=document.getElementById('df-save-notice');if(!box)return;box.className='df-save-notice is-'+type;box.hidden=false;box.innerHTML=`<span>${esc(message)}</span>${reload?'<button type="button" class="df-btn df-small" data-save-reload>Ricarica pagina</button>':''}`;box.querySelector('[data-save-reload]')?.addEventListener('click',()=>{saveDraftNow();window.dfAllowDraftReload=true;location.reload();});}
function clearSaveNotice(){const box=document.getElementById('df-save-notice');if(box)box.hidden=true;}
document.getElementById('df-builder-form').addEventListener('submit',async e=>{e.preventDefault();if(statusConflicts().size){openBuilderSection(4,true);renderStatuses();return;}sync();saveDraftNow();const form=e.currentTarget,buttons=[...document.querySelectorAll('.df-save-top'),...form.querySelectorAll('button[type="submit"]')];buttons.forEach(b=>b.disabled=true);setSaveNotice('Salvataggio del modulo…','info');try{const response=await fetch(form.action,{method:'POST',body:new FormData(form),credentials:'same-origin',headers:{'X-Requested-With':'XMLHttpRequest','Accept':'application/json'}});let result=null;try{result=await response.json();}catch{}if(!response.ok||!result||result.success!==true){const message=result?.message||(response.status===403?'La sessione è scaduta. La bozza è stata conservata.':'Il modulo non è stato salvato. Riprova.');const expired=response.status===403||/sessione|token/i.test(message);setSaveNotice(message,'error',expired);return;}clearDraft();initialHistorySignature=historySignature(captureHistoryState());setSaveNotice(result.message||'Modulo salvato.','success');window.dfAllowDraftReload=true;const redirect=result.data?.redirect||<?php echo json_encode($this->formsUrl, JSON_UNESCAPED_SLASHES); ?>;setTimeout(()=>location.assign(redirect),180);}catch(err){console.error('Forms save error',err);setSaveNotice('Impossibile completare il salvataggio. La bozza è stata conservata.','error',false);}finally{buttons.forEach(b=>b.disabled=editorLocked);}});'''
t=rep(t,old,new,'ajax draft save')

# beforeunload can be deliberately bypassed when reloading a safely stored draft.
t=rep(t,"window.addEventListener('beforeunload',e=>{if(hasUnsavedChanges()){e.preventDefault();e.returnValue='';}});","window.addEventListener('beforeunload',e=>{if(hasUnsavedChanges()&&!window.dfAllowDraftReload){e.preventDefault();e.returnValue='';}});",'beforeunload draft bypass')

# Final initialization: email thumbnails lazy-load on section 6; draft banner is checked before autosave is enabled.
old="renderSelected();renderLayout();renderTokens();renderUserEmailFields();renderEmailPickers();renderAdditional();sync();historyReady=true;historyStates=[captureHistoryState()];historyIndex=0;initialHistorySignature=historySignature(historyStates[0]);applyLockState();updateHistoryButtons();"
new="""renderSelected();renderLayout();renderTokens();renderUserEmailFields();renderAdditional();sync();historyReady=true;historyStates=[captureHistoryState()];historyIndex=0;initialHistorySignature=historySignature(historyStates[0]);applyLockState();updateHistoryButtons();const emailSection=[...document.querySelectorAll('[data-accordion]')][5];const ensureEmailPickers=()=>{if(emailPickersRendered)return;emailPickersRendered=true;renderEmailPickers();};emailSection?.querySelector('.df-section-toggle')?.addEventListener('click',()=>setTimeout(()=>{if(emailSection.classList.contains('is-open'))ensureEmailPickers();},0));const pendingDraft=showDraftBanner();draftReady=!pendingDraft;builderForm.addEventListener('input',scheduleDraft,true);builderForm.addEventListener('change',scheduleDraft,true);document.addEventListener('dragend',scheduleDraft,true);document.addEventListener('click',e=>{if(e.target.closest('.df-builder'))scheduleDraft();},true);"""
t=rep(t,old,new,'final init lazy/draft')

css=r'''
/* Forms 1.3.18: save recovery, compact properties and confirmation controls. */
.df-save-structure{background:var(--df)!important;border-color:var(--df)!important;color:#fff!important;font-weight:800!important}
.df-save-structure:hover,.df-save-structure:focus-visible{background:var(--df-dark)!important;border-color:var(--df-dark)!important;color:#fff!important}
.df-closed-box[hidden]{display:none!important}
.df-success-editor{min-height:58px!important;resize:vertical}
.df-success-options{display:flex;align-items:end;gap:18px;flex-wrap:wrap;margin-top:8px}
.df-success-options>label:not(.df-switch){display:grid;gap:5px;min-width:190px;font-weight:750}
.df-success-options select{min-height:38px}
.df-success-modal-switch{margin:0 0 3px!important}
.df-save-notice,.df-draft-banner{margin:0 0 12px;padding:10px 12px;border:1px solid #d9dee5;border-radius:8px;background:#f6f7f9;color:#1f2937}
.df-save-notice{display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap}
.df-save-notice.is-success{border-color:#9bd7b2;background:#edf9f1;color:#14532d}.df-save-notice.is-error{border-color:#f2a7b8;background:#fff1f4;color:#7a1631}.df-save-notice[hidden],.df-draft-banner[hidden]{display:none!important}
.df-draft-banner{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;border-color:#f0c36c;background:#fff9e8}.df-draft-banner>div:first-child{display:flex;gap:4px;flex-wrap:wrap}.df-draft-actions{display:flex;gap:8px}
.df-selected-config{gap:8px!important}.df-selected-config details.full{margin:0!important}.df-selected-config details.full>summary{min-height:44px!important;padding:10px 12px!important;font-size:16px!important}.df-main-settings-body,.df-layout-settings-body{padding:10px 12px!important}.df-main-settings-grid{gap:8px 10px!important}.df-selected-config-wrap{padding-top:8px!important}.df-properties-panel .df-selected-item{margin-bottom:0!important}
html[data-bs-theme="dark"] .df-save-notice,body[data-bs-theme="dark"] .df-save-notice,html[data-color-scheme="dark"] .df-save-notice{background:#1f2937;color:#f8fafc;border-color:#475569}.df-save-notice.is-error{color:#7a1631}.df-save-notice.is-success{color:#14532d}
html[data-bs-theme="dark"] .df-draft-banner,body[data-bs-theme="dark"] .df-draft-banner,html[data-color-scheme="dark"] .df-draft-banner{background:#332b18;color:#fff7d6;border-color:#8a6a25}
@media(max-width:800px){.df-success-options{align-items:stretch}.df-success-options>label{width:100%}.df-draft-actions{width:100%}.df-draft-actions button{flex:1}}
'''
if '</style>' not in t: raise RuntimeError('style end not found')
t=t.replace('</style>',css+'\n</style>',1)
builder.write_text(t)

# Public plugin: confirmation format is honored and modal is a real accessible overlay, not alert().
p=plugin.read_text()
p=rep(p,"'position' => (string) ($confirmation['position'] ?? 'below'),","'position' => (string) ($confirmation['position'] ?? 'below'),\n            'format' => (($confirmation['format'] ?? 'text') === 'html' ? 'html' : 'text'),",'plugin confirmation format')
anchor="form.addEventListener('submit',async e=>"
helper_js=r'''function safeConfirmHtml(html){const t=document.createElement('template');t.innerHTML=String(html||'');t.content.querySelectorAll('script,style,iframe,object,embed,link,meta').forEach(n=>n.remove());t.content.querySelectorAll('*').forEach(el=>{[...el.attributes].forEach(a=>{const n=a.name.toLowerCase(),v=String(a.value||'');if(n.startsWith('on')||((n==='href'||n==='src')&&/^\s*javascript:/i.test(v)))el.removeAttribute(a.name);});});return t.innerHTML;}function showConfirmModal(content,isHtml){document.querySelector('.df-public-confirm-modal')?.remove();const o=document.createElement('div');o.className='df-public-confirm-modal';o.style.cssText='position:fixed;inset:0;z-index:2147483000;display:grid;place-items:center;padding:20px;background:rgba(15,23,42,.58)';const d=document.createElement('div');d.style.cssText='width:min(560px,100%);max-height:85vh;overflow:auto;background:#fff;color:#1f2937;border-radius:12px;box-shadow:0 20px 60px rgba(0,0,0,.28);padding:22px';const h=document.createElement('div');h.style.cssText='display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:14px';h.innerHTML='<strong style="font-size:20px">Invio completato</strong><button type="button" aria-label="Chiudi" style="border:0;background:transparent;font-size:26px;cursor:pointer">×</button>';const b=document.createElement('div');if(isHtml)b.innerHTML=safeConfirmHtml(content);else b.textContent=content;const f=document.createElement('div');f.style.cssText='display:flex;justify-content:flex-end;margin-top:18px';f.innerHTML='<button type="button" style="border:1px solid #d9dee5;background:#f6f7f9;color:#1f2937;border-radius:7px;padding:8px 14px;font-weight:700;cursor:pointer">Chiudi</button>';d.append(h,b,f);o.appendChild(d);document.body.appendChild(o);const close=()=>o.remove();h.querySelector('button').onclick=close;f.querySelector('button').onclick=close;o.addEventListener('click',e=>{if(e.target===o)close();});const esc=e=>{if(e.key==='Escape'){close();document.removeEventListener('keydown',esc);}};document.addEventListener('keydown',esc);h.querySelector('button').focus();}
'''
p=rep(p,anchor,helper_js+anchor,'public confirmation helpers')
p=rep(p,"msg.textContent=j.message||(j.success?cfg.success:cfg.error);","const confirmationMessage=j.message||(j.success?cfg.success:cfg.error);if(j.success&&cfg.confirmation.format==='html')msg.innerHTML=safeConfirmHtml(confirmationMessage);else msg.textContent=confirmationMessage;",'public html message')
p=rep(p,"if(j.success&&cfg.confirmation.position==='modal'){alert(msg.textContent);}","if(j.success&&cfg.confirmation.position==='modal'){showConfirmModal(confirmationMessage,cfg.confirmation.format==='html');}",'real public modal')
plugin.write_text(p)

# Sanity checks
for path,tokens in [(builder,['draftStorageKey','df-success-format','emailPickersRendered','selected.map((x,i)=>[x,i]).filter','df-save-structure{background:var(--df)']), (controller,['JsonResponse','core.edit','La sessione è scaduta','success_message']), (plugin,["'format' =>",'safeConfirmHtml','showConfirmModal'])]:
    s=path.read_text()
    for token in tokens:
        if token not in s: raise RuntimeError(f'missing {token} in {path}')
print('Forms 1.3.18 patch applied')
