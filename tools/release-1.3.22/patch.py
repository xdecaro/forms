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
h=helper.read_text(); h=rep(h,"public const VERSION = '1.3.21';","public const VERSION = '1.3.22';",'helper version'); helper.write_text(h)
for m in (component_manifest,plugin_manifest):
    s=m.read_text(); s=rep(s,'<version>1.3.21</version>','<version>1.3.22</version>',str(m)); m.write_text(s)

# Controller: add a dedicated session-bound Builder nonce as a secure CSRF fallback.
c=controller.read_text()
old_token_method="""    public function token(): void
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
new_token_method="""    public function token(): void
    {
        $app = Factory::getApplication();
        $user = $app->getIdentity();

        if (!$user || $user->guest || !$user->authorise('core.manage', 'com_decaroforms')) {
            echo new JsonResponse(null, 'Sessione amministratore non disponibile.', true);
            $app->close();
            return;
        }

        $session = $app->getSession();
        $builderToken = (string) $session->get('com_decaroforms.builder.csrf', '');
        if ($builderToken === '') {
            $builderToken = bin2hex(random_bytes(32));
            $session->set('com_decaroforms.builder.csrf', $builderToken);
        }

        $app->setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0', true);
        echo new JsonResponse(['token' => Session::getFormToken(), 'builder_token' => $builderToken]);
        $app->close();
    }
"""
c=rep(c,old_token_method,new_token_method,'token endpoint builder nonce')

old_check="""        if (!Session::checkToken('post')) {
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
new_check="""        $session = $app->getSession();
        $postedBuilderToken = trim((string) $input->post->getString('df_builder_token', ''));
        $sessionBuilderToken = (string) $session->get('com_decaroforms.builder.csrf', '');
        $builderTokenValid = $postedBuilderToken !== '' && $sessionBuilderToken !== '' && hash_equals($sessionBuilderToken, $postedBuilderToken);
        $joomlaTokenValid = Session::checkToken('post');

        if (!$joomlaTokenValid && !$builderTokenValid) {
            $freshBuilderToken = bin2hex(random_bytes(32));
            $session->set('com_decaroforms.builder.csrf', $freshBuilderToken);
            $message = 'La sessione di sicurezza è cambiata. La bozza è stata conservata.';
            if ($isAjax) {
                echo new JsonResponse(['code' => 'invalid_token', 'token' => Session::getFormToken(), 'builder_token' => $freshBuilderToken], $message, true);
                $app->close();
                return;
            }
            $app->enqueueMessage($message . ' Ricarica il Builder e riprova.', 'warning');
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=builder&id=' . $id, false));
            return;
        }"""
c=rep(c,old_check,new_check,'dual csrf validation')
controller.write_text(c)

# Builder: create/store the dedicated nonce on page render.
t=builder.read_text()
form_anchor='''  <script>\n  (()=>{'''
prelude='''  <?php\n  $dfSession = \\Joomla\\CMS\\Factory::getApplication()->getSession();\n  $dfBuilderCsrf = (string) $dfSession->get('com_decaroforms.builder.csrf', '');\n  if ($dfBuilderCsrf === '') {\n      $dfBuilderCsrf = bin2hex(random_bytes(32));\n      $dfSession->set('com_decaroforms.builder.csrf', $dfBuilderCsrf);\n  }\n  ?>\n'''
t=rep(t,form_anchor,prelude+form_anchor,'builder nonce prelude')

# Add helper to update the dedicated nonce and refresh both tokens from endpoint.
old_apply="""    function applyToken(form,token){
      if(!token)return false;
      const wrap=document.getElementById('df-csrf-token-wrap');
      if(!wrap)return false;
      wrap.replaceChildren();
      const input=document.createElement('input');input.type='hidden';input.name=token;input.value='1';wrap.appendChild(input);
      return true;
    }
"""
new_apply="""    function applyToken(form,token){
      if(!token)return false;
      const wrap=document.getElementById('df-csrf-token-wrap');
      if(!wrap)return false;
      wrap.replaceChildren();
      const input=document.createElement('input');input.type='hidden';input.name=token;input.value='1';wrap.appendChild(input);
      return true;
    }
    function applyBuilderToken(form,token){
      if(!token)return false;
      let input=form.querySelector('input[name=\"df_builder_token\"]');
      if(!input){input=document.createElement('input');input.type='hidden';input.name='df_builder_token';form.appendChild(input);}
      input.value=token;return true;
    }
"""
t=rep(t,old_apply,new_apply,'builder token helper')

old_current="""      if(!response.ok||!result||result.success!==true||!result.data?.token)throw new Error(result?.message||'Impossibile aggiornare il token di sicurezza.');
      applyToken(form,result.data.token);return result.data.token;
"""
new_current="""      if(!response.ok||!result||result.success!==true||!result.data?.token||!result.data?.builder_token)throw new Error(result?.message||'Impossibile aggiornare il token di sicurezza.');
      applyToken(form,result.data.token);applyBuilderToken(form,result.data.builder_token);return result.data;
"""
t=rep(t,old_current,new_current,'current token dual update')

old_retry="""        if(result?.data?.code==='invalid_token'){
          if(result.data.token)applyToken(form,result.data.token);else await currentToken(form);
          ({response,result}=await send(form));
        }
"""
new_retry="""        if(result?.data?.code==='invalid_token'){
          if(result.data.token)applyToken(form,result.data.token);
          if(result.data.builder_token)applyBuilderToken(form,result.data.builder_token);
          if(!result.data.token||!result.data.builder_token)await currentToken(form);
          ({response,result}=await send(form));
        }
"""
t=rep(t,old_retry,new_retry,'invalid token retry dual update')

# Always submit the page-rendered dedicated nonce too.
old_hidden='''    <span id="df-csrf-token-wrap"><?php echo HTMLHelper::_('form.token'); ?></span>'''
new_hidden='''    <input type="hidden" name="df_builder_token" value="<?php echo htmlspecialchars($dfBuilderCsrf, ENT_QUOTES, 'UTF-8'); ?>">\n    <span id="df-csrf-token-wrap"><?php echo HTMLHelper::_('form.token'); ?></span>'''
t=rep(t,old_hidden,new_hidden,'builder nonce hidden input')

builder.write_text(t)
