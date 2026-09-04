#!/usr/bin/env python3
from pathlib import Path
import re, sys

if len(sys.argv) != 4:
    raise SystemExit('usage: apply.py COMPONENT_ROOT PLUGIN_ROOT TOOL_ROOT')
comp, plug, tool = map(Path, sys.argv[1:])

def sub(path, pattern, repl, count=1, flags=0):
    text = path.read_text()
    new, n = re.subn(pattern, repl, text, count=count, flags=flags)
    if n != count:
        raise RuntimeError(f'{path}: expected {count} replacement(s), got {n}: {pattern[:100]}')
    path.write_text(new)

def literal(path, old, new, count=1):
    text=path.read_text()
    if text.count(old) < count:
        raise RuntimeError(f'{path}: missing literal {old[:100]!r}')
    path.write_text(text.replace(old,new,count))

# Builder controller.
p=comp/'administrator/components/com_decaroforms/src/Controller/BuilderController.php'
literal(p, "$fieldsJson = $input->post->getString('fields_json', '[]');", "$fieldsJson = (string) $input->post->get('fields_json', '[]', 'raw');")
literal(p,
"            'list_columns_json' => $this->normaliseColumns($input->post->getString('list_columns_json', '[]')),\n            'updated_at' => $now,",
"            'list_columns_json' => $this->normaliseColumns((string) $input->post->get('list_columns_json', '[]', 'raw')),\n            'builder_config_json' => $this->normaliseJsonObject((string) $input->post->get('builder_config_json', '{}', 'raw')),\n            'email_config_json' => $this->normaliseJsonObject((string) $input->post->get('email_config_json', '{}', 'raw')),\n            'additional_emails_json' => $this->normaliseJsonArray((string) $input->post->get('additional_emails_json', '[]', 'raw')),\n            'integrations_json' => $this->normaliseJsonObject((string) $input->post->get('integrations_json', '{}', 'raw')),\n            'updated_at' => $now,")
literal(p, "\n        if ($id > 0) {\n            $db->updateObject('#__decaroforms_forms', $row, 'id');", "\n        if ($app->getIdentity()->authorise('core.admin', 'com_decaroforms')) {\n            $row->custom_css = trim((string) $input->post->get('custom_css', '', 'raw'));\n            $row->custom_js = trim((string) $input->post->get('custom_js', '', 'raw'));\n        }\n\n        if ($id > 0) {\n            $db->updateObject('#__decaroforms_forms', $row, 'id');")
sub(p, r"if \(!in_array\(\$type, \[[^\]]+\], true\)\) \{ \$type = 'text'; \}", "if (!in_array($type, ['text','email','tel','url','number','date','time','datetime','textarea','select','multiselect','radio','checkboxes','checkbox','toggle','consent','file','upload','nationality','country','region','city','postcode','member_number','range','separator','pagebreak','page','heading','info','fieldset','hidden','map','payment','calculated'], true)) { $type = 'text'; }")
literal(p,
"                'options_json' => json_encode(array_values($options), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),\n                'required' => !empty($field['required']) ? 1 : 0,",
"                'options_json' => json_encode(array_values($options), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),\n                'config_json' => $this->normaliseJsonObject(json_encode(is_array($field['config'] ?? null) ? $field['config'] : [], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)),\n                'required' => !empty($field['required']) ? 1 : 0,")
helper='''    private function normaliseJsonObject(string $json): string\n    {\n        if (strlen($json) > 1048576) { return '{}'; }\n        $data = json_decode($json, true);\n        if (!is_array($data)) { $data = []; }\n        return json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);\n    }\n\n    private function normaliseJsonArray(string $json): string\n    {\n        if (strlen($json) > 1048576) { return '[]'; }\n        $data = json_decode($json, true);\n        if (!is_array($data)) { $data = []; }\n        return json_encode(array_values($data), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);\n    }\n\n'''
literal(p, "    private function normaliseStatuses(string $json): string\n", helper+"    private function normaliseStatuses(string $json): string\n")

# Database schema / safe in-place upgrade.
p=comp/'script.php'
literal(p, "  `list_columns_json` longtext NULL,\n  `created_at` datetime NOT NULL,", "  `list_columns_json` longtext NULL,\n  `builder_config_json` longtext NULL,\n  `email_config_json` longtext NULL,\n  `additional_emails_json` longtext NULL,\n  `integrations_json` longtext NULL,\n  `custom_css` longtext NULL,\n  `custom_js` longtext NULL,\n  `created_at` datetime NOT NULL,")
literal(p, "  `options_json` text NULL,\n  `required` tinyint(1) NOT NULL DEFAULT 0,", "  `options_json` text NULL,\n  `config_json` longtext NULL,\n  `required` tinyint(1) NOT NULL DEFAULT 0,")
literal(p, "  `payload_json` longtext NOT NULL,\n  `internal_note` text NULL,", "  `payload_json` longtext NOT NULL,\n  `payment_json` longtext NULL,\n  `internal_note` text NULL,")
anchor="""        $columns = $db->getTableColumns($formTable, false);\n        if (!isset($columns['list_columns_json'])) {\n            $db->setQuery('ALTER TABLE ' . $db->quoteName($formTable) . ' ADD ' . $db->quoteName('list_columns_json') . ' LONGTEXT NULL AFTER ' . $db->quoteName('statuses_json'));\n            $db->execute();\n        }\n\n        return true;"""
upgrade="""        $columns = $db->getTableColumns($formTable, false);\n        if (!isset($columns['list_columns_json'])) {\n            $db->setQuery('ALTER TABLE ' . $db->quoteName($formTable) . ' ADD ' . $db->quoteName('list_columns_json') . ' LONGTEXT NULL AFTER ' . $db->quoteName('statuses_json'));\n            $db->execute();\n        }\n\n        $columns = $db->getTableColumns($formTable, false);\n        foreach ([\n            'builder_config_json' => 'list_columns_json',\n            'email_config_json' => 'builder_config_json',\n            'additional_emails_json' => 'email_config_json',\n            'integrations_json' => 'additional_emails_json',\n            'custom_css' => 'integrations_json',\n            'custom_js' => 'custom_css',\n        ] as $column => $after) {\n            if (!isset($columns[$column])) {\n                $db->setQuery('ALTER TABLE ' . $db->quoteName($formTable) . ' ADD ' . $db->quoteName($column) . ' LONGTEXT NULL AFTER ' . $db->quoteName($after));\n                $db->execute();\n                $columns[$column] = true;\n            }\n        }\n\n        $fieldTable = $db->replacePrefix('#__decaroforms_fields');\n        $fieldColumns = $db->getTableColumns($fieldTable, false);\n        if (!isset($fieldColumns['config_json'])) {\n            $db->setQuery('ALTER TABLE ' . $db->quoteName($fieldTable) . ' ADD ' . $db->quoteName('config_json') . ' LONGTEXT NULL AFTER ' . $db->quoteName('options_json'));\n            $db->execute();\n        }\n\n        $submissionTable = $db->replacePrefix('#__decaroforms_submissions');\n        $submissionColumns = $db->getTableColumns($submissionTable, false);\n        if (!isset($submissionColumns['payment_json'])) {\n            $db->setQuery('ALTER TABLE ' . $db->quoteName($submissionTable) . ' ADD ' . $db->quoteName('payment_json') . ' LONGTEXT NULL AFTER ' . $db->quoteName('payload_json'));\n            $db->execute();\n        }\n\n        return true;"""
literal(p,anchor,upgrade)

# Expanded library + version. fieldLibrary is last method.
p=comp/'administrator/components/com_decaroforms/src/Helper/FormHelper.php'
literal(p,"public const VERSION = '1.2.22';","public const VERSION = '1.3.0';")
text=p.read_text()
for old,new in [
("'nationality'=>'COM_DECAROFORMS_FIELD_NATIONALITY','email'=>'COM_DECAROFORMS_FIELD_EMAIL','phone'=>'COM_DECAROFORMS_FIELD_PHONE','address'", "'nationality'=>'COM_DECAROFORMS_FIELD_NATIONALITY','tax_code'=>'COM_DECAROFORMS_FIELD_TAX_CODE','email'=>'COM_DECAROFORMS_FIELD_EMAIL','phone'=>'COM_DECAROFORMS_FIELD_PHONE','mobile'=>'COM_DECAROFORMS_FIELD_MOBILE','pec'=>'COM_DECAROFORMS_FIELD_PEC','website'=>'COM_DECAROFORMS_FIELD_WEBSITE','address'"),
("'postcode'=>'COM_DECAROFORMS_FIELD_POSTCODE','city'=>'COM_DECAROFORMS_FIELD_CITY','country'", "'postcode'=>'COM_DECAROFORMS_FIELD_POSTCODE','city'=>'COM_DECAROFORMS_FIELD_CITY','region'=>'COM_DECAROFORMS_FIELD_REGION','country'"),
("'photo'=>'COM_DECAROFORMS_FIELD_PHOTO','payment_proof'", "'photo'=>'COM_DECAROFORMS_FIELD_PHOTO','certificate'=>'COM_DECAROFORMS_FIELD_CERTIFICATE','payment_proof'"),
("'payment_proof'=>'COM_DECAROFORMS_FIELD_PAYMENT_PROOF','privacy_consent'", "'payment_proof'=>'COM_DECAROFORMS_FIELD_PAYMENT_PROOF','payment'=>'COM_DECAROFORMS_PAYMENT','map_location'=>'COM_DECAROFORMS_FIELD_MAP','calculation'=>'COM_DECAROFORMS_FIELD_CALCULATION','privacy_consent'")]:
    if old in text: text=text.replace(old,new,1)
start=text.index('    public static function fieldLibrary(): array\n')
text=text[:start]+(tool/'field_library.phpfrag').read_text()
p.write_text(text)

# Payment status on detail and submissions list.
p=comp/'administrator/components/com_decaroforms/tmpl/submission/default.php'
literal(p,"$formId=(int)($s['form_id']??0);\n?>","$formId=(int)($s['form_id']??0);\n$payment=json_decode((string)($s['payment_json']??''),true);\n$payment=is_array($payment)?$payment:[];\n?>")
payment='''\n      <?php if($payment): ?>\n      <section class="df-section">\n        <h3><?php echo Text::_('COM_DECAROFORMS_PAYMENT'); ?></h3>\n        <div class="df-data-grid">\n          <div class="df-item"><small><?php echo Text::_('COM_DECAROFORMS_PAYMENT_METHOD'); ?></small><div><?php echo htmlspecialchars((string)($payment['label']??$payment['method']??'—'),ENT_QUOTES,'UTF-8'); ?></div></div>\n          <div class="df-item"><small><?php echo Text::_('COM_DECAROFORMS_AMOUNT'); ?></small><div><?php echo htmlspecialchars((string)($payment['amount']??'—'),ENT_QUOTES,'UTF-8'); ?></div></div>\n          <div class="df-item"><small>IBAN</small><div><?php echo htmlspecialchars((string)($payment['iban']??'—'),ENT_QUOTES,'UTF-8'); ?></div></div>\n          <div class="df-item"><small><?php echo Text::_('COM_DECAROFORMS_PAYMENT_CAUSE'); ?></small><div><?php echo htmlspecialchars((string)($payment['cause']??'—'),ENT_QUOTES,'UTF-8'); ?></div></div>\n          <div class="df-item"><small><?php echo Text::_('COM_DECAROFORMS_PAYMENT_REFERENCE'); ?></small><div><?php echo htmlspecialchars((string)($payment['reference']??'—'),ENT_QUOTES,'UTF-8'); ?></div></div>\n          <div class="df-item"><small><?php echo Text::_('COM_DECAROFORMS_PAYMENT_STATUS'); ?></small><div><?php echo (($payment['status']??'pending')==='verified')?Text::_('COM_DECAROFORMS_PAYMENT_VERIFIED'):Text::_('COM_DECAROFORMS_PAYMENT_PENDING'); ?></div></div>\n        </div>\n      </section>\n      <?php endif; ?>\n'''
literal(p,"\n      <?php if($this->files): ?>",payment+"\n      <?php if($this->files): ?>")
manage='''        <?php if($payment): ?><div class="df-field"><label for="df-payment-status"><?php echo Text::_('COM_DECAROFORMS_PAYMENT_STATUS'); ?></label><select id="df-payment-status" name="payment_status"><option value="pending" <?php echo ($payment['status']??'pending')==='pending'?'selected':''; ?>><?php echo Text::_('COM_DECAROFORMS_PAYMENT_PENDING'); ?></option><option value="verified" <?php echo ($payment['status']??'pending')==='verified'?'selected':''; ?>><?php echo Text::_('COM_DECAROFORMS_PAYMENT_VERIFIED'); ?></option></select></div><?php endif; ?>\n'''
literal(p,'        <div class="df-field"><label for="df-note">',manage+'        <div class="df-field"><label for="df-note">')

p=comp/'administrator/components/com_decaroforms/src/Controller/SubmissionController.php'
literal(p,"$note = trim($app->getInput()->post->getString('internal_note', ''));","$note = trim($app->getInput()->post->getString('internal_note', ''));\n        $paymentStatus = $app->getInput()->post->getCmd('payment_status', '');")
literal(p,"->select(['s.form_id','f.*'])","->select(['s.form_id','s.payment_json','f.*'])")
literal(p,"""            $row = (object)[\n                'id'=>$id,\n                'status'=>$status,\n                'internal_note'=>$note,\n                'updated_at'=>Factory::getDate()->toSql(),\n            ];""","""            $row = (object)[\n                'id'=>$id,\n                'status'=>$status,\n                'internal_note'=>$note,\n                'updated_at'=>Factory::getDate()->toSql(),\n            ];\n            $payment = json_decode((string)($form['payment_json'] ?? ''), true);\n            if (is_array($payment) && in_array($paymentStatus, ['pending','verified'], true)) {\n                $payment['status'] = $paymentStatus;\n                $payment['verified'] = $paymentStatus === 'verified';\n                $row->payment_json = json_encode($payment, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);\n            }""")

p=comp/'administrator/components/com_decaroforms/src/View/Submissions/HtmlView.php'
literal(p,"$submission['payload'] = json_decode((string) ($submission['payload_json'] ?? '{}'), true) ?: [];","$submission['payload'] = json_decode((string) ($submission['payload_json'] ?? '{}'), true) ?: [];\n                $submission['payment'] = json_decode((string) ($submission['payment_json'] ?? '{}'), true) ?: [];")
p=comp/'administrator/components/com_decaroforms/tmpl/submissions/default.php'
literal(p,"        '_created_at' => Text::_('COM_DECAROFORMS_DATE'),","        '_created_at' => Text::_('COM_DECAROFORMS_DATE'),\n        '_payment' => Text::_('COM_DECAROFORMS_PAYMENT'),",1)
literal(p,"        '_created_at' => (string) ($submission['created_at'] ?? ''),","        '_created_at' => (string) ($submission['created_at'] ?? ''),\n        '_payment' => (($submission['payment']['status'] ?? '') === 'verified' ? Text::_('COM_DECAROFORMS_PAYMENT_VERIFIED') : (($submission['payment']['reference'] ?? '') !== '' ? Text::_('COM_DECAROFORMS_PAYMENT_PENDING') : '—')),",1)

# Global defaults.
p=comp/'administrator/components/com_decaroforms/config.xml'
literal(p,'        <field name="default_admin_email" type="email" default="" label="COM_DECAROFORMS_CONFIG_EMAIL" description="COM_DECAROFORMS_CONFIG_EMAIL_DESC" />','''        <field name="default_admin_email" type="email" default="" label="COM_DECAROFORMS_CONFIG_EMAIL" description="COM_DECAROFORMS_CONFIG_EMAIL_DESC" />\n        <field name="default_from_email" type="email" default="" label="COM_DECAROFORMS_CONFIG_FROM_EMAIL" description="COM_DECAROFORMS_CONFIG_FROM_EMAIL_DESC" />\n        <field name="default_from_name" type="text" default="" label="COM_DECAROFORMS_CONFIG_FROM_NAME" description="COM_DECAROFORMS_CONFIG_FROM_NAME_DESC" />\n        <field name="default_reply_to_email" type="email" default="" label="COM_DECAROFORMS_CONFIG_REPLY_EMAIL" description="COM_DECAROFORMS_CONFIG_REPLY_EMAIL_DESC" />\n        <field name="default_reply_to_name" type="text" default="" label="COM_DECAROFORMS_CONFIG_REPLY_NAME" description="COM_DECAROFORMS_CONFIG_REPLY_NAME_DESC" />''')

# Version manifests.
for p in [comp/'com_decaroforms.xml', plug/'decaroforms.xml']:
    literal(p,'<version>1.2.22</version>','<version>1.3.0</version>')
    if '<creationDate>2026-09-03</creationDate>' in p.read_text():
        literal(p,'<creationDate>2026-09-03</creationDate>','<creationDate>2026-09-04</creationDate>')
print('Forms 1.3.0 patch set applied')
