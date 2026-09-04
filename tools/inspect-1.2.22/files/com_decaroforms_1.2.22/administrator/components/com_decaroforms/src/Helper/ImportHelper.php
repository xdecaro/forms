<?php

namespace DeCaro\Component\Forms\Administrator\Helper;

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Http\HttpFactory;
use Joomla\CMS\Language\Text;
use Joomla\Database\DatabaseInterface;
use PDO;
use RuntimeException;
use Throwable;

final class ImportHelper
{
    public const SESSION_KEY = 'com_decaroforms.import_state';
    public const MAX_ROWS = 10000;
    public const MAX_REMOTE_BYTES = 8_000_000;

    public static function listForms(DatabaseInterface $db): array
    {
        $q = $db->createQuery()->select(['id','title'])->from($db->quoteName('#__decaroforms_forms'))->order($db->quoteName('title').' ASC');
        $db->setQuery($q);
        return $db->loadAssocList() ?: [];
    }

    public static function listJoomlaTables(DatabaseInterface $db): array
    {
        $prefix = $db->getPrefix();
        $tables = $db->getTableList();
        sort($tables, SORT_NATURAL | SORT_FLAG_CASE);
        $out = [];
        foreach ($tables as $table) {
            $display = str_starts_with($table, $prefix) ? '#__' . substr($table, strlen($prefix)) : $table;
            $out[] = ['value'=>$table, 'label'=>$display];
        }
        return $out;
    }

    public static function prepareJoomla(DatabaseInterface $db, string $table, int $targetFormId): array
    {
        if (!in_array($table, $db->getTableList(), true)) {
            throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_TABLE'));
        }
        $columns = array_keys($db->getTableColumns($table, false));
        $db->setQuery('SELECT * FROM '.$db->quoteName($table).' LIMIT 8');
        $sample = $db->loadAssocList() ?: [];
        $db->setQuery('SELECT COUNT(*) FROM '.$db->quoteName($table));
        $count = (int) $db->loadResult();
        return self::state('joomla_db', self::normalizedJoomlaTable($db, $table), $columns, $sample, $count, $targetFormId, ['table'=>$table]);
    }

    public static function prepareCsv(array $file, int $targetFormId): array
    {
        if (($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK || empty($file['tmp_name'])) {
            throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_CSV_UPLOAD'));
        }
        if ((int)($file['size'] ?? 0) > self::MAX_REMOTE_BYTES) {
            throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_CSV_SIZE'));
        }
        $ext = strtolower(pathinfo((string)($file['name'] ?? ''), PATHINFO_EXTENSION));
        if (!in_array($ext, ['csv','txt','tsv'], true)) {
            throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_CSV_TYPE'));
        }
        $tmpDir = rtrim((string)Factory::getApplication()->get('tmp_path'), '/\\') . '/decaroforms-import';
        if (!is_dir($tmpDir) && !@mkdir($tmpDir, 0755, true) && !is_dir($tmpDir)) {
            throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_TMP'));
        }
        $path = $tmpDir . '/' . bin2hex(random_bytes(16)) . '.csv';
        if (!@move_uploaded_file((string)$file['tmp_name'], $path) && !@rename((string)$file['tmp_name'], $path)) {
            throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_TMP_WRITE'));
        }
        [$columns,$rows,$delimiter,$count] = self::readCsv($path, 8, true);
        $display=(string)($file['name'] ?? 'CSV'); $sourceName=$display.' · '.strtoupper(substr(hash_file('sha256',$path),0,8));
        return self::state('csv', $sourceName, $columns, $rows, $count, $targetFormId, ['path'=>$path,'delimiter'=>$delimiter]);
    }

    public static function prepareGoogle(string $sourceType, string $url, int $targetFormId): array
    {
        $url = trim($url);
        $csvUrl = self::googleCsvUrl($url);
        $parts = parse_url($csvUrl);
        if (!is_array($parts) || strtolower((string)($parts['host'] ?? '')) !== 'docs.google.com') {
            throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_GOOGLE_HOST'));
        }
        $http = HttpFactory::getHttp();
        $response = $http->get($csvUrl, [], 15);
        if ((int)$response->code < 200 || (int)$response->code >= 300) {
            throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_GOOGLE_ACCESS'));
        }
        $body = (string)$response->body;
        if ($body === '' || strlen($body) > self::MAX_REMOTE_BYTES) {
            throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_GOOGLE_SIZE'));
        }
        $tmpDir = rtrim((string)Factory::getApplication()->get('tmp_path'), '/\\') . '/decaroforms-import';
        if (!is_dir($tmpDir) && !@mkdir($tmpDir, 0755, true) && !is_dir($tmpDir)) {
            throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_TMP'));
        }
        $path = $tmpDir . '/' . bin2hex(random_bytes(16)) . '.csv';
        file_put_contents($path, $body);
        [$columns,$rows,$delimiter,$count] = self::readCsv($path, 8, true);
        $label = $sourceType === 'google_forms' ? 'Google Forms → Sheets' : 'Google Sheets';
        $sourceName=$label.' · '.strtoupper(substr(hash('sha256',$csvUrl),0,8));
        return self::state($sourceType, $sourceName, $columns, $rows, $count, $targetFormId, ['path'=>$path,'delimiter'=>$delimiter,'url'=>$url,'csv_url'=>$csvUrl]);
    }

    public static function prepareExternal(array $config, int $targetFormId): array
    {
        $cfg = self::sanitizeExternalConfig($config);
        $pdo = self::externalPdo($cfg);
        $table = self::quoteExternalIdentifier($cfg['table']);
        $columns = [];
        $stmt = $pdo->query('SHOW COLUMNS FROM '.$table);
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) ?: [] as $col) { $columns[] = (string)$col['Field']; }
        if (!$columns) { throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_NO_COLUMNS')); }
        $sample = $pdo->query('SELECT * FROM '.$table.' LIMIT 8')->fetchAll(PDO::FETCH_ASSOC) ?: [];
        $count = (int)$pdo->query('SELECT COUNT(*) FROM '.$table)->fetchColumn();
        return self::state('external_db', $cfg['host'].' / '.$cfg['database'].' / '.$cfg['table'], $columns, $sample, $count, $targetFormId, $cfg);
    }

    public static function loadRows(DatabaseInterface $db, array $state, int $limit): array
    {
        $limit = max(1, min(self::MAX_ROWS, $limit));
        $type = (string)($state['type'] ?? '');
        $config = (array)($state['config'] ?? []);
        if ($type === 'joomla_db') {
            $table = (string)($config['table'] ?? '');
            if (!in_array($table, $db->getTableList(), true)) { throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_TABLE')); }
            $db->setQuery('SELECT * FROM '.$db->quoteName($table).' LIMIT '.(int)$limit);
            return $db->loadAssocList() ?: [];
        }
        if (in_array($type, ['csv','google_sheets','google_forms'], true)) {
            $path = (string)($config['path'] ?? '');
            if (!is_file($path)) { throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_TMP_EXPIRED')); }
            [, $rows] = self::readCsv($path, $limit, false, (string)($config['delimiter'] ?? ','));
            return $rows;
        }
        if ($type === 'external_db') {
            $pdo = self::externalPdo($config);
            $table = self::quoteExternalIdentifier((string)$config['table']);
            return $pdo->query('SELECT * FROM '.$table.' LIMIT '.(int)$limit)->fetchAll(PDO::FETCH_ASSOC) ?: [];
        }
        throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_SOURCE'));
    }

    public static function run(DatabaseInterface $db, array $state, array $options): array
    {
        $targetFormId = (int)($state['target_form_id'] ?? 0);
        $columns = (array)($state['columns'] ?? []);
        $mappings = (array)($options['map'] ?? []);
        $include = array_values(array_filter((array)($options['include'] ?? []), static fn($v)=>in_array($v,$columns,true)));
        $limit = (int)($options['limit'] ?? min(self::MAX_ROWS, max(1,(int)($state['count'] ?? 1000))));
        $rows = self::loadRows($db, $state, $limit);
        if (!$rows) { return ['form_id'=>$targetFormId,'imported'=>0,'skipped'=>0,'processed'=>0]; }

        $db->transactionStart();
        try {
            if ($targetFormId <= 0) {
                $title = trim((string)($options['new_form_title'] ?? ''));
                if ($title === '') { throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_NEW_TITLE')); }
                if (!$include) { throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_SELECT_COLUMN')); }
                $targetFormId = self::createFormFromColumns($db, $title, $include);
                $createdFields=self::formFields($db,$targetFormId); $mappings=[];
                foreach($createdFields as $i=>$createdField){ if(isset($include[$i])) $mappings[$include[$i]]=(string)$createdField['field_key']; }
            } else {
                if (!self::formExists($db, $targetFormId)) { throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_TARGET')); }
                $mappings = array_filter($mappings, static fn($v)=>is_string($v) && $v !== '');
                if (!$mappings) { throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_MAPPING')); }
            }

            $fields = self::formFields($db, $targetFormId);
            $fieldByKey = [];
            foreach ($fields as $f) { $fieldByKey[$f['field_key']] = $f; }
            $sourceName = (string)($state['source_name'] ?? $state['type'] ?? 'source');
            $sourceType = (string)($state['type'] ?? 'source');
            $emailColumn = (string)($options['email_column'] ?? '');
            $statusColumn = (string)($options['status_column'] ?? '');
            $dateColumn = (string)($options['date_column'] ?? '');
            $referenceColumn = (string)($options['reference_column'] ?? '');
            $noteColumn = (string)($options['note_column'] ?? '');
            $imported=0; $skipped=0; $processed=0;

            foreach ($rows as $row) {
                $processed++;
                $sourceKey = self::rowKey($row);
                if (self::alreadyImported($db, $sourceType, $sourceName, $sourceKey)) { $skipped++; continue; }
                $payload = [];
                foreach ($mappings as $sourceColumn=>$fieldKey) {
                    if (!array_key_exists($sourceColumn,$row) || !isset($fieldByKey[$fieldKey])) { continue; }
                    $label = (string)$fieldByKey[$fieldKey]['label'];
                    $value = $row[$sourceColumn];
                    if (is_string($value)) { $value = trim($value); }
                    $payload[$label] = $value;
                }
                if (!$payload) { $skipped++; continue; }
                $email = self::emailValue($row, $emailColumn, $mappings, $fieldByKey);
                $status = self::mapStatus((string)($row[$statusColumn] ?? 'new'));
                $created = self::parseDate((string)($row[$dateColumn] ?? '')) ?: Factory::getDate()->toSql();
                $reference = self::reference($db, (string)($row[$referenceColumn] ?? ''), $sourceKey);
                $note = $noteColumn !== '' ? (string)($row[$noteColumn] ?? '') : '';
                $submission = (object)[
                    'form_id'=>$targetFormId,'reference'=>$reference,'email'=>$email,'status'=>$status,
                    'payload_json'=>json_encode($payload, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES),
                    'internal_note'=>$note,'created_at'=>$created,'updated_at'=>null,
                ];
                $db->insertObject('#__decaroforms_submissions',$submission,'id');
                self::logImport($db,$sourceType,$sourceName,$sourceKey,(int)$submission->id);
                $imported++;
            }
            $db->transactionCommit();
            self::cleanupStateFile($state);
            return ['form_id'=>$targetFormId,'imported'=>$imported,'skipped'=>$skipped,'processed'=>$processed];
        } catch (Throwable $e) {
            $db->transactionRollback();
            throw $e;
        }
    }

    public static function formFields(DatabaseInterface $db, int $formId): array
    {
        $q=$db->createQuery()->select(['field_key','label','field_type'])->from($db->quoteName('#__decaroforms_fields'))->where($db->quoteName('form_id').'='.(int)$formId)->order($db->quoteName('sort_order').' ASC');
        $db->setQuery($q);
        return $db->loadAssocList() ?: [];
    }

    public static function autoColumn(array $columns, array $needles): string
    {
        foreach ($needles as $needle) {
            foreach ($columns as $col) {
                $n = strtolower(preg_replace('/[^a-z0-9]+/','_',self::ascii((string)$col)) ?? '');
                if ($n === $needle || str_contains($n,$needle)) { return (string)$col; }
            }
        }
        return '';
    }

    public static function cleanupStateFile(array $state): void
    {
        $path = (string)($state['config']['path'] ?? '');
        if ($path !== '' && is_file($path) && str_contains($path, 'decaroforms-import')) { @unlink($path); }
    }

    private static function state(string $type,string $name,array $columns,array $sample,int $count,int $targetFormId,array $config): array
    {
        return ['type'=>$type,'source_name'=>$name,'columns'=>array_values($columns),'sample'=>$sample,'count'=>$count,'target_form_id'=>$targetFormId,'config'=>$config,'prepared_at'=>time()];
    }

    private static function readCsv(string $path, int $limit, bool $countAll, ?string $forcedDelimiter=null): array
    {
        $fh = fopen($path,'rb'); if (!$fh) { throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_CSV_READ')); }
        $first = fgets($fh); if ($first === false) { fclose($fh); throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_CSV_EMPTY')); }
        $delimiter = $forcedDelimiter ?: self::detectDelimiter($first);
        rewind($fh);
        $header = fgetcsv($fh, 0, $delimiter);
        if (!is_array($header) || !$header) { fclose($fh); throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_CSV_HEADER')); }
        $columns = self::uniqueHeaders($header);
        $rows=[]; $count=0;
        while (($values=fgetcsv($fh,0,$delimiter)) !== false) {
            if (count($values)===1 && trim((string)$values[0])==='') { continue; }
            $count++;
            if (count($rows) < $limit) {
                $values = array_pad(array_slice($values,0,count($columns)), count($columns), '');
                $rows[] = array_combine($columns,$values) ?: [];
            }
            if (!$countAll && $count >= $limit) { break; }
        }
        fclose($fh);
        return [$columns,$rows,$delimiter,$count];
    }

    private static function detectDelimiter(string $line): string
    {
        $scores=[]; foreach ([','=>',',';'=>';','\t'=>"\t"] as $k=>$d) { $scores[$d]=substr_count($line,$d); }
        arsort($scores); $d=(string)array_key_first($scores); return ($scores[$d]??0)>0?$d:',';
    }

    private static function uniqueHeaders(array $headers): array
    {
        $out=[];$seen=[];
        foreach($headers as $i=>$header){$h=trim((string)$header);if($i===0)$h=preg_replace('/^\xEF\xBB\xBF/','',$h)??$h;if($h==='')$h='column_'.($i+1);$base=$h;$n=2;while(isset($seen[mb_strtolower($h,'UTF-8')]))$h=$base.' '.$n++;$seen[mb_strtolower($h,'UTF-8')]=1;$out[]=$h;}
        return $out;
    }

    private static function googleCsvUrl(string $url): string
    {
        if (preg_match('~^https://docs\.google\.com/spreadsheets/d/([^/]+)~i',$url,$m)) {
            $gid='0'; if (preg_match('/[?#&]gid=(\d+)/',$url,$gm)) $gid=$gm[1];
            return 'https://docs.google.com/spreadsheets/d/'.rawurlencode($m[1]).'/export?format=csv&gid='.rawurlencode($gid);
        }
        throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_GOOGLE_URL'));
    }

    private static function sanitizeExternalConfig(array $cfg): array
    {
        $out=['host'=>trim((string)($cfg['host']??'')),'port'=>(int)($cfg['port']??3306),'database'=>trim((string)($cfg['database']??'')),'username'=>(string)($cfg['username']??''),'password'=>(string)($cfg['password']??''),'table'=>trim((string)($cfg['table']??''))];
        if($out['host']===''||$out['database']===''||$out['username']===''||$out['table']==='')throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_EXTERNAL_REQUIRED'));
        if($out['port']<1||$out['port']>65535)throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_EXTERNAL_PORT'));
        if(!preg_match('/^[A-Za-z0-9_$-]+$/',$out['database'])||!preg_match('/^[A-Za-z0-9_$-]+$/',$out['table']))throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_EXTERNAL_NAME'));
        return $out;
    }

    private static function externalPdo(array $cfg): PDO
    {
        if (!class_exists(PDO::class) || !in_array('mysql', PDO::getAvailableDrivers(), true)) { throw new RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_PDO')); }
        $dsn='mysql:host='.$cfg['host'].';port='.(int)$cfg['port'].';dbname='.$cfg['database'].';charset=utf8mb4';
        return new PDO($dsn,(string)$cfg['username'],(string)$cfg['password'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_TIMEOUT=>8]);
    }

    private static function quoteExternalIdentifier(string $id): string { return '`'.str_replace('`','',$id).'`'; }
    private static function normalizedJoomlaTable(DatabaseInterface $db,string $table): string { $p=$db->getPrefix();return str_starts_with($table,$p)?'#__'.substr($table,strlen($p)):$table; }

    private static function createFormFromColumns(DatabaseInterface $db,string $title,array $columns): int
    {
        $slugBase=FormHelper::slugify($title);$slug=$slugBase;$n=2;while(self::slugExists($db,$slug))$slug=$slugBase.'-'.$n++;
        $now=Factory::getDate()->toSql();
        $form=(object)['title'=>$title,'slug'=>$slug,'description'=>'Imported data source. Review field settings before publishing this form.','enabled'=>0,'show_heading'=>1,'success_message'=>'','closed_reason'=>'closed','closed_message'=>'','admin_email'=>'','user_confirmation'=>0,'email_template_user'=>'standard','email_template_admin'=>'standard','email_subject_user'=>'','email_subject_admin'=>'','created_at'=>$now,'updated_at'=>$now];
        $db->insertObject('#__decaroforms_forms',$form,'id');$formId=(int)$form->id;
        $used=[];$sort=0;
        foreach($columns as $column){$key=self::fieldKey((string)$column);$base=$key;$i=2;while(isset($used[$key]))$key=$base.'_'.$i++;$used[$key]=1;$field=(object)['form_id'=>$formId,'field_key'=>$key,'field_type'=>self::guessType((string)$column),'category'=>self::guessCategory((string)$column),'label'=>(string)$column,'placeholder'=>'','help_text'=>'','default_value'=>'','options_json'=>'[]','required'=>0,'sort_order'=>$sort++];$db->insertObject('#__decaroforms_fields',$field);}
        return $formId;
    }

    private static function formExists(DatabaseInterface $db,int $id): bool { $db->setQuery('SELECT COUNT(*) FROM '.$db->quoteName('#__decaroforms_forms').' WHERE '.$db->quoteName('id').'='.(int)$id);return (int)$db->loadResult()>0; }
    private static function slugExists(DatabaseInterface $db,string $slug): bool { $q=$db->createQuery()->select('COUNT(*)')->from($db->quoteName('#__decaroforms_forms'))->where($db->quoteName('slug').'='.$db->quote($slug));$db->setQuery($q);return (int)$db->loadResult()>0; }
    private static function alreadyImported(DatabaseInterface $db,string $type,string $name,string $key): bool { $q=$db->createQuery()->select('COUNT(*)')->from($db->quoteName('#__decaroforms_import_log'))->where($db->quoteName('source_type').'='.$db->quote($type))->where($db->quoteName('source_name').'='.$db->quote(substr($name,0,255)))->where($db->quoteName('source_key').'='.$db->quote($key));$db->setQuery($q);return (int)$db->loadResult()>0; }
    private static function logImport(DatabaseInterface $db,string $type,string $name,string $key,int $targetId): void { $o=(object)['source_type'=>$type,'source_name'=>substr($name,0,255),'source_key'=>$key,'target_id'=>$targetId,'imported_at'=>Factory::getDate()->toSql()];$db->insertObject('#__decaroforms_import_log',$o); }
    private static function rowKey(array $row): string { ksort($row);return hash('sha256',json_encode($row,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES)?:serialize($row)); }
    private static function fieldKey(string $v): string { $v=strtolower(self::ascii($v));$v=preg_replace('/[^a-z0-9]+/','_',$v)??'field';return trim($v,'_')?:'field'; }
    private static function ascii(string $v): string { return iconv('UTF-8','ASCII//TRANSLIT//IGNORE',$v) ?: $v; }
    private static function guessType(string $c): string { $n=strtolower(self::ascii($c));if(str_contains($n,'email')||str_contains($n,'mail'))return 'email';if(str_contains($n,'phone')||str_contains($n,'telefono')||str_contains($n,'telephone')||str_contains($n,'gsm'))return 'tel';if(str_contains($n,'date')||str_contains($n,'data'))return 'date';if(str_contains($n,'message')||str_contains($n,'note')||str_contains($n,'comment')||str_contains($n,'description'))return 'textarea';if(str_contains($n,'consent')||str_contains($n,'privacy')||str_contains($n,'accept'))return 'consent';if(preg_match('/(^|_)(count|number|numero|qty|quantity|total|price|amount|age)(_|$)/',$n))return 'number';return 'text'; }
    private static function guessCategory(string $c): string { $t=self::guessType($c);if(in_array($t,['email','tel'],true))return 'contact';if($t==='consent')return 'consent';if($t==='date')return 'event';return 'custom'; }
    private static function emailValue(array $row,string $emailColumn,array $mappings,array $fields): string { if($emailColumn!==''&&filter_var(trim((string)($row[$emailColumn]??'')),FILTER_VALIDATE_EMAIL))return trim((string)$row[$emailColumn]);foreach($mappings as $src=>$key){if(isset($fields[$key])&&($fields[$key]['field_type']??'')==='email'){$v=trim((string)($row[$src]??''));if(filter_var($v,FILTER_VALIDATE_EMAIL))return $v;}}return ''; }
    private static function mapStatus(string $v): string { $v=strtolower(trim(self::ascii($v)));return match($v){'processing','in_progress','in lavorazione','en cours','en_cours','traitement'=>'processing','replied','answered','risposto','repondu','reponse'=>'replied','closed','chiuso','ferme','cloture','termine'=>'closed','spam'=>'spam',default=>'new'}; }
    private static function parseDate(string $v): ?string { $v=trim($v);if($v==='')return null;try{$dt=new \DateTime($v);return $dt->format('Y-m-d H:i:s');}catch(Throwable){return null;} }
    private static function reference(DatabaseInterface $db,string $candidate,string $sourceKey): string { $candidate=trim($candidate);if($candidate==='')$candidate='IMP-'.date('Ymd').'-'.strtoupper(substr($sourceKey,0,8));$base=substr(preg_replace('/[^A-Za-z0-9._-]+/','-', $candidate)??$candidate,0,48);if($base==='')$base='IMP-'.strtoupper(substr($sourceKey,0,12));$ref=$base;$n=2;while(true){$q=$db->createQuery()->select('COUNT(*)')->from($db->quoteName('#__decaroforms_submissions'))->where($db->quoteName('reference').'='.$db->quote($ref));$db->setQuery($q);if((int)$db->loadResult()===0)return $ref;$suffix='-'.$n++;$ref=substr($base,0,48-strlen($suffix)).$suffix;} }
}
