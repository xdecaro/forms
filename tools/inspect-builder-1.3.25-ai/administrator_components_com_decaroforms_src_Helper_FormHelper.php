<?php

namespace DeCaro\Component\Forms\Administrator\Helper;

defined('_JEXEC') or die;

use Joomla\CMS\Language\Text;

final class FormHelper
{
    public const VERSION = '1.3.25';


    public static function fieldTranslationKey(string $fieldKey): ?string
    {
        $map = [
            'first_name'=>'COM_DECAROFORMS_FIELD_FIRST_NAME','last_name'=>'COM_DECAROFORMS_FIELD_LAST_NAME','full_name'=>'COM_DECAROFORMS_FIELD_FULL_NAME','birth_date'=>'COM_DECAROFORMS_FIELD_BIRTH_DATE','gender'=>'COM_DECAROFORMS_FIELD_GENDER','nationality'=>'COM_DECAROFORMS_FIELD_NATIONALITY','tax_code'=>'COM_DECAROFORMS_FIELD_TAX_CODE','email'=>'COM_DECAROFORMS_FIELD_EMAIL','phone'=>'COM_DECAROFORMS_FIELD_PHONE','mobile'=>'COM_DECAROFORMS_FIELD_MOBILE','pec'=>'COM_DECAROFORMS_FIELD_PEC','website'=>'COM_DECAROFORMS_FIELD_WEBSITE','address'=>'COM_DECAROFORMS_FIELD_ADDRESS','street_number'=>'COM_DECAROFORMS_FIELD_STREET_NUMBER','box'=>'COM_DECAROFORMS_FIELD_BOX','postcode'=>'COM_DECAROFORMS_FIELD_POSTCODE','city'=>'COM_DECAROFORMS_FIELD_CITY','province'=>'COM_DECAROFORMS_FIELD_PROVINCE','region'=>'COM_DECAROFORMS_FIELD_REGION','country'=>'COM_DECAROFORMS_FIELD_COUNTRY','organisation'=>'COM_DECAROFORMS_FIELD_ORGANISATION','club'=>'COM_DECAROFORMS_FIELD_CLUB','role'=>'COM_DECAROFORMS_FIELD_ROLE','member_number'=>'COM_DECAROFORMS_FIELD_MEMBER_NUMBER','sport'=>'COM_DECAROFORMS_FIELD_SPORT','team_name'=>'COM_DECAROFORMS_FIELD_TEAM_NAME','level'=>'COM_DECAROFORMS_FIELD_LEVEL','event_date'=>'COM_DECAROFORMS_FIELD_EVENT_DATE','arrival_date'=>'COM_DECAROFORMS_FIELD_ARRIVAL_DATE','departure_date'=>'COM_DECAROFORMS_FIELD_DEPARTURE_DATE','participants'=>'COM_DECAROFORMS_FIELD_PARTICIPANTS','subject'=>'COM_DECAROFORMS_FIELD_SUBJECT','message'=>'COM_DECAROFORMS_FIELD_MESSAGE','notes'=>'COM_DECAROFORMS_FIELD_NOTES','motivation'=>'COM_DECAROFORMS_FIELD_MOTIVATION','attachment'=>'COM_DECAROFORMS_FIELD_ATTACHMENT','identity_document'=>'COM_DECAROFORMS_FIELD_IDENTITY_DOCUMENT','photo'=>'COM_DECAROFORMS_FIELD_PHOTO','certificate'=>'COM_DECAROFORMS_FIELD_CERTIFICATE','payment_proof'=>'COM_DECAROFORMS_FIELD_PAYMENT_PROOF','payment'=>'COM_DECAROFORMS_PAYMENT','map_location'=>'COM_DECAROFORMS_FIELD_MAP','calculation'=>'COM_DECAROFORMS_FIELD_CALCULATION','privacy_consent'=>'COM_DECAROFORMS_FIELD_PRIVACY','terms_consent'=>'COM_DECAROFORMS_FIELD_TERMS','newsletter_consent'=>'COM_DECAROFORMS_FIELD_NEWSLETTER','custom_text'=>'COM_DECAROFORMS_FIELD_CUSTOM_TEXT','custom_textarea'=>'COM_DECAROFORMS_FIELD_CUSTOM_TEXTAREA','custom_number'=>'COM_DECAROFORMS_FIELD_CUSTOM_NUMBER','custom_date'=>'COM_DECAROFORMS_FIELD_CUSTOM_DATE','custom_select'=>'COM_DECAROFORMS_FIELD_CUSTOM_SELECT','custom_radio'=>'COM_DECAROFORMS_FIELD_CUSTOM_RADIO','custom_checkboxes'=>'COM_DECAROFORMS_FIELD_CUSTOM_CHECKBOXES'
        ];
        $aliases = ['prenom'=>'first_name','nom'=>'last_name','date_naissance'=>'birth_date','gsm'=>'phone','adresse'=>'address','numero'=>'street_number','boite'=>'box','code_postal'=>'postcode','localite'=>'city','nationalite'=>'nationality','sexe'=>'gender'];
        $fieldKey = strtolower(trim($fieldKey));
        $fieldKey = $aliases[$fieldKey] ?? $fieldKey;
        $base = preg_replace('/_\d+$/', '', $fieldKey) ?: $fieldKey;
        $base = $aliases[$base] ?? $base;
        return $map[$base] ?? null;
    }

    public static function knownLanguageValues(string $languageKey): array
    {
        static $cache = [];
        if (isset($cache[$languageKey])) {
            return $cache[$languageKey];
        }
        $values = [];
        foreach (['en-GB','it-IT','fr-FR'] as $tag) {
            $file = JPATH_ADMINISTRATOR . '/components/com_decaroforms/language/' . $tag . '/com_decaroforms.ini';
            if (!is_file($file)) { continue; }
            $ini = @parse_ini_file($file, false, INI_SCANNER_RAW);
            if (is_array($ini) && isset($ini[$languageKey])) {
                $values[] = trim((string) $ini[$languageKey], "\"'");
            }
        }
        return $cache[$languageKey] = array_values(array_unique($values));
    }

    public static function localizedFieldLabel(string $fieldKey, string $storedLabel): string
    {
        $key = self::fieldTranslationKey($fieldKey);
        if ($key === null) { return $storedLabel; }
        $known = self::knownLanguageValues($key);
        return in_array($storedLabel, $known, true) ? Text::_($key) : $storedLabel;
    }

    public static function localizedPayloadLabel(string $storedLabel): string
    {
        foreach ([
            'first_name','last_name','full_name','birth_date','gender','nationality','email','phone','address','street_number','box','postcode','city','country','organisation','club','role','member_number','sport','team_name','level','event_date','arrival_date','departure_date','participants','subject','message','notes','motivation','attachment','identity_document','photo','payment_proof','privacy_consent','terms_consent','newsletter_consent','custom_text','custom_textarea','custom_number','custom_date','custom_select','custom_radio','custom_checkboxes'
        ] as $fieldKey) {
            $key = self::fieldTranslationKey($fieldKey);
            if ($key !== null && in_array($storedLabel, self::knownLanguageValues($key), true)) {
                return Text::_($key);
            }
        }
        return $storedLabel;
    }

    public static function localizedPayloadValue(string $storedLabel, mixed $value): string
    {
        $consentKeys = ['privacy_consent','terms_consent','newsletter_consent'];
        foreach ($consentKeys as $fieldKey) {
            $key = self::fieldTranslationKey($fieldKey);
            if ($key !== null && in_array($storedLabel, self::knownLanguageValues($key), true)) {
                return ((string) $value === '1') ? Text::_('JYES') : Text::_('JNO');
            }
        }
        return is_array($value) ? implode(', ', $value) : (string) $value;
    }

    public static function slugify(string $value): string
    {
        $value = trim(mb_strtolower($value, 'UTF-8'));
        $value = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $value) ?: $value;
        $value = preg_replace('/[^a-z0-9]+/', '-', $value) ?? '';
        return trim($value, '-') ?: 'form';
    }

    public static function adminStyles(): string
    {
        return <<<'CSS'
<style id="decaroforms-admin-global">
.df-wrap,.df-builder,.df-info,.df-imp,.df-mig,.df-dashboard,.df-recent,.df-submissions,.df-detail{max-width:none!important;width:100%!important;box-sizing:border-box}
:root[data-color-scheme="dark"] .df-wrap,:root[data-color-scheme="dark"] .df-builder,:root[data-color-scheme="dark"] .df-info,:root[data-color-scheme="dark"] .df-imp,:root[data-color-scheme="dark"] .df-mig,:root[data-color-scheme="dark"] .df-dashboard,:root[data-color-scheme="dark"] .df-recent,:root[data-color-scheme="dark"] .df-submissions,:root[data-color-scheme="dark"] .df-detail{color:#f1f4f7!important}
:root[data-color-scheme="dark"] .df-card,:root[data-color-scheme="dark"] .df-section,:root[data-color-scheme="dark"] .df-source,:root[data-color-scheme="dark"] .df-lib-item,:root[data-color-scheme="dark"] .df-selected-item,:root[data-color-scheme="dark"] .df-email-card,:root[data-color-scheme="dark"] .df-table,:root[data-color-scheme="dark"] .df-table tbody,:root[data-color-scheme="dark"] .df-table tr,:root[data-color-scheme="dark"] .df-table td,:root[data-color-scheme="dark"] .df-dashboard-card{background:#1f2731!important;color:#f1f4f7!important;border-color:#46515f!important}
:root[data-color-scheme="dark"] .df-card h3,:root[data-color-scheme="dark"] .df-section-head,:root[data-color-scheme="dark"] .df-selected-top,:root[data-color-scheme="dark"] .df-card-meta,:root[data-color-scheme="dark"] .df-table th,:root[data-color-scheme="dark"] .df-note,:root[data-color-scheme="dark"] .df-dashboard-card-head{background:#29333f!important;color:#f1f4f7!important;border-color:#46515f!important}
:root[data-color-scheme="dark"] .df-btn,:root[data-color-scheme="dark"] .df-mini-actions button,:root[data-color-scheme="dark"] .df-template-row button,:root[data-color-scheme="dark"] input:not([type="checkbox"]):not([type="radio"]),:root[data-color-scheme="dark"] select,:root[data-color-scheme="dark"] textarea{background:#151c24!important;color:#f5f7fa!important;border-color:#566271!important}
:root[data-color-scheme="dark"] input::placeholder,:root[data-color-scheme="dark"] textarea::placeholder{color:#98a3b1!important}
:root[data-color-scheme="dark"] .df-stat small,:root[data-color-scheme="dark"] .df-head p,:root[data-color-scheme="dark"] .df-bhead p,:root[data-color-scheme="dark"] .df-info-head p,:root[data-color-scheme="dark"] .df-note,:root[data-color-scheme="dark"] .df-muted,:root[data-color-scheme="dark"] .df-lib-item small,:root[data-color-scheme="dark"] .df-card p,:root[data-color-scheme="dark"] .df-admin-footer,:root[data-color-scheme="dark"] .df-item small{color:#c1c8d0!important}
:root[data-color-scheme="dark"] .df-badge:not([style]){background:#384451!important;color:#eef3f8!important}
:root[data-color-scheme="dark"] .df-on,:root[data-color-scheme="dark"] .df-ok{background:#183c2a!important;color:#9be3b8!important}
:root[data-color-scheme="dark"] .df-off,:root[data-color-scheme="dark"] .df-bad,:root[data-color-scheme="dark"] .df-danger{background:#46232a!important;color:#ffb3bd!important}
:root[data-color-scheme="dark"] .df-table th,:root[data-color-scheme="dark"] .df-table td,:root[data-color-scheme="dark"] .df-item,:root[data-color-scheme="dark"] .df-admin-footer{border-color:#46515f!important}
</style>
CSS;
    }

    public static function footer(): string
    {
        return self::adminStyles() . '<div class="df-admin-footer" style="margin:30px 0 12px;padding:16px 12px 0;border-top:1px solid var(--bs-border-color,#d9dee5);text-align:center;color:var(--bs-secondary-color,#667085);font-size:12px"><strong>'
            . htmlspecialchars(Text::sprintf('COM_DECAROFORMS_FOOTER', self::VERSION), ENT_QUOTES, 'UTF-8') . '</strong></div>';
    }

    public static function defaultStatuses(): array
    {
        return [
            ['key'=>'new','label'=>Text::_('COM_DECAROFORMS_STATUS_NEW'),'color'=>'#0d6efd'],
            ['key'=>'processing','label'=>Text::_('COM_DECAROFORMS_STATUS_PROCESSING'),'color'=>'#f59e0b'],
            ['key'=>'replied','label'=>Text::_('COM_DECAROFORMS_STATUS_REPLIED'),'color'=>'#198754'],
            ['key'=>'closed','label'=>Text::_('COM_DECAROFORMS_STATUS_CLOSED'),'color'=>'#6c757d'],
            ['key'=>'spam','label'=>Text::_('COM_DECAROFORMS_STATUS_SPAM'),'color'=>'#dc3545'],
        ];
    }

    public static function defaultStatusColor(string $status, int $index = 0): string
    {
        $known = [
            'new'=>'#0d6efd',
            'processing'=>'#f59e0b',
            'replied'=>'#198754',
            'closed'=>'#6c757d',
            'spam'=>'#dc3545',
        ];
        if (isset($known[$status])) { return $known[$status]; }
        $palette = ['#7c3aed','#0891b2','#be123c','#2563eb','#15803d','#b45309','#4b5563'];
        return $palette[$index % count($palette)];
    }

    public static function statusesForForm(array $form): array
    {
        $raw = json_decode((string)($form['statuses_json'] ?? ''), true);
        if (!is_array($raw) || !$raw) { return self::defaultStatuses(); }
        $out=[];
        foreach (array_values($raw) as $index => $row) {
            if (!is_array($row)) { continue; }
            $key = strtolower(trim((string)($row['key'] ?? '')));
            $key = preg_replace('/[^a-z0-9_-]+/', '_', $key) ?? '';
            $label = trim((string)($row['label'] ?? ''));
            $color = strtolower(trim((string)($row['color'] ?? '')));
            if (!preg_match('/^#[0-9a-f]{6}$/', $color)) { $color = self::defaultStatusColor($key, $index); }
            if ($key !== '' && $label !== '' && !isset($out[$key])) {
                $out[$key]=['key'=>substr($key,0,30),'label'=>substr($label,0,100),'color'=>$color];
            }
        }
        return array_values($out) ?: self::defaultStatuses();
    }

    public static function statusLabel(string $status, array $statuses = []): string
    {
        foreach ($statuses ?: self::defaultStatuses() as $item) {
            if (($item['key'] ?? '') === $status) { return (string)($item['label'] ?? $status); }
        }
        return $status;
    }

    public static function statusColor(string $status, array $statuses = []): string
    {
        foreach ($statuses ?: self::defaultStatuses() as $index => $item) {
            if (($item['key'] ?? '') !== $status) { continue; }
            $color = strtolower((string)($item['color'] ?? ''));
            return preg_match('/^#[0-9a-f]{6}$/', $color) ? $color : self::defaultStatusColor($status, (int)$index);
        }
        return self::defaultStatusColor($status);
    }

    public static function statusTextColor(string $background): string
    {
        $hex = ltrim(strtolower($background), '#');
        if (!preg_match('/^[0-9a-f]{6}$/', $hex)) { return '#ffffff'; }
        $r = hexdec(substr($hex,0,2));
        $g = hexdec(substr($hex,2,2));
        $b = hexdec(substr($hex,4,2));
        $luminance = (0.299*$r + 0.587*$g + 0.114*$b);
        return $luminance > 165 ? '#17202a' : '#ffffff';
    }

    public static function statusBadgeStyle(string $status, array $statuses = []): string
    {
        $background = self::statusColor($status, $statuses);
        return 'background:' . $background . ';color:' . self::statusTextColor($background) . ';';
    }

    public static function listColumnsForForm(array $form): array
    {
        $raw = json_decode((string)($form['list_columns_json'] ?? ''), true);
        if (!is_array($raw) || !$raw) { return ['_reference','_email','_status','_created_at']; }
        $out=[];
        foreach ($raw as $key) {
            $key=(string)$key;
            if ($key !== '' && !in_array($key,$out,true)) { $out[]=$key; }
        }
        return $out ?: ['_reference','_email','_status','_created_at'];
    }

    public static function payloadValueForField(array $payload, array $field): string
    {
        $stored=(string)($field['label'] ?? '');
        $candidates=[$stored, self::localizedFieldLabel((string)($field['field_key'] ?? ''), $stored)];
        $langKey=self::fieldTranslationKey((string)($field['field_key'] ?? ''));
        if ($langKey !== null) { $candidates=array_merge($candidates,self::knownLanguageValues($langKey)); }
        foreach (array_unique($candidates) as $label) {
            if ($label !== '' && array_key_exists($label,$payload)) {
                $v=$payload[$label];
                return is_array($v) ? implode(', ',array_map('strval',$v)) : (string)$v;
            }
        }
        return '';
    }

    public static function fieldLibrary(): array
    {
        return [
            ['key'=>'first_name','type'=>'text','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_FIRST_NAME'),'placeholder'=>'','required'=>true],
            ['key'=>'last_name','type'=>'text','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_LAST_NAME'),'placeholder'=>'','required'=>true],
            ['key'=>'full_name','type'=>'text','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_FULL_NAME'),'placeholder'=>'','required'=>false],
            ['key'=>'birth_date','type'=>'date','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_BIRTH_DATE'),'placeholder'=>'','required'=>false],
            ['key'=>'gender','type'=>'select','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_GENDER'),'placeholder'=>'','required'=>false,'options'=>[Text::_('COM_DECAROFORMS_OPT_FEMALE'),Text::_('COM_DECAROFORMS_OPT_MALE'),Text::_('COM_DECAROFORMS_OPT_OTHER'),Text::_('COM_DECAROFORMS_OPT_NOT_SAY')]],
            ['key'=>'nationality','type'=>'nationality','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_NATIONALITY'),'placeholder'=>'','required'=>false],
            ['key'=>'tax_code','type'=>'tax_code','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_TAX_CODE'),'placeholder'=>'RSSMRA80A01H501U','required'=>true,'config'=>['uppercase'=>true,'max_length'=>16,'verify_links'=>true,'links'=>[]]],
            ['key'=>'member_number','type'=>'member_number','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_MEMBER_NUMBER'),'placeholder'=>'','required'=>false,'config'=>['min_length'=>1,'max_length'=>20]],
            ['key'=>'role','type'=>'select','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_ROLE'),'placeholder'=>'','required'=>false,'options'=>[Text::_('COM_DECAROFORMS_ROLE_PRESIDENT'),Text::_('COM_DECAROFORMS_ROLE_VICEPRESIDENT'),Text::_('COM_DECAROFORMS_ROLE_SECRETARY'),Text::_('COM_DECAROFORMS_ROLE_TREASURER'),Text::_('COM_DECAROFORMS_ROLE_COUNCILLOR'),Text::_('COM_DECAROFORMS_ROLE_MANAGER'),Text::_('COM_DECAROFORMS_OPT_OTHER')]],
            ['key'=>'organisation','type'=>'text','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_ORGANISATION'),'placeholder'=>'','required'=>false],
            ['key'=>'club','type'=>'text','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_CLUB'),'placeholder'=>'','required'=>false],

            ['key'=>'email','type'=>'email','category'=>'contact','label'=>Text::_('COM_DECAROFORMS_FIELD_EMAIL'),'placeholder'=>'name@example.com','required'=>true],
            ['key'=>'phone','type'=>'tel','category'=>'contact','label'=>Text::_('COM_DECAROFORMS_FIELD_PHONE'),'placeholder'=>'','required'=>false],
            ['key'=>'mobile','type'=>'tel','category'=>'contact','label'=>Text::_('COM_DECAROFORMS_FIELD_MOBILE'),'placeholder'=>'','required'=>false],
            ['key'=>'pec','type'=>'email','category'=>'contact','label'=>Text::_('COM_DECAROFORMS_FIELD_PEC'),'placeholder'=>'','required'=>false],
            ['key'=>'website','type'=>'url','category'=>'contact','label'=>Text::_('COM_DECAROFORMS_FIELD_WEBSITE'),'placeholder'=>'https://','required'=>false],

            ['key'=>'address','type'=>'text','category'=>'address','label'=>Text::_('COM_DECAROFORMS_FIELD_ADDRESS'),'placeholder'=>'','required'=>false],
            ['key'=>'street_number','type'=>'text','category'=>'address','label'=>Text::_('COM_DECAROFORMS_FIELD_STREET_NUMBER'),'placeholder'=>'','required'=>false],
            ['key'=>'box','type'=>'text','category'=>'address','label'=>Text::_('COM_DECAROFORMS_FIELD_BOX'),'placeholder'=>'','required'=>false],
            ['key'=>'postcode','type'=>'postcode','category'=>'address','label'=>Text::_('COM_DECAROFORMS_FIELD_POSTCODE'),'placeholder'=>'00100','required'=>false],
            ['key'=>'city','type'=>'city','category'=>'address','label'=>Text::_('COM_DECAROFORMS_FIELD_CITY'),'placeholder'=>'','required'=>false,'options'=>[]],
            ['key'=>'province','type'=>'province','category'=>'address','label'=>'Provincia','placeholder'=>'Roma (RM)','required'=>false,'config'=>['display_format'=>'name_code']],
            ['key'=>'region','type'=>'region','category'=>'address','label'=>Text::_('COM_DECAROFORMS_FIELD_REGION'),'placeholder'=>'','required'=>false,'default'=>'Lazio'],
            ['key'=>'country','type'=>'country','category'=>'address','label'=>Text::_('COM_DECAROFORMS_FIELD_COUNTRY'),'placeholder'=>'','required'=>false,'default'=>'Italia'],
            ['key'=>'map_location','type'=>'map','category'=>'address','label'=>Text::_('COM_DECAROFORMS_FIELD_MAP'),'placeholder'=>Text::_('COM_DECAROFORMS_ADDRESS_SEARCH_PLACEHOLDER'),'required'=>false,'config'=>['lat'=>41.9028,'lng'=>12.4964,'zoom'=>12,'use_location'=>true]],

            ['key'=>'custom_select','type'=>'select','category'=>'choices','label'=>Text::_('COM_DECAROFORMS_FIELD_CUSTOM_SELECT'),'placeholder'=>'','required'=>false,'options'=>[Text::_('COM_DECAROFORMS_OPT_1'),Text::_('COM_DECAROFORMS_OPT_2')]],
            ['key'=>'custom_radio','type'=>'radio','category'=>'choices','label'=>Text::_('COM_DECAROFORMS_FIELD_CUSTOM_RADIO'),'placeholder'=>'','required'=>false,'options'=>[Text::_('COM_DECAROFORMS_OPT_1'),Text::_('COM_DECAROFORMS_OPT_2')]],
            ['key'=>'custom_checkboxes','type'=>'checkboxes','category'=>'choices','label'=>Text::_('COM_DECAROFORMS_FIELD_CUSTOM_CHECKBOXES'),'placeholder'=>'','required'=>false,'options'=>[Text::_('COM_DECAROFORMS_OPT_1'),Text::_('COM_DECAROFORMS_OPT_2')]],
            ['key'=>'custom_multiselect','type'=>'multiselect','category'=>'choices','label'=>Text::_('COM_DECAROFORMS_FIELD_MULTISELECT'),'placeholder'=>'','required'=>false,'options'=>[Text::_('COM_DECAROFORMS_OPT_1'),Text::_('COM_DECAROFORMS_OPT_2')]],
            ['key'=>'custom_checkbox','type'=>'checkbox','category'=>'choices','label'=>Text::_('COM_DECAROFORMS_FIELD_CHECKBOX'),'placeholder'=>'','required'=>false],
            ['key'=>'custom_toggle','type'=>'toggle','category'=>'choices','label'=>Text::_('COM_DECAROFORMS_FIELD_TOGGLE'),'placeholder'=>'','required'=>false],
            ['key'=>'level','type'=>'select','category'=>'choices','label'=>Text::_('COM_DECAROFORMS_FIELD_LEVEL'),'placeholder'=>'','required'=>false,'options'=>[Text::_('COM_DECAROFORMS_OPT_BEGINNER'),Text::_('COM_DECAROFORMS_OPT_INTERMEDIATE'),Text::_('COM_DECAROFORMS_OPT_ADVANCED'),Text::_('COM_DECAROFORMS_OPT_OTHER')]],
            ['key'=>'sport','type'=>'select','category'=>'choices','label'=>Text::_('COM_DECAROFORMS_FIELD_SPORT'),'placeholder'=>'','required'=>false,'options'=>[]],

            ['key'=>'custom_number','type'=>'number','category'=>'values','label'=>Text::_('COM_DECAROFORMS_FIELD_CUSTOM_NUMBER'),'placeholder'=>'','required'=>false],
            ['key'=>'participants','type'=>'number','category'=>'values','label'=>Text::_('COM_DECAROFORMS_FIELD_PARTICIPANTS'),'placeholder'=>'','required'=>false],
            ['key'=>'range_slider','type'=>'range','category'=>'values','label'=>Text::_('COM_DECAROFORMS_FIELD_RANGE'),'placeholder'=>'','required'=>false,'config'=>['min'=>0,'max'=>100,'step'=>1,'unit'=>'','dual'=>false]],
            ['key'=>'calculation','type'=>'calculated','category'=>'values','label'=>Text::_('COM_DECAROFORMS_FIELD_CALCULATION'),'placeholder'=>'','required'=>false,'config'=>['formula'=>'','decimals'=>2,'prefix'=>'','suffix'=>'','visible'=>true]],

            ['key'=>'custom_date','type'=>'date','category'=>'datetime','label'=>Text::_('COM_DECAROFORMS_FIELD_CUSTOM_DATE'),'placeholder'=>'','required'=>false],
            ['key'=>'custom_time','type'=>'time','category'=>'datetime','label'=>Text::_('COM_DECAROFORMS_FIELD_TIME'),'placeholder'=>'','required'=>false],
            ['key'=>'custom_datetime','type'=>'datetime','category'=>'datetime','label'=>Text::_('COM_DECAROFORMS_FIELD_DATETIME'),'placeholder'=>'','required'=>false],
            ['key'=>'event_date','type'=>'date','category'=>'datetime','label'=>Text::_('COM_DECAROFORMS_FIELD_EVENT_DATE'),'placeholder'=>'','required'=>false],
            ['key'=>'arrival_date','type'=>'date','category'=>'datetime','label'=>Text::_('COM_DECAROFORMS_FIELD_ARRIVAL_DATE'),'placeholder'=>'','required'=>false],
            ['key'=>'departure_date','type'=>'date','category'=>'datetime','label'=>Text::_('COM_DECAROFORMS_FIELD_DEPARTURE_DATE'),'placeholder'=>'','required'=>false],

            ['key'=>'attachment','type'=>'upload','category'=>'document','label'=>Text::_('COM_DECAROFORMS_FIELD_ATTACHMENT'),'placeholder'=>'','required'=>false,'config'=>['accept'=>'.pdf,.jpg,.jpeg,.png,.webp,.doc,.docx','max_mb'=>5,'max_files'=>1,'multiple'=>false]],
            ['key'=>'identity_document','type'=>'upload','category'=>'document','label'=>Text::_('COM_DECAROFORMS_FIELD_IDENTITY_DOCUMENT'),'placeholder'=>'','required'=>false,'config'=>['accept'=>'.pdf,.jpg,.jpeg,.png','max_mb'=>5,'max_files'=>2,'multiple'=>true]],
            ['key'=>'photo','type'=>'upload','category'=>'document','label'=>Text::_('COM_DECAROFORMS_FIELD_PHOTO'),'placeholder'=>'','required'=>false,'config'=>['accept'=>'.jpg,.jpeg,.png,.webp','max_mb'=>5,'max_files'=>1,'multiple'=>false]],
            ['key'=>'certificate','type'=>'upload','category'=>'document','label'=>Text::_('COM_DECAROFORMS_FIELD_CERTIFICATE'),'placeholder'=>'','required'=>false,'config'=>['accept'=>'.pdf,.jpg,.jpeg,.png','max_mb'=>5,'max_files'=>2,'multiple'=>true]],
            ['key'=>'payment_proof','type'=>'upload','category'=>'document','label'=>Text::_('COM_DECAROFORMS_FIELD_PAYMENT_PROOF'),'placeholder'=>'','required'=>false,'config'=>['accept'=>'.pdf,.jpg,.jpeg,.png','max_mb'=>5,'max_files'=>2,'multiple'=>true]],
            ['key'=>'custom_upload','type'=>'upload','category'=>'document','label'=>Text::_('COM_DECAROFORMS_FIELD_CUSTOM_UPLOAD'),'placeholder'=>'','required'=>false,'config'=>['accept'=>'.pdf,.jpg,.jpeg,.png,.webp,.doc,.docx','max_mb'=>5,'max_files'=>1,'multiple'=>false,'button_label'=>'']],

            ['key'=>'payment','type'=>'payment','category'=>'payment','label'=>Text::_('COM_DECAROFORMS_PAYMENT'),'placeholder'=>'','required'=>false,'config'=>['method'=>'bank','iban'=>'','bic'=>'','bank_country'=>'IT','holder'=>'','amount'=>'','cause'=>'{last_name} {first_name} - {riferimento}']],
            ['key'=>'payment_method','type'=>'select','category'=>'payment','label'=>Text::_('COM_DECAROFORMS_FIELD_PAYMENT_METHOD'),'placeholder'=>'','required'=>false,'options'=>['Bonifico bancario','Carta — '.Text::_('COM_DECAROFORMS_COMING_SOON'),'PayPal — '.Text::_('COM_DECAROFORMS_COMING_SOON')]],
            ['key'=>'iban','type'=>'text','category'=>'payment','label'=>'IBAN','placeholder'=>'IT00 A000 0000 0000 0000 0000 000','required'=>false,'config'=>['uppercase'=>true]],
            ['key'=>'account_holder','type'=>'text','category'=>'payment','label'=>Text::_('COM_DECAROFORMS_ACCOUNT_HOLDER'),'placeholder'=>'','required'=>false],
            ['key'=>'payment_amount','type'=>'text','category'=>'payment','label'=>Text::_('COM_DECAROFORMS_AMOUNT'),'placeholder'=>'0,00','required'=>false],
            ['key'=>'payment_cause','type'=>'text','category'=>'payment','label'=>Text::_('COM_DECAROFORMS_PAYMENT_CAUSE'),'placeholder'=>'','required'=>false],
            ['key'=>'payment_reference','type'=>'text','category'=>'payment','label'=>Text::_('COM_DECAROFORMS_PAYMENT_REFERENCE'),'placeholder'=>'','required'=>false],

            ['key'=>'section_heading','type'=>'heading','category'=>'structure','label'=>Text::_('COM_DECAROFORMS_FIELD_HEADING'),'placeholder'=>'','required'=>false,'config'=>['content'=>'']],
            ['key'=>'info_text','type'=>'info','category'=>'structure','label'=>Text::_('COM_DECAROFORMS_FIELD_INFO'),'placeholder'=>'','required'=>false,'config'=>['content'=>'']],
            ['key'=>'separator','type'=>'separator','category'=>'structure','label'=>Text::_('COM_DECAROFORMS_FIELD_SEPARATOR'),'placeholder'=>'','required'=>false,'config'=>['color'=>'#dfe3e7','border_width'=>1,'border_style'=>'solid','line_width'=>100,'margin'=>20]],
            ['key'=>'pagebreak','type'=>'pagebreak','category'=>'structure','label'=>Text::_('COM_DECAROFORMS_FIELD_PAGEBREAK'),'placeholder'=>'','required'=>false,'config'=>['color'=>'#dfe3e7','border_width'=>1,'border_style'=>'solid','line_width'=>100,'margin'=>20,'show_line'=>true]],
            ['key'=>'page','type'=>'page','category'=>'structure','label'=>Text::_('COM_DECAROFORMS_FIELD_MULTIPAGE'),'placeholder'=>'','required'=>false,'config'=>['page_title'=>Text::_('COM_DECAROFORMS_PAGE_TITLE_DEFAULT'),'page_description'=>'','show_progress'=>true]],
            ['key'=>'fieldset','type'=>'fieldset','category'=>'structure','label'=>Text::_('COM_DECAROFORMS_FIELD_FIELDSET'),'placeholder'=>'','required'=>false,'config'=>['content'=>'']],
            ['key'=>'hidden_field','type'=>'hidden','category'=>'structure','label'=>Text::_('COM_DECAROFORMS_FIELD_HIDDEN'),'placeholder'=>'','required'=>false],

            ['key'=>'privacy_consent','type'=>'consent','category'=>'consent','label'=>Text::_('COM_DECAROFORMS_FIELD_PRIVACY'),'placeholder'=>'','required'=>true],
            ['key'=>'terms_consent','type'=>'consent','category'=>'consent','label'=>Text::_('COM_DECAROFORMS_FIELD_TERMS'),'placeholder'=>'','required'=>true],
            ['key'=>'newsletter_consent','type'=>'consent','category'=>'consent','label'=>Text::_('COM_DECAROFORMS_FIELD_NEWSLETTER'),'placeholder'=>'','required'=>false],

            ['key'=>'custom_text','type'=>'text','category'=>'custom','label'=>Text::_('COM_DECAROFORMS_FIELD_CUSTOM_TEXT'),'placeholder'=>'','required'=>false],
            ['key'=>'custom_textarea','type'=>'textarea','category'=>'custom','label'=>Text::_('COM_DECAROFORMS_FIELD_CUSTOM_TEXTAREA'),'placeholder'=>'','required'=>false],
            ['key'=>'subject','type'=>'text','category'=>'custom','label'=>Text::_('COM_DECAROFORMS_FIELD_SUBJECT'),'placeholder'=>'','required'=>false],
            ['key'=>'message','type'=>'textarea','category'=>'custom','label'=>Text::_('COM_DECAROFORMS_FIELD_MESSAGE'),'placeholder'=>'','required'=>false],
            ['key'=>'notes','type'=>'textarea','category'=>'custom','label'=>Text::_('COM_DECAROFORMS_FIELD_NOTES'),'placeholder'=>'','required'=>false],
            ['key'=>'motivation','type'=>'textarea','category'=>'custom','label'=>Text::_('COM_DECAROFORMS_FIELD_MOTIVATION'),'placeholder'=>'','required'=>false],
            ['key'=>'team_name','type'=>'text','category'=>'custom','label'=>Text::_('COM_DECAROFORMS_FIELD_TEAM_NAME'),'placeholder'=>'','required'=>false],
        ];
    }
}
