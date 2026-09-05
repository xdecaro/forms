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

def rep(text, old, new, label, count=1):
    if old not in text:
        raise RuntimeError(f'{label} not found')
    return text.replace(old,new,count)

def sub(text, pattern, new, label, flags=re.S):
    out,n=re.subn(pattern,new,text,count=1,flags=flags)
    if n != 1:
        raise RuntimeError(f'{label} replacement count={n}')
    return out

# Versions.
h=helper.read_text(); h=rep(h,"public const VERSION = '1.3.20';","public const VERSION = '1.3.21';",'helper version'); helper.write_text(h)
for m in (component_manifest,plugin_manifest):
    s=m.read_text(); s=rep(s,'<version>1.3.20</version>','<version>1.3.21</version>',str(m)); m.write_text(s)

# Controller: resolve id before token check, return a fresh token to AJAX, and never show a raw 403 page for a normal form fallback.
c=controller.read_text()
old="""        $isAjax = strtolower($input->server->getString('HTTP_X_REQUESTED_WITH', '')) === 'xmlhttprequest';

        if (!Session::checkToken('post')) {
            if ($isAjax) {
                echo new JsonResponse(null, 'La sessione è scaduta. Ricarica la pagina: la bozza del modulo resta disponibile.', true);
                $app->close();
                return;
            }
            throw new \\RuntimeException(Text::_('JINVALID_TOKEN'), 403);
        }

        $id = $input->post->getInt('id', 0);"""
new="""        $isAjax = strtolower($input->server->getString('HTTP_X_REQUESTED_WITH', '')) === 'xmlhttprequest';
        $id = $input->post->getInt('id', 0);

        if (!Session::checkToken('post')) {
            $message = 'La sessione di sicurezza è stata aggiornata. Il modulo non è stato salvato con il vecchio token.';
            if ($isAjax) {
                echo new JsonResponse(['code' => 'invalid_token', 'token' => Session::getFormToken()], $message, true);
                $app->close();
                return;
            }
            $app->enqueueMessage($message . ' Ricarica il Builder e ripristina la bozza.', 'warning');
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=builder&id=' . $id, false));
            return;
        }"""
c=rep(c,old,new,'token failure handling')

# Read-only authenticated endpoint used immediately before save to obtain the current Joomla CSRF token.
anchor="""    public function save(): void
    {"""
token_method="""    public function token(): void
    {
        $app = Factory::getApplication();
        $user = $app->getIdentity();

        if (!$user || $user->guest || !$user->authorise('core.manage', 'com_decaroforms')) {
            echo new JsonResponse(null, 'Sessione amministratore non disponibile.', true);
            $app->close();
            return;
        }

        $app->setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0', true);
        echo new JsonResponse(['token' => Session::getFormToken()]);
        $app->close();
    }

"""
c=rep(c,anchor,token_method+anchor,'token endpoint')
controller.write_text(c)

# Builder: wrap the Joomla token so it can be replaced safely without guessing hidden fields.
t=builder.read_text()
t=rep(t,"    <?php echo HTMLHelper::_('form.token'); ?>","    <span id=\"df-csrf-token-wrap\"><?php echo HTMLHelper::_('form.token'); ?></span>",'token wrapper')

# Robust save handler is deliberately separate from the large Builder IIFE. Even if another UI feature throws,
# native POST is still intercepted and a raw Joomla 403 page cannot be reached through the normal Save buttons.
form_old='''  <form method="post" action="<?php echo $this->saveUrl; ?>" id="df-builder-form">'''
form_new=r'''  <script>
  (()=>{
    const tokenUrl='index.php?option=com_decaroforms&task=builder.token&format=json';
    const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    function notice(message,type='info',reload=false){
      if(typeof window.dfSetSaveNotice==='function'){window.dfSetSaveNotice(message,type,reload);return;}
      let box=document.getElementById('df-save-notice');
      if(!box){box=document.createElement('div');box.id='df-save-notice';document.querySelector('.df-builder')?.prepend(box);}
      if(!box)return;
      box.className='df-save-notice is-'+type;box.hidden=false;
      box.innerHTML=`<span>${esc(message)}</span>${reload?'<button type="button" class="df-btn df-small" data-save-reload>Ricarica pagina</button>':''}`;
      box.querySelector('[data-save-reload]')?.addEventListener('click',()=>location.reload());
    }
    function applyToken(form,token){
      if(!token)return false;
      const wrap=document.getElementById('df-csrf-token-wrap');
      if(!wrap)return false;
      wrap.replaceChildren();
      const input=document.createElement('input');input.type='hidden';input.name=token;input.value='1';wrap.appendChild(input);
      return true;
    }
    async function currentToken(form){
      const response=await fetch(tokenUrl+'&_df='+Date.now(),{method:'GET',credentials:'same-origin',cache:'no-store',headers:{'Accept':'application/json','X-Requested-With':'XMLHttpRequest'}});
      let result=null;try{result=await response.json();}catch{}
      if(!response.ok||!result||result.success!==true||!result.data?.token)throw new Error(result?.message||'Impossibile aggiornare il token di sicurezza.');
      applyToken(form,result.data.token);return result.data.token;
    }
    async function send(form){
      const response=await fetch(form.action,{method:'POST',body:new FormData(form),credentials:'same-origin',cache:'no-store',headers:{'X-Requested-With':'XMLHttpRequest','Accept':'application/json'}});
      let result=null;try{result=await response.json();}catch{}
      return {response,result};
    }
    window.DeCaroFormsBuilderSubmit=async function(event,form){
      event?.preventDefault();event?.stopPropagation();
      if(!form||form.dataset.dfSaving==='1')return false;
      form.dataset.dfSaving='1';
      try{
        if(typeof window.dfBuilderSync==='function')window.dfBuilderSync();
        if(typeof window.dfBuilderSaveDraft==='function')window.dfBuilderSaveDraft();
        const buttons=[...document.querySelectorAll('.df-save-top'),...form.querySelectorAll('button[type="submit"]')];buttons.forEach(b=>b.disabled=true);
        notice('Verifica della sessione e salvataggio del modulo…','info');
        try{await currentToken(form);}catch(err){notice((err?.message||'Sessione non disponibile.')+' La bozza è stata conservata.','error',true);return false;}
        let {response,result}=await send(form);
        if(result?.data?.code==='invalid_token'){
          if(result.data.token)applyToken(form,result.data.token);else await currentToken(form);
          ({response,result}=await send(form));
        }
        if(!response.ok||!result||result.success!==true){
          const message=result?.message||(response.status===403?'La sessione non è più valida. La bozza è stata conservata.':'Il modulo non è stato salvato. Riprova.');
          notice(message,'error',response.status===403||/sessione|token/i.test(message));return false;
        }
        if(typeof window.dfBuilderClearDraft==='function')window.dfBuilderClearDraft();
        notice(result.message||'Modulo salvato.','success');
        window.dfAllowDraftReload=true;
        const redirect=result.data?.redirect||'index.php?option=com_decaroforms&view=forms';
        setTimeout(()=>location.assign(redirect),180);
      }catch(err){console.error('Forms robust save error',err);notice('Impossibile completare il salvataggio. La bozza è stata conservata.','error',false);}
      finally{
        form.dataset.dfSaving='0';
        const locked=document.querySelector('.df-builder')?.classList.contains('is-locked');
        [...document.querySelectorAll('.df-save-top'),...form.querySelectorAll('button[type="submit"]')].forEach(b=>b.disabled=!!locked);
      }
      return false;
    };
  })();
  </script>
  <form method="post" action="<?php echo $this->saveUrl; ?>" id="df-builder-form" onsubmit="window.DeCaroFormsBuilderSubmit(event,this); return false;">'''
t=rep(t,form_old,form_new,'robust standalone submit')

# Remove the old late-bound submit listener to avoid duplicate requests.
pattern=r"document\.getElementById\('df-builder-form'\)\.addEventListener\('submit',async e=>\{.*?\}\);\n\nconst builderRoot="
t=sub(t,pattern,"const builderRoot=",'remove old submit listener')

# Export the minimal state helpers used by the standalone save guard.
anchor_sync="""function clearSaveNotice(){const box=document.getElementById('df-save-notice');if(box)box.hidden=true;}"""
exports="""
window.dfSetSaveNotice=setSaveNotice;
window.dfBuilderSaveDraft=saveDraftNow;
window.dfBuilderClearDraft=clearDraft;
window.dfBuilderSync=sync;
"""
t=rep(t,anchor_sync,anchor_sync+exports,'save helper exports')

builder.write_text(t)
