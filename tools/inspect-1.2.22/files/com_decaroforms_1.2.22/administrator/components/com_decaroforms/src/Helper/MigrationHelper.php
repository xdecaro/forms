<?php

namespace DeCaro\Component\Forms\Administrator\Helper;

defined('_JEXEC') or die;

use Joomla\CMS\Component\ComponentHelper;
use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\Database\DatabaseInterface;
use Throwable;

final class MigrationHelper
{
    private const SOURCE = 'com_lsfsaffiliations';

    public static function definitions(): array
    {
        return [
            'contact' => ['title'=>'Contact','slug'=>'lsfs-contact','table'=>'#__lsfs_contact_messages','email'=>['email'],'status'=>'application_status','note'=>'internal_note','title_param'=>'contact_form_title','title_default'=>'Contactez-nous','success_param'=>'contact_success_message','success_default'=>'Merci pour votre message. Votre demande a bien été envoyée.'],
            'affiliation' => ['title'=>'Affiliation forms','slug'=>'lsfs-affiliation','table'=>'#__lsfs_affiliations','email'=>['email'],'status'=>'statut_dossier','note'=>'note_interne','title_default'=>'Bulletin d’affiliation','success_param'=>'affiliation_success_message','success_default'=>'Votre bulletin d’affiliation a bien été enregistré.'],
            'beach' => ['title'=>'Beach Volley 2026','slug'=>'lsfs-beach-volley-2026','table'=>'#__lsfs_beachvolley_registrations','email'=>['captain_email'],'status'=>'application_status','note'=>'internal_note','title_default'=>'Beach Volley 2026','success_param'=>'beach_success_message','success_default'=>'Votre inscription a bien été enregistrée.','file'=>['field_key'=>'payment_proof','filename'=>'payment_filename','mime'=>'payment_mime','size'=>'payment_size','sha'=>'payment_sha256','blob'=>'payment_data_blob','base64'=>'payment_data_base64']],
            'festi' => ['title'=>'FestiHandisport 2026','slug'=>'lsfs-festihandisport-2026','table'=>'#__lsfs_festi_registrations','email'=>['visitor_email','institution_email'],'status'=>'application_status','note'=>'internal_note','title_default'=>'FestiHandisport 2026','success_param'=>'festi_success_message','success_default'=>'Votre inscription FestiHandisport a bien été enregistrée.','file'=>['field_key'=>'payment_proof','filename'=>'payment_filename','mime'=>'payment_mime','size'=>'payment_size','sha'=>'payment_sha256','blob'=>'payment_data_blob'],'participants'=>'#__lsfs_festi_participants'],
            'training' => ['title'=>'Sports Association Training','slug'=>'lsfs-sports-association-training','table'=>'#__lsfs_training_association_registrations','email'=>['email'],'status'=>'application_status','note'=>'internal_note','title_default'=>'Sports Association Training','success_param'=>'training_success_message','success_default'=>'Votre inscription à la formation a bien été enregistrée.','file'=>['field_key'=>'attachment','filename'=>'attachment_filename','mime'=>'attachment_mime','size'=>'attachment_size','sha'=>'attachment_sha256','blob'=>'attachment_data_blob']],
            'sandwich' => ['title'=>'Reservation Sandwiches','slug'=>'lsfs-reservation-sandwiches','table'=>'#__lsfs_sandwich_reservations','email'=>['email'],'status'=>'application_status','note'=>'internal_note','title_param'=>'sandwich_event_title','title_default'=>'Reservation Sandwiches','success_param'=>'sandwich_success_message','success_default'=>'Votre réservation de sandwich a bien été enregistrée.'],
            'reservation' => ['title'=>'Reservation — Sandwich + Fruit','slug'=>'lsfs-reservation-sandwich-fruit','table'=>'#__lsfs_simple_reservations','email'=>['email'],'status'=>'application_status','note'=>'internal_note','title_param'=>'reservation_form_title','title_default'=>'Reservation','success_param'=>'reservation_success_message','success_default'=>'Votre réservation a bien été enregistrée.','file'=>['field_key'=>'payment_proof','filename'=>'payment_filename','mime'=>'payment_mime','size'=>'payment_size','sha'=>'payment_sha256','blob'=>'payment_data_blob']],
            'hotel' => ['title'=>'Reservation Hotel','slug'=>'lsfs-reservation-hotel','table'=>'#__lsfs_hotel_reservations','email'=>['email'],'status'=>'application_status','note'=>'internal_note','title_param'=>'hotel_form_title','title_default'=>'Reservation Hotel','success_param'=>'hotel_success_message','success_default'=>'Votre réservation d’hôtel a bien été enregistrée.','file'=>['field_key'=>'payment_proof','filename'=>'payment_filename','mime'=>'payment_mime','size'=>'payment_size','sha'=>'payment_sha256','blob'=>'payment_data_blob']],
        ];
    }

    public static function inspect(DatabaseInterface $db): array
    {
        $ext = self::sourceExtension($db);
        $items=[]; $total=0; $migrated=0;
        foreach (self::definitions() as $key=>$def) {
            $exists=self::tableExists($db,$def['table']); $count=0;
            if ($exists) { $db->setQuery('SELECT COUNT(*) FROM '.$db->quoteName($db->replacePrefix($def['table']))); $count=(int)$db->loadResult(); }
            $done=self::migratedCount($db,$def['table']);
            $formId=self::mappedTarget($db,'@form:'.$key,0,'form');
            $items[]=['key'=>$key,'title'=>$def['title'],'table'=>$def['table'],'exists'=>$exists,'source_count'=>$count,'migrated_count'=>$done,'form_id'=>$formId];
            $total += $count; $migrated += min($done,$count);
        }
        return ['installed'=>$ext['installed'],'version'=>$ext['version'],'items'=>$items,'source_total'=>$total,'migrated_total'=>$migrated,'complete'=>$total>0 && $migrated >= $total];
    }

    public static function migrate(DatabaseInterface $db): array
    {
        if (!self::sourceExtension($db)['installed']) throw new \RuntimeException(Text::_('COM_DECAROFORMS_ERR_LSFS_NOT_DETECTED'));
        $params=ComponentHelper::getParams(self::SOURCE);
        $result=['forms_created'=>0,'submissions_imported'=>0,'files_imported'=>0,'skipped'=>0];
        $db->transactionStart();
        try {
            foreach (self::definitions() as $key=>$def) {
                if (!self::tableExists($db,$def['table'])) continue;
                $formId=self::ensureForm($db,$key,$def,$params,$result);
                self::importRows($db,$key,$def,$formId,$result);
            }
            $db->transactionCommit();
        } catch (Throwable $e) { $db->transactionRollback(); throw $e; }
        return $result;
    }

    private static function ensureForm(DatabaseInterface $db,string $key,array $def,$params,array &$result): int
    {
        $mapped=self::mappedTarget($db,'@form:'.$key,0,'form');
        if ($mapped>0 && self::targetExists($db,'#__decaroforms_forms',$mapped)) return $mapped;
        $slug=$def['slug']; $base=$slug; $n=2; while(self::slugExists($db,$slug)) $slug=$base.'-imported-'.$n++;
        $title=($def['title_param']??'')!=='' ? (string)$params->get($def['title_param'],$def['title_default']) : $def['title_default'];
        $now=Factory::getDate()->toSql();
        $form=(object)[
            'title'=>$title,'slug'=>$slug,'description'=>'Imported from LSFS Forms. Review this generic equivalent before replacing the legacy public form.',
            'enabled'=>(int)$params->get($key.'_enabled',1)?1:0,'show_heading'=>(int)$params->get($key.'_show_form_heading',1)?1:0,
            'success_message'=>(string)$params->get($def['success_param'],$def['success_default']),'closed_reason'=>(string)$params->get($key.'_closed_reason','closed'),'closed_message'=>(string)$params->get($key.'_closed_message',''),
            'admin_email'=>self::firstEmail((string)$params->get($key.'_email_admin_to','')),'user_confirmation'=>(int)$params->get($key.'_email_user_enabled',1)?1:0,
            'email_template_user'=>self::template((string)$params->get($key.'_email_user_template','standard')),'email_template_admin'=>self::template((string)$params->get($key.'_email_admin_template','standard')),
            'email_subject_user'=>(string)$params->get($key.'_email_user_subject',''),'email_subject_admin'=>(string)$params->get($key.'_email_admin_subject',''),'created_at'=>$now,'updated_at'=>$now,
        ];
        $db->insertObject('#__decaroforms_forms',$form,'id'); $formId=(int)$form->id;
        foreach (self::sourceFields($db,$def) as $i=>$field) {
            $row=(object)['form_id'=>$formId,'field_key'=>$field['key'],'field_type'=>$field['type'],'category'=>$field['category'],'label'=>$field['label'],'placeholder'=>'','help_text'=>'','default_value'=>'','options_json'=>'[]','required'=>$field['required'],'sort_order'=>$i];
            $db->insertObject('#__decaroforms_fields',$row);
        }
        self::logMigration($db,'@form:'.$key,0,'form',$formId,''); $result['forms_created']++; return $formId;
    }

    private static function sourceFields(DatabaseInterface $db,array $def): array
    {
        $table=$db->replacePrefix($def['table']); $columns=$db->getTableColumns($table,false); $out=[];
        $skip=['id','reference','submission_token',$def['status'],$def['note'],'created_at','updated_at'];
        if (!empty($def['file'])) $skip=array_merge($skip,array_filter([$def['file']['filename'],$def['file']['mime'],$def['file']['size'],$def['file']['sha'],$def['file']['blob'],$def['file']['base64']??null]));
        foreach (array_keys($columns) as $column) {
            if (in_array($column,$skip,true)) continue;
            $out[]=['key'=>self::fieldKey($column),'type'=>self::guessType($column),'category'=>self::guessCategory($column),'label'=>self::humanize($column),'required'=>0];
        }
        if (!empty($def['file'])) $out[]=['key'=>$def['file']['field_key'],'type'=>'file','category'=>'document','label'=>self::humanize($def['file']['field_key']),'required'=>0];
        return $out;
    }

    private static function importRows(DatabaseInterface $db,string $key,array $def,int $formId,array &$result): void
    {
        $table=$db->replacePrefix($def['table']); $db->setQuery('SELECT * FROM '.$db->quoteName($table).' ORDER BY '.$db->quoteName('id').' ASC'); $rows=$db->loadAssocList()?:[];
        foreach($rows as $row){
            $sourceId=(int)($row['id']??0); if($sourceId<=0) continue;
            $mapped=self::mappedTarget($db,$def['table'],$sourceId,'submission');
            if($mapped>0 && self::targetExists($db,'#__decaroforms_submissions',$mapped)){ $result['skipped']++; continue; }
            $legacyRef=trim((string)($row['reference']??'')); $reference=self::uniqueReference($db,$legacyRef!==''?$legacyRef:'LSFS-'.strtoupper($key).'-'.$sourceId,$sourceId);
            $payload=self::payload($db,$def,$row); $created=(string)($row['created_at']??Factory::getDate()->toSql());
            $submission=(object)['form_id'=>$formId,'reference'=>$reference,'email'=>self::rowEmail($row,$def['email']),'status'=>self::status((string)($row[$def['status']]??'new')),'payload_json'=>json_encode($payload,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES),'internal_note'=>(string)($row[$def['note']]??''),'created_at'=>$created,'updated_at'=>($row['updated_at']??null)?:null];
            $db->insertObject('#__decaroforms_submissions',$submission,'id'); $submissionId=(int)$submission->id;
            self::importFile($db,$def,$row,$submissionId,$created,$result); self::logMigration($db,$def['table'],$sourceId,'submission',$submissionId,$legacyRef); $result['submissions_imported']++;
        }
    }

    private static function payload(DatabaseInterface $db,array $def,array $row): array
    {
        $exclude=['id','submission_token',$def['status'],$def['note'],'created_at','updated_at','payment_data_blob','payment_data_base64','attachment_data_blob'];
        if (!empty($def['file'])) $exclude=array_merge($exclude,array_filter([$def['file']['filename'],$def['file']['mime'],$def['file']['size'],$def['file']['sha'],$def['file']['blob'],$def['file']['base64']??null]));
        $payload=[];
        foreach($row as $column=>$value){
            if(in_array($column,$exclude,true)) continue;
            if(str_ends_with($column,'_json')){ $d=json_decode((string)$value,true); if(json_last_error()===JSON_ERROR_NONE)$value=$d; }
            $payload[$column==='reference'?'Legacy reference':self::humanize($column)]=$value;
        }
        if(!empty($def['participants']) && self::tableExists($db,$def['participants'])){
            $rid=(int)($row['id']??0); $q=$db->createQuery()->select(['participant_order','name','age','hearing_status'])->from($db->quoteName($def['participants']))->where($db->quoteName('registration_id').'=:rid')->bind(':rid',$rid)->order('participant_order ASC,id ASC'); $db->setQuery($q); $parts=$db->loadAssocList()?:[];
            if($parts)$payload['Participants']=array_map(static fn($p)=>'#'.$p['participant_order'].' — '.$p['name'].' — age '.$p['age'].' — '.$p['hearing_status'],$parts);
        }
        $payload['Legacy source ID']=(int)($row['id']??0); $payload['Legacy status']=(string)($row[$def['status']]??''); $payload['Migration source']='LSFS Forms / '.$def['table']; return $payload;
    }

    private static function importFile(DatabaseInterface $db,array $def,array $row,int $submissionId,string $created,array &$result): void
    {
        if(empty($def['file'])) return; $f=$def['file']; $name=trim((string)($row[$f['filename']]??'')); if($name==='') return; $data=$row[$f['blob']]??null;
        if((!is_string($data)||$data==='')&&!empty($f['base64'])){ $raw=(string)($row[$f['base64']]??''); if($raw!==''){ $decoded=base64_decode($raw,true); if($decoded!==false)$data=$decoded; }}
        if(!is_string($data)||$data==='') return; $size=(int)($row[$f['size']]??strlen($data)); if($size<=0)$size=strlen($data); $sha=trim((string)($row[$f['sha']]??'')); if($sha==='')$sha=hash('sha256',$data);
        $file=(object)['submission_id'=>$submissionId,'field_key'=>$f['field_key'],'file_name'=>substr(basename($name),0,190),'mime_type'=>substr((string)($row[$f['mime']]??'application/octet-stream'),0,100),'file_size'=>$size,'sha256'=>$sha,'data_blob'=>$data,'created_at'=>$created]; $db->insertObject('#__decaroforms_files',$file); $result['files_imported']++;
    }

    private static function sourceExtension(DatabaseInterface $db): array
    {
        try{$q=$db->createQuery()->select('manifest_cache')->from($db->quoteName('#__extensions'))->where($db->quoteName('type').'='.$db->quote('component'))->where($db->quoteName('element').'='.$db->quote(self::SOURCE));$db->setQuery($q);$cache=$db->loadResult();if(!$cache)return ['installed'=>false,'version'=>''];$j=json_decode((string)$cache,true)?:[];return ['installed'=>true,'version'=>(string)($j['version']??'')];}catch(Throwable){return ['installed'=>false,'version'=>''];}
    }
    private static function tableExists(DatabaseInterface $db,string $table): bool { return in_array($db->replacePrefix($table),$db->getTableList(),true); }
    private static function migratedCount(DatabaseInterface $db,string $table): int { if(!self::tableExists($db,'#__decaroforms_migrations'))return 0;$sourceComponent=self::SOURCE;$q=$db->createQuery()->select('COUNT(*)')->from($db->quoteName('#__decaroforms_migrations'))->where($db->quoteName('source_component').'=:c')->bind(':c',$sourceComponent)->where($db->quoteName('source_table').'=:t')->bind(':t',$table)->where($db->quoteName('target_type').'='.$db->quote('submission'));$db->setQuery($q);return (int)$db->loadResult(); }
    private static function mappedTarget(DatabaseInterface $db,string $table,int $sourceId,string $type): int { if(!self::tableExists($db,'#__decaroforms_migrations'))return 0;$sourceComponent=self::SOURCE;$q=$db->createQuery()->select('target_id')->from($db->quoteName('#__decaroforms_migrations'))->where($db->quoteName('source_component').'=:c')->bind(':c',$sourceComponent)->where($db->quoteName('source_table').'=:t')->bind(':t',$table)->where($db->quoteName('source_id').'=:sid')->bind(':sid',$sourceId)->where($db->quoteName('target_type').'=:ty')->bind(':ty',$type);$db->setQuery($q);return (int)$db->loadResult(); }
    private static function logMigration(DatabaseInterface $db,string $table,int $sourceId,string $type,int $targetId,string $ref): void { $o=(object)['source_component'=>self::SOURCE,'source_table'=>$table,'source_id'=>$sourceId,'target_type'=>$type,'target_id'=>$targetId,'source_reference'=>$ref,'migrated_at'=>Factory::getDate()->toSql()];$db->insertObject('#__decaroforms_migrations',$o); }
    private static function targetExists(DatabaseInterface $db,string $table,int $id): bool { $q=$db->createQuery()->select('COUNT(*)')->from($db->quoteName($table))->where($db->quoteName('id').'=:id')->bind(':id',$id);$db->setQuery($q);return (int)$db->loadResult()>0; }
    private static function slugExists(DatabaseInterface $db,string $slug): bool { $q=$db->createQuery()->select('COUNT(*)')->from($db->quoteName('#__decaroforms_forms'))->where($db->quoteName('slug').'=:s')->bind(':s',$slug);$db->setQuery($q);return (int)$db->loadResult()>0; }
    private static function uniqueReference(DatabaseInterface $db,string $ref,int $sourceId): string { $base=substr($ref,0,48);$candidate=$base;$n=0;while(true){$q=$db->createQuery()->select('COUNT(*)')->from($db->quoteName('#__decaroforms_submissions'))->where($db->quoteName('reference').'=:r')->bind(':r',$candidate);$db->setQuery($q);if((int)$db->loadResult()===0)return $candidate;$n++;$suffix='-M'.$sourceId.($n>1?'-'.$n:'');$candidate=substr($base,0,max(1,48-strlen($suffix))).$suffix;}}
    private static function rowEmail(array $row,array $columns): string { foreach($columns as $c){$e=trim((string)($row[$c]??''));if(filter_var($e,FILTER_VALIDATE_EMAIL))return $e;}return ''; }
    private static function firstEmail(string $v): string { foreach(preg_split('/[;,\r\n]+/',$v)?:[] as $e){$e=trim($e);if(filter_var($e,FILTER_VALIDATE_EMAIL))return $e;}return ''; }
    private static function template(string $v): string { return in_array($v,['standard','minimal','institutional','card','compact'],true)?$v:'standard'; }
    private static function status(string $v): string { $v=mb_strtolower(trim($v),'UTF-8');return match($v){'processing','in_progress','en_cours','en traitement','traitement'=>'processing','replied','answered','reply','répondu','repondu'=>'replied','closed','cloture','clôturé','cloturé','termine','terminé'=>'closed','spam'=>'spam',default=>'new'}; }
    private static function fieldKey(string $c): string { $k=preg_replace('/[^a-z0-9_]+/','_',mb_strtolower($c,'UTF-8'))??'field';return trim($k,'_')?:'field'; }
    private static function guessType(string $c): string { $c=mb_strtolower($c,'UTF-8');if(str_contains($c,'email'))return 'email';if(str_contains($c,'phone')||$c==='gsm')return 'tel';if(str_ends_with($c,'_date')||str_contains($c,'birth_date')||$c==='date_naissance'||$c==='deadline')return 'date';if(str_ends_with($c,'_json')||str_contains($c,'message')||str_contains($c,'motivation')||str_contains($c,'needs')||str_starts_with($c,'note_'))return 'textarea';if(str_contains($c,'consent')||str_starts_with($c,'confirm_')||str_ends_with($c,'_accepted')||$c==='attention_confirm')return 'consent';if(preg_match('/(^|_)(price|rate|total|nights|people|guests|fee)(_|$)/',$c))return 'number';return 'text'; }
    private static function guessCategory(string $c): string { $t=self::guessType($c);if(in_array($t,['email','tel'],true))return 'contact';if($t==='consent')return 'consent';if($t==='date')return 'event';if(str_contains($c,'address')||str_contains($c,'postal')||str_contains($c,'localite')||str_contains($c,'city'))return 'address';if(str_contains($c,'club')||str_contains($c,'institution'))return 'organisation';if(str_contains($c,'sport')||str_contains($c,'team')||str_contains($c,'player')||str_contains($c,'discipline'))return 'sport';return 'custom'; }
    private static function humanize(string $c): string { $map=['nom'=>'Last name','prenom'=>'First name','date_naissance'=>'Date of birth','lieu_naissance'=>'Place of birth','nationalite'=>'Nationality','adresse'=>'Address','numero'=>'Street number','boite'=>'Box / Apartment','code_postal'=>'Postal code','localite'=>'City','discipline'=>'Discipline','discipline_autre'=>'Other discipline','sexe'=>'Gender','type_membre'=>'Member type','statut_membre'=>'Member status','gsm'=>'Phone'];if(isset($map[$c]))return $map[$c];$v=preg_replace('/_+/',' ',$c)??$c;return mb_convert_case($v,MB_CASE_TITLE,'UTF-8'); }
}
