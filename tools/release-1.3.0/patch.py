#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit('usage: patch.py COMPONENT_ROOT PLUGIN_ROOT')
comp = Path(sys.argv[1])
plug = Path(sys.argv[2])

def replace(path: Path, old: str, new: str, count: int = -1):
    text = path.read_text()
    if old not in text:
        raise RuntimeError(f'pattern not found in {path}: {old[:120]!r}')
    text2 = text.replace(old, new, count)
    path.write_text(text2)

# BuilderController: persist all new JSON settings and field configuration while preserving old controller methods.
p = comp / 'administrator/components/com_decaroforms/src/Controller/BuilderController.php'
replace(p, "$fieldsJson = $input->post->getString('fields_json', '[]');", "$fieldsJson = (string) $input->post->get('fields_json', '[]', 'raw');")
replace(p,
"            'list_columns_json' => $this->normaliseColumns($input->post->getString('list_columns_json', '[]')),\n            'updated_at' => Factory::getDate()->toSql(),",
"            'list_columns_json' => $this->normaliseColumns((string) $input->post->get('list_columns_json', '[]', 'raw')),\n            'builder_config_json' => $this->normaliseJsonObject((string) $input->post->get('builder_config_json', '{}', 'raw')),\n            'email_config_json' => $this->normaliseJsonObject((string) $input->post->get('email_config_json', '{}', 'raw')),\n            'additional_emails_json' => $this->normaliseJsonArray((string) $input->post->get('additional_emails_json', '[]', 'raw')),\n            'integrations_json' => $this->normaliseJsonObject((string) $input->post->get('integrations_json', '{}', 'raw')),\n            'updated_at' => Factory::getDate()->toSql(),")
replace(p,
"        if ($id > 0) {\n            $row->id = $id;",
"        if ($app->getIdentity()->authorise('core.admin', 'com_decaroforms')) {\n            $row->custom_css = trim((string) $input->post->get('custom_css', '', 'raw'));\n            $row->custom_js = trim((string) $input->post->get('custom_js', '', 'raw'));\n        }\n\n        if ($id > 0) {\n            $row->id = $id;", 1)
replace(p,
"            if (!in_array($type, ['text','email','tel','number','date','time','textarea','select','radio','checkboxes','consent','file'], true)) {\n                $type = 'text';\n            }",
"            if (!in_array($type, ['text','email','tel','url','number','date','time','datetime','textarea','select','multiselect','radio','checkboxes','checkbox','toggle','consent','file','upload','nationality','country','region','city','postcode','member_number','range','separator','pagebreak','page','heading','info','fieldset','hidden','map','payment','calculated'], true)) {\n                $type = 'text';\n            }")
replace(p,
"                'options_json' => json_encode($options, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),\n                'required' => !empty($field['required']) ? 1 : 0,",
"                'options_json' => json_encode($options, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),\n                'config_json' => $this->normaliseJsonObject(json_encode(is_array($field['config'] ?? null) ? $field['config'] : [], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)),\n                'required' => !empty($field['required']) ? 1 : 0,")
marker = "    private function normaliseStatuses(string $json): string\n"
insert = '''    private function normaliseJsonObject(string $json): string\n    {\n        if (strlen($json) > 1048576) { return '{}'; }\n        $data = json_decode($json, true);\n        if (!is_array($data)) { $data = []; }\n        return json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);\n    }\n\n    private function normaliseJsonArray(string $json): string\n    {\n        if (strlen($json) > 1048576) { return '[]'; }\n        $data = json_decode($json, true);\n        if (!is_array($data)) { $data = []; }\n        $data = array_values($data);\n        return json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);\n    }\n\n'''
replace(p, marker, insert + marker, 1)

# Installer schema and upgrades.
p = comp / 'script.php'
replace(p,
"`list_columns_json` longtext NULL,\n`created_at` datetime NOT NULL,",
"`list_columns_json` longtext NULL,\n`builder_config_json` longtext NULL,\n`email_config_json` longtext NULL,\n`additional_emails_json` longtext NULL,\n`integrations_json` longtext NULL,\n`custom_css` longtext NULL,\n`custom_js` longtext NULL,\n`created_at` datetime NOT NULL,")
replace(p,
"`options_json` longtext NULL,\n`required` tinyint(1) NOT NULL DEFAULT 0,",
"`options_json` longtext NULL,\n`config_json` longtext NULL,\n`required` tinyint(1) NOT NULL DEFAULT 0,")
replace(p,
"`payload_json` longtext NOT NULL,\n`internal_note` text NULL,",
"`payload_json` longtext NOT NULL,\n`payment_json` longtext NULL,\n`internal_note` text NULL,")
upgrade_anchor = "        return true;\n    }\n"
upgrade_code = '''        $formColumns = $db->getTableColumns('#__decaroforms_forms', false);\n        foreach ([\n            'builder_config_json' => "ALTER TABLE `#__decaroforms_forms` ADD `builder_config_json` LONGTEXT NULL AFTER `list_columns_json`",\n            'email_config_json' => "ALTER TABLE `#__decaroforms_forms` ADD `email_config_json` LONGTEXT NULL AFTER `builder_config_json`",\n            'additional_emails_json' => "ALTER TABLE `#__decaroforms_forms` ADD `additional_emails_json` LONGTEXT NULL AFTER `email_config_json`",\n            'integrations_json' => "ALTER TABLE `#__decaroforms_forms` ADD `integrations_json` LONGTEXT NULL AFTER `additional_emails_json`",\n            'custom_css' => "ALTER TABLE `#__decaroforms_forms` ADD `custom_css` LONGTEXT NULL AFTER `integrations_json`",\n            'custom_js' => "ALTER TABLE `#__decaroforms_forms` ADD `custom_js` LONGTEXT NULL AFTER `custom_css`",\n        ] as $column => $sql) {\n            if (!isset($formColumns[$column])) { $db->setQuery($sql)->execute(); }\n        }\n        $fieldColumns = $db->getTableColumns('#__decaroforms_fields', false);\n        if (!isset($fieldColumns['config_json'])) {\n            $db->setQuery("ALTER TABLE `#__decaroforms_fields` ADD `config_json` LONGTEXT NULL AFTER `options_json`")->execute();\n        }\n        $submissionColumns = $db->getTableColumns('#__decaroforms_submissions', false);\n        if (!isset($submissionColumns['payment_json'])) {\n            $db->setQuery("ALTER TABLE `#__decaroforms_submissions` ADD `payment_json` LONGTEXT NULL AFTER `payload_json`")->execute();\n        }\n\n'''
# Add only to updateSchema(), directly before its first return true after migration guards. Existing script has one main method; this is safe because only first occurrence needed.
replace(p, upgrade_anchor, upgrade_code + upgrade_anchor, 1)

# FormHelper: version and expanded field library.
p = comp / 'administrator/components/com_decaroforms/src/Helper/FormHelper.php'
replace(p, "public const VERSION = '1.2.22';", "public const VERSION = '1.3.0';")
# Extend key map for new reusable built-ins.
replace(p, "'nationality'=>'COM_DECAROFORMS_FIELD_NATIONALITY','email'=>'COM_DECAROFORMS_FIELD_EMAIL','phone'=>'COM_DECAROFORMS_FIELD_PHONE','address'", "'nationality'=>'COM_DECAROFORMS_FIELD_NATIONALITY','tax_code'=>'COM_DECAROFORMS_FIELD_TAX_CODE','email'=>'COM_DECAROFORMS_FIELD_EMAIL','phone'=>'COM_DECAROFORMS_FIELD_PHONE','mobile'=>'COM_DECAROFORMS_FIELD_MOBILE','pec'=>'COM_DECAROFORMS_FIELD_PEC','website'=>'COM_DECAROFORMS_FIELD_WEBSITE','address'")
replace(p, "'postcode'=>'COM_DECAROFORMS_FIELD_POSTCODE','city'=>'COM_DECAROFORMS_FIELD_CITY','country'", "'postcode'=>'COM_DECAROFORMS_FIELD_POSTCODE','city'=>'COM_DECAROFORMS_FIELD_CITY','region'=>'COM_DECAROFORMS_FIELD_REGION','country'")
replace(p, "'photo'=>'COM_DECAROFORMS_FIELD_PHOTO','payment_proof'", "'photo'=>'COM_DECAROFORMS_FIELD_PHOTO','certificate'=>'COM_DECAROFORMS_FIELD_CERTIFICATE','payment_proof'")
replace(p, "'payment_proof'=>'COM_DECAROFORMS_FIELD_PAYMENT_PROOF','privacy_consent'", "'payment_proof'=>'COM_DECAROFORMS_FIELD_PAYMENT_PROOF','payment'=>'COM_DECAROFORMS_PAYMENT','map_location'=>'COM_DECAROFORMS_FIELD_MAP','calculation'=>'COM_DECAROFORMS_FIELD_CALCULATION','privacy_consent'")
start = p.read_text().index('    public static function fieldLibrary(): array\n')
prefix = p.read_text()[:start]
new_func = r'''    public static function fieldLibrary(): array
    {
        return [
            ['key'=>'first_name','type'=>'text','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_FIRST_NAME'),'placeholder'=>'','required'=>true],
            ['key'=>'last_name','type'=>'text','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_LAST_NAME'),'placeholder'=>'','required'=>true],
            ['key'=>'full_name','type'=>'text','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_FULL_NAME'),'placeholder'=>'','required'=>false],
            ['key'=>'birth_date','type'=>'date','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_BIRTH_DATE'),'placeholder'=>'','required'=>false],
            ['key'=>'gender','type'=>'select','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_GENDER'),'placeholder'=>'','required'=>false,'options'=>[Text::_('COM_DECAROFORMS_OPT_FEMALE'),Text::_('COM_DECAROFORMS_OPT_MALE'),Text::_('COM_DECAROFORMS_OPT_OTHER'),Text::_('COM_DECAROFORMS_OPT_NOT_SAY')]],
            ['key'=>'nationality','type'=>'nationality','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_NATIONALITY'),'placeholder'=>'','required'=>false],
            ['key'=>'tax_code','type'=>'text','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_TAX_CODE'),'placeholder'=>'','required'=>false],
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

            ['key'=>'payment','type'=>'payment','category'=>'payment','label'=>Text::_('COM_DECAROFORMS_PAYMENT'),'placeholder'=>'','required'=>false,'config'=>['method'=>'bank','iban'=>'','holder'=>'','amount'=>'','cause'=>'{last_name} {first_name} - {riferimento}']],

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
'''
p.write_text(prefix + new_func)

# Submission detail: payment section and management status.
p = comp / 'administrator/components/com_decaroforms/tmpl/submission/default.php'
replace(p, "$formId=(int)($s['form_id']??0);\n?>", "$formId=(int)($s['form_id']??0);\n$payment=json_decode((string)($s['payment_json']??''),true);\n$payment=is_array($payment)?$payment:[];\n?>")
payment_block = '''\n      <?php if($payment): ?>\n      <section class="df-section">\n        <h3><?php echo Text::_('COM_DECAROFORMS_PAYMENT'); ?></h3>\n        <div class="df-data-grid">\n          <div class="df-item"><small><?php echo Text::_('COM_DECAROFORMS_PAYMENT_METHOD'); ?></small><div><?php echo htmlspecialchars((string)($payment['label']??$payment['method']??'—'),ENT_QUOTES,'UTF-8'); ?></div></div>\n          <div class="df-item"><small><?php echo Text::_('COM_DECAROFORMS_AMOUNT'); ?></small><div><?php echo htmlspecialchars((string)($payment['amount']??'—'),ENT_QUOTES,'UTF-8'); ?></div></div>\n          <div class="df-item"><small>IBAN</small><div><?php echo htmlspecialchars((string)($payment['iban']??'—'),ENT_QUOTES,'UTF-8'); ?></div></div>\n          <div class="df-item"><small><?php echo Text::_('COM_DECAROFORMS_PAYMENT_CAUSE'); ?></small><div><?php echo htmlspecialchars((string)($payment['cause']??'—'),ENT_QUOTES,'UTF-8'); ?></div></div>\n          <div class="df-item"><small><?php echo Text::_('COM_DECAROFORMS_PAYMENT_REFERENCE'); ?></small><div><?php echo htmlspecialchars((string)($payment['reference']??'—'),ENT_QUOTES,'UTF-8'); ?></div></div>\n          <div class="df-item"><small><?php echo Text::_('COM_DECAROFORMS_PAYMENT_STATUS'); ?></small><div><?php echo (($payment['status']??'pending')==='verified')?Text::_('COM_DECAROFORMS_PAYMENT_VERIFIED'):Text::_('COM_DECAROFORMS_PAYMENT_PENDING'); ?></div></div>\n        </div>\n      </section>\n      <?php endif; ?>\n'''
replace(p, "\n      <?php if($this->files): ?>", payment_block + "\n      <?php if($this->files): ?>", 1)
pay_manage = '''\n        <?php if($payment): ?><div class="df-field"><label for="df-payment-status"><?php echo Text::_('COM_DECAROFORMS_PAYMENT_STATUS'); ?></label><select id="df-payment-status" name="payment_status"><option value="pending" <?php echo ($payment['status']??'pending')==='pending'?'selected':''; ?>><?php echo Text::_('COM_DECAROFORMS_PAYMENT_PENDING'); ?></option><option value="verified" <?php echo ($payment['status']??'pending')==='verified'?'selected':''; ?>><?php echo Text::_('COM_DECAROFORMS_PAYMENT_VERIFIED'); ?></option></select></div><?php endif; ?>\n'''
replace(p, "        <div class=\"df-field\"><label for=\"df-note\">", pay_manage + "        <div class=\"df-field\"><label for=\"df-note\">", 1)

# SubmissionController: allow payment verification state update.
p = comp / 'administrator/components/com_decaroforms/src/Controller/SubmissionController.php'
replace(p, "$note = trim($app->getInput()->post->getString('internal_note', ''));", "$note = trim($app->getInput()->post->getString('internal_note', ''));\n        $paymentStatus = $app->getInput()->post->getCmd('payment_status', '');")
replace(p, "->select(['s.form_id','f.*'])", "->select(['s.form_id','s.payment_json','f.*'])")
replace(p,
"            $row = (object)[\n                'id'=>$id,\n                'status'=>$status,\n                'internal_note'=>$note,\n                'updated_at'=>Factory::getDate()->toSql(),\n            ];",
"            $row = (object)[\n                'id'=>$id,\n                'status'=>$status,\n                'internal_note'=>$note,\n                'updated_at'=>Factory::getDate()->toSql(),\n            ];\n            $payment = json_decode((string)($form['payment_json'] ?? ''), true);\n            if (is_array($payment) && in_array($paymentStatus, ['pending','verified'], true)) {\n                $payment['status'] = $paymentStatus;\n                $payment['verified'] = $paymentStatus === 'verified';\n                $row->payment_json = json_encode($payment, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);\n            }")

# Submissions view/template: decode and expose optional payment column.
p = comp / 'administrator/components/com_decaroforms/src/View/Submissions/HtmlView.php'
replace(p, "$submission['payload'] = json_decode((string) ($submission['payload_json'] ?? '{}'), true) ?: [];", "$submission['payload'] = json_decode((string) ($submission['payload_json'] ?? '{}'), true) ?: [];\n                $submission['payment'] = json_decode((string) ($submission['payment_json'] ?? '{}'), true) ?: [];")
p = comp / 'administrator/components/com_decaroforms/tmpl/submissions/default.php'
replace(p, "'_created_at' => Text::_('COM_DECAROFORMS_DATE'),", "'_created_at' => Text::_('COM_DECAROFORMS_DATE'),\n        '_payment' => Text::_('COM_DECAROFORMS_PAYMENT'),", 1)
replace(p, "'_created_at' => (string) ($submission['created_at'] ?? ''),", "'_created_at' => (string) ($submission['created_at'] ?? ''),\n        '_payment' => (($submission['payment']['status'] ?? '') === 'verified' ? Text::_('COM_DECAROFORMS_PAYMENT_VERIFIED') : (($submission['payment']['reference'] ?? '') !== '' ? Text::_('COM_DECAROFORMS_PAYMENT_PENDING') : '—')),", 1)

# Global Forms email defaults.
p = comp / 'administrator/components/com_decaroforms/config.xml'
replace(p, "        <field name=\"default_admin_email\" type=\"email\" default=\"\" label=\"COM_DECAROFORMS_CONFIG_EMAIL\" description=\"COM_DECAROFORMS_CONFIG_EMAIL_DESC\" />", "        <field name=\"default_admin_email\" type=\"email\" default=\"\" label=\"COM_DECAROFORMS_CONFIG_EMAIL\" description=\"COM_DECAROFORMS_CONFIG_EMAIL_DESC\" />\n        <field name=\"default_from_email\" type=\"email\" default=\"\" label=\"COM_DECAROFORMS_CONFIG_FROM_EMAIL\" description=\"COM_DECAROFORMS_CONFIG_FROM_EMAIL_DESC\" />\n        <field name=\"default_from_name\" type=\"text\" default=\"\" label=\"COM_DECAROFORMS_CONFIG_FROM_NAME\" description=\"COM_DECAROFORMS_CONFIG_FROM_NAME_DESC\" />\n        <field name=\"default_reply_to_email\" type=\"email\" default=\"\" label=\"COM_DECAROFORMS_CONFIG_REPLY_EMAIL\" description=\"COM_DECAROFORMS_CONFIG_REPLY_EMAIL_DESC\" />\n        <field name=\"default_reply_to_name\" type=\"text\" default=\"\" label=\"COM_DECAROFORMS_CONFIG_REPLY_NAME\" description=\"COM_DECAROFORMS_CONFIG_REPLY_NAME_DESC\" />")

# Version manifests.
for p in [comp/'com_decaroforms.xml', plug/'decaroforms.xml']:
    replace(p, '<version>1.2.22</version>', '<version>1.3.0</version>')
    replace(p, '<creationDate>2026-09-03</creationDate>', '<creationDate>2026-09-04</creationDate>')

print('Forms 1.3.0 patches applied')
