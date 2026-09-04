<?php

namespace DeCaro\Plugin\System\Forms\Extension;

defined('_JEXEC') or die;

use Joomla\CMS\Component\ComponentHelper;
use Joomla\CMS\Event\Application\AfterRenderEvent;
use Joomla\CMS\Event\Application\AfterRouteEvent;
use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\Mail\MailerFactoryInterface;
use Joomla\CMS\Log\Log;
use Joomla\CMS\Plugin\CMSPlugin;
use Joomla\CMS\Session\Session;
use Joomla\Database\DatabaseAwareTrait;
use Joomla\Database\DatabaseInterface;
use Joomla\Event\SubscriberInterface;
use RuntimeException;
use Throwable;

final class FormsPlugin extends CMSPlugin implements SubscriberInterface
{
    use DatabaseAwareTrait;
    protected $autoloadLanguage = true;
    private bool $formsLanguagesLoaded = false;
    private const MAX_FILE_BYTES = 5242880;

    private function ensureLanguages(): void
    {
        if ($this->formsLanguagesLoaded) { return; }
        $this->loadLanguage();
        $language = $this->getApplication()->getLanguage();
        $language->load('com_decaroforms', JPATH_ADMINISTRATOR . '/components/com_decaroforms', null, true);
        $this->formsLanguagesLoaded = true;
    }

    private function componentIniValues(string $key): array
    {
        static $cache = [];
        if (isset($cache[$key])) { return $cache[$key]; }
        $values = [];
        foreach (['en-GB','it-IT','fr-FR'] as $tag) {
            $file = JPATH_ADMINISTRATOR . '/components/com_decaroforms/language/' . $tag . '/com_decaroforms.ini';
            if (!is_file($file)) { continue; }
            $ini = @parse_ini_file($file, false, INI_SCANNER_RAW);
            if (is_array($ini) && isset($ini[$key])) { $values[] = trim((string)$ini[$key], "\"'"); }
        }
        return $cache[$key] = array_values(array_unique($values));
    }

    private function canonicalFieldKey(string $fieldKey): string
    {
        $aliases = [
            'prenom'=>'first_name','nom'=>'last_name','date_naissance'=>'birth_date','gsm'=>'phone',
            'adresse'=>'address','numero'=>'street_number','boite'=>'box','code_postal'=>'postcode',
            'localite'=>'city','nationalite'=>'nationality','sexe'=>'gender'
        ];
        $fieldKey = strtolower(trim($fieldKey));
        if (isset($aliases[$fieldKey])) { return $aliases[$fieldKey]; }
        $base = preg_replace('/_\d+$/', '', $fieldKey) ?: $fieldKey;
        return $aliases[$base] ?? $base;
    }

    private function fieldLanguageKey(string $fieldKey): ?string
    {
        $map = [
            'first_name'=>'COM_DECAROFORMS_FIELD_FIRST_NAME','last_name'=>'COM_DECAROFORMS_FIELD_LAST_NAME','full_name'=>'COM_DECAROFORMS_FIELD_FULL_NAME','birth_date'=>'COM_DECAROFORMS_FIELD_BIRTH_DATE','gender'=>'COM_DECAROFORMS_FIELD_GENDER','nationality'=>'COM_DECAROFORMS_FIELD_NATIONALITY','email'=>'COM_DECAROFORMS_FIELD_EMAIL','phone'=>'COM_DECAROFORMS_FIELD_PHONE','address'=>'COM_DECAROFORMS_FIELD_ADDRESS','street_number'=>'COM_DECAROFORMS_FIELD_STREET_NUMBER','box'=>'COM_DECAROFORMS_FIELD_BOX','postcode'=>'COM_DECAROFORMS_FIELD_POSTCODE','city'=>'COM_DECAROFORMS_FIELD_CITY','country'=>'COM_DECAROFORMS_FIELD_COUNTRY','organisation'=>'COM_DECAROFORMS_FIELD_ORGANISATION','club'=>'COM_DECAROFORMS_FIELD_CLUB','role'=>'COM_DECAROFORMS_FIELD_ROLE','member_number'=>'COM_DECAROFORMS_FIELD_MEMBER_NUMBER','sport'=>'COM_DECAROFORMS_FIELD_SPORT','team_name'=>'COM_DECAROFORMS_FIELD_TEAM_NAME','level'=>'COM_DECAROFORMS_FIELD_LEVEL','event_date'=>'COM_DECAROFORMS_FIELD_EVENT_DATE','arrival_date'=>'COM_DECAROFORMS_FIELD_ARRIVAL_DATE','departure_date'=>'COM_DECAROFORMS_FIELD_DEPARTURE_DATE','participants'=>'COM_DECAROFORMS_FIELD_PARTICIPANTS','subject'=>'COM_DECAROFORMS_FIELD_SUBJECT','message'=>'COM_DECAROFORMS_FIELD_MESSAGE','notes'=>'COM_DECAROFORMS_FIELD_NOTES','motivation'=>'COM_DECAROFORMS_FIELD_MOTIVATION','attachment'=>'COM_DECAROFORMS_FIELD_ATTACHMENT','identity_document'=>'COM_DECAROFORMS_FIELD_IDENTITY_DOCUMENT','photo'=>'COM_DECAROFORMS_FIELD_PHOTO','payment_proof'=>'COM_DECAROFORMS_FIELD_PAYMENT_PROOF','privacy_consent'=>'COM_DECAROFORMS_FIELD_PRIVACY','terms_consent'=>'COM_DECAROFORMS_FIELD_TERMS','newsletter_consent'=>'COM_DECAROFORMS_FIELD_NEWSLETTER','custom_text'=>'COM_DECAROFORMS_FIELD_CUSTOM_TEXT','custom_textarea'=>'COM_DECAROFORMS_FIELD_CUSTOM_TEXTAREA','custom_number'=>'COM_DECAROFORMS_FIELD_CUSTOM_NUMBER','custom_date'=>'COM_DECAROFORMS_FIELD_CUSTOM_DATE','custom_select'=>'COM_DECAROFORMS_FIELD_CUSTOM_SELECT','custom_radio'=>'COM_DECAROFORMS_FIELD_CUSTOM_RADIO','custom_checkboxes'=>'COM_DECAROFORMS_FIELD_CUSTOM_CHECKBOXES'
        ];
        return $map[$this->canonicalFieldKey($fieldKey)] ?? null;
    }

    private function activeComponentIniValue(string $key): string
    {
        static $cache = [];
        $tag = $this->getApplication()->getLanguage()->getTag();
        $cacheKey = $tag . ':' . $key;
        if (isset($cache[$cacheKey])) { return $cache[$cacheKey]; }
        foreach ([$tag, 'en-GB'] as $candidate) {
            $file = JPATH_ADMINISTRATOR . '/components/com_decaroforms/language/' . $candidate . '/com_decaroforms.ini';
            if (!is_file($file)) { continue; }
            $ini = @parse_ini_file($file, false, INI_SCANNER_RAW);
            if (is_array($ini) && isset($ini[$key])) {
                return $cache[$cacheKey] = trim((string)$ini[$key], "\"'");
            }
        }
        return $cache[$cacheKey] = Text::_($key);
    }

    private function localizedFieldLabel(array $field): string
    {
        $stored = (string)($field['label'] ?? '');
        $key = $this->fieldLanguageKey((string)($field['field_key'] ?? ''));
        if ($key === null) { return $stored; }
        return in_array($stored, $this->componentIniValues($key), true)
            ? $this->activeComponentIniValue($key)
            : $stored;
    }

    private function localizedOptionLabel(array $field, string $stored): string
    {
        $fieldKey = $this->canonicalFieldKey((string)($field['field_key'] ?? ''));
        $maps = [
            'gender' => ['COM_DECAROFORMS_OPT_FEMALE','COM_DECAROFORMS_OPT_MALE','COM_DECAROFORMS_OPT_OTHER','COM_DECAROFORMS_OPT_NOT_SAY'],
            'level' => ['COM_DECAROFORMS_OPT_BEGINNER','COM_DECAROFORMS_OPT_INTERMEDIATE','COM_DECAROFORMS_OPT_ADVANCED','COM_DECAROFORMS_OPT_OTHER'],
        ];
        foreach ($maps[$fieldKey] ?? [] as $key) {
            if (in_array($stored, $this->componentIniValues($key), true)) {
                return $this->activeComponentIniValue($key);
            }
        }
        return $stored;
    }

    private function localizedSuccessMessage(string $stored): string
    {
        $known = [
            'Thank you. Your submission has been received.',
            'Grazie. Il tuo invio è stato ricevuto.',
            'Merci. Votre formulaire a bien été envoyé.'
        ];
        return $stored === '' || in_array($stored, $known, true) ? Text::_('PLG_SYSTEM_DECAROFORMS_SUCCESS') : $stored;
    }

    public static function getSubscribedEvents(): array
    {
        return ['onAfterRoute'=>'onAfterRoute','onAfterRender'=>'onAfterRender'];
    }

    public function onAfterRoute(AfterRouteEvent $event): void
    {
        $this->ensureLanguages();
        $app=$event->getApplication();
        if(!$app->isClient('site') || strtoupper($app->getInput()->getMethod())!=='POST') return;
        if($app->getInput()->post->getInt('decaroforms_submit',0)!==1) return;
        $this->respond($this->handleSubmission());
    }

    public function onAfterRender(AfterRenderEvent $event): void
    {
        $this->ensureLanguages();
        $app=$event->getApplication();
        if(!$app->isClient('site')) return;
        $body=$app->getBody();
        if(strpos($body,'{forms}')!==false) $body=str_replace('{forms}',$this->renderFormsList(),$body);
        $body=preg_replace_callback('/\{form\s+(?:id=["\']?(\d+)["\']?|slug=["\']?([a-zA-Z0-9_-]+)["\']?)\s*\}/i',function(array $m){$id=!empty($m[1])?(int)$m[1]:0;$slug=!empty($m[2])?(string)$m[2]:'';return $this->renderForm($id,$slug);},$body)??$body;
        $app->setBody($body);
    }

    private function getDb(): DatabaseInterface { return $this->getDatabase(); }

    private function loadForm(int $id=0,string $slug=''): array
    {
        try{$db=$this->getDb();$q=$db->createQuery()->select('*')->from($db->quoteName('#__decaroforms_forms'));if($id>0){$q->where($db->quoteName('id').'=:id')->bind(':id',$id);}elseif($slug!==''){$q->where($db->quoteName('slug').'=:slug')->bind(':slug',$slug);}else{return [];} $db->setQuery($q);return $db->loadAssoc()?:[];}catch(Throwable){return [];}
    }

    private function loadFields(int $formId): array
    {
        try{$db=$this->getDb();$q=$db->createQuery()->select('*')->from($db->quoteName('#__decaroforms_fields'))->where($db->quoteName('form_id').'=:id')->bind(':id',$formId)->order('sort_order ASC,id ASC');$db->setQuery($q);$rows=$db->loadAssocList()?:[];foreach($rows as &$r){$r['options']=json_decode((string)($r['options_json']??'[]'),true)?:[];}unset($r);return $rows;}catch(Throwable){return [];}
    }

    private function renderFormsList(): string
    {
        try{$db=$this->getDb();$q=$db->createQuery()->select('*')->from($db->quoteName('#__decaroforms_forms'))->where($db->quoteName('enabled').' = 1')->order('title ASC');$db->setQuery($q);$forms=$db->loadAssocList()?:[];}catch(Throwable){$forms=[];}
        if(!$forms) return '<div class="df-public-empty">'.htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_NO_FORMS'),ENT_QUOTES,'UTF-8').'</div>';
        $html='<div class="df-public-list"><style>.df-public-list{display:flex;flex-direction:column;gap:12px}.df-public-list details{border:1px solid #dfe3e7;border-radius:8px;background:#fff;overflow:hidden}.df-public-list summary{cursor:pointer;padding:15px 17px;font-weight:800}.df-public-list .df-public-desc{padding:0 17px 13px;color:#667085}.df-public-list .df-public-form{padding:0 17px 17px}</style>';
        foreach($forms as $f){$html.='<details><summary>'.htmlspecialchars($f['title'],ENT_QUOTES,'UTF-8').'</summary>';if(trim((string)$f['description'])!=='')$html.='<div class="df-public-desc">'.nl2br(htmlspecialchars($f['description'],ENT_QUOTES,'UTF-8')).'</div>';$html.='<div class="df-public-form">'.$this->renderForm((int)$f['id']).'</div></details>';}
        return $html.'</div>';
    }

    private function renderForm(int $id=0,string $slug=''): string
    {
        $form=$this->loadForm($id,$slug);if(!$form) return '<div class="alert alert-warning">'.htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_NOT_FOUND'),ENT_QUOTES,'UTF-8').'</div>';
        if(!(bool)$form['enabled']) return $this->renderClosed($form);
        $fields=$this->loadFields((int)$form['id']);
        $accent=(string)ComponentHelper::getParams('com_decaroforms')->get('accent_color','#e60046');if(!preg_match('/^#[0-9a-fA-F]{6}$/',$accent))$accent='#e60046';
        $uid='df-form-'.(int)$form['id'].'-'.substr(hash('crc32b',microtime(true).random_int(1,999999)),0,6);
        $action=htmlspecialchars((string)($_SERVER['REQUEST_URI']??''),ENT_QUOTES,'UTF-8');
        $html='<div id="'.$uid.'" class="df-public-form-wrap" style="--df-accent:'.htmlspecialchars($accent,ENT_QUOTES,'UTF-8').'">';
        $html.='<style>#'.$uid.'{width:100%;font-family:inherit}#'.$uid.' *{box-sizing:border-box}#'.$uid.' .df-box{padding:22px;border:1px solid #dfe3e7;border-radius:8px;background:#fff}#'.$uid.' h3{margin:0 0 16px;font-size:25px}#'.$uid.' .df-desc{margin:-7px 0 18px;color:#667085}#'.$uid.' .df-field{margin-bottom:15px}#'.$uid.' label{display:block;margin-bottom:6px;font-weight:750}#'.$uid.' input[type=text],#'.$uid.' input[type=email],#'.$uid.' input[type=tel],#'.$uid.' input[type=number],#'.$uid.' input[type=date],#'.$uid.' input[type=time],#'.$uid.' select,#'.$uid.' textarea{width:100%;min-height:44px;border:1px solid #ccd3db;border-radius:6px;padding:9px 11px;background:#fff;color:#20262d;font:inherit}#'.$uid.' textarea{min-height:120px;resize:vertical}#'.$uid.' .df-help{margin-top:4px;color:#707a84;font-size:12px}#'.$uid.' .df-options{display:flex;flex-direction:column;gap:7px}#'.$uid.' .df-option{display:flex;align-items:flex-start;gap:8px}#'.$uid.' .df-option input{margin-top:4px}#'.$uid.' button{min-height:44px;padding:0 18px;border:0;border-radius:6px;background:var(--df-accent);color:#fff;font-weight:800;cursor:pointer}#'.$uid.' .df-msg{display:none;margin:0 0 14px;padding:11px 13px;border-radius:6px;background:#eef7f1;color:#176b3a}#'.$uid.' .df-msg.error{background:#fdebec;color:#9f2430}@media(max-width:640px){#'.$uid.' .df-box{padding:17px}}</style><div class="df-box">';
        if((bool)$form['show_heading']){$html.='<h3>'.htmlspecialchars($form['title'],ENT_QUOTES,'UTF-8').'</h3>';if(trim((string)$form['description'])!=='')$html.='<div class="df-desc">'.nl2br(htmlspecialchars($form['description'],ENT_QUOTES,'UTF-8')).'</div>';}
        $html.='<div class="df-msg" aria-live="polite"></div><form method="post" enctype="multipart/form-data" action="'.$action.'"><input type="hidden" name="decaroforms_submit" value="1"><input type="hidden" name="decaroforms_form_id" value="'.(int)$form['id'].'"><input type="hidden" name="decaroforms_started" value="'.time().'"><div style="position:absolute;left:-10000px" aria-hidden="true"><label>Website<input type="text" name="decaroforms_website" tabindex="-1" autocomplete="off"></label></div>';
        foreach($fields as $field)$html.=$this->renderField($field);
        $html.='<input type="hidden" name="'.Session::getFormToken().'" value="1"><button type="submit">'.htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_SEND'),ENT_QUOTES,'UTF-8').'</button></form></div></div>';
        $success=json_encode($this->localizedSuccessMessage((string)($form['success_message']??'')),JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
        $html.='<script>(()=>{const r=document.getElementById('.json_encode($uid).'),f=r?.querySelector("form"),m=r?.querySelector(".df-msg");if(!f||!m)return;f.addEventListener("submit",async e=>{e.preventDefault();m.style.display="none";const b=f.querySelector("button[type=submit]");b.disabled=true;try{const x=await fetch(f.action,{method:"POST",body:new FormData(f),credentials:"same-origin",headers:{"X-Requested-With":"XMLHttpRequest"}});const j=await x.json();m.classList.toggle("error",!j.success);m.textContent=j.message||('.$success.');m.style.display="block";if(j.success)f.reset();}catch(_){m.classList.add("error");m.textContent="'.htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_ERROR'),ENT_QUOTES,'UTF-8').'";m.style.display="block";}finally{b.disabled=false;}})})();</script>';
        return $html;
    }

    private function renderField(array $f): string
    {
        $key=(string)$f['field_key'];$name='df_fields['.$key.']';$id='df_'.preg_replace('/[^a-zA-Z0-9_]/','_',$key).'_'.(int)$f['id'];$label=htmlspecialchars($this->localizedFieldLabel($f),ENT_QUOTES,'UTF-8');$req=(bool)$f['required'];$required=$req?' required':'';$star=$req?' *':'';$placeholder=htmlspecialchars((string)($f['placeholder']??''),ENT_QUOTES,'UTF-8');$value=htmlspecialchars((string)($f['default_value']??''),ENT_QUOTES,'UTF-8');$type=(string)$f['field_type'];$html='<div class="df-field">';
        if($type==='consent'){$html.='<label class="df-option"><input type="checkbox" id="'.$id.'" name="'.$name.'" value="1"'.$required.'><span>'.$label.$star.'</span></label>';}
        elseif(in_array($type,['radio','checkboxes'],true)){$html.='<label>'.$label.$star.'</label><div class="df-options">';foreach(($f['options']??[]) as $opt){$rawSafe=htmlspecialchars((string)$opt,ENT_QUOTES,'UTF-8');$displaySafe=htmlspecialchars($this->localizedOptionLabel($f,(string)$opt),ENT_QUOTES,'UTF-8');$nm=$name.($type==='checkboxes'?'[]':'');$inputType=$type==='radio'?'radio':'checkbox';$html.='<label class="df-option"><input type="'.$inputType.'" name="'.$nm.'" value="'.$rawSafe.'"'.$required.'><span>'.$displaySafe.'</span></label>';}$html.='</div>';}
        elseif($type==='select'){$html.='<label for="'.$id.'">'.$label.$star.'</label><select id="'.$id.'" name="'.$name.'"'.$required.'><option value="">—</option>';foreach(($f['options']??[]) as $opt){$rawSafe=htmlspecialchars((string)$opt,ENT_QUOTES,'UTF-8');$displaySafe=htmlspecialchars($this->localizedOptionLabel($f,(string)$opt),ENT_QUOTES,'UTF-8');$html.='<option value="'.$rawSafe.'">'.$displaySafe.'</option>';}$html.='</select>';}
        elseif($type==='textarea'){$html.='<label for="'.$id.'">'.$label.$star.'</label><textarea id="'.$id.'" name="'.$name.'" placeholder="'.$placeholder.'"'.$required.'>'.$value.'</textarea>';}
        elseif($type==='file'){$html.='<label for="'.$id.'">'.$label.$star.'</label><input id="'.$id.'" type="file" name="df_file_'.$key.'"'.$required.' accept=".pdf,.jpg,.jpeg,.png,.webp,.doc,.docx">';}
        else{$inputType=in_array($type,['email','tel','number','date','time'],true)?$type:'text';$html.='<label for="'.$id.'">'.$label.$star.'</label><input id="'.$id.'" type="'.$inputType.'" name="'.$name.'" value="'.$value.'" placeholder="'.$placeholder.'"'.$required.'>';}
        if(trim((string)($f['help_text']??''))!=='')$html.='<div class="df-help">'.htmlspecialchars($f['help_text'],ENT_QUOTES,'UTF-8').'</div>';return $html.'</div>';
    }

    private function renderClosed(array $form): string
    {
        $reason=(string)($form['closed_reason']??'closed');$custom=trim((string)($form['closed_message']??''));$messages=['closed'=>Text::_('PLG_SYSTEM_DECAROFORMS_CLOSED'),'limit'=>Text::_('PLG_SYSTEM_DECAROFORMS_LIMIT'),'deadline'=>Text::_('PLG_SYSTEM_DECAROFORMS_DEADLINE'),'temporary'=>Text::_('PLG_SYSTEM_DECAROFORMS_TEMPORARY'),'custom'=>$custom?:Text::_('PLG_SYSTEM_DECAROFORMS_CLOSED')];$msg=$custom!==''?$custom:($messages[$reason]??$messages['closed']);return '<div style="padding:18px 20px;border:1px solid #dfe3e7;border-left:5px solid #e60046;border-radius:7px;background:#fff"><strong>'.htmlspecialchars($form['title'],ENT_QUOTES,'UTF-8').'</strong><div style="margin-top:5px">'.nl2br(htmlspecialchars($msg,ENT_QUOTES,'UTF-8')).'</div></div>';
    }

    private function handleSubmission(): array
    {
        $app=$this->getApplication();if(!Session::checkToken('post'))return ['success'=>false,'message'=>Text::_('JINVALID_TOKEN')];
        $id=$app->getInput()->post->getInt('decaroforms_form_id',0);$form=$this->loadForm($id);if(!$form)return ['success'=>false,'message'=>Text::_('PLG_SYSTEM_DECAROFORMS_NOT_FOUND')];if(!(bool)$form['enabled'])return ['success'=>false,'message'=>strip_tags($this->renderClosed($form))];
        if(trim($app->getInput()->post->getString('decaroforms_website',''))!=='')return ['success'=>false,'message'=>Text::_('PLG_SYSTEM_DECAROFORMS_ERROR')];$started=$app->getInput()->post->getInt('decaroforms_started',0);if($started<=0||time()-$started<2||time()-$started>86400)return ['success'=>false,'message'=>Text::_('PLG_SYSTEM_DECAROFORMS_ERROR')];
        $session=$app->getSession();$last=(int)$session->get('decaroforms.last.'.$id,0);if($last>0&&time()-$last<8)return ['success'=>false,'message'=>Text::_('PLG_SYSTEM_DECAROFORMS_TOO_FAST')];
        $fields=$this->loadFields($id);$posted=$app->getInput()->post->get('df_fields',[],'array');$payload=[];$email='';$files=[];
        foreach($fields as $f){$key=(string)$f['field_key'];$type=(string)$f['field_type'];$required=(bool)$f['required'];if($type==='file'){$file=$app->getInput()->files->get('df_file_'.$key,null,'raw');if(is_array($file)&&!empty($file['tmp_name'])&&is_uploaded_file($file['tmp_name'])){$files[]=['field'=>$f,'file'=>$file];$displayLabel=$this->localizedFieldLabel($f);$payload[$displayLabel]=(string)($file['name']??'file');}elseif($required)return ['success'=>false,'message'=>Text::sprintf('PLG_SYSTEM_DECAROFORMS_REQUIRED',$this->localizedFieldLabel($f))];continue;}
            $raw=$posted[$key]??($type==='consent'?'':'');if(is_array($raw)){$value=array_values(array_filter(array_map(static fn($v)=>trim(strip_tags((string)$v)),$raw),static fn($v)=>$v!==''));}else{$value=trim(strip_tags((string)$raw));}
            if($required && (($type==='consent'&&$value!=='1')||(is_array($value)?count($value)===0:$value==='')))return ['success'=>false,'message'=>Text::sprintf('PLG_SYSTEM_DECAROFORMS_REQUIRED',$this->localizedFieldLabel($f))];
            if($type==='email'&&$value!==''){if(!filter_var($value,FILTER_VALIDATE_EMAIL))return ['success'=>false,'message'=>Text::_('PLG_SYSTEM_DECAROFORMS_INVALID_EMAIL')];if($email==='')$email=$value;}
            if($type==='number'&&$value!==''&&!is_numeric($value))return ['success'=>false,'message'=>Text::sprintf('PLG_SYSTEM_DECAROFORMS_INVALID_FIELD',$this->localizedFieldLabel($f))];
            if(in_array($type,['select','radio'],true)&&$value!==''&&!in_array($value,$f['options']??[],true))return ['success'=>false,'message'=>Text::sprintf('PLG_SYSTEM_DECAROFORMS_INVALID_FIELD',$this->localizedFieldLabel($f))];
            if($type==='checkboxes'&&is_array($value)){foreach($value as $v)if(!in_array($v,$f['options']??[],true))return ['success'=>false,'message'=>Text::sprintf('PLG_SYSTEM_DECAROFORMS_INVALID_FIELD',$this->localizedFieldLabel($f))];}
            $payload[$this->localizedFieldLabel($f)]=$value;
        }
        foreach($files as $pack){$check=$this->validateFile($pack['file']);if($check!==true)return ['success'=>false,'message'=>$check];}
        $statusRows=json_decode((string)($form['statuses_json']??''),true);$defaultStatus='new';if(is_array($statusRows)&&!empty($statusRows[0]['key'])){$candidate=preg_replace('/[^a-z0-9_-]+/','_',strtolower((string)$statusRows[0]['key']));if($candidate!=='')$defaultStatus=substr($candidate,0,30);}
        $reference='FRM-'.date('Ymd').'-'.strtoupper(substr(bin2hex(random_bytes(5)),0,8));$now=Factory::getDate()->toSql();$row=(object)['form_id'=>$id,'reference'=>$reference,'email'=>$email,'status'=>$defaultStatus,'payload_json'=>json_encode($payload,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES),'internal_note'=>'','created_at'=>$now,'updated_at'=>null];
        try{$db=$this->getDb();$db->insertObject('#__decaroforms_submissions',$row,'id');$submissionId=(int)$row->id;foreach($files as $pack)$this->saveFile($submissionId,(string)$pack['field']['field_key'],$pack['file'],$now);$session->set('decaroforms.last.'.$id,time());$this->sendEmails($form,$reference,$payload,$email);return ['success'=>true,'message'=>$this->localizedSuccessMessage((string)($form['success_message']??'')),'reference'=>$reference];}catch(Throwable $e){Log::add('Forms submission error: '.$e->getMessage(), Log::ERROR, 'com_decaroforms');return ['success'=>false,'message'=>Text::_('PLG_SYSTEM_DECAROFORMS_ERROR')];}
    }

    private function validateFile(array $file): true|string
    {
        $size=(int)($file['size']??0);if($size<=0||$size>self::MAX_FILE_BYTES)return Text::_('PLG_SYSTEM_DECAROFORMS_FILE_SIZE');$tmp=(string)($file['tmp_name']??'');$finfo=new \finfo(FILEINFO_MIME_TYPE);$mime=(string)$finfo->file($tmp);$allowed=['application/pdf','image/jpeg','image/png','image/webp','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document'];return in_array($mime,$allowed,true)?true:Text::_('PLG_SYSTEM_DECAROFORMS_FILE_TYPE');
    }

    private function saveFile(int $submissionId,string $fieldKey,array $file,string $now): void
    {
        $tmp=(string)$file['tmp_name'];$data=file_get_contents($tmp);if($data===false)throw new RuntimeException(Text::_('PLG_SYSTEM_DECAROFORMS_UPLOAD_READ_ERROR'));$finfo=new \finfo(FILEINFO_MIME_TYPE);$row=(object)['submission_id'=>$submissionId,'field_key'=>$fieldKey,'file_name'=>substr(basename((string)$file['name']),0,190),'mime_type'=>(string)$finfo->file($tmp),'file_size'=>(int)$file['size'],'sha256'=>hash('sha256',$data),'data_blob'=>$data,'created_at'=>$now];$this->getDb()->insertObject('#__decaroforms_files',$row);
    }

    private function sendEmails(array $form,string $reference,array $payload,string $userEmail): void
    {
        try{$params=ComponentHelper::getParams('com_decaroforms');$admin=trim((string)$form['admin_email']);if($admin==='')$admin=trim((string)$params->get('default_admin_email',''));if($admin==='')$admin=trim((string)Factory::getConfig()->get('mailfrom',''));$siteName=(string)Factory::getConfig()->get('sitename','Website');$summary=$this->emailSummary($payload);$mf=Factory::getContainer()->get(MailerFactoryInterface::class);
            if($admin!==''&&filter_var($admin,FILTER_VALIDATE_EMAIL)){$subject=(string)($form['email_subject_admin']?:Text::_('PLG_SYSTEM_DECAROFORMS_EMAIL_ADMIN_SUBJECT'));$subject=strtr($subject,['{form_title}'=>$form['title'],'{reference}'=>$reference]);$html=$this->emailTemplate((string)$form['email_template_admin'],$form['title'],$reference,$summary);$m=$mf->createMailer();$m->addRecipient($admin);if($userEmail!=='')$m->addReplyTo($userEmail);$m->setSubject($subject);$m->isHtml(true);$m->setBody($html);$m->send();}
            if((bool)$form['user_confirmation']&&$userEmail!==''&&filter_var($userEmail,FILTER_VALIDATE_EMAIL)){$subject=(string)($form['email_subject_user']?:Text::_('PLG_SYSTEM_DECAROFORMS_EMAIL_USER_SUBJECT'));$subject=strtr($subject,['{form_title}'=>$form['title'],'{reference}'=>$reference]);$html=$this->emailTemplate((string)$form['email_template_user'],$form['title'],$reference,$summary,true);$m=$mf->createMailer();$m->addRecipient($userEmail);$m->setSubject($subject);$m->isHtml(true);$m->setBody($html);$m->send();}
        }catch(Throwable $e){try{Log::add('Forms email error: '.$e->getMessage(), Log::WARNING, 'com_decaroforms');}catch(Throwable){}}
    }

    private function emailSummary(array $payload): string
    {
        $rows='';foreach($payload as $k=>$v){$value=is_array($v)?implode(', ',$v):(string)$v;$rows.='<tr><td style="padding:7px 9px;border-bottom:1px solid #e8ebef;font-weight:700;vertical-align:top">'.htmlspecialchars((string)$k,ENT_QUOTES,'UTF-8').'</td><td style="padding:7px 9px;border-bottom:1px solid #e8ebef">'.nl2br(htmlspecialchars($value,ENT_QUOTES,'UTF-8')).'</td></tr>';}return '<table role="presentation" style="width:100%;border-collapse:collapse">'.$rows.'</table>';
    }

    private function emailTemplate(string $template,string $title,string $reference,string $summary,bool $forUser=false): string
    {
        $accent=(string)ComponentHelper::getParams('com_decaroforms')->get('accent_color','#e60046');if(!preg_match('/^#[0-9a-fA-F]{6}$/',$accent))$accent='#e60046';$brand=trim((string)ComponentHelper::getParams('com_decaroforms')->get('brand_name',''));if($brand==='')$brand=(string)Factory::getConfig()->get('sitename','Website');$safeBrand=htmlspecialchars($brand,ENT_QUOTES,'UTF-8');$safeTitle=htmlspecialchars($title,ENT_QUOTES,'UTF-8');$safeRef=htmlspecialchars($reference,ENT_QUOTES,'UTF-8');$intro=$forUser?'<p style="margin:0 0 15px">'.htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_EMAIL_USER_INTRO'),ENT_QUOTES,'UTF-8').'</p>':'';$content=$intro.'<h2 style="margin:0 0 6px">'.$safeTitle.'</h2><p style="margin:0 0 18px;color:#667085">'.htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_REFERENCE'),ENT_QUOTES,'UTF-8').': <strong>'.$safeRef.'</strong></p>'.$summary;
        return match($template){'minimal'=>'<div style="font-family:Arial,sans-serif;color:#20262d;max-width:680px;margin:auto">'.$content.'<p style="margin-top:22px;color:#8a929b;font-size:12px">'.$safeBrand.'</p></div>','institutional'=>'<div style="font-family:Arial,sans-serif;background:#f2f4f7;padding:22px"><div style="max-width:680px;margin:auto;background:#fff"><div style="background:#27364a;color:#fff;padding:15px 20px;font-weight:800">'.$safeBrand.'</div><div style="padding:22px">'.$content.'</div></div></div>','card'=>'<div style="font-family:Arial,sans-serif;background:#f4f5f7;padding:25px"><div style="max-width:650px;margin:auto;background:#fff;border-radius:10px;box-shadow:0 4px 18px rgba(0,0,0,.09);padding:24px">'.$content.'</div></div>','compact'=>'<div style="font-family:Arial,sans-serif;max-width:680px;margin:auto;border-left:5px solid '.$accent.';padding:16px 20px">'.$content.'</div>',default=>'<div style="font-family:Arial,sans-serif;background:#f4f5f7;padding:22px"><div style="max-width:680px;margin:auto;background:#fff"><div style="background:'.$accent.';color:#fff;padding:16px 20px;font-weight:800">'.$safeBrand.'</div><div style="padding:22px">'.$content.'</div></div></div>'};
    }

    private function respond(array $data): void
    {
        $app=$this->getApplication();header('Content-Type: application/json; charset=utf-8');echo json_encode($data,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);$app->close();
    }
}
