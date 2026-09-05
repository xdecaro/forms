<?php

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\FormHelper;
use Joomla\CMS\HTML\HTMLHelper;
use Joomla\CMS\Language\Text;

$form = $this->form;
$id = (int) ($form['id'] ?? 0);
$val = static fn(string $key, string $default = '') => htmlspecialchars((string) ($form[$key] ?? $default), ENT_QUOTES, 'UTF-8');
$checked = static fn(string $key, bool $default = false) => array_key_exists($key, $form) ? ((int) $form[$key] === 1) : $default;
$decode = static function (mixed $value, array $default = []): array {
    $data = json_decode((string) $value, true);
    return is_array($data) ? $data : $default;
};

$initialFields = [];
foreach ($this->fields as $field) {
    $initialFields[] = [
        'key' => (string) $field['field_key'],
        'type' => (string) $field['field_type'],
        'category' => (string) $field['category'],
        'label' => FormHelper::localizedFieldLabel((string) $field['field_key'], (string) $field['label']),
        'placeholder' => (string) $field['placeholder'],
        'help' => (string) $field['help_text'],
        'default' => (string) $field['default_value'],
        'options' => $field['options'] ?? [],
        'required' => (int) $field['required'] === 1,
        'config' => $field['config'] ?? [],
    ];
}

$initialStatuses = FormHelper::statusesForForm($form);
$initialColumns = FormHelper::listColumnsForForm($form);
$builderConfig = $decode($form['builder_config_json'] ?? '', []);
$emailConfig = $decode($form['email_config_json'] ?? '', []);
$additionalEmails = $decode($form['additional_emails_json'] ?? '', []);
$integrations = $decode($form['integrations_json'] ?? '', []);

if (!isset($emailConfig['admin']) || !is_array($emailConfig['admin'])) {
    $emailConfig['admin'] = [];
}
if (!isset($emailConfig['user']) || !is_array($emailConfig['user'])) {
    $emailConfig['user'] = [];
}
$emailConfig['admin'] += [
    'to' => (string) ($form['admin_email'] ?? ''),
    'from_email' => '', 'from_name' => '', 'reply_to' => '{email}', 'reply_name' => '', 'cc' => '', 'bcc' => '',
    'subject' => (string) ($form['email_subject_admin'] ?? ''),
    'template' => (string) ($form['email_template_admin'] ?? 'standard'),
    'auto_message' => true, 'attach_uploads' => false, 'html' => '',
    'custom' => ['base' => 'standard', 'primary' => '#e60046', 'secondary' => '#26364a', 'background' => '#ffffff', 'text' => '#20262d', 'button' => '#e60046', 'border' => '#dfe3e7', 'radius' => 8],
];
$emailConfig['user'] += [
    'enabled' => (int) ($form['user_confirmation'] ?? 0) === 1,
    'to_field' => 'email', 'reply_to' => '', 'reply_name' => '',
    'subject' => (string) ($form['email_subject_user'] ?? ''),
    'template' => (string) ($form['email_template_user'] ?? 'standard'),
    'auto_message' => true, 'attach_uploads' => false, 'html' => '',
    'custom' => ['base' => 'standard', 'primary' => '#e60046', 'secondary' => '#26364a', 'background' => '#ffffff', 'text' => '#20262d', 'button' => '#e60046', 'border' => '#dfe3e7', 'radius' => 8],
];
?>
<style>
.df-builder{--df:#e60046;--df-dark:#b40038;--df-border:var(--bs-border-color,#dfe3e7);width:100%;max-width:none}.df-builder *{box-sizing:border-box}.df-bhead{display:flex;align-items:flex-end;justify-content:space-between;gap:14px;margin:4px 0 18px}.df-bhead h2{margin:0;font-size:27px}.df-bhead p{margin:5px 0 0;color:var(--bs-secondary-color,#667085)}.df-bactions{display:flex;gap:8px;flex-wrap:wrap}.df-btn{display:inline-flex;align-items:center;justify-content:center;min-height:39px;padding:0 14px;border:1px solid;border-radius:6px;text-decoration:none;font-weight:750;cursor:pointer}.df-small{min-height:34px;padding:0 10px;font-size:12px}.df-ui-icon{width:16px;height:16px;display:inline-block;flex:0 0 auto;vertical-align:-2px}.df-ui-icon path,.df-ui-icon line,.df-ui-icon polyline,.df-ui-icon rect,.df-ui-icon circle{vector-effect:non-scaling-stroke}.df-btn .df-ui-icon,.df-lock-toggle .df-ui-icon{margin-right:6px}.df-icon-only .df-ui-icon,.df-layout-actions button .df-ui-icon,.df-mini-actions button .df-ui-icon,.df-status-remove .df-ui-icon,.df-lib-delete .df-ui-icon,.df-saved-quick-delete .df-ui-icon{margin:0}.df-icon-only{display:inline-flex;align-items:center;justify-content:center}.df-section{margin-bottom:13px;border:1px solid var(--df-border);border-radius:9px;background:var(--bs-body-bg,#fff);overflow:hidden}.df-section-toggle{width:100%;display:flex;align-items:center;justify-content:space-between;gap:12px;padding:15px 17px;border:0;background:var(--df);color:#fff;text-align:left;font:inherit;font-weight:850;cursor:pointer;transition:background .18s ease}.df-section-toggle:hover,.df-section-toggle:focus-visible{background:var(--df-dark);color:#fff}.df-section-toggle strong{font-size:18px;color:#fff}.df-section-chevron{color:#fff}.df-section-chevron{transition:transform .35s ease}.df-section.is-open .df-section-chevron{transform:rotate(180deg)}.df-section-body-wrap{display:grid;grid-template-rows:0fr;transition:grid-template-rows .42s cubic-bezier(.2,.7,.2,1)}.df-section.is-open .df-section-body-wrap{grid-template-rows:1fr}.df-section-body-inner{min-height:0;overflow:hidden}.df-section-body{padding:17px}.df-grid{display:grid;grid-template-columns:1fr 1fr;gap:14px}.df-field{display:flex;flex-direction:column;gap:6px}.df-field-full{grid-column:1/-1}.df-field label,.df-label{font-weight:750}.df-field input:not([type=checkbox]):not([type=radio]),.df-field textarea,.df-field select,.df-input{width:100%;border:1px solid var(--bs-border-color,#d5dbe3);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit;padding:10px 11px;min-height:42px}.df-field textarea{min-height:88px;resize:vertical}.df-check{display:flex;align-items:center;gap:9px;min-height:42px}.df-check input{width:18px;height:18px}.df-note{font-size:12px;color:var(--bs-secondary-color,#667085)}.df-subbox{border:1px solid var(--df-border);border-radius:8px;padding:14px;background:color-mix(in srgb,var(--bs-body-bg,#fff) 96%,var(--bs-tertiary-bg,#f7f8fa))}.df-subbox+.df-subbox{margin-top:12px}.df-subbox h4{margin:0 0 12px;font-size:16px}.df-inline{display:flex;align-items:center;gap:9px;flex-wrap:wrap}.df-spread{display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap}.df-template-row{display:flex;gap:8px;flex-wrap:wrap}.df-template-row button{min-height:36px;padding:0 12px;border:1px solid var(--df-border);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit;font-weight:700;cursor:pointer}.df-template-row button:hover{border-color:var(--df);color:var(--df)}.df-template-row button.is-active{background:var(--df);border-color:var(--df);color:#fff}.df-template-row button.is-active:hover{background:var(--df-dark);border-color:var(--df-dark);color:#fff}.df-layout-feedback{font-size:12px;font-weight:800;color:#18794e}
.df-selected{display:flex;flex-direction:column;gap:9px}.df-selected-empty{padding:24px;border:1px dashed var(--bs-border-color,#d5dbe3);border-radius:6px;text-align:center;color:var(--bs-secondary-color,#667085)}.df-selected-item{border:1px solid var(--df-border);border-radius:7px;overflow:hidden}.df-selected-top{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:10px;align-items:center;padding:11px 12px;background:var(--bs-tertiary-bg,#f7f8fa)}.df-mini-actions{display:flex;gap:5px}.df-mini-actions button{min-width:32px;height:30px;border:1px solid var(--df-border);border-radius:5px;background:var(--bs-body-bg,#fff);color:inherit;cursor:pointer}.df-selected-config{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;padding:12px}.df-selected-config .full{grid-column:1/-1}.df-selected-config input:not([type=checkbox]):not([type=radio]),.df-selected-config select,.df-selected-config textarea{width:100%;border:1px solid var(--bs-border-color,#d5dbe3);border-radius:5px;background:var(--bs-body-bg,#fff);color:inherit;padding:8px 9px;min-height:38px}.df-selected-config textarea.df-options{min-height:96px;max-height:180px;resize:vertical}.df-config-panel{grid-column:1/-1;border-top:1px dashed var(--df-border);padding-top:10px}.df-config-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:9px}.df-condition-list{display:flex;flex-direction:column;gap:7px;margin-top:8px}.df-condition-row{display:grid;grid-template-columns:1.2fr .8fr 1fr 34px;gap:7px}.df-condition-row button{border:1px solid var(--df-border);border-radius:5px;background:transparent;color:inherit}.df-required{display:flex;align-items:center;gap:7px}.df-required input{width:17px;height:17px}
.df-layout-widths{display:grid;grid-template-columns:repeat(4,minmax(90px,1fr));gap:9px}.df-layout-widths .df-field[hidden]{display:none}.df-presets{display:flex;flex-wrap:wrap;gap:7px;margin-top:10px}.df-preset{border:1px solid var(--df-border);border-radius:999px;padding:6px 10px;background:var(--bs-body-bg,#fff);color:inherit;cursor:pointer;font-weight:700;font-size:12px}.df-layout-total{font-weight:800}.df-layout-total.is-error{color:#b42318}.df-layout-total.is-ok{color:#18794e}
.df-library-tools{display:grid;grid-template-columns:minmax(220px,1fr) 250px;gap:10px;margin-bottom:12px}.df-library-tools input,.df-library-tools select{min-height:42px;border:1px solid var(--df-border);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit;padding:0 11px}.df-library{display:flex;flex-direction:column;gap:8px}.df-library-group{border:1px solid var(--df-border);border-radius:7px;overflow:hidden}.df-library-group summary{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:11px 13px;background:var(--bs-tertiary-bg,#f7f8fa);font-weight:800;cursor:pointer;list-style:none}.df-library-group summary::-webkit-details-marker{display:none}.df-library-count{display:inline-flex;min-width:26px;height:24px;align-items:center;justify-content:center;border-radius:999px;background:color-mix(in srgb,var(--df) 12%,transparent);color:var(--df);font-size:12px}.df-library-items{display:flex;flex-direction:column;gap:7px;padding:9px}.df-lib-item{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:12px;align-items:center;padding:10px 11px;border:1px solid var(--df-border);border-radius:6px}.df-lib-item strong{display:block}.df-lib-item small{color:var(--bs-secondary-color,#667085)}.df-add{min-height:34px;padding:0 12px;border:0;border-radius:5px;background:var(--df);color:#fff;font-weight:800;cursor:pointer}
.df-status-editor{display:flex;flex-direction:column;gap:8px}.df-status-row{display:grid;grid-template-columns:minmax(0,1fr) minmax(120px,.65fr) 110px 34px;gap:7px;align-items:center}.df-status-row input{width:100%;border:1px solid var(--df-border);border-radius:5px;background:var(--bs-body-bg,#fff);color:inherit;padding:8px 9px}.df-status-color-wrap{display:flex;align-items:center;gap:6px}.df-status-color{width:44px!important;min-width:44px;height:39px;padding:3px!important}.df-status-color-value{font:700 10px/1 ui-monospace,SFMono-Regular,Menlo,monospace}.df-status-remove{border:1px solid var(--df-border);border-radius:5px;background:var(--bs-body-bg,#fff);color:inherit;height:36px}.df-column-tools{display:flex;gap:7px;flex-wrap:wrap;margin:8px 0}.df-column-list{display:flex;flex-wrap:wrap;gap:7px}.df-column-item{display:inline-flex;align-items:center;gap:7px;padding:8px 10px;border:1px solid var(--df-border);border-radius:6px;background:var(--bs-body-bg,#fff)}.df-column-item input{width:17px;height:17px}
.df-email-block{border:1px solid var(--df-border);border-radius:8px;overflow:hidden;margin-bottom:11px}.df-email-block>summary{padding:12px 14px;background:var(--bs-tertiary-bg,#f7f8fa);font-weight:850;cursor:pointer}.df-email-block-body{padding:14px}.df-email-templates{display:grid;grid-template-columns:repeat(4,minmax(130px,1fr));gap:9px;margin-top:8px}.df-email-choice{border:1px solid var(--df-border);border-radius:7px;padding:8px;background:var(--bs-body-bg,#fff)}.df-email-choice.is-active{border-color:var(--df);box-shadow:0 0 0 2px color-mix(in srgb,var(--df) 18%,transparent)}.df-email-thumb{display:block;width:100%;height:62px;border:1px solid #e1e4e8;border-radius:5px;background:#fff;cursor:pointer;overflow:hidden}.df-email-thumb span{display:block;height:13px;background:var(--preview,#e60046)}.df-email-thumb[data-template="minimal"] span{height:3px;background:#dfe3e7}.df-email-thumb[data-template="institutional"] span{background:#26364a}.df-email-thumb[data-template="card"]{margin:3px;box-shadow:0 2px 7px rgba(0,0,0,.13)}.df-email-thumb[data-template="compact"]{border-left:5px solid #e60046}.df-email-thumb[data-template="modern"]{background:linear-gradient(135deg,#fff 70%,#eef1f5 70%)}.df-email-thumb[data-template="elegant"]{border-color:#c9b98d}.df-email-thumb[data-template="receipt"]{background:repeating-linear-gradient(0deg,#fff 0 8px,#f4f5f7 8px 9px)}.df-email-choice-foot{display:flex;align-items:center;gap:7px;margin-top:7px;font-size:12px;font-weight:800}.df-email-special{margin-top:10px;padding:12px;border:1px dashed var(--df-border);border-radius:7px}.df-codearea{width:100%;min-height:190px;border:1px solid var(--df-border);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit;padding:11px;font:13px/1.55 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;resize:vertical}.df-tokenbar{display:flex;align-items:center;gap:7px;flex-wrap:wrap;margin:10px 0}.df-tokenbar select{min-height:36px;border:1px solid var(--df-border);border-radius:5px;background:var(--bs-body-bg,#fff);color:inherit}.df-additional-list{display:flex;flex-direction:column;gap:9px}.df-additional-card{border:1px solid var(--df-border);border-radius:7px;padding:12px}.df-additional-head{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-bottom:10px}.df-additional-grid{display:grid;grid-template-columns:1fr 1fr;gap:9px}.df-additional-grid .full{grid-column:1/-1}
.df-preview-modal[hidden]{display:none!important}.df-preview-modal{position:fixed;inset:0;z-index:12000;display:grid;place-items:center;padding:20px}.df-preview-backdrop{position:absolute;inset:0;background:rgba(0,0,0,.58)}.df-preview-dialog{position:relative;z-index:1;width:min(850px,100%);max-height:90vh;overflow:auto;border:1px solid var(--df-border);border-radius:10px;background:var(--bs-body-bg,#fff);box-shadow:0 24px 80px rgba(0,0,0,.28)}.df-preview-head,.df-preview-foot{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:14px 16px;border-bottom:1px solid var(--df-border)}.df-preview-foot{border-top:1px solid var(--df-border);border-bottom:0;justify-content:flex-end}.df-preview-body{padding:17px;background:#e9edf2}.df-preview-canvas{max-width:700px;margin:auto}.df-preview-x{width:36px;height:36px;border:1px solid var(--df-border);border-radius:6px;background:transparent;color:inherit;font-size:22px}
.df-security-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.df-custom-code-grid{display:grid;grid-template-columns:1fr;gap:12px}.df-custom-code-grid .df-field{width:100%;min-width:0}.df-custom-code-grid .df-codearea{width:100%;max-width:none;box-sizing:border-box}.df-warning{padding:10px 12px;border-left:4px solid #f59e0b;background:color-mix(in srgb,#f59e0b 10%,transparent);font-size:12px}.df-admin-footer{width:100%;box-sizing:border-box;clear:both;margin:28px 0 10px;padding-top:16px;border-top:1px solid var(--df-border);text-align:center;color:var(--bs-secondary-color,#667085);font-size:12px}
@media(max-width:980px){.df-email-templates{grid-template-columns:repeat(3,1fr)}.df-config-grid{grid-template-columns:1fr 1fr}.df-custom-code-grid{grid-template-columns:1fr}}
@media(max-width:800px){.df-bhead{align-items:flex-start;flex-direction:column}.df-grid,.df-selected-config,.df-library-tools,.df-additional-grid,.df-security-grid{grid-template-columns:1fr}.df-field-full,.df-selected-config .full,.df-additional-grid .full{grid-column:auto}.df-layout-widths{grid-template-columns:1fr 1fr}.df-email-templates{grid-template-columns:1fr 1fr}.df-condition-row{grid-template-columns:1fr 1fr}.df-condition-row button{grid-column:2}.df-config-grid{grid-template-columns:1fr 1fr}}
@media(max-width:560px){.df-section-body{padding:12px}.df-email-templates,.df-layout-widths,.df-config-grid{grid-template-columns:1fr}.df-status-row{grid-template-columns:1fr 1fr}.df-status-color-wrap{grid-column:1}.df-selected-top{grid-template-columns:1fr}.df-mini-actions{justify-content:flex-start}.df-column-item{width:100%}.df-condition-row{grid-template-columns:1fr}.df-condition-row button{grid-column:auto}.df-preview-modal{padding:8px}}

/* Forms 1.3.2 UX refinements */
.df-section-toggle{background:var(--bs-tertiary-bg,#f7f8fa)!important;color:inherit!important;border:0!important}
.df-section-toggle:hover,.df-section-toggle:focus-visible{background:color-mix(in srgb,var(--bs-tertiary-bg,#f7f8fa) 88%,var(--df) 12%)!important;color:inherit!important}
.df-section-toggle strong,.df-section-chevron{color:inherit!important}
.df-template-row button.is-active{background:var(--bs-body-bg,#fff)!important;color:var(--df)!important;border-color:var(--df)!important;box-shadow:0 0 0 2px color-mix(in srgb,var(--df) 16%,transparent)}
.df-closed-box{grid-column:1/-1;background:var(--df);border-radius:8px;padding:14px}.df-closed-box label{color:#fff}.df-closed-box .df-note{color:#fff;opacity:.9}.df-closed-box input,.df-closed-box select{background:#fff!important;color:#1f2937!important}
.df-switch{display:inline-flex;align-items:center;gap:10px;font-weight:750;cursor:pointer;min-height:42px}.df-switch input{position:absolute;opacity:0;pointer-events:none}.df-switch-ui{position:relative;width:42px;height:24px;border-radius:999px;background:#aeb6c2;transition:.2s}.df-switch-ui:after{content:"";position:absolute;width:18px;height:18px;left:3px;top:3px;border-radius:50%;background:#fff;box-shadow:0 1px 3px rgba(0,0,0,.28);transition:.2s}.df-switch input:checked+.df-switch-ui{background:#0d6efd}.df-switch input:checked+.df-switch-ui:after{transform:translateX(18px)}.df-switch input:focus-visible+.df-switch-ui{outline:3px solid color-mix(in srgb,#0d6efd 28%,transparent);outline-offset:2px}
.df-selected-item .df-selected-config-wrap{display:grid;grid-template-rows:0fr;transition:grid-template-rows .32s ease}.df-selected-item.is-open .df-selected-config-wrap{grid-template-rows:1fr}.df-selected-config-inner{overflow:hidden;min-height:0}.df-field-toggle{border:0;background:transparent;color:inherit;padding:0;text-align:left;cursor:pointer;display:flex;align-items:center;gap:9px;min-width:0}.df-field-toggle-main{min-width:0}.df-field-chevron{transition:transform .25s}.df-selected-item.is-open .df-field-chevron{transform:rotate(180deg)}.df-field-summary{display:flex;gap:6px;flex-wrap:wrap;margin-top:3px}.df-summary-chip{font-size:10px;padding:2px 6px;border:1px solid var(--df-border);border-radius:999px;color:var(--bs-secondary-color,#667085)}
.df-condition-details{grid-column:1/-1;border-top:1px dashed var(--df-border);padding-top:8px}.df-condition-details>summary,.df-field-advanced>summary{cursor:pointer;font-weight:800;list-style:none;display:flex;align-items:center;justify-content:space-between}.df-condition-details>summary::-webkit-details-marker,.df-field-advanced>summary::-webkit-details-marker{display:none}.df-condition-details>summary:after,.df-field-advanced>summary:after{content:'⌄';font-size:12px}.df-condition-details[open]>summary:after,.df-field-advanced[open]>summary:after{transform:rotate(180deg)}.df-condition-body{padding-top:9px}.df-field-advanced{grid-column:1/-1;border-top:1px dashed var(--df-border);padding-top:8px}
.df-layout-visual-head{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;margin-bottom:10px}.df-layout-canvas{display:flex;flex-direction:column;gap:10px}.df-layout-row{min-height:72px;border:1px dashed var(--df-border);border-radius:8px;padding:9px;display:flex;align-items:stretch;gap:8px;background:color-mix(in srgb,var(--bs-tertiary-bg,#f7f8fa) 45%,transparent)}.df-layout-card{position:relative;min-width:120px;max-width:100%;border:1px solid var(--df-border);border-radius:7px;background:var(--bs-body-bg,#fff);padding:10px;display:flex;align-items:center;gap:8px;cursor:grab;box-shadow:0 1px 2px rgba(0,0,0,.04)}.df-layout-card.dragging{opacity:.4}.df-layout-handle{font-weight:900;color:var(--bs-secondary-color,#667085);letter-spacing:-2px}.df-layout-card strong{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:1}.df-layout-card select{width:auto;min-width:78px;min-height:32px;border:1px solid var(--df-border);border-radius:5px;background:var(--bs-body-bg,#fff);color:inherit}.df-layout-newrow{min-height:48px;border:1px dashed var(--df-border);border-radius:8px;display:flex;align-items:center;justify-content:center;color:var(--bs-secondary-color,#667085);font-size:12px}.df-layout-row.is-over,.df-layout-newrow.is-over{border-color:var(--df);background:color-mix(in srgb,var(--df) 7%,transparent)}.df-layout-advanced-box{margin-top:12px}.df-layout-empty{padding:22px;border:1px dashed var(--df-border);border-radius:8px;text-align:center;color:var(--bs-secondary-color,#667085)}
.df-library-tabs{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:10px}.df-library-tab{border:1px solid var(--df-border);border-radius:999px;min-height:32px;padding:0 10px;background:var(--bs-body-bg,#fff);color:inherit;font-weight:750;font-size:12px;cursor:pointer;display:inline-flex;align-items:center;gap:6px}.df-library-tab.is-active{border-color:var(--df);color:var(--df);box-shadow:0 0 0 2px color-mix(in srgb,var(--df) 12%,transparent)}.df-library-tab-count{font-size:10px;min-width:19px;height:19px;border-radius:999px;background:color-mix(in srgb,var(--df) 10%,transparent);display:inline-flex;align-items:center;justify-content:center}.df-library-tools-v2{display:block;margin-bottom:10px}.df-library-tools-v2 input{width:100%;min-height:42px;border:1px solid var(--df-border);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit;padding:0 11px}.df-library-items-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}.df-library-empty{padding:20px;text-align:center;color:var(--bs-secondary-color,#667085);border:1px dashed var(--df-border);border-radius:7px}
.df-info{border:0;background:transparent;color:#3971c7;font-weight:900;font-size:15px;padding:0 3px;cursor:pointer;vertical-align:middle}.df-info-wrap{position:relative;display:inline-flex;align-items:center}.df-info-bubble{position:absolute;z-index:50;left:50%;top:calc(100% + 7px);transform:translateX(-50%);width:min(320px,76vw);padding:9px 10px;border:1px solid var(--df-border);border-radius:7px;background:var(--bs-body-bg,#fff);color:var(--bs-body-color,#222);box-shadow:0 8px 28px rgba(0,0,0,.16);font-size:12px;font-weight:500;line-height:1.4;display:none}.df-info-wrap.is-open .df-info-bubble{display:block}.df-label-info{display:inline-flex;align-items:center;gap:4px}
.df-email-special-choice{border-style:dashed!important}.df-email-choice[data-special="1"]{background:color-mix(in srgb,var(--bs-tertiary-bg,#f7f8fa) 55%,transparent)}
@media(max-width:800px){.df-library-tabs{flex-wrap:nowrap;overflow-x:auto;padding-bottom:4px}.df-library-tab{flex:0 0 auto}.df-library-items-grid{grid-template-columns:1fr}.df-layout-row{flex-direction:column}.df-layout-card{width:100%!important}.df-selected-config{grid-template-columns:1fr}.df-config-grid{grid-template-columns:1fr}.df-closed-box .df-grid{grid-template-columns:1fr}}


/* Forms 1.3.3 interaction hotfix */
.df-section-toggle:hover,
.df-section-toggle:focus-visible{
  background:var(--bs-tertiary-bg,#f7f8fa)!important;
  color:inherit!important;
  box-shadow:none!important;
}
.df-closed-box{
  background:color-mix(in srgb,var(--df) 7%,var(--bs-body-bg,#fff))!important;
  border:1px solid color-mix(in srgb,var(--df) 34%,var(--df-border,#dfe3e7))!important;
}
.df-closed-box label{
  color:var(--bs-body-color,#1f2937)!important;
}
.df-closed-box .df-note{
  color:var(--bs-secondary-color,#667085)!important;
  opacity:1!important;
}
.df-closed-box input,
.df-closed-box select{
  background:var(--bs-body-bg,#fff)!important;
  color:var(--bs-body-color,#1f2937)!important;
}


/* Forms 1.3.4 accordion visual style */
.df-section-toggle{
  background:var(--bs-dark,#1f2937)!important;
  color:#fff!important;
}
.df-section-toggle strong,
.df-section-toggle .df-section-chevron{
  color:#fff!important;
}
.df-section-toggle:hover,
.df-section-toggle:focus-visible{
  background:color-mix(in srgb,var(--bs-dark,#1f2937) 90%,#fff 10%)!important;
  color:#fff!important;
  box-shadow:none!important;
}
.df-section-toggle:focus-visible{
  outline:2px solid var(--bs-primary,#0d6efd)!important;
  outline-offset:2px;
}


/* Forms 1.3.5 dark-mode surfaces + independent accordion polish */
.df-builder{
  --df-theme-surface:var(--bs-body-bg,#fff);
  --df-theme-surface-soft:var(--bs-tertiary-bg,#f7f8fa);
  --df-theme-input:var(--bs-body-bg,#fff);
  --df-theme-text:var(--bs-body-color,#1f2937);
  --df-theme-muted:var(--bs-secondary-color,#667085);
  --df-theme-border:var(--bs-border-color,#dfe3e7);
  --df-close-bg:color-mix(in srgb,var(--df) 7%,var(--bs-body-bg,#fff));
  --df-close-border:color-mix(in srgb,var(--df) 34%,var(--df-border,#dfe3e7));
  --df-close-label:var(--bs-body-color,#1f2937);
}
[data-bs-theme="dark"] .df-builder,
html[data-bs-theme="dark"] .df-builder,
body[data-bs-theme="dark"] .df-builder{
  --df-theme-surface:#1f2937;
  --df-theme-surface-soft:#263241;
  --df-theme-input:#111922;
  --df-theme-text:#f4f7fb;
  --df-theme-muted:#b6c0ce;
  --df-theme-border:#4a596b;
  --df-close-bg:rgba(230,0,70,.14);
  --df-close-border:#a94762;
  --df-close-label:#ffb1c3;
}
@media (prefers-color-scheme:dark){
  .df-builder{
    --df-theme-surface:#1f2937;
    --df-theme-surface-soft:#263241;
    --df-theme-input:#111922;
    --df-theme-text:#f4f7fb;
    --df-theme-muted:#b6c0ce;
    --df-theme-border:#4a596b;
    --df-close-bg:rgba(230,0,70,.14);
    --df-close-border:#a94762;
    --df-close-label:#ffb1c3;
  }
}

/* Internal cards: remove white islands in dark mode. */
.df-builder .df-subbox,
.df-builder .df-email-block,
.df-builder .df-email-block-body,
.df-builder .df-additional-card,
.df-builder .df-column-item,
.df-builder .df-email-choice,
.df-builder .df-email-special,
.df-builder .df-info-bubble{
  background:var(--df-theme-surface)!important;
  color:var(--df-theme-text)!important;
  border-color:var(--df-theme-border)!important;
}
.df-builder .df-email-block>summary{
  background:var(--df-theme-surface-soft)!important;
  color:var(--df-theme-text)!important;
  border-color:var(--df-theme-border)!important;
}
.df-builder .df-subbox h4,
.df-builder .df-email-block summary,
.df-builder .df-column-item span,
.df-builder .df-email-choice-foot,
.df-builder .df-additional-card,
.df-builder .df-security-grid,
.df-builder .df-status-color-value{
  color:var(--df-theme-text)!important;
}
.df-builder .df-note{
  color:var(--df-theme-muted)!important;
}

/* Form controls inside Builder use a real dark surface instead of white. */
.df-builder .df-field input:not([type=checkbox]):not([type=radio]):not([type=color]),
.df-builder .df-field textarea,
.df-builder .df-field select,
.df-builder .df-input,
.df-builder .df-status-row input:not([type=color]),
.df-builder .df-status-remove,
.df-builder .df-tokenbar select,
.df-builder .df-codearea{
  background:var(--df-theme-input)!important;
  color:var(--df-theme-text)!important;
  border-color:var(--df-theme-border)!important;
}
.df-builder .df-field input::placeholder,
.df-builder .df-field textarea::placeholder,
.df-builder .df-codearea::placeholder{
  color:var(--df-theme-muted)!important;
  opacity:.82;
}
.df-builder .df-status-remove{
  background:var(--df-theme-input)!important;
  color:var(--df-theme-text)!important;
  border-color:var(--df-theme-border)!important;
}

/* Closed-form warning: light red in light mode, dark red translucent in dark mode. */
.df-builder .df-closed-box{
  background:var(--df-close-bg)!important;
  border-color:var(--df-close-border)!important;
}
.df-builder .df-closed-box label{
  color:var(--df-close-label)!important;
}
.df-builder .df-closed-box input,
.df-builder .df-closed-box select{
  background:var(--df-theme-input)!important;
  color:var(--df-theme-text)!important;
  border-color:var(--df-theme-border)!important;
}

/* Custom CSS/JS helper line: align it with the editor content. */
.df-builder .df-custom-code-grid .df-note{
  display:block;
  padding-left:5px;
  margin-top:2px;
}


/* Forms 1.3.6 mobile library + status UX */
.df-builder .df-status-remove{
  border-color:#dc3545!important;
  color:#b42332!important;
  background:color-mix(in srgb,#dc3545 6%,var(--df-theme-input,var(--bs-body-bg,#fff)))!important;
  font-weight:850;
}
.df-builder .df-status-remove:hover,
.df-builder .df-status-remove:focus-visible{
  border-color:#dc3545!important;
  color:#fff!important;
  background:#b42332!important;
}
[data-bs-theme="dark"] .df-builder .df-library-tab,
html[data-bs-theme="dark"] .df-builder .df-library-tab,
body[data-bs-theme="dark"] .df-builder .df-library-tab{
  background:#1f2937!important;
  color:#f4f7fb!important;
  border-color:#4a596b!important;
  box-shadow:none!important;
}
[data-bs-theme="dark"] .df-builder .df-library-tab:hover,
html[data-bs-theme="dark"] .df-builder .df-library-tab:hover,
body[data-bs-theme="dark"] .df-builder .df-library-tab:hover{
  background:#2a3747!important;
  color:#fff!important;
  border-color:#64748b!important;
}
[data-bs-theme="dark"] .df-builder .df-library-tab.is-active,
html[data-bs-theme="dark"] .df-builder .df-library-tab.is-active,
body[data-bs-theme="dark"] .df-builder .df-library-tab.is-active{
  background:rgba(230,0,70,.14)!important;
  color:#ff9bb4!important;
  border-color:#e60046!important;
  box-shadow:0 0 0 2px rgba(230,0,70,.12)!important;
}
[data-bs-theme="dark"] .df-builder .df-library-tab-count,
html[data-bs-theme="dark"] .df-builder .df-library-tab-count,
body[data-bs-theme="dark"] .df-builder .df-library-tab-count{
  background:#334155!important;
  color:#e5edf7!important;
}
[data-bs-theme="dark"] .df-builder .df-library-tab.is-active .df-library-tab-count,
html[data-bs-theme="dark"] .df-builder .df-library-tab.is-active .df-library-tab-count,
body[data-bs-theme="dark"] .df-builder .df-library-tab.is-active .df-library-tab-count{
  background:rgba(230,0,70,.22)!important;
  color:#ffd3de!important;
}
@media (prefers-color-scheme:dark){
 .df-builder .df-library-tab{background:#1f2937!important;color:#f4f7fb!important;border-color:#4a596b!important;box-shadow:none!important}
 .df-builder .df-library-tab:hover{background:#2a3747!important;color:#fff!important;border-color:#64748b!important}
 .df-builder .df-library-tab.is-active{background:rgba(230,0,70,.14)!important;color:#ff9bb4!important;border-color:#e60046!important;box-shadow:0 0 0 2px rgba(230,0,70,.12)!important}
 .df-builder .df-library-tab-count{background:#334155!important;color:#e5edf7!important}
 .df-builder .df-library-tab.is-active .df-library-tab-count{background:rgba(230,0,70,.22)!important;color:#ffd3de!important}
 .df-builder .df-status-remove{color:#ff9aa8!important;background:rgba(220,53,69,.10)!important;border-color:#b94b59!important}
 .df-builder .df-status-remove:hover,.df-builder .df-status-remove:focus-visible{color:#fff!important;background:#9f2f3d!important;border-color:#d95d6c!important}
}
@media(max-width:560px){
 .df-builder .df-status-editor{gap:14px}
 .df-builder .df-status-row{
   grid-template-columns:minmax(0,1fr) minmax(0,1fr)!important;
   gap:10px!important;
   padding:11px!important;
   border:1px solid var(--df-theme-border,var(--df-border))!important;
   border-radius:8px!important;
   background:var(--df-theme-surface-soft,var(--bs-tertiary-bg,#f7f8fa))!important;
 }
 .df-builder .df-status-row>input{min-width:0}
 .df-builder .df-status-color-wrap{grid-column:1!important;min-width:0}
 .df-builder .df-status-remove{grid-column:2!important;width:100%!important;height:44px!important;min-width:0}
}


/* Forms 1.3.7 layout dark-mode and spacing fixes */
.df-builder .df-layout-newrow{
  margin-top:16px;
  margin-bottom:18px;
  padding:12px 14px;
  line-height:1.45;
}
.df-builder .df-layout-advanced-box{
  margin-top:18px;
}
[data-bs-theme="dark"] .df-builder .df-layout-row,
html[data-bs-theme="dark"] .df-builder .df-layout-row,
body[data-bs-theme="dark"] .df-builder .df-layout-row{
  background:rgba(255,255,255,.035)!important;
  border-color:#657386!important;
}
[data-bs-theme="dark"] .df-builder .df-layout-card,
html[data-bs-theme="dark"] .df-builder .df-layout-card,
body[data-bs-theme="dark"] .df-builder .df-layout-card{
  background:#151c24!important;
  color:#f4f7fb!important;
  border-color:#5b697a!important;
  box-shadow:0 1px 2px rgba(0,0,0,.28)!important;
}
[data-bs-theme="dark"] .df-builder .df-layout-card strong,
html[data-bs-theme="dark"] .df-builder .df-layout-card strong,
body[data-bs-theme="dark"] .df-builder .df-layout-card strong{
  color:#f4f7fb!important;
}
[data-bs-theme="dark"] .df-builder .df-layout-handle,
html[data-bs-theme="dark"] .df-builder .df-layout-handle,
body[data-bs-theme="dark"] .df-builder .df-layout-handle{
  color:#a9b6c6!important;
}
[data-bs-theme="dark"] .df-builder .df-layout-card select,
html[data-bs-theme="dark"] .df-builder .df-layout-card select,
body[data-bs-theme="dark"] .df-builder .df-layout-card select{
  background:#111820!important;
  color:#f8fafc!important;
  border-color:#5b697a!important;
}
[data-bs-theme="dark"] .df-builder .df-layout-newrow,
html[data-bs-theme="dark"] .df-builder .df-layout-newrow,
body[data-bs-theme="dark"] .df-builder .df-layout-newrow{
  background:rgba(255,255,255,.025)!important;
  color:#aeb9c7!important;
  border-color:#758294!important;
}
@media (prefers-color-scheme:dark){
 .df-builder .df-layout-row{background:rgba(255,255,255,.035)!important;border-color:#657386!important}
 .df-builder .df-layout-card{background:#151c24!important;color:#f4f7fb!important;border-color:#5b697a!important;box-shadow:0 1px 2px rgba(0,0,0,.28)!important}
 .df-builder .df-layout-card strong{color:#f4f7fb!important}
 .df-builder .df-layout-handle{color:#a9b6c6!important}
 .df-builder .df-layout-card select{background:#111820!important;color:#f8fafc!important;border-color:#5b697a!important}
 .df-builder .df-layout-newrow{background:rgba(255,255,255,.025)!important;color:#aeb9c7!important;border-color:#758294!important}
}


/* Forms 1.3.8 light accordion + saved-field controls */
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle{
  background:#f6f7f9!important;
  color:#1f2937!important;
  border-color:#d9dee5!important;
}
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle:hover{
  background:#eef1f4!important;
}
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section.is-open>.df-section-toggle{
  background:#f1f4f8!important;
}
.df-builder .df-save-preset svg{width:16px;height:16px;display:block}
.df-builder .df-save-preset.is-saved{
  border-color:#198754!important;
  color:#198754!important;
  box-shadow:0 0 0 2px color-mix(in srgb,#198754 14%,transparent)!important;
}
.df-builder .df-lib-actions{display:flex;align-items:center;gap:6px}
.df-builder .df-lib-delete{
  min-width:34px;height:34px;border:1px solid #dc3545;border-radius:5px;background:transparent;color:#b42332;font-weight:900;cursor:pointer;
}
.df-builder .df-lib-delete:hover,.df-builder .df-lib-delete:focus-visible{background:#dc3545;color:#fff}
@media(max-width:560px){
 .df-builder .df-mini-actions{flex-wrap:wrap}
 .df-builder .df-save-preset{order:-1}
}


/* Forms 1.3.9: accordion contrast fix in Joomla light mode. */
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle,
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle *,
html[data-bs-theme="light"] .df-builder .df-section-toggle,
html[data-bs-theme="light"] .df-builder .df-section-toggle *{
  color:#1f2937!important;
}
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle,
html[data-bs-theme="light"] .df-builder .df-section-toggle{
  background:#f6f7f9!important;
  border-color:#d9dee5!important;
  box-shadow:none!important;
}
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle:hover,
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle:focus-visible,
html[data-bs-theme="light"] .df-builder .df-section-toggle:hover,
html[data-bs-theme="light"] .df-builder .df-section-toggle:focus-visible{
  background:#eef1f4!important;
  color:#1f2937!important;
}
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section.is-open>.df-section-toggle,
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section.is-open>.df-section-toggle *,
html[data-bs-theme="light"] .df-builder .df-section.is-open>.df-section-toggle,
html[data-bs-theme="light"] .df-builder .df-section.is-open>.df-section-toggle *{
  background:#f1f4f8!important;
  color:#1f2937!important;
}
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle svg,
html[data-bs-theme="light"] .df-builder .df-section-toggle svg{
  color:#1f2937!important;
  fill:currentColor!important;
  stroke:currentColor!important;
}
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle .df-section-chevron,
html[data-bs-theme="light"] .df-builder .df-section-toggle .df-section-chevron{
  color:#1f2937!important;
}


/* Forms 1.3.10: template cards have an explicit facsimile-preview action. */
.df-builder .df-email-choice{position:relative;cursor:pointer;transition:border-color .16s ease,box-shadow .16s ease,transform .16s ease}
.df-builder .df-email-choice:hover{border-color:#9aa7b8;box-shadow:0 4px 14px rgba(15,23,42,.08)}
.df-builder .df-email-thumb{position:relative;overflow:hidden;cursor:pointer}
.df-builder .df-email-thumb-art{display:block;width:100%;height:100%}
.df-builder .df-email-preview-label{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);display:inline-flex;align-items:center;gap:5px;padding:5px 9px;border-radius:999px;background:rgba(31,41,55,.9);color:#fff;font-size:11px;font-weight:800;white-space:nowrap;opacity:0;transition:opacity .16s ease,transform .16s ease;pointer-events:none}
.df-builder .df-email-thumb:hover .df-email-preview-label,.df-builder .df-email-thumb:focus-visible .df-email-preview-label{opacity:1;transform:translate(-50%,-50%) scale(1.02)}
.df-builder .df-email-thumb:focus-visible{outline:2px solid var(--bs-primary,#0d6efd);outline-offset:2px}
.df-builder .df-preview-modal.is-open{display:grid!important}
@media(max-width:560px){.df-builder .df-email-preview-label{opacity:.88;font-size:10px;padding:4px 7px}}
@media(prefers-reduced-motion:reduce){.df-builder .df-email-choice,.df-builder .df-email-preview-label{transition:none}}


/* Forms 1.3.11: explicit, delegated email facsimile preview controls. */
.df-builder .df-email-choice-foot{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-top:7px}
.df-builder .df-email-radio{display:flex;align-items:center;gap:7px;min-width:0;font-size:12px;font-weight:800}
.df-builder .df-email-preview-btn{border:0;background:transparent;color:var(--bs-link-color,#0d6efd);font-size:11px;font-weight:800;padding:3px 5px;border-radius:4px;cursor:pointer;white-space:nowrap}
.df-builder .df-email-preview-btn:hover,.df-builder .df-email-preview-btn:focus-visible{background:color-mix(in srgb,var(--bs-primary,#0d6efd) 10%,transparent);outline:none}
.df-builder .df-email-preview-label{opacity:.9;pointer-events:none}
.df-builder .df-email-thumb:hover .df-email-preview-label,.df-builder .df-email-thumb:focus-visible .df-email-preview-label{opacity:1}
.df-preview-modal.is-open{display:grid!important;z-index:2147483000!important}
@media(max-width:560px){.df-builder .df-email-choice-foot{align-items:flex-start;flex-direction:column}.df-builder .df-email-preview-btn{padding-left:0}}


/* Forms 1.3.12: self-contained live email preview modal. */
.df-live-preview-modal{position:fixed;inset:0;z-index:2147483647;display:grid;place-items:center;padding:20px;pointer-events:auto}
.df-live-preview-backdrop{position:absolute;inset:0;background:rgba(15,23,42,.68);backdrop-filter:blur(2px)}
.df-live-preview-dialog{position:relative;z-index:1;width:min(860px,calc(100vw - 32px));max-height:calc(100vh - 32px);display:flex;flex-direction:column;background:var(--bs-body-bg,#fff);color:var(--bs-body-color,#1f2937);border:1px solid var(--bs-border-color,#d9dee5);border-radius:14px;box-shadow:0 24px 70px rgba(0,0,0,.28);overflow:hidden}
.df-live-preview-head,.df-live-preview-foot{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:14px 16px;background:var(--bs-tertiary-bg,#f6f7f9);border-bottom:1px solid var(--bs-border-color,#d9dee5)}
.df-live-preview-foot{justify-content:flex-end;border-top:1px solid var(--bs-border-color,#d9dee5);border-bottom:0}
.df-live-preview-body{padding:18px;overflow:auto;background:var(--bs-body-bg,#fff)}
.df-live-preview-close{cursor:pointer}
button.df-live-preview-close{min-width:38px;min-height:38px;border:1px solid var(--bs-border-color,#d9dee5);border-radius:8px;background:var(--bs-body-bg,#fff);color:inherit;font-weight:800}
@media(max-width:560px){.df-live-preview-modal{padding:10px}.df-live-preview-dialog{width:calc(100vw - 20px);max-height:calc(100vh - 20px)}.df-live-preview-body{padding:12px}}


/* Forms 1.3.13: compact visual field builder. */
.df-builder-workspace{display:grid;grid-template-columns:minmax(0,1fr) minmax(300px,360px);gap:14px;align-items:start}
.df-form-canvas-panel,.df-properties-panel{min-width:0;border:1px solid var(--df-border);border-radius:8px;background:var(--bs-body-bg,#fff)}
.df-form-canvas-panel{padding:14px}.df-properties-panel{position:sticky;top:12px;max-height:calc(100vh - 32px);overflow:auto}
.df-properties-title{padding:13px 14px;border-bottom:1px solid var(--df-border);background:var(--bs-tertiary-bg,#f7f8fa)}
.df-properties-title strong,.df-properties-title span{display:block}.df-properties-title span{margin-top:2px;color:var(--bs-secondary-color,#667085);font-size:11px}
.df-builder-workspace .df-layout-canvas{gap:7px}.df-builder-workspace .df-layout-row{position:relative;min-height:54px;padding:5px;gap:6px;border-style:solid;background:color-mix(in srgb,var(--bs-tertiary-bg,#f7f8fa) 38%,transparent)}
.df-builder-workspace .df-layout-row.is-over{border-color:var(--df);box-shadow:inset 0 0 0 1px var(--df)}
.df-builder-workspace .df-layout-card{min-width:110px;min-height:42px;padding:5px 7px;gap:7px;border-radius:6px;box-shadow:none;transition:border-color .16s,box-shadow .16s,background .16s}
.df-builder-workspace .df-layout-card:hover,.df-builder-workspace .df-layout-card.is-active{border-color:var(--df);box-shadow:0 0 0 2px color-mix(in srgb,var(--df) 12%,transparent)}
.df-builder-workspace .df-layout-card strong{font-size:13px}.df-builder-workspace .df-layout-handle{cursor:grab;font-size:16px;line-height:1;letter-spacing:-3px;padding:7px 3px}
.df-layout-meta{display:flex;align-items:center;gap:4px;margin-left:auto}.df-layout-type{max-width:92px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;padding:3px 6px;border-radius:999px;background:color-mix(in srgb,var(--df) 9%,transparent);color:var(--df);font-size:10px;font-weight:800}
.df-builder-workspace .df-layout-card select{min-width:62px;min-height:29px;height:29px;padding:2px 5px;font-size:11px}
.df-layout-actions{display:flex;align-items:center;gap:2px}.df-layout-actions button{width:29px;height:29px;padding:0;border:0;border-radius:5px;background:transparent;color:inherit;cursor:pointer;font-size:14px}.df-layout-actions button:hover{background:var(--bs-tertiary-bg,#eef1f5);color:var(--df)}.df-layout-actions .df-canvas-remove:hover{color:#b42318}
.df-builder-workspace .df-layout-newrow{display:none;min-height:34px;margin-top:7px;border-color:var(--df);color:var(--df);background:color-mix(in srgb,var(--df) 6%,transparent);font-weight:800}.df-builder-workspace.is-dragging .df-layout-newrow{display:flex}
.df-add-field-main{width:100%;min-height:38px;margin-top:9px;border:1px dashed color-mix(in srgb,var(--df) 70%,var(--df-border));border-radius:7px;background:color-mix(in srgb,var(--df) 4%,var(--bs-body-bg,#fff));color:var(--df);font-weight:850;cursor:pointer}.df-add-field-main:hover{background:color-mix(in srgb,var(--df) 9%,var(--bs-body-bg,#fff));border-style:solid}
.df-properties-panel .df-selected-empty{margin:12px;padding:20px 12px}.df-properties-panel .df-selected-item{display:none;border:0;border-radius:0}.df-properties-panel .df-selected-item.is-open{display:block}.df-properties-panel .df-selected-top{padding:9px 11px}.df-properties-panel .df-field-toggle{pointer-events:none}.df-properties-panel .df-field-chevron{display:none}.df-properties-panel .df-selected-config{grid-template-columns:1fr;gap:8px;padding:11px}.df-properties-panel .df-selected-config .full,.df-properties-panel .df-config-panel,.df-properties-panel .df-condition-details,.df-properties-panel .df-field-advanced{grid-column:auto}.df-properties-panel .df-selected-config input:not([type=checkbox]):not([type=radio]),.df-properties-panel .df-selected-config select{min-height:35px;padding:6px 8px}.df-properties-panel .df-mini-actions button[data-act="up"],.df-properties-panel .df-mini-actions button[data-act="down"]{display:none}
.df-field-width-pills{display:grid;grid-template-columns:repeat(3,1fr);gap:5px}.df-field-width-pills button{min-height:31px;border:1px solid var(--df-border);border-radius:5px;background:var(--bs-body-bg,#fff);color:inherit;font-size:11px;font-weight:800;cursor:pointer}.df-field-width-pills button.is-active{border-color:var(--df);background:color-mix(in srgb,var(--df) 10%,var(--bs-body-bg,#fff));color:var(--df)}
@media(max-width:1050px){.df-builder-workspace{grid-template-columns:1fr}.df-properties-panel{position:static;max-height:none}}
@media(max-width:800px){.df-builder-workspace .df-layout-row{flex-direction:row;flex-wrap:wrap}.df-builder-workspace .df-layout-card{width:100%!important}.df-layout-type{display:none}}
@media(max-width:560px){.df-form-canvas-panel{padding:10px}.df-builder-workspace .df-layout-card{min-height:46px}.df-layout-actions button{width:32px;height:32px}.df-builder-workspace .df-layout-card select{min-width:58px}.df-layout-visual-head .df-switch{width:100%}}


/* Forms 1.3.14: balanced rows, safer editing and clearer controls. */
.df-editor-toolbar{position:sticky;top:0;z-index:40;display:flex;align-items:center;justify-content:space-between;gap:10px;margin:0 0 12px;padding:8px;border:1px solid var(--df-border);border-radius:8px;background:color-mix(in srgb,var(--bs-body-bg,#fff) 94%,transparent);backdrop-filter:blur(7px)}
.df-editor-toolbar button{min-height:34px;padding:6px 11px;border:1px solid var(--df-border);background:var(--bs-body-bg,#fff);color:inherit;font-weight:750;cursor:pointer}.df-editor-toolbar button:first-child{border-radius:6px 0 0 6px}.df-editor-toolbar button:last-child{border-radius:0 6px 6px 0}.df-editor-toolbar button:disabled{opacity:.42;cursor:not-allowed}.df-history-actions,.df-edit-mode{display:flex}.df-lock-toggle.is-active{background:#26364a;color:#fff;border-color:#26364a}
.df-builder.is-locked #df-builder-form input:not([type=hidden]),.df-builder.is-locked #df-builder-form select,.df-builder.is-locked #df-builder-form textarea{opacity:.72}.df-builder.is-locked .df-layout-handle{cursor:not-allowed}.df-builder.is-locked .df-layout-card{box-shadow:none}
.df-required-badge{display:inline-flex;align-items:center;padding:3px 7px;border-radius:999px;background:#fee4e8;color:#c5003c;font-size:10px;font-weight:850;white-space:nowrap}.df-summary-chip.df-required-badge{border-color:#f5a3ba;background:#fee4e8;color:#b90038}
.df-canvas-remove{color:#b42318!important}.df-main-settings,.df-condition-details,.df-tax-links{border:1px solid var(--df-border);border-radius:6px;background:color-mix(in srgb,var(--bs-tertiary-bg,#f7f8fa) 45%,transparent)}.df-main-settings>summary,.df-condition-details>summary,.df-tax-links>summary{cursor:pointer;padding:10px 11px;color:#2869b2;font-weight:800}.df-main-settings-body,.df-condition-body,.df-tax-links-body{padding:0 11px 11px}.df-main-settings-grid{display:grid;gap:8px}.df-condition-controls{display:grid;grid-template-columns:1fr;gap:8px;margin-top:8px}.df-condition-details .df-condition-row{grid-template-columns:1fr}.df-condition-details [data-add-condition]{margin-top:9px}
.df-status-row{grid-template-columns:minmax(0,1fr) 110px 34px}.df-status-row.is-conflict input[data-status-label]{border-color:#dc3545;box-shadow:0 0 0 2px rgba(220,53,69,.12)}.df-status-warning{margin:8px 0;padding:8px 10px;border:1px solid #dc3545;border-radius:6px;background:#fff1f3;color:#a40024;font-weight:700}
.df-email-templates{grid-template-columns:repeat(6,minmax(0,1fr))!important}.df-email-thumb{width:100%;height:105px;padding:0!important;background:#eef1f5!important;border:0!important}.df-email-thumb-frame{display:block;width:500%;height:525px;border:0;transform:scale(.2);transform-origin:top left;pointer-events:none;background:#fff}.df-email-choice-foot{justify-content:flex-start}.df-email-preview-btn{display:none!important}.df-email-preview-label{opacity:0!important}.df-email-thumb:hover .df-email-preview-label,.df-email-thumb:focus-visible .df-email-preview-label{opacity:1!important}
@media(max-width:900px){.df-email-templates{grid-template-columns:repeat(3,minmax(0,1fr))!important}.df-email-thumb{height:120px}.df-email-thumb-frame{transform:scale(.2)}}
@media(max-width:560px){.df-editor-toolbar{align-items:stretch;flex-direction:column}.df-editor-toolbar>div{display:grid;grid-template-columns:1fr 1fr}.df-email-templates{grid-template-columns:1fr!important}.df-email-thumb{height:150px}.df-email-thumb-frame{transform:scale(.25)}}


/* Forms 1.3.15: explicit light-mode surfaces and compact field layout accordion. */
.df-layout-settings{grid-column:1/-1;border:1px solid var(--df-border);border-radius:6px;background:color-mix(in srgb,var(--bs-tertiary-bg,#f7f8fa) 45%,transparent);overflow:hidden}
.df-layout-settings>summary{cursor:pointer;list-style:none;display:flex;align-items:center;justify-content:space-between;padding:10px 11px;color:#2869b2;font-weight:800}
.df-layout-settings>summary::-webkit-details-marker{display:none}
.df-layout-settings>summary:after{content:'⌄';font-size:12px;transition:transform .2s ease}
.df-layout-settings[open]>summary:after{transform:rotate(180deg)}
.df-layout-settings-body{display:grid;gap:12px;padding:0 11px 11px}
.df-field-width-block>label{display:block;margin-bottom:7px;font-weight:750}

/* Joomla can be light while the operating system prefers dark. These final rules make the Builder follow Joomla, not the OS. */
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-layout-row{
  background:#f6f7f9!important;border-color:#d9dee5!important;color:#1f2937!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-layout-card{
  background:#fff!important;color:#1f2937!important;border-color:#d9dee5!important;box-shadow:0 1px 2px rgba(15,23,42,.05)!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-layout-card strong{color:#1f2937!important}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-layout-handle{color:#7b8796!important}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-layout-card select{
  background:#fff!important;color:#1f2937!important;border-color:#cfd6df!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-layout-newrow{
  background:#fff!important;color:#667085!important;border-color:#cfd6df!important;
}

html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-subbox,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-email-block,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-email-block-body,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-email-choice,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-email-special,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-additional-card{
  background:#fff!important;color:#1f2937!important;border-color:#d9dee5!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-email-block>summary{
  background:#f6f7f9!important;color:#1f2937!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-subbox h4,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-email-block summary,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-email-block label,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-subbox label,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-check,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-label-info,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-email-choice-foot,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-status-color-value{
  color:#1f2937!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-note{color:#667085!important}

html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-status-row input:not([type=color]),
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-status-remove,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-column-item,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-field input:not([type=checkbox]):not([type=radio]):not([type=color]),
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-field textarea,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-field select,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-codearea,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-tokenbar select{
  background:#fff!important;color:#1f2937!important;border-color:#cfd6df!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-codearea::placeholder,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder input::placeholder,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder textarea::placeholder{color:#8a94a3!important;opacity:1}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-column-item{color:#1f2937!important}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-status-remove{color:#b42318!important;background:#fff!important;border-color:#e3a3aa!important}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-status-remove:hover,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-status-remove:focus-visible{background:#fff1f3!important;color:#a10f25!important;border-color:#dc3545!important}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-warning{background:#fff8e8!important;color:#5f4600!important}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-layout-settings,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-main-settings,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-condition-details,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-tax-links{
  background:#f8f9fb!important;color:#1f2937!important;border-color:#d9dee5!important;
}


/* Forms 1.3.16: toolbar contrast, neutral navigation and readable closed-state labels. */
.df-editor-toolbar{
  display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;
  margin:0 0 12px;padding:8px 10px;border:1px solid var(--df-border);border-radius:8px;
  background:var(--bs-body-bg,#fff);
}
.df-editor-toolbar .df-history-actions,.df-editor-toolbar .df-edit-mode{display:flex;align-items:center;flex-wrap:wrap}
.df-editor-toolbar button{transition:background .16s ease,border-color .16s ease,color .16s ease,opacity .16s ease}
.df-editor-toolbar .df-save-top{
  min-height:34px;margin-left:8px;padding:6px 13px;border:1px solid var(--df)!important;border-radius:6px!important;
  background:var(--df)!important;color:#fff!important;font-weight:800;cursor:pointer;
}
.df-editor-toolbar .df-save-top:hover,.df-editor-toolbar .df-save-top:focus-visible{background:var(--df-dark)!important;border-color:var(--df-dark)!important;color:#fff!important}
.df-editor-toolbar .df-save-top:disabled{opacity:.46!important;cursor:not-allowed!important}

/* Light mode: toolbar and navigation stay neutral, like Joomla's Menu button. */
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-editor-toolbar,
html[data-bs-theme="light"] .df-builder .df-editor-toolbar{
  background:#fff!important;border-color:#d9dee5!important;color:#1f2937!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-editor-toolbar button:not(.df-save-top),
html[data-bs-theme="light"] .df-builder .df-editor-toolbar button:not(.df-save-top){
  background:#fff!important;color:#1f2937!important;border-color:#d9dee5!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-editor-toolbar button:not(.df-save-top):hover,
html[data-bs-theme="light"] .df-builder .df-editor-toolbar button:not(.df-save-top):hover{
  background:#f6f7f9!important;color:#1f2937!important;border-color:#cfd6df!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-lock-toggle.is-active,
html[data-bs-theme="light"] .df-builder .df-lock-toggle.is-active{
  background:#eef1f4!important;color:#1f2937!important;border-color:#c7d0da!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-back-btn,
html[data-bs-theme="light"] .df-builder .df-back-btn{
  background:#fff!important;color:#1f2937!important;border-color:#d9dee5!important;box-shadow:none!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-back-btn:hover,
html[data-bs-theme="light"] .df-builder .df-back-btn:hover{
  background:#f6f7f9!important;color:#1f2937!important;border-color:#cfd6df!important;
}

/* The two closed-form labels must remain readable on the pale pink semantic panel. */
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-closed-box label,
html[data-bs-theme="light"] .df-builder .df-closed-box label{
  color:#7a1631!important;opacity:1!important;font-weight:750!important;
}

/* Dark mode: no white action strip and no washed-out controls. */
html[data-bs-theme="dark"] .df-builder .df-editor-toolbar,
body[data-bs-theme="dark"] .df-builder .df-editor-toolbar,
html[data-color-scheme="dark"] .df-builder .df-editor-toolbar{
  background:#1f2937!important;border-color:#475569!important;color:#f8fafc!important;
}
html[data-bs-theme="dark"] .df-builder .df-editor-toolbar button:not(.df-save-top),
body[data-bs-theme="dark"] .df-builder .df-editor-toolbar button:not(.df-save-top),
html[data-color-scheme="dark"] .df-builder .df-editor-toolbar button:not(.df-save-top){
  background:#111827!important;color:#f8fafc!important;border-color:#475569!important;
}
html[data-bs-theme="dark"] .df-builder .df-editor-toolbar button:not(.df-save-top):hover,
body[data-bs-theme="dark"] .df-builder .df-editor-toolbar button:not(.df-save-top):hover,
html[data-color-scheme="dark"] .df-builder .df-editor-toolbar button:not(.df-save-top):hover{
  background:#273548!important;color:#fff!important;border-color:#64748b!important;
}
html[data-bs-theme="dark"] .df-builder .df-lock-toggle.is-active,
body[data-bs-theme="dark"] .df-builder .df-lock-toggle.is-active,
html[data-color-scheme="dark"] .df-builder .df-lock-toggle.is-active{
  background:#334155!important;color:#fff!important;border-color:#64748b!important;
}
html[data-bs-theme="dark"] .df-builder .df-back-btn,
body[data-bs-theme="dark"] .df-builder .df-back-btn,
html[data-color-scheme="dark"] .df-builder .df-back-btn{
  background:#1f2937!important;color:#f8fafc!important;border-color:#475569!important;box-shadow:none!important;
}
html[data-bs-theme="dark"] .df-builder .df-back-btn:hover,
body[data-bs-theme="dark"] .df-builder .df-back-btn:hover,
html[data-color-scheme="dark"] .df-builder .df-back-btn:hover{
  background:#273548!important;color:#fff!important;border-color:#64748b!important;
}
@media(max-width:800px){
  .df-editor-toolbar{align-items:stretch}
  .df-editor-toolbar .df-edit-mode{margin-left:auto}
  .df-editor-toolbar .df-save-top{margin-left:6px}
}


/* Forms 1.3.17: quick-model save action and light/dark contrast fixes. */
.df-layout-head-actions{display:flex;align-items:center;justify-content:flex-end;gap:12px;flex-wrap:wrap}
.df-save-structure{white-space:nowrap}
.df-saved-quick-heading{margin:13px 0 7px;font-size:12px;font-weight:850;color:var(--bs-secondary-color,#667085);text-transform:uppercase;letter-spacing:.04em}
.df-saved-quick-row{margin-bottom:8px}
.df-saved-quick-item{display:inline-flex;align-items:stretch;border:1px solid var(--df-border);border-radius:6px;overflow:hidden;background:var(--bs-body-bg,#fff)}
.df-saved-quick-item button{border:0!important;border-radius:0!important;box-shadow:none!important}
.df-saved-quick-use{background:var(--bs-body-bg,#fff)!important;color:inherit!important}
.df-saved-quick-use.is-active{color:var(--df)!important;background:color-mix(in srgb,var(--df) 7%,var(--bs-body-bg,#fff))!important}
.df-saved-quick-delete{min-width:34px!important;padding:0 8px!important;background:transparent!important;color:#b42318!important;border-left:1px solid var(--df-border)!important}
.df-saved-quick-delete:hover{background:#fff1f3!important;color:#a40024!important}

/* Library category pills: neutral by default, red only as a selection accent. */
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-library-tab,
html[data-bs-theme="light"] .df-builder .df-library-tab{
 background:#f6f7f9!important;color:#1f2937!important;border-color:#d9dee5!important;box-shadow:none!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-library-tab:hover,
html[data-bs-theme="light"] .df-builder .df-library-tab:hover{
 background:#eef1f4!important;color:#1f2937!important;border-color:#cfd6df!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-library-tab.is-active,
html[data-bs-theme="light"] .df-builder .df-library-tab.is-active{
 background:#fff!important;color:var(--df)!important;border-color:var(--df)!important;box-shadow:0 0 0 2px color-mix(in srgb,var(--df) 10%,transparent)!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-library-tab-count,
html[data-bs-theme="light"] .df-builder .df-library-tab-count{
 background:#e7ebf0!important;color:#344054!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-library-tab.is-active .df-library-tab-count,
html[data-bs-theme="light"] .df-builder .df-library-tab.is-active .df-library-tab-count{
 background:#ffe5ec!important;color:var(--df)!important;
}

/* Columns list: never inherit white text while Joomla is in light mode. */
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-column-item,
html[data-bs-theme="light"] .df-builder .df-column-item{
 background:#fff!important;color:#1f2937!important;border-color:#d9dee5!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-column-item *,
html[data-bs-theme="light"] .df-builder .df-column-item *{color:#1f2937!important;opacity:1!important}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-column-item:has(input:checked),
html[data-bs-theme="light"] .df-builder .df-column-item:has(input:checked){background:#f8fafc!important}

/* Status delete is destructive: filled red removes ambiguity. */
.df-builder .df-status-remove{background:#dc3545!important;border-color:#dc3545!important;color:#fff!important;font-weight:850;cursor:pointer}
.df-builder .df-status-remove:hover,.df-builder .df-status-remove:focus-visible{background:#b4232f!important;border-color:#b4232f!important;color:#fff!important}

html[data-bs-theme="dark"] .df-builder .df-library-tab,
body[data-bs-theme="dark"] .df-builder .df-library-tab,
html[data-color-scheme="dark"] .df-builder .df-library-tab{background:#1f2937!important;color:#f8fafc!important;border-color:#475569!important}
html[data-bs-theme="dark"] .df-builder .df-library-tab.is-active,
body[data-bs-theme="dark"] .df-builder .df-library-tab.is-active,
html[data-color-scheme="dark"] .df-builder .df-library-tab.is-active{background:#111827!important;color:#ff91ad!important;border-color:#e60046!important;box-shadow:0 0 0 2px rgba(230,0,70,.16)!important}
html[data-bs-theme="dark"] .df-builder .df-library-tab-count,
body[data-bs-theme="dark"] .df-builder .df-library-tab-count,
html[data-color-scheme="dark"] .df-builder .df-library-tab-count{background:#334155!important;color:#f8fafc!important}
html[data-bs-theme="dark"] .df-builder .df-column-item,
body[data-bs-theme="dark"] .df-builder .df-column-item,
html[data-color-scheme="dark"] .df-builder .df-column-item{background:#111827!important;color:#f8fafc!important;border-color:#475569!important}
html[data-bs-theme="dark"] .df-builder .df-column-item *,
body[data-bs-theme="dark"] .df-builder .df-column-item *,
html[data-color-scheme="dark"] .df-builder .df-column-item *{color:#f8fafc!important;opacity:1!important}
@media(max-width:800px){.df-layout-head-actions{width:100%;justify-content:flex-start}.df-save-structure{order:2}}


/* Forms 1.3.18: save recovery, compact properties and confirmation controls. */
.df-save-structure{font-weight:800!important}
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


/* Forms 1.3.24: single button system. Do not derive light buttons from Bootstrap/OS colour variables. */
.df-builder,.df-action-modal,.df-live-preview-modal,.df-preview-modal{
  --df-btn-bg:#fff;
  --df-btn-text:#1f2937;
  --df-btn-border:#d9dee5;
  --df-btn-hover-bg:#f6f7f9;
  --df-btn-hover-border:#cfd6df;
}
html[data-bs-theme="dark"] .df-builder,body[data-bs-theme="dark"] .df-builder,html[data-color-scheme="dark"] .df-builder,
html[data-bs-theme="dark"] .df-action-modal,body[data-bs-theme="dark"] .df-action-modal,html[data-color-scheme="dark"] .df-action-modal,
html[data-bs-theme="dark"] .df-live-preview-modal,body[data-bs-theme="dark"] .df-live-preview-modal,html[data-color-scheme="dark"] .df-live-preview-modal,
html[data-bs-theme="dark"] .df-preview-modal,body[data-bs-theme="dark"] .df-preview-modal,html[data-color-scheme="dark"] .df-preview-modal{
  --df-btn-bg:#111827;
  --df-btn-text:#f8fafc;
  --df-btn-border:#475569;
  --df-btn-hover-bg:#273548;
  --df-btn-hover-border:#64748b;
}
.df-builder .df-btn,.df-action-modal .df-btn,.df-live-preview-modal .df-btn,.df-preview-modal .df-btn{
  background:var(--df-btn-bg)!important;
  color:var(--df-btn-text)!important;
  border-color:var(--df-btn-border)!important;
  box-shadow:none!important;
}
.df-builder .df-btn:hover,.df-builder .df-btn:focus-visible,
.df-action-modal .df-btn:hover,.df-action-modal .df-btn:focus-visible,
.df-live-preview-modal .df-btn:hover,.df-live-preview-modal .df-btn:focus-visible,
.df-preview-modal .df-btn:hover,.df-preview-modal .df-btn:focus-visible{
  background:var(--df-btn-hover-bg)!important;
  color:var(--df-btn-text)!important;
  border-color:var(--df-btn-hover-border)!important;
}
.df-builder .df-btn.df-primary,.df-builder .df-btn.df-btn-primary,.df-builder .df-save-structure,.df-builder .df-add,
.df-action-modal .df-btn.df-primary,.df-action-modal .df-btn.df-btn-primary{
  background:var(--df)!important;
  border-color:var(--df)!important;
  color:#fff!important;
}
.df-builder .df-btn.df-primary:hover,.df-builder .df-btn.df-primary:focus-visible,
.df-builder .df-btn.df-btn-primary:hover,.df-builder .df-btn.df-btn-primary:focus-visible,
.df-builder .df-save-structure:hover,.df-builder .df-save-structure:focus-visible,.df-builder .df-add:hover,
.df-action-modal .df-btn.df-primary:hover,.df-action-modal .df-btn.df-primary:focus-visible,
.df-action-modal .df-btn.df-btn-primary:hover,.df-action-modal .df-btn.df-btn-primary:focus-visible{
  background:var(--df-dark)!important;
  border-color:var(--df-dark)!important;
  color:#fff!important;
}
.df-builder .df-btn.df-danger,.df-builder .df-btn.df-btn-danger{
  background:#fff1f3!important;
  border-color:#e69aa7!important;
  color:#a4132d!important;
}
.df-builder .df-btn.df-danger:hover,.df-builder .df-btn.df-btn-danger:hover,
.df-builder .df-btn.df-danger:focus-visible,.df-builder .df-btn.df-btn-danger:focus-visible{
  background:#dc3545!important;
  border-color:#dc3545!important;
  color:#fff!important;
}
html[data-bs-theme="dark"] .df-builder .df-btn.df-danger,body[data-bs-theme="dark"] .df-builder .df-btn.df-danger,html[data-color-scheme="dark"] .df-builder .df-btn.df-danger,
html[data-bs-theme="dark"] .df-builder .df-btn.df-btn-danger,body[data-bs-theme="dark"] .df-builder .df-btn.df-btn-danger,html[data-color-scheme="dark"] .df-builder .df-btn.df-btn-danger{
  background:#4a1e2b!important;
  border-color:#a94e68!important;
  color:#ffc0d0!important;
}
.df-summary-chip{background:#eef1f4!important;border-color:#d5dbe3!important;color:#4b5563!important;font-weight:750}.df-summary-chip.df-required-badge,.df-required-badge{background:#fff0f4!important;border-color:#f1a7b9!important;color:#a4133c!important}
.df-selected-config details.full>summary,.df-main-settings>summary,.df-layout-settings>summary,.df-condition-details>summary,.df-tax-links>summary{min-height:40px!important;padding:8px 10px!important;font-size:14px!important;line-height:1.25!important}.df-main-settings-body,.df-layout-settings-body,.df-condition-body,.df-tax-links-body{padding:8px 10px 10px!important}.df-selected-config{gap:6px!important;padding:9px!important}.df-main-settings-grid,.df-condition-controls{gap:6px 8px!important}.df-selected-config-wrap{padding-top:5px!important}
.df-builder-workspace .df-layout-row{display:grid!important;align-items:stretch!important}.df-layout-card{overflow:visible}.df-layout-drop-guide{position:absolute;inset:3px;z-index:15;display:none;grid-template-columns:1fr 1fr 1fr;gap:4px;pointer-events:none}.df-builder-workspace.is-dragging .df-layout-card:not(.dragging) .df-layout-drop-guide{display:grid;pointer-events:auto}.df-layout-drop-guide span{display:flex;align-items:center;justify-content:center;text-align:center;padding:4px;border:1px dashed #4b8fe2;border-radius:5px;background:rgba(239,246,255,.94);color:#1d4f91;font-size:10px;font-weight:850;cursor:copy}.df-layout-drop-guide span.is-over{background:#dbeafe;border-style:solid;box-shadow:inset 0 0 0 1px #2563eb}.df-layout-drop-guide [data-drop-newrow]{background:rgba(238,242,255,.96);color:#4338ca;border-color:#818cf8}
.df-email-choice-foot{justify-content:space-between!important}.df-email-preview-btn{display:inline-flex!important;align-items:center!important;justify-content:center!important;border:0!important;background:transparent!important;color:#2869b2!important;font-size:11px!important;font-weight:800!important;padding:4px 6px!important;cursor:pointer!important}.df-email-preview-btn:hover{text-decoration:underline}.df-email-preview-label{opacity:.88!important}
.df-action-modal{position:fixed;inset:0;z-index:30000;display:grid;place-items:center;padding:16px}.df-action-backdrop{position:absolute;inset:0;background:rgba(15,23,42,.66);backdrop-filter:blur(2px)}.df-action-dialog{position:relative;z-index:1;width:min(520px,calc(100vw - 28px));background:var(--bs-body-bg,#fff);color:var(--bs-body-color,#1f2937);border:1px solid var(--bs-border-color,#d9dee5);border-radius:12px;box-shadow:0 24px 70px rgba(0,0,0,.3);overflow:hidden}.df-action-head,.df-action-foot{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:13px 15px;border-bottom:1px solid var(--bs-border-color,#d9dee5)}.df-action-head strong{font-size:17px}.df-action-body{padding:16px}.df-action-body p{margin:0 0 12px;line-height:1.5}.df-action-foot{justify-content:flex-end;border-top:1px solid var(--bs-border-color,#d9dee5);border-bottom:0}.df-action-x{width:34px;height:34px;border:1px solid var(--bs-border-color,#d9dee5);border-radius:7px;background:transparent;color:inherit;font-size:21px;cursor:pointer}.df-action-input-label{display:grid;gap:6px;font-weight:750}.df-action-input{width:100%;min-height:42px;border:1px solid var(--bs-border-color,#d5dbe3);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit;padding:9px 10px}.df-builder .df-action-danger,.df-action-modal .df-action-danger{background:#dc3545!important;border-color:#dc3545!important;color:#fff!important}.df-action-modal .df-action-danger:hover{background:#b4232f!important;border-color:#b4232f!important;color:#fff!important}
html[data-bs-theme="dark"] .df-summary-chip,body[data-bs-theme="dark"] .df-summary-chip,html[data-color-scheme="dark"] .df-summary-chip{background:#253140!important;border-color:#536174!important;color:#e5eaf0!important}html[data-bs-theme="dark"] .df-summary-chip.df-required-badge,body[data-bs-theme="dark"] .df-summary-chip.df-required-badge,html[data-color-scheme="dark"] .df-summary-chip.df-required-badge{background:#4a1e2b!important;border-color:#a94e68!important;color:#ffc0d0!important}html[data-bs-theme="dark"] .df-layout-drop-guide span,body[data-bs-theme="dark"] .df-layout-drop-guide span{background:rgba(25,43,66,.96);color:#c8ddff;border-color:#6ba3e8}html[data-bs-theme="dark"] .df-layout-drop-guide [data-drop-newrow],body[data-bs-theme="dark"] .df-layout-drop-guide [data-drop-newrow]{background:rgba(43,39,82,.97);color:#d9d5ff;border-color:#8b86e8}
@media(max-width:800px){.df-builder-workspace .df-layout-row{grid-template-columns:1fr!important}.df-layout-drop-guide{grid-template-columns:1fr 1fr 1fr}.df-layout-drop-guide span{font-size:9px}}


/* Forms 1.3.25: stable full-width custom-code editor and runtime diagnostics. */
.df-custom-code-grid{display:grid!important;grid-template-columns:minmax(0,1fr)!important;gap:14px!important;width:100%!important;max-width:none!important}
.df-custom-code-grid>.df-field{width:100%!important;max-width:none!important;min-width:0!important}
.df-custom-code-grid .df-codearea{display:block;width:100%!important;max-width:none!important}
</style>

<div class="df-builder">
  <div class="df-bhead">
    <div><h2><?php echo $id ? Text::_('COM_DECAROFORMS_BUILDER_EDIT_TITLE') : Text::_('COM_DECAROFORMS_BUILDER_CREATE_TITLE'); ?></h2><p><?php echo Text::_('COM_DECAROFORMS_BUILDER_DESC'); ?></p></div>
    <div class="df-bactions"><a class="df-btn df-back-btn" href="<?php echo $this->formsUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_BACK_FORMS'); ?></a><?php if ($id): ?><a class="df-btn df-danger" href="<?php echo $this->deleteUrl; ?>" data-confirm-delete-link data-delete-label="modulo"><?php echo Text::_('COM_DECAROFORMS_DELETE'); ?></a><?php endif; ?></div>
  </div>


  <div class="df-editor-toolbar" role="toolbar" aria-label="Modifica modulo">
    <div class="df-history-actions"><button type="button" id="df-undo" title="Annulla ultima modifica" disabled>↶ Annulla</button><button type="button" id="df-redo" title="Ripristina modifica" disabled>↷ Ripristina</button></div>
    <div class="df-edit-mode" aria-label="Modalità modifica"><button type="button" class="df-lock-toggle" data-lock="1"><svg class="df-ui-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><rect x="5" y="10" width="14" height="10" rx="2" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M8 10V7a4 4 0 0 1 8 0v3" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg><span>Bloccato</span></button><button type="button" class="df-lock-toggle" data-lock="0"><svg class="df-ui-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M4 20l4.2-1 10.5-10.5a2.1 2.1 0 0 0-3-3L5.2 16 4 20z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M14.5 6.7l2.8 2.8" fill="none" stroke="currentColor" stroke-width="1.8"/></svg><span>Modifica</span></button><button class="df-save-top" type="submit" form="df-builder-form"><?php echo Text::_('COM_DECAROFORMS_SAVE_FORM'); ?></button></div>
  </div>
  <div class="df-save-notice" id="df-save-notice" hidden role="status" aria-live="polite"></div>
  <div class="df-draft-banner" id="df-draft-banner" hidden>
    <div><strong>Bozza non salvata disponibile</strong><span id="df-draft-time"></span></div>
    <div class="df-draft-actions"><button type="button" class="df-btn df-small df-primary" id="df-draft-restore">Ripristina bozza</button><button type="button" class="df-btn df-small" id="df-draft-discard">Ignora</button></div>
  </div>

  <?php
  $dfSession = \Joomla\CMS\Factory::getApplication()->getSession();
  $dfBuilderCsrf = (string) $dfSession->get('com_decaroforms.builder.csrf', '');
  if ($dfBuilderCsrf === '') {
      $dfBuilderCsrf = bin2hex(random_bytes(32));
      $dfSession->set('com_decaroforms.builder.csrf', $dfBuilderCsrf);
  }
  ?>
  <script>
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
    function applyBuilderToken(form,token){
      if(!token)return false;
      let input=form.querySelector('input[name="df_builder_token"]');
      if(!input){input=document.createElement('input');input.type='hidden';input.name='df_builder_token';form.appendChild(input);}
      input.value=token;return true;
    }
    async function currentToken(form){
      const response=await fetch(tokenUrl+'&_df='+Date.now(),{method:'GET',credentials:'same-origin',cache:'no-store',headers:{'Accept':'application/json','X-Requested-With':'XMLHttpRequest'}});
      let result=null;try{result=await response.json();}catch{}
      if(!response.ok||!result||result.success!==true||!result.data?.token||!result.data?.builder_token)throw new Error(result?.message||'Impossibile aggiornare il token di sicurezza.');
      applyToken(form,result.data.token);applyBuilderToken(form,result.data.builder_token);return result.data;
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
        const fieldsInput=form.querySelector('#df-fields-json'),fieldsCountInput=form.querySelector('#df-fields-count');
        const liveCount=typeof window.dfBuilderFieldCount==='function'?Number(window.dfBuilderFieldCount()):Number(fieldsCountInput?.value||0);
        let payloadFields=null;try{payloadFields=JSON.parse(fieldsInput?.value||'');}catch{}
        if(!Array.isArray(payloadFields)||payloadFields.length!==liveCount){
          notice('I campi del modulo non sono sincronizzati. Il salvataggio è stato bloccato per evitare la perdita dei campi.','error',false);
          if(typeof window.dfBuilderSaveDraft==='function')window.dfBuilderSaveDraft();
          return false;
        }
        if(fieldsCountInput)fieldsCountInput.value=String(liveCount);
        if(typeof window.dfBuilderSaveDraft==='function')window.dfBuilderSaveDraft();
        const buttons=[...document.querySelectorAll('.df-save-top'),...form.querySelectorAll('button[type="submit"]')];buttons.forEach(b=>b.disabled=true);
        notice('Verifica della sessione e salvataggio del modulo…','info');
        try{await currentToken(form);}catch(err){notice((err?.message||'Sessione non disponibile.')+' La bozza è stata conservata.','error',true);return false;}
        let {response,result}=await send(form);
        if(result?.data?.code==='invalid_token'){
          if(result.data.token)applyToken(form,result.data.token);
          if(result.data.builder_token)applyBuilderToken(form,result.data.builder_token);
          if(!result.data.token||!result.data.builder_token)await currentToken(form);
          ({response,result}=await send(form));
        }
        if(!response.ok||!result||result.success!==true){
          const message=result?.message||(response.status===403?'La sessione non è più valida. La bozza è stata conservata.':'Il modulo non è stato salvato. Riprova.');
          notice(message,'error',response.status===403||/sessione|token/i.test(message));return false;
        }
        const expectedFields=typeof window.dfBuilderFieldCount==='function'?Number(window.dfBuilderFieldCount()):Number(form.querySelector('#df-fields-count')?.value||0);
        if(Number(result.data?.fields_saved)!==expectedFields){notice('Il modulo è stato ricevuto, ma il controllo dei campi non coincide. La bozza è stata conservata.','error',false);return false;}
        if(typeof window.dfBuilderClearDraft==='function')window.dfBuilderClearDraft();
        const saveNotice=document.getElementById('df-save-notice');if(saveNotice)saveNotice.hidden=true;
        window.dfAllowDraftReload=true;
        const redirect=result.data?.redirect||'index.php?option=com_decaroforms&view=forms';
        location.assign(redirect);
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
  <form method="post" action="<?php echo $this->saveUrl; ?>" id="df-builder-form" onsubmit="window.DeCaroFormsBuilderSubmit(event,this); return false;">
    <input type="hidden" name="id" value="<?php echo $id; ?>">
    <input type="hidden" name="fields_json" id="df-fields-json"><input type="hidden" name="fields_count" id="df-fields-count" value="0"><input type="hidden" name="fields_payload" value="1">
    <input type="hidden" name="statuses_json" id="df-statuses-json">
    <input type="hidden" name="list_columns_json" id="df-columns-json">
    <input type="hidden" name="builder_config_json" id="df-builder-config-json">
    <input type="hidden" name="email_config_json" id="df-email-config-json">
    <input type="hidden" name="additional_emails_json" id="df-additional-emails-json">
    <input type="hidden" name="integrations_json" id="df-integrations-json">
    <input type="hidden" name="email_template_admin" id="df-legacy-admin-template" value="<?php echo htmlspecialchars((string) ($emailConfig['admin']['template'] ?? 'standard'), ENT_QUOTES, 'UTF-8'); ?>">
    <input type="hidden" name="email_template_user" id="df-legacy-user-template" value="<?php echo htmlspecialchars((string) ($emailConfig['user']['template'] ?? 'standard'), ENT_QUOTES, 'UTF-8'); ?>">

    <section class="df-section is-open" data-accordion>
      <button class="df-section-toggle" type="button" aria-expanded="true"><strong>1. <?php echo Text::_('COM_DECAROFORMS_SECTION_SETTINGS'); ?></strong><span class="df-section-chevron">⌄</span></button>
      <div class="df-section-body-wrap"><div class="df-section-body-inner"><div class="df-section-body"><div class="df-grid">
        <div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_TITLE'); ?> *</label><input name="title" required value="<?php echo $val('title'); ?>" placeholder="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_TITLE_PLACEHOLDER'), ENT_QUOTES, 'UTF-8'); ?>"></div>
        <div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_SLUG'); ?></label><input name="slug" value="<?php echo $val('slug'); ?>" placeholder="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_SLUG_PLACEHOLDER'), ENT_QUOTES, 'UTF-8'); ?>"><span class="df-note"><?php echo Text::_('COM_DECAROFORMS_SLUG_HELP'); ?></span></div>
        <div class="df-field df-field-full"><label><?php echo Text::_('COM_DECAROFORMS_DESCRIPTION'); ?></label><textarea name="description"><?php echo $val('description'); ?></textarea></div>
        <div class="df-field"><label class="df-switch"><input type="checkbox" name="enabled" value="1" <?php echo $checked('enabled', true) ? 'checked' : ''; ?>><span class="df-switch-ui" aria-hidden="true"></span><span><?php echo Text::_('COM_DECAROFORMS_ENABLED'); ?></span></label></div>
        <div class="df-field"><label class="df-switch"><input type="checkbox" name="show_heading" value="1" <?php echo $checked('show_heading', true) ? 'checked' : ''; ?>><span class="df-switch-ui" aria-hidden="true"></span><span><?php echo Text::_('COM_DECAROFORMS_SHOW_HEADING'); ?></span></label></div>
        <div class="df-field df-field-full df-success-message-block"><label><?php echo Text::_('COM_DECAROFORMS_SUCCESS_MESSAGE'); ?></label><textarea class="df-success-editor" name="success_message" rows="2"><?php echo $val('success_message', Text::_('COM_DECAROFORMS_SUCCESS_DEFAULT')); ?></textarea><div class="df-success-options"><label><span>Formato messaggio</span><select id="df-success-format"><option value="text">Testo semplice</option><option value="html">HTML</option></select></label><label class="df-switch df-success-modal-switch"><input type="checkbox" id="df-success-modal"><span class="df-switch-ui" aria-hidden="true"></span><span>Mostra in finestra modal</span></label></div><span class="df-note">La posizione completa del messaggio può essere regolata anche in “Validazione e conferma”.</span></div>
        <div class="df-closed-box"><div class="df-grid"><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_WHEN_DISABLED'); ?></label><select name="closed_reason"><option value="closed" <?php echo $val('closed_reason', 'closed') === 'closed' ? 'selected' : ''; ?>><?php echo Text::_('COM_DECAROFORMS_CLOSED_REGISTRATIONS'); ?></option><option value="limit" <?php echo $val('closed_reason') === 'limit' ? 'selected' : ''; ?>><?php echo Text::_('COM_DECAROFORMS_LIMIT_REACHED'); ?></option><option value="deadline" <?php echo $val('closed_reason') === 'deadline' ? 'selected' : ''; ?>><?php echo Text::_('COM_DECAROFORMS_DEADLINE_EXPIRED'); ?></option><option value="temporary" <?php echo $val('closed_reason') === 'temporary' ? 'selected' : ''; ?>><?php echo Text::_('COM_DECAROFORMS_TEMPORARILY_CLOSED'); ?></option><option value="custom" <?php echo $val('closed_reason') === 'custom' ? 'selected' : ''; ?>><?php echo Text::_('COM_DECAROFORMS_CUSTOM_MESSAGE'); ?></option></select></div><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_CLOSED_MESSAGE'); ?></label><input name="closed_message" value="<?php echo $val('closed_message'); ?>" placeholder="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_OPTIONAL_CUSTOM_TEXT'), ENT_QUOTES, 'UTF-8'); ?>"></div></div></div>
      </div></div></div></div>
    </section>

    <section class="df-section" data-accordion>
      <button class="df-section-toggle" type="button" aria-expanded="false"><strong>2. <?php echo Text::_('COM_DECAROFORMS_SECTION_TEMPLATES'); ?></strong><span class="df-section-chevron">⌄</span></button>
      <div class="df-section-body-wrap"><div class="df-section-body-inner"><div class="df-section-body"><div class="df-template-row"><button type="button" data-form-template="contact"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_CONTACT'); ?></button><button type="button" data-form-template="registration"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_REGISTRATION'); ?></button><button type="button" data-form-template="event"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_EVENT'); ?></button><button type="button" data-form-template="membership"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_MEMBERSHIP'); ?></button><button type="button" data-form-template="reservation"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_RESERVATION'); ?></button><button type="button" data-form-template="blank"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_BLANK'); ?></button></div><div class="df-saved-quick-heading" id="df-saved-quick-heading" hidden>Modelli salvati</div><div class="df-template-row df-saved-quick-row" id="df-saved-quick-templates"></div><p class="df-note"><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_NOTE'); ?></p></div></div></div>
    </section>

    <section class="df-section" data-accordion>
      <button class="df-section-toggle" type="button" aria-expanded="false"><strong>3. Campi del modulo</strong><span class="df-section-chevron">⌄</span></button>
      <div class="df-section-body-wrap"><div class="df-section-body-inner"><div class="df-section-body">
        <div class="df-builder-workspace">
          <div class="df-form-canvas-panel">
            <div class="df-layout-visual-head"><div><strong>Struttura del modulo</strong><div class="df-note">Trascina i campi per cambiare ordine o riga. La linea blu appare nel punto di rilascio.</div></div><div class="df-layout-head-actions"><button class="df-btn df-small df-btn-primary df-save-structure" type="button" id="df-save-structure" title="Salva questa struttura nei Modelli rapidi"><svg class="df-ui-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M5 3h11l3 3v15H5V3zM7 3v6h9V4M8 21v-7h8v7" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg><span>Salva struttura</span></button><label class="df-switch"><input type="checkbox" id="df-layout-mobile-stack"><span class="df-switch-ui" aria-hidden="true"></span><span><?php echo Text::_('COM_DECAROFORMS_LAYOUT_MOBILE_STACK'); ?></span></label></div></div>
            <div class="df-layout-canvas" id="df-layout-canvas"></div>
            <div class="df-layout-newrow" id="df-layout-newrow">Rilascia qui per creare una nuova riga</div>
            <button class="df-add-field-main" type="button" id="df-open-library"><span aria-hidden="true">＋</span> Aggiungi campo</button>
            <div hidden aria-hidden="true"><select id="df-layout-columns"><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option></select><span id="df-layout-total"></span><div id="df-layout-widths"></div><button type="button" id="df-layout-apply">Applica</button></div>
          </div>
          <aside class="df-properties-panel" aria-live="polite">
            <div class="df-properties-title"><div><strong>Impostazioni campo</strong><span>Seleziona un campo per modificarlo</span></div></div>
            <div class="df-selected" id="df-selected"></div>
          </aside>
        </div>
      </div></div></div>
    </section>

    <section class="df-section" data-accordion>
      <button class="df-section-toggle" type="button" aria-expanded="false"><strong>4. <?php echo Text::_('COM_DECAROFORMS_SECTION_LIBRARY'); ?></strong><span class="df-section-chevron">⌄</span></button>
      <div class="df-section-body-wrap"><div class="df-section-body-inner"><div class="df-section-body"><div class="df-library-tabs" id="df-library-tabs"></div><div class="df-library-tools-v2"><input type="search" id="df-library-search" placeholder="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_SEARCH_FIELD'), ENT_QUOTES, 'UTF-8'); ?>"><select id="df-library-filter" hidden></select></div><div class="df-library" id="df-library"></div></div></div></div>
    </section>

    <section class="df-section" data-accordion>
      <button class="df-section-toggle" type="button" aria-expanded="false"><strong>5. Stati e visualizzazione</strong><span class="df-section-chevron">⌄</span></button>
      <div class="df-section-body-wrap"><div class="df-section-body-inner"><div class="df-section-body">
        <div class="df-subbox"><h4>Stati degli invii</h4><p class="df-note"><?php echo Text::_('COM_DECAROFORMS_FORM_STATUSES_NOTE'); ?></p><div class="df-status-editor" id="df-status-editor"></div><button type="button" class="df-btn df-small" id="df-add-status" style="margin-top:9px">+ <?php echo Text::_('COM_DECAROFORMS_ADD_STATUS'); ?></button></div>
        <div class="df-subbox"><div class="df-spread"><div><h4>Colonne dell’elenco</h4><p class="df-note"><?php echo Text::_('COM_DECAROFORMS_TABLE_COLUMNS_NOTE'); ?></p></div><div class="df-column-tools"><button class="df-btn df-small" type="button" id="df-columns-all"><?php echo Text::_('COM_DECAROFORMS_SELECT_ALL'); ?></button><button class="df-btn df-small" type="button" id="df-columns-reset"><?php echo Text::_('COM_DECAROFORMS_RESET_DEFAULT'); ?></button></div></div><div class="df-column-list" id="df-column-list"></div></div>
      </div></div></div>
    </section>

    <section class="df-section" data-accordion>
      <button class="df-section-toggle" type="button" aria-expanded="false"><strong>6. <?php echo Text::_('COM_DECAROFORMS_SECTION_EMAIL'); ?></strong><span class="df-section-chevron">⌄</span></button>
      <div class="df-section-body-wrap"><div class="df-section-body-inner"><div class="df-section-body">
        <div class="df-tokenbar"><strong><?php echo Text::_('COM_DECAROFORMS_INSERT_VARIABLE'); ?></strong><select id="df-token-picker"></select><button class="df-btn df-small" type="button" id="df-token-insert"><?php echo Text::_('COM_DECAROFORMS_INSERT'); ?></button><span class="df-note"><?php echo Text::_('COM_DECAROFORMS_VARIABLE_NOTE'); ?></span></div>

        <details class="df-email-block" open><summary><?php echo Text::_('COM_DECAROFORMS_EMAIL_ADMIN_SECTION'); ?></summary><div class="df-email-block-body">
          <div class="df-grid"><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_ADMIN_EMAIL'); ?></label><input name="admin_email" data-email="admin.to" value="<?php echo htmlspecialchars((string) ($emailConfig['admin']['to'] ?? ''), ENT_QUOTES, 'UTF-8'); ?>" placeholder="<?php echo htmlspecialchars($this->defaultAdminEmail ?: $this->globalMailFrom ?: 'admin@example.com', ENT_QUOTES, 'UTF-8'); ?>"><span class="df-note"><?php echo Text::_('COM_DECAROFORMS_ADMIN_EMAIL_INHERIT'); ?></span></div><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_EMAIL_ADMIN_SUBJECT'); ?></label><input name="email_subject_admin" data-email="admin.subject" value="<?php echo htmlspecialchars((string) ($emailConfig['admin']['subject'] ?? ''), ENT_QUOTES, 'UTF-8'); ?>" placeholder="Nuovo invio – {form_title}"></div></div>
          <div class="df-grid"><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_FROM_EMAIL'); ?></label><input data-email="admin.from_email" value="<?php echo htmlspecialchars((string) ($emailConfig['admin']['from_email'] ?? ''), ENT_QUOTES, 'UTF-8'); ?>" placeholder="<?php echo htmlspecialchars($this->globalMailFrom, ENT_QUOTES, 'UTF-8'); ?>"></div><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_FROM_NAME'); ?></label><input data-email="admin.from_name" value="<?php echo htmlspecialchars((string) ($emailConfig['admin']['from_name'] ?? ''), ENT_QUOTES, 'UTF-8'); ?>" placeholder="<?php echo htmlspecialchars($this->globalFromName, ENT_QUOTES, 'UTF-8'); ?>"></div><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_REPLY_TO_EMAIL'); ?></label><input data-email="admin.reply_to" value="<?php echo htmlspecialchars((string) ($emailConfig['admin']['reply_to'] ?? '{email}'), ENT_QUOTES, 'UTF-8'); ?>"></div><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_REPLY_TO_NAME'); ?></label><input data-email="admin.reply_name" value="<?php echo htmlspecialchars((string) ($emailConfig['admin']['reply_name'] ?? ''), ENT_QUOTES, 'UTF-8'); ?>"></div></div>
          <details style="margin:8px 0 12px"><summary><strong><?php echo Text::_('COM_DECAROFORMS_ADVANCED_OPTIONS'); ?></strong></summary><div class="df-grid" style="margin-top:9px"><div class="df-field"><label>CC</label><input data-email="admin.cc" value="<?php echo htmlspecialchars((string) ($emailConfig['admin']['cc'] ?? ''), ENT_QUOTES, 'UTF-8'); ?>"></div><div class="df-field"><label>BCC</label><input data-email="admin.bcc" value="<?php echo htmlspecialchars((string) ($emailConfig['admin']['bcc'] ?? ''), ENT_QUOTES, 'UTF-8'); ?>"></div><div class="df-field"><label class="df-check"><input type="checkbox" data-email-check="admin.auto_message" <?php echo !empty($emailConfig['admin']['auto_message']) ? 'checked' : ''; ?>> <?php echo Text::_('COM_DECAROFORMS_AUTO_EMAIL_MESSAGE'); ?></label></div><div class="df-field"><label class="df-check"><input type="checkbox" data-email-check="admin.attach_uploads" <?php echo !empty($emailConfig['admin']['attach_uploads']) ? 'checked' : ''; ?>> <?php echo Text::_('COM_DECAROFORMS_ATTACH_UPLOADS'); ?></label></div></div></details>
          <h4><?php echo Text::_('COM_DECAROFORMS_EMAIL_TEMPLATE'); ?></h4><div class="df-email-templates" data-email-picker="admin"></div><div class="df-email-special" data-email-special="admin" hidden></div>
        </div></details>

        <details class="df-email-block"><summary><?php echo Text::_('COM_DECAROFORMS_EMAIL_USER_SECTION'); ?></summary><div class="df-email-block-body">
          <label class="df-check"><input type="checkbox" name="user_confirmation" value="1" id="df-user-confirmation" <?php echo !empty($emailConfig['user']['enabled']) ? 'checked' : ''; ?>> <strong><?php echo Text::_('COM_DECAROFORMS_USER_CONFIRMATION_CLEAR'); ?></strong></label><p class="df-note"><?php echo Text::_('COM_DECAROFORMS_USER_CONFIRMATION_NOTE'); ?></p>
          <div id="df-user-email-settings"><div class="df-grid"><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_USER_EMAIL_FIELD'); ?></label><select data-email="user.to_field" id="df-user-email-field"></select></div><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_EMAIL_USER_SUBJECT'); ?></label><input name="email_subject_user" data-email="user.subject" value="<?php echo htmlspecialchars((string) ($emailConfig['user']['subject'] ?? ''), ENT_QUOTES, 'UTF-8'); ?>" placeholder="Abbiamo ricevuto il tuo invio – {form_title}"></div><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_REPLY_TO_EMAIL'); ?></label><input data-email="user.reply_to" value="<?php echo htmlspecialchars((string) ($emailConfig['user']['reply_to'] ?? ''), ENT_QUOTES, 'UTF-8'); ?>"></div><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_REPLY_TO_NAME'); ?></label><input data-email="user.reply_name" value="<?php echo htmlspecialchars((string) ($emailConfig['user']['reply_name'] ?? ''), ENT_QUOTES, 'UTF-8'); ?>"></div></div>
          <div class="df-inline" style="margin:8px 0"><label class="df-check"><input type="checkbox" data-email-check="user.auto_message" <?php echo !empty($emailConfig['user']['auto_message']) ? 'checked' : ''; ?>> <?php echo Text::_('COM_DECAROFORMS_AUTO_EMAIL_MESSAGE'); ?></label><label class="df-check"><input type="checkbox" data-email-check="user.attach_uploads" <?php echo !empty($emailConfig['user']['attach_uploads']) ? 'checked' : ''; ?>> <?php echo Text::_('COM_DECAROFORMS_ATTACH_UPLOADS'); ?></label></div>
          <h4><?php echo Text::_('COM_DECAROFORMS_EMAIL_TEMPLATE'); ?></h4><div class="df-email-templates" data-email-picker="user"></div><div class="df-email-special" data-email-special="user" hidden></div></div>
        </div></details>

        <details class="df-email-block"><summary><?php echo Text::_('COM_DECAROFORMS_ADDITIONAL_EMAILS'); ?></summary><div class="df-email-block-body"><div class="df-spread"><p class="df-note" style="margin:0"><?php echo Text::_('COM_DECAROFORMS_ADDITIONAL_EMAILS_NOTE'); ?></p><button class="df-btn df-small" type="button" id="df-additional-add">+ <?php echo Text::_('COM_DECAROFORMS_NEW_EMAIL'); ?></button></div><div class="df-additional-list" id="df-additional-list" style="margin-top:10px"></div></div></details>
      </div></div></div>
    </section>

    <section class="df-section" data-accordion>
      <button class="df-section-toggle" type="button" aria-expanded="false"><strong>7. <?php echo Text::_('COM_DECAROFORMS_SECTION_VALIDATION'); ?></strong><span class="df-section-chevron">⌄</span></button>
      <div class="df-section-body-wrap"><div class="df-section-body-inner"><div class="df-section-body">
        <div class="df-subbox"><h4>Controllo dei campi</h4><div class="df-security-grid"><div class="df-field"><label class="df-check"><input type="checkbox" id="df-validation-ajax"><span>Controlla i campi prima dell’invio</span><span class="df-info-wrap"><button class="df-info" type="button" aria-label="Informazioni">ⓘ</button><span class="df-info-bubble">Verifica subito che i campi obbligatori e i valori inseriti siano corretti prima dell’invio.</span></span></label></div><div class="df-field"><label class="df-check"><input type="checkbox" id="df-validation-scroll"><span>Vai al primo campo con errore</span><span class="df-info-wrap"><button class="df-info" type="button" aria-label="Informazioni">ⓘ</button><span class="df-info-bubble">Se c’è un errore, porta automaticamente l’utente al primo campo da correggere.</span></span></label></div><div class="df-field"><label class="df-label-info">Simbolo per i campi obbligatori <span class="df-info-wrap"><button class="df-info" type="button" aria-label="Informazioni">ⓘ</button><span class="df-info-bubble">È il simbolo mostrato accanto ai campi obbligatori. Il valore predefinito è *.</span></span></label><input id="df-required-marker" maxlength="8"></div><div class="df-field"><label class="df-label-info">Messaggio generale in caso di errore <span class="df-info-wrap"><button class="df-info" type="button" aria-label="Informazioni">ⓘ</button><span class="df-info-bubble">Messaggio mostrato quando uno o più campi non sono compilati correttamente.</span></span></label><input id="df-error-message"></div></div></div>
        <div class="df-subbox"><h4>Conferma dopo l’invio</h4><div class="df-security-grid"><div class="df-field"><label class="df-check"><input type="checkbox" id="df-confirm-enabled"><span>Mostra messaggio di conferma</span></label></div><div class="df-field"><label class="df-label-info">Dove mostrare il messaggio <span class="df-info-wrap"><button class="df-info" type="button" aria-label="Informazioni">ⓘ</button><span class="df-info-bubble">Scegli se mostrarlo sotto Invia, al posto del modulo oppure in una finestra.</span></span></label><select id="df-confirm-position"><option value="below"><?php echo Text::_('COM_DECAROFORMS_CONFIRM_BELOW'); ?></option><option value="replace"><?php echo Text::_('COM_DECAROFORMS_CONFIRM_REPLACE'); ?></option><option value="modal"><?php echo Text::_('COM_DECAROFORMS_CONFIRM_MODAL'); ?></option></select></div><div class="df-field"><label class="df-check"><input type="checkbox" id="df-confirm-scroll"><span>Vai automaticamente al messaggio</span></label></div><div class="df-field"><label class="df-check"><input type="checkbox" id="df-confirm-continue"><span>Mostra pulsante Continua</span></label></div><div class="df-field"><label>Testo del pulsante Continua</label><input id="df-confirm-continue-label"></div><div class="df-field"><label>Pagina da aprire dopo Continua</label><input id="df-confirm-continue-url" placeholder="https://..."></div></div></div>
        <div class="df-subbox"><h4>Protezione dagli invii automatici</h4><div class="df-security-grid"><div class="df-field"><label class="df-label-info">Tempo minimo per compilare il modulo <span class="df-info-wrap"><button class="df-info" type="button" aria-label="Informazioni">ⓘ</button><span class="df-info-bubble">Blocca gli invii completati in modo anormalmente veloce, tipici dei bot.</span></span></label><input type="number" id="df-min-seconds" min="0" max="60"></div><div class="df-field"><label class="df-label-info">Attesa minima tra due invii <span class="df-info-wrap"><button class="df-info" type="button" aria-label="Informazioni">ⓘ</button><span class="df-info-bubble">Impedisce invii ripetuti a distanza di pochi secondi.</span></span></label><input type="number" id="df-rate-seconds" min="0" max="3600"></div></div><p class="df-note">Le protezioni di sicurezza principali sono sempre attive. <span class="df-info-wrap"><button class="df-info" type="button" aria-label="Informazioni">ⓘ</button><span class="df-info-bubble">Comprendono controllo della richiesta, campo anti-bot invisibile e verifica lato server.</span></span></p></div>
      </div></div></div>
    </section>

    <section class="df-section" data-accordion>
      <button class="df-section-toggle" type="button" aria-expanded="false"><strong>8. <?php echo Text::_('COM_DECAROFORMS_SECTION_CUSTOM_CODE'); ?></strong><span class="df-section-chevron">⌄</span></button>
      <div class="df-section-body-wrap"><div class="df-section-body-inner"><div class="df-section-body">
        <?php if ($this->canCustomCode): ?><div class="df-custom-code-grid"><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_CUSTOM_CSS'); ?></label><textarea class="df-codearea" id="df-custom-css" name="custom_css" placeholder=".mia-classe { ... }"><?php echo htmlspecialchars((string) ($form['custom_css'] ?? ''), ENT_QUOTES, 'UTF-8'); ?></textarea><span class="df-note"><?php echo Text::_('COM_DECAROFORMS_CUSTOM_CSS_NOTE'); ?></span></div><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_CUSTOM_JS'); ?></label><textarea class="df-codearea" id="df-custom-js" name="custom_js" placeholder="// JavaScript"><?php echo htmlspecialchars((string) ($form['custom_js'] ?? ''), ENT_QUOTES, 'UTF-8'); ?></textarea><span class="df-note"><?php echo Text::_('COM_DECAROFORMS_CUSTOM_JS_NOTE'); ?></span></div></div><div class="df-warning" style="margin-top:10px"><?php echo Text::_('COM_DECAROFORMS_CUSTOM_CODE_WARNING'); ?></div><?php else: ?><div class="df-warning"><?php echo Text::_('COM_DECAROFORMS_CUSTOM_CODE_SUPERUSER'); ?></div><?php endif; ?>
      </div></div></div>
    </section>

    <section class="df-section" data-accordion>
      <button class="df-section-toggle" type="button" aria-expanded="false"><strong>9. <?php echo Text::_('COM_DECAROFORMS_SECTION_INTEGRATIONS'); ?></strong><span class="df-section-chevron">⌄</span></button>
      <div class="df-section-body-wrap"><div class="df-section-body-inner"><div class="df-section-body">
        <div class="df-subbox"><h4><?php echo Text::_('COM_DECAROFORMS_CALCULATIONS'); ?></h4><p class="df-note"><?php echo Text::_('COM_DECAROFORMS_CALCULATIONS_NOTE'); ?></p><button class="df-btn df-small" type="button" id="df-add-calculation"><?php echo Text::_('COM_DECAROFORMS_ADD_CALCULATED_FIELD'); ?></button></div>
        <div class="df-subbox"><h4>Google Sheets</h4><div class="df-grid"><div class="df-field"><label class="df-check"><input type="checkbox" id="df-sheets-enabled"> <?php echo Text::_('COM_DECAROFORMS_SHEETS_ENABLE'); ?></label></div><div></div><div class="df-field df-field-full"><label><?php echo Text::_('COM_DECAROFORMS_SHEETS_WEBHOOK'); ?></label><input id="df-sheets-webhook" placeholder="https://script.google.com/macros/s/.../exec"><span class="df-note"><?php echo Text::_('COM_DECAROFORMS_SHEETS_WEBHOOK_NOTE'); ?></span></div><div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_SHEETS_SECRET'); ?></label><input id="df-sheets-secret" autocomplete="off"></div><div class="df-field"><label class="df-check"><input type="checkbox" id="df-sheets-files"> <?php echo Text::_('COM_DECAROFORMS_SHEETS_INCLUDE_FILES'); ?></label></div></div><p class="df-note"><?php echo Text::_('COM_DECAROFORMS_SHEETS_PRIMARY_DB'); ?></p></div>
      </div></div></div>
    </section>

    <div class="df-bactions" style="justify-content:flex-end"><a class="df-btn" href="<?php echo $this->formsUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_CANCEL'); ?></a><button class="df-btn df-primary" type="submit"><?php echo Text::_('COM_DECAROFORMS_SAVE_FORM'); ?></button></div>
    <input type="hidden" name="df_builder_token" value="<?php echo htmlspecialchars($dfBuilderCsrf, ENT_QUOTES, 'UTF-8'); ?>">
    <span id="df-csrf-token-wrap"><?php echo HTMLHelper::_('form.token'); ?></span>
  </form>

  <div class="df-preview-modal" id="df-email-preview-modal" hidden><div class="df-preview-backdrop" data-preview-close></div><div class="df-preview-dialog" role="dialog" aria-modal="true"><div class="df-preview-head"><div><strong id="df-preview-title"></strong><div class="df-note" id="df-preview-subject"></div></div><button class="df-preview-x" type="button" data-preview-close>×</button></div><div class="df-preview-body"><div class="df-preview-canvas" id="df-preview-canvas"></div></div><div class="df-preview-foot"><button class="df-btn" type="button" data-preview-close><?php echo Text::_('COM_DECAROFORMS_CLOSE'); ?></button></div></div></div>

</div>

<?php echo FormHelper::footer(); ?>

<script>
(()=>{
const esc=s=>String(s??'').replace(/[&<>'"]/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[m]));
const clone=o=>JSON.parse(JSON.stringify(o??{}));
const uiIcon=name=>{const icons={
 save:'<svg class="df-ui-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 3h11l3 3v15H5V3zM7 3v6h9V4M8 21v-7h8v7" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>',
 edit:'<svg class="df-ui-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20l4.2-1 10.5-10.5a2.1 2.1 0 0 0-3-3L5.2 16 4 20z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M14.5 6.7l2.8 2.8" fill="none" stroke="currentColor" stroke-width="1.8"/></svg>',
 copy:'<svg class="df-ui-icon" viewBox="0 0 24 24" aria-hidden="true"><rect x="8" y="8" width="11" height="11" rx="2" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2" fill="none" stroke="currentColor" stroke-width="1.8"/></svg>',
 trash:'<svg class="df-ui-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M9 7V4h6v3M7 7l1 13h8l1-13M10 10v7M14 10v7" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>'
};return icons[name]||'';};
const setDeep=(obj,path,val)=>{const p=path.split('.');let x=obj;for(let i=0;i<p.length-1;i++){if(!x[p[i]]||typeof x[p[i]]!=='object')x[p[i]]={};x=x[p[i]];}x[p.at(-1)]=val;};
const getDeep=(obj,path,def='')=>{let x=obj;for(const p of path.split('.')){if(x==null||typeof x!=='object'||!(p in x))return def;x=x[p];}return x??def;};
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

const tr=<?php echo json_encode([
'add'=>Text::_('COM_DECAROFORMS_ADD'),'empty'=>Text::_('COM_DECAROFORMS_NO_FIELDS_SELECTED'),'options'=>Text::_('COM_DECAROFORMS_OPTIONS_ONE_LINE'),'moveUp'=>Text::_('COM_DECAROFORMS_MOVE_UP'),'moveDown'=>Text::_('COM_DECAROFORMS_MOVE_DOWN'),'remove'=>Text::_('COM_DECAROFORMS_REMOVE'),'label'=>Text::_('COM_DECAROFORMS_LABEL'),'key'=>Text::_('COM_DECAROFORMS_FIELD_KEY'),'type'=>Text::_('COM_DECAROFORMS_TYPE'),'placeholder'=>Text::_('COM_DECAROFORMS_PLACEHOLDER'),'help'=>Text::_('COM_DECAROFORMS_HELP_TEXT'),'default'=>Text::_('COM_DECAROFORMS_DEFAULT_VALUE'),'required'=>Text::_('COM_DECAROFORMS_REQUIRED_FIELD'),'layout'=>Text::_('COM_DECAROFORMS_FIELD_LAYOUT'),'conditions'=>Text::_('COM_DECAROFORMS_CONDITIONS'),'addCondition'=>Text::_('COM_DECAROFORMS_ADD_CONDITION'),'all'=>Text::_('COM_DECAROFORMS_ALL_CONDITIONS'),'any'=>Text::_('COM_DECAROFORMS_ANY_CONDITION'),'selected'=>Text::_('COM_DECAROFORMS_TEMPLATE_SELECTED'),'preview'=>Text::_('COM_DECAROFORMS_PREVIEW'),'customize'=>Text::_('COM_DECAROFORMS_CUSTOMIZE'),'html'=>Text::_('COM_DECAROFORMS_HTML_FREE'),'chatgpt'=>Text::_('COM_DECAROFORMS_CHATGPT_GENERATOR'),'copyPrompt'=>Text::_('COM_DECAROFORMS_COPY_CHATGPT_PROMPT'),'copied'=>Text::_('COM_DECAROFORMS_COPIED'),'newEmail'=>Text::_('COM_DECAROFORMS_NEW_EMAIL'),'noAdditional'=>Text::_('COM_DECAROFORMS_NO_ADDITIONAL_EMAILS'),'emailName'=>Text::_('COM_DECAROFORMS_EMAIL_INTERNAL_NAME'),'condition'=>Text::_('COM_DECAROFORMS_CONDITION'),'template'=>Text::_('COM_DECAROFORMS_EMAIL_TEMPLATE'),
'cats'=>['personal'=>Text::_('COM_DECAROFORMS_CATEGORY_PERSONAL'),'contact'=>Text::_('COM_DECAROFORMS_CATEGORY_CONTACT'),'address'=>Text::_('COM_DECAROFORMS_CATEGORY_ADDRESS'),'choices'=>Text::_('COM_DECAROFORMS_CATEGORY_CHOICES'),'values'=>Text::_('COM_DECAROFORMS_CATEGORY_VALUES'),'datetime'=>Text::_('COM_DECAROFORMS_CATEGORY_DATETIME'),'document'=>Text::_('COM_DECAROFORMS_CATEGORY_DOCUMENT'),'payment'=>Text::_('COM_DECAROFORMS_CATEGORY_PAYMENT'),'structure'=>Text::_('COM_DECAROFORMS_CATEGORY_STRUCTURE'),'consent'=>Text::_('COM_DECAROFORMS_CATEGORY_CONSENT'),'custom'=>Text::_('COM_DECAROFORMS_CATEGORY_CUSTOM')],
'types'=>['text'=>Text::_('COM_DECAROFORMS_TYPE_TEXT'),'email'=>Text::_('COM_DECAROFORMS_TYPE_EMAIL'),'tel'=>Text::_('COM_DECAROFORMS_TYPE_TEL'),'url'=>'URL','number'=>Text::_('COM_DECAROFORMS_TYPE_NUMBER'),'date'=>Text::_('COM_DECAROFORMS_TYPE_DATE'),'time'=>Text::_('COM_DECAROFORMS_TYPE_TIME'),'datetime'=>Text::_('COM_DECAROFORMS_TYPE_DATETIME'),'textarea'=>Text::_('COM_DECAROFORMS_TYPE_TEXTAREA'),'select'=>Text::_('COM_DECAROFORMS_TYPE_SELECT'),'multiselect'=>Text::_('COM_DECAROFORMS_TYPE_MULTISELECT'),'radio'=>Text::_('COM_DECAROFORMS_TYPE_RADIO'),'checkboxes'=>Text::_('COM_DECAROFORMS_TYPE_CHECKBOXES'),'checkbox'=>Text::_('COM_DECAROFORMS_TYPE_CHECKBOX'),'toggle'=>Text::_('COM_DECAROFORMS_TYPE_TOGGLE'),'consent'=>Text::_('COM_DECAROFORMS_TYPE_CONSENT'),'file'=>Text::_('COM_DECAROFORMS_TYPE_FILE'),'upload'=>Text::_('COM_DECAROFORMS_TYPE_UPLOAD'),'nationality'=>Text::_('COM_DECAROFORMS_FIELD_NATIONALITY'),'country'=>Text::_('COM_DECAROFORMS_FIELD_COUNTRY'),'region'=>Text::_('COM_DECAROFORMS_FIELD_REGION'),'city'=>Text::_('COM_DECAROFORMS_FIELD_CITY'),'province'=>'Provincia','tax_code'=>'Codice fiscale','postcode'=>Text::_('COM_DECAROFORMS_FIELD_POSTCODE'),'member_number'=>Text::_('COM_DECAROFORMS_FIELD_MEMBER_NUMBER'),'range'=>Text::_('COM_DECAROFORMS_TYPE_RANGE'),'separator'=>Text::_('COM_DECAROFORMS_TYPE_SEPARATOR'),'pagebreak'=>Text::_('COM_DECAROFORMS_TYPE_PAGEBREAK'),'page'=>Text::_('COM_DECAROFORMS_TYPE_MULTIPAGE'),'heading'=>Text::_('COM_DECAROFORMS_TYPE_HEADING'),'info'=>Text::_('COM_DECAROFORMS_TYPE_INFO'),'fieldset'=>Text::_('COM_DECAROFORMS_TYPE_FIELDSET'),'hidden'=>Text::_('COM_DECAROFORMS_TYPE_HIDDEN'),'map'=>Text::_('COM_DECAROFORMS_TYPE_MAP'),'payment'=>Text::_('COM_DECAROFORMS_TYPE_PAYMENT'),'calculated'=>Text::_('COM_DECAROFORMS_TYPE_CALCULATED')]
], JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;
const library=<?php echo json_encode(FormHelper::fieldLibrary(), JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;

/* Forms 1.3.8: reusable saved field presets. */
const savedPresetStorageKey='decaroforms_saved_field_presets_v1';
function loadSavedFieldPresets(){
 try{
  const parsed=JSON.parse(localStorage.getItem(savedPresetStorageKey)||'[]');
  return Array.isArray(parsed)?parsed.filter(x=>x&&typeof x==='object'&&x.label&&x.type).slice(0,100):[];
 }catch(e){console.warn('Forms saved field presets could not be loaded',e);return [];}
}
function persistSavedFieldPresets(){
 try{localStorage.setItem(savedPresetStorageKey,JSON.stringify(savedFieldPresets));}
 catch(e){console.warn('Forms saved field presets could not be saved',e);}
}
let savedFieldPresets=loadSavedFieldPresets();
savedFieldPresets.forEach(p=>library.push({...p,category:'custom',_savedPresetId:p._savedPresetId||p.id||''}));
function saveFieldPreset(field){
 const copy=JSON.parse(JSON.stringify(field||{}));
 copy.category='custom';
 copy.options=Array.isArray(copy.options)?copy.options:[];
 const existing=savedFieldPresets.find(p=>String(p.key||'')===String(copy.key||'')&&String(p.label||'')===String(copy.label||''));
 copy._savedPresetId=existing?existing._savedPresetId:('saved_'+Date.now().toString(36)+'_'+Math.random().toString(36).slice(2,7));
 const idx=savedFieldPresets.findIndex(p=>p._savedPresetId===copy._savedPresetId);
 if(idx>=0)savedFieldPresets[idx]=copy;else savedFieldPresets.push(copy);
 persistSavedFieldPresets();
 const libIdx=library.findIndex(p=>p._savedPresetId===copy._savedPresetId);
 if(libIdx>=0)library[libIdx]=copy;else library.push(copy);
 renderLibrary();
 return copy._savedPresetId;
}
function deleteSavedFieldPreset(id){
 savedFieldPresets=savedFieldPresets.filter(p=>p._savedPresetId!==id);
 persistSavedFieldPresets();
 for(let i=library.length-1;i>=0;i--)if(library[i]._savedPresetId===id)library.splice(i,1);
 renderLibrary();
}

let selected=<?php echo json_encode($initialFields, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;
let statuses=<?php echo json_encode($initialStatuses, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;
let columns=<?php echo json_encode($initialColumns, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;
let builderConfig=<?php echo json_encode($builderConfig, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;
let emailConfig=<?php echo json_encode($emailConfig, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;
let additionalEmails=<?php echo json_encode(array_values($additionalEmails), JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;
let integrations=<?php echo json_encode($integrations, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;

builderConfig.layout={columns:1,widths:[100],mobile_stack:true,...(builderConfig.layout||{})};
builderConfig.validation={ajax:true,scroll_error:true,required_marker:'*',error_message:'<?php echo addslashes(Text::_('COM_DECAROFORMS_DEFAULT_ERROR_MESSAGE')); ?>',...(builderConfig.validation||{})};
builderConfig.confirmation={enabled:true,position:'below',format:'text',scroll:false,continue:false,continue_label:'<?php echo addslashes(Text::_('COM_DECAROFORMS_CONTINUE')); ?>',continue_url:'',...(builderConfig.confirmation||{})};
builderConfig.security={min_seconds:2,rate_seconds:8,...(builderConfig.security||{})};
builderConfig.geography={default_country:'IT',default_region:'Lazio',...(builderConfig.geography||{})};
integrations.google_sheets={enabled:false,webhook_url:'',secret:'',include_files:false,...(integrations.google_sheets||{})};
emailConfig.admin=emailConfig.admin||{};emailConfig.user=emailConfig.user||{};
emailConfig.admin.custom={base:'standard',primary:'#e60046',secondary:'#26364a',background:'#ffffff',text:'#20262d',button:'#e60046',border:'#dfe3e7',radius:8,...(emailConfig.admin.custom||{})};
emailConfig.user.custom={base:'standard',primary:'#e60046',secondary:'#26364a',background:'#ffffff',text:'#20262d',button:'#e60046',border:'#dfe3e7',radius:8,...(emailConfig.user.custom||{})};

const hidden={fields:document.getElementById('df-fields-json'),fieldCount:document.getElementById('df-fields-count'),statuses:document.getElementById('df-statuses-json'),columns:document.getElementById('df-columns-json'),builder:document.getElementById('df-builder-config-json'),email:document.getElementById('df-email-config-json'),additional:document.getElementById('df-additional-emails-json'),integrations:document.getElementById('df-integrations-json')};
const sel=document.getElementById('df-selected'),lib=document.getElementById('df-library'),search=document.getElementById('df-library-search'),filter=document.getElementById('df-library-filter'),statusEditor=document.getElementById('df-status-editor'),columnList=document.getElementById('df-column-list');
const types=Object.keys(tr.types);
const categoryOrder=['personal','contact','address','choices','values','datetime','document','payment','structure','consent','custom'];
const templateDefs=[['standard','Standard'],['minimal','Minimal'],['institutional','Istituzionale'],['card','Scheda'],['compact','Compatto'],['modern','Moderno'],['elegant','Elegante'],['receipt','Ricevuta'],['professional','Professionale'],['custom','Personalizzato'],['html','HTML libero'],['chatgpt','AI']];

let historyStates=[],historyIndex=-1,historyReady=false,historyApplying=false,historyTimer=null,initialHistorySignature='';
function simpleFormState(){return [...document.querySelectorAll('#df-builder-form [name]:not([type="hidden"])')].map(el=>({name:el.name,type:el.type,value:el.type==='checkbox'||el.type==='radio'?!!el.checked:el.value}));}
function captureHistoryState(){return {selected:clone(selected),statuses:clone(statuses),columns:clone(columns),builderConfig:clone(builderConfig),emailConfig:clone(emailConfig),additionalEmails:clone(additionalEmails),integrations:clone(integrations),activeFieldKey,form:simpleFormState()};}
function historySignature(state){return JSON.stringify(state);}
function updateHistoryButtons(){const locked=document.querySelector('.df-builder')?.classList.contains('is-locked');document.getElementById('df-undo').disabled=locked||historyIndex<=0;document.getElementById('df-redo').disabled=locked||historyIndex<0||historyIndex>=historyStates.length-1;}
function pushHistory(){if(!historyReady||historyApplying)return;const state=captureHistoryState(),sig=historySignature(state);if(historyIndex>=0&&historySignature(historyStates[historyIndex])===sig)return;historyStates=historyStates.slice(0,historyIndex+1);historyStates.push(state);if(historyStates.length>50)historyStates.shift();historyIndex=historyStates.length-1;updateHistoryButtons();}
function scheduleHistory(){if(!historyReady||historyApplying)return;clearTimeout(historyTimer);historyTimer=setTimeout(pushHistory,300);}
function restoreHistory(index){if(index<0||index>=historyStates.length)return;historyApplying=true;const s=clone(historyStates[index]);selected=s.selected;statuses=s.statuses;columns=s.columns;builderConfig=s.builderConfig;emailConfig=s.emailConfig;additionalEmails=s.additionalEmails;integrations=s.integrations;activeFieldKey=s.activeFieldKey;renderSelected();renderLayout();renderStatuses();renderColumns();renderTokens();renderUserEmailFields();if(emailPickersRendered)renderEmailPickers();renderAdditional();const controls=[...document.querySelectorAll('#df-builder-form [name]:not([type="hidden"])')];(s.form||[]).forEach((v,i)=>{const el=controls[i];if(el&&el.name===v.name){if(el.type==='checkbox'||el.type==='radio')el.checked=!!v.value;else el.value=v.value;}});historyIndex=index;sync();historyApplying=false;applyLockState();updateHistoryButtons();}
function sync(){hidden.fields.value=JSON.stringify(selected);if(hidden.fieldCount)hidden.fieldCount.value=String(selected.length);hidden.statuses.value=JSON.stringify(statuses.map(({_new,...st})=>st));hidden.columns.value=JSON.stringify(columns);hidden.builder.value=JSON.stringify(builderConfig);hidden.email.value=JSON.stringify(emailConfig);hidden.additional.value=JSON.stringify(additionalEmails);hidden.integrations.value=JSON.stringify(integrations);document.getElementById('df-legacy-admin-template').value=emailConfig.admin.template||'standard';document.getElementById('df-legacy-user-template').value=emailConfig.user.template||'standard';scheduleHistory();if(document.querySelector('.df-builder')?.classList.contains('is-locked'))queueMicrotask(applyLockState);}
function uniqueKey(base,ignoreKey=''){base=String(base||'field').replace(/[^a-zA-Z0-9_]+/g,'_').replace(/^_+|_+$/g,'').toLowerCase()||'field';let k=base,n=2;while(selected.some(x=>x.key===k&&x.key!==ignoreKey))k=base+'_'+n++;return k;}
function defaultFieldConfig(x){x.config=x.config&&typeof x.config==='object'?x.config:{};x.config.layout={row:Number(x.config.layout?.row||selected.length+1),col:Number(x.config.layout?.col||1),width:Number(x.config.layout?.width||100),...(x.config.layout||{})};x.config.conditions=Array.isArray(x.config.conditions)?x.config.conditions:[];x.config.condition_logic=x.config.condition_logic||'all';x.config.condition_action=x.config.condition_action||'show';return x;}
selected=selected.map(defaultFieldConfig);window.dfBuilderSync=sync;window.dfBuilderFieldCount=()=>selected.length;window.dfBuilderFieldsSnapshot=()=>clone(selected);
function fieldsInRow(row){return selected.map((f,i)=>[f,i]).filter(([f])=>Number(f.config?.layout?.row||1)===Number(row)).sort(([a],[b])=>(a.config.layout.col||1)-(b.config.layout.col||1));}
function distributeRow(row){const items=fieldsInRow(row),n=items.length;if(!n)return;const base=Math.floor(100/n),extra=100-base*n;items.forEach(([f],i)=>{f.config.layout.width=base+(i<extra?1:0);f.config.layout.col=i+1;});}
function repairInvalidRows(){[...new Set(selected.map(f=>Number(f.config.layout.row||1)))].forEach(row=>{const items=fieldsInRow(row),total=items.reduce((sum,[f])=>sum+Number(f.config.layout.width||0),0);if(total!==100)distributeRow(row);});}
repairInvalidRows();
const openFieldKeys=new Set(selected.slice(0,1).map(x=>x.key));let activeFieldKey=selected[0]?.key||null;
function add(item){const x=defaultFieldConfig(clone(item));x.key=uniqueKey(x.key);x.options=Array.isArray(x.options)?x.options:[];const maxRow=Math.max(0,...selected.map(f=>Number(f.config?.layout?.row||0)));x.config.layout={row:maxRow+1,col:1,width:100};selected.push(x);activeFieldKey=x.key;openFieldKeys.clear();openFieldKeys.add(x.key);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();const selectedSection=[...document.querySelectorAll('[data-accordion]')][2];if(selectedSection){selectedSection.classList.add('is-open');selectedSection.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','true');}setTimeout(()=>{sel.querySelector('.df-selected-item.is-open')?.scrollIntoView({behavior:'smooth',block:'nearest'});},100);}

/* Forms 1.3.6: bind quick templates early so unrelated later initializers cannot disable them. */
const quickFormTemplates={contact:['first_name','last_name','email','phone','subject','message','privacy_consent'],registration:['first_name','last_name','birth_date','email','phone','address','postcode','city','privacy_consent'],event:['first_name','last_name','email','event_date','participants','notes','privacy_consent'],membership:['first_name','last_name','birth_date','email','phone','address','postcode','city','member_number','privacy_consent'],reservation:['first_name','last_name','email','phone','event_date','participants','notes'],blank:[]};
function applyQuickTemplate(button){
 const name=button.dataset.formTemplate;
 const map=Object.fromEntries(library.map(x=>[x.key,x]));
 try{
  const wanted=quickFormTemplates[name]||[];
  const next=[];
  if(name!=='blank')wanted.forEach(k=>{if(!map[k])return;const f=defaultFieldConfig(clone(map[k]));f.key=String(f.key||k);f.options=Array.isArray(f.options)?f.options:[];next.push(f);});
  if(name!=='blank'&&!next.length)throw new Error('Quick template contains no available fields: '+name);
  selected.splice(0,selected.length,...next);
  selected.forEach((f,i)=>{defaultFieldConfig(f);f.config.layout={row:i+1,col:1,width:100};});
  openFieldKeys.clear();
  activeFieldKey=selected[0]?.key||null;
  if(activeFieldKey)openFieldKeys.add(activeFieldKey);
  sync();renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();
  document.querySelectorAll('[data-form-template]').forEach(x=>x.classList.toggle('is-active',x===button));
  const quick=[...document.querySelectorAll('[data-accordion]')][1];
  quick?.classList.remove('is-open');quick?.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','false');
  openBuilderSection(2,true);
 }catch(err){console.error('Forms quick template error',err);alert('Impossibile caricare il modello rapido. Ricarica la pagina e riprova.');}
}
document.addEventListener('click',e=>{const button=e.target.closest('[data-form-template]');if(!button)return;e.preventDefault();e.stopPropagation();applyQuickTemplate(button);});

/* Forms 1.3.17: reusable quick models saved from the current module structure. */
const savedQuickTemplateStorageKey='decaroforms_saved_quick_templates_v1';
function loadSavedQuickTemplates(){
 try{const parsed=JSON.parse(localStorage.getItem(savedQuickTemplateStorageKey)||'[]');return Array.isArray(parsed)?parsed:[];}
 catch(e){console.warn('Forms saved quick models could not be loaded',e);return [];}
}
function persistSavedQuickTemplates(){
 try{localStorage.setItem(savedQuickTemplateStorageKey,JSON.stringify(savedQuickTemplates));}
 catch(e){console.warn('Forms saved quick models could not be saved',e);}
}
let savedQuickTemplates=loadSavedQuickTemplates();
function renderSavedQuickTemplates(){
 const box=document.getElementById('df-saved-quick-templates'),heading=document.getElementById('df-saved-quick-heading');
 if(!box)return;
 box.innerHTML='';
 if(heading)heading.hidden=!savedQuickTemplates.length;
 savedQuickTemplates.forEach(tpl=>{
  const wrap=document.createElement('span');wrap.className='df-saved-quick-item';
  wrap.innerHTML=`<button type="button" class="df-saved-quick-use" data-saved-quick="${esc(tpl.id)}" title="Carica modello rapido">${esc(tpl.name)}</button><button type="button" class="df-saved-quick-delete df-icon-only" data-saved-quick-delete="${esc(tpl.id)}" title="Elimina modello salvato" aria-label="Elimina modello salvato">${uiIcon('trash')}</button>`;
  box.appendChild(wrap);
 });
}
function saveQuickTemplateNamed(name){
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
function applySavedQuickTemplate(id,button){
 const tpl=savedQuickTemplates.find(x=>x.id===id);if(!tpl)return;
 const next=(Array.isArray(tpl.fields)?tpl.fields:[]).map(f=>defaultFieldConfig(clone(f)));
 selected.splice(0,selected.length,...next);
 activeFieldKey=selected[0]?.key||null;
 normalizeLayoutRows();renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();sync();
 document.querySelectorAll('[data-form-template],.df-saved-quick-use').forEach(x=>x.classList.toggle('is-active',x===button));
 const quick=[...document.querySelectorAll('[data-accordion]')][1];
 quick?.classList.remove('is-open');quick?.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','false');
 const fieldsSection=[...document.querySelectorAll('[data-accordion]')][2];
 fieldsSection?.classList.add('is-open');fieldsSection?.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','true');
}
document.getElementById('df-save-structure')?.addEventListener('click',saveCurrentStructureAsQuickTemplate);
document.addEventListener('click',e=>{
 const use=e.target.closest('[data-saved-quick]');
 if(use){e.preventDefault();e.stopPropagation();applySavedQuickTemplate(use.dataset.savedQuick,use);return;}
 const del=e.target.closest('[data-saved-quick-delete]');
 if(del){e.preventDefault();e.stopPropagation();const tpl=savedQuickTemplates.find(x=>x.id===del.dataset.savedQuickDelete);confirmDelete(`il modello salvato “${tpl?.name||'Modello personalizzato'}”`,()=>{savedQuickTemplates=savedQuickTemplates.filter(x=>x.id!==del.dataset.savedQuickDelete);persistSavedQuickTemplates();renderSavedQuickTemplates();});}
});
renderSavedQuickTemplates();



// Accordion behavior.
const accordionSections=[...document.querySelectorAll('[data-accordion]')];accordionSections.forEach((section,index)=>{const btn=section.querySelector('.df-section-toggle');const setOpen=open=>{section.classList.toggle('is-open',open);btn?.setAttribute('aria-expanded',open?'true':'false');};setOpen(index===0);btn?.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();const open=!section.classList.contains('is-open');setOpen(open);});});

let activeLibraryCategory='personal';
function renderLibrary(){
 const tabs=document.getElementById('df-library-tabs');
 const q=(search.value||'').trim().toLowerCase();
 const counts=Object.fromEntries(categoryOrder.map(c=>[c,library.filter(x=>x.category===c).length]));
 tabs.innerHTML=`<button type="button" class="df-library-tab ${activeLibraryCategory==='all'?'is-active':''}" data-libcat="all">Tutti <span class="df-library-tab-count">${library.length}</span></button>`+categoryOrder.map(c=>`<button type="button" class="df-library-tab ${activeLibraryCategory===c?'is-active':''}" data-libcat="${c}">${esc(tr.cats[c]||c)} <span class="df-library-tab-count">${counts[c]||0}</span></button>`).join('');
 tabs.querySelectorAll('[data-libcat]').forEach(b=>b.onclick=()=>{activeLibraryCategory=b.dataset.libcat;renderLibrary();});
 const items=library.filter(x=>(q||activeLibraryCategory==='all'||x.category===activeLibraryCategory)&&(!q||`${x.label} ${x.key} ${x.type} ${tr.cats[x.category]||''}`.toLowerCase().includes(q)));
 lib.innerHTML='';
 if(!items.length){lib.innerHTML='<div class="df-library-empty">Nessun campo trovato.</div>';return;}
 const grid=document.createElement('div');grid.className='df-library-items-grid';
 items.forEach(x=>{const d=document.createElement('div');d.className='df-lib-item';const saved=!!x._savedPresetId;d.innerHTML=`<div><strong>${esc(x.label)}</strong><small>${esc(tr.cats[x.category]||x.category)} · ${esc(tr.types[x.type]||x.type)}${saved?' · Salvato':''}</small></div><div class="df-lib-actions"><button class="df-add" type="button">${esc(tr.add)}</button>${saved?`<button class="df-lib-delete df-icon-only" type="button" title="${esc(tr.remove)}" aria-label="${esc(tr.remove)}">${uiIcon('trash')}</button>`:''}</div>`;d.querySelector('.df-add').onclick=()=>add(x);d.querySelector('.df-lib-delete')?.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();confirmDelete(`il campo personalizzato “${x.label||'Campo'}”`,()=>deleteSavedFieldPreset(x._savedPresetId));});grid.appendChild(d);});lib.appendChild(grid);
}
filter.innerHTML='';filter.hidden=true;search.addEventListener('input',renderLibrary);renderLibrary();

function fieldSelectOptions(current=''){return selected.map(f=>`<option value="${esc(f.key)}" ${f.key===current?'selected':''}>${esc(f.label)} (${esc(f.key)})</option>`).join('');}
function configHtml(x){const c=x.config||{},t=x.type;let h='';if(['select','multiselect','radio','checkboxes','city'].includes(t)){h+=`<div class="full"><label>${esc(tr.options)}</label><textarea class="df-options" data-k="options">${esc((x.options||[]).join('\n'))}</textarea><div class="df-note"><?php echo addslashes(Text::_('COM_DECAROFORMS_OPTIONS_COMPACT_NOTE')); ?></div></div>`;}
if(['file','upload'].includes(t)){h+=`<div class="df-config-panel"><strong><?php echo addslashes(Text::_('COM_DECAROFORMS_UPLOAD_SETTINGS')); ?></strong><div class="df-config-grid"><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_FILE_TYPES')); ?></label><input data-cfg="accept" value="${esc(c.accept||'.pdf,.jpg,.jpeg,.png,.webp,.doc,.docx')}"></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_MAX_MB')); ?></label><input type="number" min="1" max="25" data-cfg="max_mb" value="${esc(c.max_mb||5)}"></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_MAX_FILES')); ?></label><input type="number" min="1" max="10" data-cfg="max_files" value="${esc(c.max_files||1)}"></div><div class="df-required"><input type="checkbox" data-cfg-check="multiple" ${c.multiple?'checked':''}><label><?php echo addslashes(Text::_('COM_DECAROFORMS_MULTIPLE_FILES')); ?></label></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_BUTTON_LABEL')); ?></label><input data-cfg="button_label" value="${esc(c.button_label||'')}"></div></div></div>`;}
if(t==='range'){h+=`<div class="df-config-panel"><strong><?php echo addslashes(Text::_('COM_DECAROFORMS_RANGE_SETTINGS')); ?></strong><div class="df-config-grid"><div><label>Min</label><input type="number" data-cfg="min" value="${esc(c.min??0)}"></div><div><label>Max</label><input type="number" data-cfg="max" value="${esc(c.max??100)}"></div><div><label>Step</label><input type="number" data-cfg="step" value="${esc(c.step??1)}"></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_UNIT')); ?></label><input data-cfg="unit" value="${esc(c.unit||'')}"></div><div class="df-required"><input type="checkbox" data-cfg-check="dual" ${c.dual?'checked':''}><label><?php echo addslashes(Text::_('COM_DECAROFORMS_DUAL_RANGE')); ?></label></div></div></div>`;}
if(['separator','pagebreak'].includes(t)){h+=`<div class="df-config-panel"><strong><?php echo addslashes(Text::_('COM_DECAROFORMS_LINE_SETTINGS')); ?></strong><div class="df-config-grid"><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_COLOR')); ?></label><input type="color" data-cfg="color" value="${esc(c.color||'#dfe3e7')}"></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_BORDER_WIDTH')); ?> (px)</label><input type="number" min="0" max="20" data-cfg="border_width" value="${esc(c.border_width??1)}"></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_BORDER_STYLE')); ?></label><select data-cfg="border_style"><option value="solid" ${c.border_style==='solid'||!c.border_style?'selected':''}>Continua</option><option value="dashed" ${c.border_style==='dashed'?'selected':''}>Tratteggiata</option><option value="dotted" ${c.border_style==='dotted'?'selected':''}>Puntinata</option><option value="double" ${c.border_style==='double'?'selected':''}>Doppia</option></select></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_LINE_LENGTH')); ?> %</label><input type="number" min="0" max="100" data-cfg="line_width" value="${esc(c.line_width??100)}"></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_MARGIN')); ?> px</label><input type="number" min="0" max="200" data-cfg="margin" value="${esc(c.margin??20)}"></div>${t==='pagebreak'?`<div class="df-required"><input type="checkbox" data-cfg-check="show_line" ${c.show_line!==false?'checked':''}><label><?php echo addslashes(Text::_('COM_DECAROFORMS_SHOW_LINE_FRONTEND')); ?></label></div>`:''}</div></div>`;}
if(t==='page'){h+=`<div class="df-config-panel"><strong><?php echo addslashes(Text::_('COM_DECAROFORMS_MULTIPAGE_SETTINGS')); ?></strong><div class="df-config-grid"><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_PAGE_TITLE')); ?></label><input data-cfg="page_title" value="${esc(c.page_title||x.label)}"></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_PAGE_DESCRIPTION')); ?></label><input data-cfg="page_description" value="${esc(c.page_description||'')}"></div><div class="df-required"><input type="checkbox" data-cfg-check="show_progress" ${c.show_progress!==false?'checked':''}><label><?php echo addslashes(Text::_('COM_DECAROFORMS_SHOW_PROGRESS')); ?></label></div></div></div>`;}
if(t==='map'){h+=`<div class="df-config-panel"><strong><?php echo addslashes(Text::_('COM_DECAROFORMS_MAP_SETTINGS')); ?></strong><div class="df-config-grid"><div><label>Lat</label><input data-cfg="lat" value="${esc(c.lat||'41.9028')}"></div><div><label>Lng</label><input data-cfg="lng" value="${esc(c.lng||'12.4964')}"></div><div><label>Zoom</label><input type="number" min="2" max="19" data-cfg="zoom" value="${esc(c.zoom||12)}"></div><div class="df-required"><input type="checkbox" data-cfg-check="use_location" ${c.use_location!==false?'checked':''}><label><?php echo addslashes(Text::_('COM_DECAROFORMS_ALLOW_GEOLOCATION')); ?></label></div></div></div>`;}
if(t==='payment'){h+=`<div class="df-config-panel"><strong><?php echo addslashes(Text::_('COM_DECAROFORMS_PAYMENT_SETTINGS')); ?></strong><div class="df-config-grid"><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_PAYMENT_METHOD')); ?></label><select data-cfg="method"><option value="bank">Bonifico bancario</option><option disabled>Carta — <?php echo addslashes(Text::_('COM_DECAROFORMS_COMING_SOON')); ?></option><option disabled>PayPal — <?php echo addslashes(Text::_('COM_DECAROFORMS_COMING_SOON')); ?></option></select></div><div><label>IBAN</label><input data-cfg="iban" value="${esc(c.iban||'')}"></div><div><label>BIC / SWIFT</label><input data-cfg="bic" value="${esc(c.bic||'')}" placeholder="BCITITMM"></div><div><label>Paese banca</label><input data-cfg="bank_country" value="${esc(c.bank_country||'IT')}" placeholder="IT"></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_ACCOUNT_HOLDER')); ?></label><input data-cfg="holder" value="${esc(c.holder||'')}"></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_AMOUNT')); ?></label><input data-cfg="amount" value="${esc(c.amount||'')}"></div><div class="full"><label><?php echo addslashes(Text::_('COM_DECAROFORMS_PAYMENT_CAUSE')); ?></label><input data-cfg="cause" value="${esc(c.cause||'{last_name} {first_name} - {riferimento}')}"><div class="df-note">{first_name} {last_name} {email} {riferimento} {data} {anno}</div></div></div></div>`;}
if(t==='calculated'){h+=`<div class="df-config-panel"><strong><?php echo addslashes(Text::_('COM_DECAROFORMS_CALC_SETTINGS')); ?></strong><div class="df-config-grid"><div class="full"><label><?php echo addslashes(Text::_('COM_DECAROFORMS_FORMULA')); ?></label><input data-cfg="formula" value="${esc(c.formula||'')}"><div class="df-note">Esempio: {participants} * 25</div></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_PREFIX')); ?></label><input data-cfg="prefix" value="${esc(c.prefix||'')}"></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_SUFFIX')); ?></label><input data-cfg="suffix" value="${esc(c.suffix||'')}"></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_DECIMALS')); ?></label><input type="number" min="0" max="6" data-cfg="decimals" value="${esc(c.decimals??2)}"></div><div class="df-required"><input type="checkbox" data-cfg-check="visible" ${c.visible!==false?'checked':''}><label><?php echo addslashes(Text::_('COM_DECAROFORMS_VISIBLE_FIELD')); ?></label></div></div></div>`;}
if(['heading','info','fieldset'].includes(t)){h+=`<div class="df-config-panel"><strong><?php echo addslashes(Text::_('COM_DECAROFORMS_CONTENT')); ?></strong><textarea class="df-options" data-cfg="content">${esc(c.content||'')}</textarea></div>`;}
if(t==='province'){h+=`<div class="df-config-panel"><label>Formato provincia</label><select data-cfg="display_format"><option value="name_code" ${c.display_format==='name_code'||!c.display_format?'selected':''}>Nome e sigla — Roma (RM)</option><option value="name" ${c.display_format==='name'?'selected':''}>Solo nome — Roma</option><option value="code" ${c.display_format==='code'?'selected':''}>Solo sigla — RM</option></select></div>`;}
if(t==='tax_code'){const linkNames=[['first_name','Nome'],['last_name','Cognome'],['birth_date','Data di nascita'],['gender','Sesso'],['birth_city','Comune di nascita'],['birth_country','Stato estero'],['birth_province','Provincia di nascita']];c.links=c.links||{};const opts=(role,current)=>`<option value="">Campo non collegato — Aggiungi campo</option>`+selected.filter(f=>f.key!==x.key).map(f=>`<option value="${esc(f.key)}" ${current===f.key?'selected':''}>${esc(f.label)} (${esc(f.key)})</option>`).join('');h+=`<details class="df-tax-links"><summary>Verifica codice fiscale</summary><div class="df-tax-links-body"><p class="df-note">Collega i dati già presenti per verificare la coerenza. Il codice resta quello dichiarato dall’utente.</p>${linkNames.map(([role,label])=>`<div class="df-field"><label>${label}</label><select data-tax-link="${role}">${opts(role,c.links[role]||'')}</select></div>`).join('')}<div class="df-tax-conflict" hidden></div></div></details>`;}
if(t==='member_number'){h+=`<div class="df-config-panel"><div class="df-config-grid"><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_MIN_LENGTH')); ?></label><input type="number" data-cfg="min_length" value="${esc(c.min_length||1)}"></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_MAX_LENGTH')); ?></label><input type="number" data-cfg="max_length" value="${esc(c.max_length||20)}"></div></div><div class="df-note"><?php echo addslashes(Text::_('COM_DECAROFORMS_NUMERIC_ID_NOTE')); ?></div></div>`;}
if(t==='postcode'){h+=`<div class="df-config-panel"><div class="df-note"><?php echo addslashes(Text::_('COM_DECAROFORMS_POSTCODE_ITALY_NOTE')); ?></div></div>`;}
return h;}
function renderConditions(x,i){const c=x.config||{},rules=Array.isArray(c.conditions)?c.conditions:[];const rows=rules.map((r,ri)=>`<div class="df-condition-row"><select data-cond-field="${ri}"><option value="">— Campo —</option>${fieldSelectOptions(r.field||'')}</select><select data-cond-op="${ri}">${[['eq','='],['neq','≠'],['contains','contiene'],['not_contains','non contiene'],['empty','vuoto'],['not_empty','non vuoto'],['gt','>'],['lt','<'],['checked','selezionato'],['not_checked','non selezionato']].map(([v,l])=>`<option value="${v}" ${r.operator===v?'selected':''}>${l}</option>`).join('')}</select><input data-cond-value="${ri}" value="${esc(r.value||'')}" placeholder="Valore"><button type="button" data-cond-remove="${ri}">${uiIcon('trash')}<span>Elimina condizione</span></button></div>`).join('');return `<details class="df-condition-details"><summary>${esc(tr.conditions)} <span class="df-note">${rules.length?rules.length+' regola'+(rules.length===1?'':'e'):''}</span></summary><div class="df-condition-body"><p class="df-note">Mostra, nascondi o rendi obbligatorio questo campo in base ad altri valori.</p><div class="df-condition-controls"><div><label>Azione</label><select data-cfg="condition_action"><option value="show" ${c.condition_action==='show'?'selected':''}>Mostra</option><option value="hide" ${c.condition_action==='hide'?'selected':''}>Nascondi</option><option value="require" ${c.condition_action==='require'?'selected':''}>Rendi obbligatorio</option><option value="disable" ${c.condition_action==='disable'?'selected':''}>Disabilita</option></select></div><div><label>Applica le condizioni</label><select data-cfg="condition_logic"><option value="all" ${c.condition_logic!=='any'?'selected':''}>${esc(tr.all)}</option><option value="any" ${c.condition_logic==='any'?'selected':''}>${esc(tr.any)}</option></select></div></div><div class="df-condition-list">${rows||`<div class="df-note">Nessuna condizione configurata.</div>`}</div><button class="df-btn df-small" type="button" data-add-condition>+ ${esc(tr.addCondition)}</button></div></details>`;}
function renderSelected(){sel.innerHTML='';if(!selected.length){activeFieldKey=null;openFieldKeys.clear();sel.innerHTML='<div class="df-selected-empty">Seleziona o aggiungi un campo per modificarne le impostazioni.</div>';sync();renderLayoutCanvas();return;}if(!selected.some(x=>x.key===activeFieldKey))activeFieldKey=selected[0].key;openFieldKeys.clear();openFieldKeys.add(activeFieldKey);selected.map((x,i)=>[x,i]).filter(([x])=>x.key===activeFieldKey).forEach(([x,i])=>{defaultFieldConfig(x);const d=document.createElement('div');d.className='df-selected-item is-open';const req=x.required?'<span class="df-summary-chip df-required-badge">Obbligatorio</span>':'';d.innerHTML=`<div class="df-selected-top"><button type="button" class="df-field-toggle" data-field-toggle><span class="df-field-chevron">⌄</span><span class="df-field-toggle-main"><strong>${i+1}. ${esc(x.label)}</strong><span class="df-field-summary"><span class="df-summary-chip">${esc(tr.types[x.type]||x.type)}</span>${req}<span class="df-summary-chip">${esc(x.config.layout.width||100)}%</span></span></span></button><div class="df-mini-actions"><button type="button" data-act="save-preset" class="df-save-preset" title="Salva come campo personalizzato" aria-label="Salva come campo personalizzato"><svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M5 3h11l3 3v15H5V3zm2 2v5h9V5H7zm0 14h10v-6H7v6z" fill="currentColor"/></svg></button><button type="button" data-act="up" title="${esc(tr.moveUp)}">↑</button><button type="button" data-act="down" title="${esc(tr.moveDown)}">↓</button><button type="button" data-act="remove" class="df-icon-only" title="${esc(tr.remove)}" aria-label="${esc(tr.remove)}">${uiIcon('trash')}</button></div></div><div class="df-selected-config-wrap"><div class="df-selected-config-inner"><div class="df-selected-config"><details class="full df-main-settings" open><summary>Impostazioni principali</summary><div class="df-main-settings-body"><div class="df-main-settings-grid"><div><label>${esc(tr.label)}</label><input data-k="label" value="${esc(x.label)}"></div><div><label>${esc(tr.key)}</label><input data-k="key" value="${esc(x.key)}"></div><div><label>${esc(tr.type)}</label><select data-k="type">${types.map(t=>`<option value="${t}" ${x.type===t?'selected':''}>${esc(tr.types[t]||t)}</option>`).join('')}</select></div><div><label>${esc(tr.placeholder)}</label><input data-k="placeholder" value="${esc(x.placeholder||'')}"></div><div><label>${esc(tr.default)}</label><input data-k="default" value="${esc(x.default||'')}"></div><div><label>${esc(tr.help)}</label><input data-k="help" value="${esc(x.help||'')}"></div></div></div></details><details class="full df-layout-settings"><summary>Layout e larghezza</summary><div class="df-layout-settings-body"><div class="df-required"><input type="checkbox" data-k-check="required" ${x.required?'checked':''}><label>${esc(tr.required)}</label></div><div class="df-field-width-block"><label>Larghezza</label><div class="df-field-width-pills">${[100,75,66,60,50,40,33,25].map(w=>`<button type="button" data-field-width="${w}" class="${Number(x.config.layout.width||100)===w?'is-active':''}">${w}%</button>`).join('')}</div></div></div></details>${configHtml(x)}${renderConditions(x,i)}</div></div></div>`;
 d.querySelector('[data-field-toggle]').onclick=()=>{};d.querySelectorAll('[data-field-width]').forEach(btn=>btn.onclick=()=>{setFieldWidth(i,Number(btn.dataset.fieldWidth));});
 d.querySelectorAll('[data-k]').forEach(el=>el.addEventListener('input',()=>{const k=el.dataset.k;if(k==='options')x.options=el.value.split(/\r?\n/).map(v=>v.trim()).filter(Boolean);else{if(k==='key'){const old=x.key,next=uniqueKey(el.value,old);x.key=next;el.value=next;openFieldKeys.delete(old);openFieldKeys.add(next);activeFieldKey=next;}else x[k]=el.value;}sync();if(k==='label'||k==='key'){renderColumns();renderTokens();renderUserEmailFields();renderAdditional();renderLayoutCanvas();}if(k==='type'){renderSelected();renderColumns();renderUserEmailFields();}}));
 d.querySelectorAll('[data-k-check]').forEach(el=>el.addEventListener('change',()=>{x[el.dataset.kCheck]=el.checked;sync();renderSelected();renderLayoutCanvas();}));
 d.querySelectorAll('[data-cfg]').forEach(el=>{const ev=el.tagName==='SELECT'?'change':'input';el.addEventListener(ev,()=>{setDeep(x.config,el.dataset.cfg,el.type==='number'?Number(el.value):el.value);sync();if(el.dataset.cfg.startsWith('layout.'))renderLayoutCanvas();});});
 d.querySelectorAll('[data-cfg-check]').forEach(el=>el.addEventListener('change',()=>{setDeep(x.config,el.dataset.cfgCheck,el.checked);sync();})); d.querySelectorAll('[data-tax-link]').forEach(el=>el.addEventListener('change',()=>{x.config.links=x.config.links||{};x.config.links[el.dataset.taxLink]=el.value;sync();}));const labelCounts=selected.reduce((m,f)=>{const k=String(f.label||'').trim().toLocaleLowerCase();if(k)m[k]=(m[k]||0)+1;return m;},{}),hasDuplicateLabels=Object.values(labelCounts).some(n=>n>1);const conflict=d.querySelector('.df-tax-conflict');if(conflict&&hasDuplicateLabels){conflict.hidden=false;conflict.className='df-status-warning';conflict.textContent='Attenzione: esistono campi con lo stesso nome. Usa la chiave mostrata tra parentesi per scegliere quello corretto.';}
 d.querySelector('[data-act="save-preset"]').onclick=e=>{e.preventDefault();e.stopPropagation();const btn=e.currentTarget;openActionModal({title:'Salva campo personalizzato',message:`Salvare “${x.label||'Campo'}” nella Libreria campi → Personalizzati?`,confirmLabel:'Salva',onConfirm:()=>{saveFieldPreset(x);btn.classList.add('is-saved');btn.title='Salvato nei campi personalizzati';setTimeout(()=>{btn.classList.remove('is-saved');btn.title='Salva come campo personalizzato';},1200);}});}; d.querySelector('[data-act="up"]').onclick=()=>{if(i>0){[selected[i-1],selected[i]]=[selected[i],selected[i-1]];renderSelected();renderLayoutCanvas();}};d.querySelector('[data-act="down"]').onclick=()=>{if(i<selected.length-1){[selected[i+1],selected[i]]=[selected[i],selected[i+1]];renderSelected();renderLayoutCanvas();}};d.querySelector('[data-act="remove"]').onclick=()=>confirmDelete(`il campo “${x.label||'Campo'}”`,()=>{const removedRow=Number(x.config.layout.row||1);openFieldKeys.delete(x.key);selected.splice(i,1);activeFieldKey=selected[Math.min(i,selected.length-1)]?.key||null;normalizeLayoutRows();distributeRow(removedRow);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();sync();});
 d.querySelector('[data-add-condition]')?.addEventListener('click',e=>{e.preventDefault();x.config.conditions.push({field:'',operator:'eq',value:''});renderSelected();setTimeout(()=>{const items=sel.querySelectorAll('.df-selected-item');items[i]?.querySelector('.df-condition-details')?.setAttribute('open','');},0);});d.querySelectorAll('[data-cond-field]').forEach(el=>el.addEventListener('change',()=>{x.config.conditions[Number(el.dataset.condField)].field=el.value;sync();}));d.querySelectorAll('[data-cond-op]').forEach(el=>el.addEventListener('change',()=>{x.config.conditions[Number(el.dataset.condOp)].operator=el.value;sync();}));d.querySelectorAll('[data-cond-value]').forEach(el=>el.addEventListener('input',()=>{x.config.conditions[Number(el.dataset.condValue)].value=el.value;sync();}));d.querySelectorAll('[data-cond-remove]').forEach(el=>el.addEventListener('click',()=>confirmDelete('questa condizione',()=>{x.config.conditions.splice(Number(el.dataset.condRemove),1);renderSelected();sync();})));sel.appendChild(d);});sync();}

// Layout.
const layoutColumns=document.getElementById('df-layout-columns'),layoutWidths=document.getElementById('df-layout-widths'),layoutTotal=document.getElementById('df-layout-total'),mobileStack=document.getElementById('df-layout-mobile-stack'),layoutCanvas=document.getElementById('df-layout-canvas'),layoutNewRow=document.getElementById('df-layout-newrow');
let draggedFieldIndex=null;
function normalizeLayoutRows(){const rows=[...new Set(selected.map(f=>Number(f.config?.layout?.row||1)))].sort((a,b)=>a-b);const map=new Map(rows.map((r,i)=>[r,i+1]));selected.forEach(f=>{defaultFieldConfig(f);f.config.layout.row=map.get(Number(f.config.layout.row||1))||1;});for(const row of [...new Set(selected.map(f=>f.config.layout.row))])selected.filter(f=>f.config.layout.row===row).sort((a,b)=>(a.config.layout.col||1)-(b.config.layout.col||1)).forEach((f,i)=>f.config.layout.col=i+1);}
function widthChoices(current){const vals=[100,75,66,60,50,40,33,25];if(!vals.includes(Number(current)))vals.push(Number(current)||100);return vals.map(v=>`<option value="${v}" ${Number(current)===v?'selected':''}>${v}%</option>`).join('');}
function setFieldWidth(index,width){if(index==null||!selected[index])return;const field=selected[index],row=Number(field.config.layout.row||1),items=fieldsInRow(row);width=Math.max(10,Math.min(100,Number(width)||100));if(items.length===1){field.config.layout.width=100;}else if(width===100){field.config.layout.width=100;let nextRow=Math.max(0,...selected.map(f=>Number(f.config.layout.row||1)))+1;items.filter(([,i])=>i!==index).forEach(([f])=>{f.config.layout.row=nextRow++;f.config.layout.col=1;f.config.layout.width=100;});normalizeLayoutRows();}else{field.config.layout.width=width;const others=items.filter(([,i])=>i!==index),remaining=100-width,base=Math.floor(remaining/others.length),extra=remaining-base*others.length;others.forEach(([f],i)=>f.config.layout.width=base+(i<extra?1:0));}sync();renderSelected();renderLayoutCanvas();}
function selectField(index){if(index==null||!selected[index])return;activeFieldKey=selected[index].key;openFieldKeys.clear();openFieldKeys.add(activeFieldKey);renderSelected();document.querySelectorAll('.df-layout-card').forEach(card=>card.classList.toggle('is-active',card.dataset.fieldKey===activeFieldKey));}
function duplicateField(index){if(index==null||!selected[index])return;const copy=clone(selected[index]);copy.key=uniqueKey(copy.key);copy.label=`${copy.label} copia`;defaultFieldConfig(copy);selected.splice(index+1,0,copy);activeFieldKey=copy.key;openFieldKeys.clear();openFieldKeys.add(copy.key);normalizeLayoutRows();distributeRow(copy.config.layout.row);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();}
function removeCanvasField(index){if(index==null||!selected[index])return;const old=selected[index].key,oldRow=Number(selected[index].config.layout.row||1);selected.splice(index,1);openFieldKeys.delete(old);activeFieldKey=selected[Math.min(index,selected.length-1)]?.key||null;normalizeLayoutRows();distributeRow(oldRow);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();sync();}
function moveFieldToRow(index,row,targetIndex=null){if(index==null||!selected[index])return;const field=selected[index],oldRow=Number(selected[index].config.layout.row||1);selected.splice(index,1);let insertAt=targetIndex==null?selected.length:Number(targetIndex);if(index<insertAt)insertAt--;insertAt=Math.max(0,Math.min(selected.length,insertAt));field.config.layout.row=row;selected.splice(insertAt,0,field);normalizeLayoutRows();distributeRow(oldRow);distributeRow(field.config.layout.row);activeFieldKey=field.key;sync();renderSelected();renderLayoutCanvas();}
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

function renderLayoutCanvas(){
 if(!layoutCanvas)return;normalizeLayoutRows();layoutCanvas.innerHTML='';
 if(!selected.length){layoutCanvas.innerHTML='<div class="df-layout-empty">Il modulo è vuoto. Premi “Aggiungi campo” per iniziare.</div>';return;}
 const rows=[...new Set(selected.map(f=>Number(f.config.layout.row||1)))].sort((a,b)=>a-b);
 rows.forEach(rowNo=>{
  const row=document.createElement('div');row.className='df-layout-row';row.dataset.row=String(rowNo);const rowItems=fieldsInRow(rowNo);row.style.gridTemplateColumns=rowItems.map(([f])=>Math.max(10,Number(f.config.layout.width||100))+'fr').join(' ');
  rowItems.forEach(([f,i])=>{
   const card=document.createElement('div');card.className='df-layout-card'+(f.key===activeFieldKey?' is-active':'');card.dataset.fieldKey=f.key;card.draggable=true;card.style.width='100%';const required=f.required?'<span class="df-required-badge">Obbligatorio</span>':'';
   card.innerHTML=`<span class="df-layout-handle" title="Trascina" aria-hidden="true">⋮⋮</span><strong>${esc(f.label)}</strong><span class="df-layout-meta"><span class="df-layout-type">${esc(tr.types[f.type]||f.type)}</span>${required}<select aria-label="Larghezza campo">${widthChoices(f.config.layout.width||100)}</select><span class="df-layout-actions"><button type="button" data-canvas-edit class="df-icon-only" title="Modifica campo" aria-label="Modifica campo">${uiIcon('edit')}</button><button type="button" data-canvas-duplicate class="df-icon-only" title="Duplica campo" aria-label="Duplica campo">${uiIcon('copy')}</button><button type="button" data-canvas-remove class="df-canvas-remove df-icon-only" title="Elimina campo" aria-label="Elimina campo">${uiIcon('trash')}</button></span></span><div class="df-layout-drop-guide" aria-hidden="true"><span data-drop-side="before">← Stessa riga</span><span data-drop-newrow>Nuova riga ↓</span><span data-drop-side="after">Stessa riga →</span></div>`;
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
function ensureInitialFieldWorkspace(){
  if(!selected.length)return;
  renderSelected();
  renderLayoutCanvas();
  const verify=()=>{
    if(selected.length&&layoutCanvas&&!layoutCanvas.querySelector('.df-layout-card')){
      renderSelected();
      renderLayoutCanvas();
    }
  };
  requestAnimationFrame(()=>{verify();setTimeout(verify,60);});
}
window.dfBuilderEnsureRender=ensureInitialFieldWorkspace;
ensureInitialFieldWorkspace();
layoutNewRow?.addEventListener('dragover',e=>{e.preventDefault();layoutNewRow.classList.add('is-over');});layoutNewRow?.addEventListener('dragleave',()=>layoutNewRow.classList.remove('is-over'));layoutNewRow?.addEventListener('drop',e=>{e.preventDefault();layoutNewRow.classList.remove('is-over');const max=Math.max(0,...selected.map(f=>Number(f.config?.layout?.row||1)));moveFieldToRow(draggedFieldIndex,max+1);});
document.getElementById('df-open-library')?.addEventListener('click',()=>openBuilderSection(3,true));
function renderLayout(){let n=Math.max(1,Math.min(4,Number(builderConfig.layout.columns||1)));builderConfig.layout.columns=n;layoutColumns.value=String(n);mobileStack.checked=builderConfig.layout.mobile_stack!==false;let widths=Array.isArray(builderConfig.layout.widths)?builderConfig.layout.widths.slice(0,n).map(Number):[];while(widths.length<n)widths.push(Math.floor(100/n));if(n===1)widths=[100];builderConfig.layout.widths=widths;layoutWidths.innerHTML='';for(let i=0;i<4;i++){const w=document.createElement('div');w.className='df-field';if(i>=n)w.hidden=true;w.innerHTML=`<label>Colonna ${i+1}</label><input type="number" min="0" max="100" data-width="${i}" value="${esc(widths[i]??0)}">`;w.querySelector('input').addEventListener('input',e=>{builderConfig.layout.widths[i]=Number(e.target.value||0);renderLayoutTotal();sync();});layoutWidths.appendChild(w);}renderLayoutTotal();renderLayoutCanvas();sync();}
function renderLayoutTotal(){const total=(builderConfig.layout.widths||[]).slice(0,builderConfig.layout.columns).reduce((a,b)=>a+Number(b||0),0);layoutTotal.textContent=`Totale: ${total}%`;layoutTotal.classList.toggle('is-ok',total===100);layoutTotal.classList.toggle('is-error',total!==100);}
layoutColumns.addEventListener('change',()=>{builderConfig.layout.columns=Number(layoutColumns.value);builderConfig.layout.widths=Array.from({length:builderConfig.layout.columns},(_,i)=>builderConfig.layout.widths?.[i]??Math.floor(100/builderConfig.layout.columns));if(builderConfig.layout.columns===1)builderConfig.layout.widths=[100];renderLayout();});mobileStack.addEventListener('change',()=>{builderConfig.layout.mobile_stack=mobileStack.checked;sync();});document.querySelectorAll('[data-layout-preset]').forEach(b=>b.addEventListener('click',()=>{const w=b.dataset.layoutPreset.split(',').map(Number);builderConfig.layout.columns=w.length;builderConfig.layout.widths=w;renderLayout();}));document.getElementById('df-layout-apply').addEventListener('click',e=>{const widths=builderConfig.layout.widths.slice(0,builderConfig.layout.columns);selected.forEach((f,i)=>{defaultFieldConfig(f);const col=(i%builderConfig.layout.columns)+1,row=Math.floor(i/builderConfig.layout.columns)+1;f.config.layout={row,col,width:widths[col-1]||100};});renderSelected();renderLayoutCanvas();sync();const btn=e.currentTarget,old=btn.textContent;btn.textContent=selected.length?`✓ Applicato a ${selected.length} camp${selected.length===1?'o':'i'}`:'Nessun campo selezionato';setTimeout(()=>btn.textContent=old,1600);});

// Statuses and columns.
function slugStatus(v){return String(v||'status').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-z0-9]+/g,'_').replace(/^_+|_+$/g,'').slice(0,30)||'status';}const statusPalette=['#0d6efd','#f59e0b','#198754','#6c757d','#dc3545','#7c3aed','#0891b2'];
function normalizedStatusLabel(v){return String(v||'').trim().toLocaleLowerCase();}
function statusConflicts(){const seen=new Set(),dupes=new Set();statuses.forEach(st=>{const n=normalizedStatusLabel(st.label);if(!n)return;if(seen.has(n))dupes.add(n);seen.add(n);});return dupes;}
function renderStatuses(){statusEditor.innerHTML='';const dupes=statusConflicts();if(dupes.size){const warning=document.createElement('div');warning.className='df-status-warning';warning.textContent='Esistono stati con lo stesso nome. Rinominali prima di salvare.';statusEditor.appendChild(warning);}statuses.forEach((st,i)=>{st.color=/^#[0-9a-fA-F]{6}$/.test(st.color||'')?st.color:statusPalette[i%statusPalette.length];const r=document.createElement('div');r.className='df-status-row'+(dupes.has(normalizedStatusLabel(st.label))?' is-conflict':'');r.innerHTML=`<input data-status-label value="${esc(st.label||'')}" placeholder="Nome stato"><div class="df-status-color-wrap"><input class="df-status-color" data-status-color type="color" value="${esc(st.color)}"><span class="df-status-color-value">${esc(st.color)}</span></div><button type="button" class="df-status-remove df-icon-only" title="Elimina stato" aria-label="Elimina stato">${uiIcon('trash')}</button>`;const li=r.querySelector('[data-status-label]'),ci=r.querySelector('[data-status-color]');li.oninput=()=>{st.label=li.value;if(st._new)st.key=slugStatus(li.value);sync();};li.onblur=renderStatuses;ci.oninput=()=>{st.color=ci.value.toLowerCase();r.querySelector('.df-status-color-value').textContent=st.color;sync();};r.querySelector('button').onclick=()=>{if(statuses.length>1)confirmDelete(`lo stato “${st.label||'Stato'}”`,()=>{statuses.splice(i,1);renderStatuses();});};statusEditor.appendChild(r);});sync();}
document.getElementById('df-add-status').onclick=()=>{statuses.push({key:'',label:'',color:statusPalette[statuses.length%statusPalette.length],_new:true});renderStatuses();statusEditor.querySelector('.df-status-row:last-child [data-status-label]')?.focus();};renderStatuses();
function columnItems(){return [['_reference','<?php echo addslashes(Text::_('COM_DECAROFORMS_REFERENCE')); ?>'],['_email','<?php echo addslashes(Text::_('COM_DECAROFORMS_EMAIL')); ?>'],['_status','<?php echo addslashes(Text::_('COM_DECAROFORMS_STATUS')); ?>'],['_created_at','<?php echo addslashes(Text::_('COM_DECAROFORMS_DATE')); ?>'],['_payment','<?php echo addslashes(Text::_('COM_DECAROFORMS_PAYMENT')); ?>'],...selected.filter(x=>!['separator','pagebreak','page','heading','info','fieldset'].includes(x.type)).map(x=>[x.key,x.label])];}
function renderColumns(){const items=columnItems();columns=columns.filter(k=>items.some(i=>i[0]===k));if(!columns.length)columns=['_reference','_email','_status','_created_at'];columnList.innerHTML='';items.forEach(([key,label])=>{const d=document.createElement('label');d.className='df-column-item';d.innerHTML=`<input type="checkbox" ${columns.includes(key)?'checked':''}><span>${esc(label)}</span>`;d.querySelector('input').onchange=e=>{if(e.target.checked){if(!columns.includes(key))columns.push(key);}else columns=columns.filter(x=>x!==key);sync();};columnList.appendChild(d);});sync();}
document.getElementById('df-columns-all').onclick=()=>{columns=columnItems().map(i=>i[0]);renderColumns();};document.getElementById('df-columns-reset').onclick=()=>{columns=['_reference','_email','_status','_created_at'];renderColumns();};renderColumns();



document.addEventListener('click',e=>{const link=e.target.closest('[data-confirm-delete-link]');if(!link)return;e.preventDefault();e.stopPropagation();const href=link.href;confirmDelete('questo modulo',()=>{window.dfAllowDraftReload=true;location.assign(href);});});
document.addEventListener('click',e=>{const btn=e.target.closest('.df-info');if(btn){e.preventDefault();e.stopPropagation();const wrap=btn.closest('.df-info-wrap');document.querySelectorAll('.df-info-wrap.is-open').forEach(x=>{if(x!==wrap)x.classList.remove('is-open');});wrap?.classList.toggle('is-open');return;}if(!e.target.closest('.df-info-wrap'))document.querySelectorAll('.df-info-wrap.is-open').forEach(x=>x.classList.remove('is-open'));});document.addEventListener('keydown',e=>{if(e.key==='Escape')document.querySelectorAll('.df-info-wrap.is-open').forEach(x=>x.classList.remove('is-open'));});

// Email configuration and previews.
let lastTokenTarget=null;document.querySelectorAll('[data-email]').forEach(el=>{const path=el.dataset.email;el.addEventListener('focus',()=>lastTokenTarget=el);const ev=el.tagName==='SELECT'?'change':'input';el.addEventListener(ev,()=>{setDeep(emailConfig,path,el.value);sync();});});document.querySelectorAll('[data-email-check]').forEach(el=>el.addEventListener('change',()=>{setDeep(emailConfig,el.dataset.emailCheck,el.checked);sync();}));
const userConfirmation=document.getElementById('df-user-confirmation');userConfirmation.addEventListener('change',()=>{emailConfig.user.enabled=userConfirmation.checked;document.getElementById('df-user-email-settings').hidden=!userConfirmation.checked;sync();});
function renderUserEmailFields(){const s=document.getElementById('df-user-email-field'),emails=selected.filter(x=>x.type==='email'||x.key==='email');const current=emailConfig.user.to_field||emails[0]?.key||'email';s.innerHTML=emails.map(x=>`<option value="${esc(x.key)}" ${x.key===current?'selected':''}>${esc(x.label)}</option>`).join('')||'<option value="email">Email</option>';emailConfig.user.to_field=s.value||current;s.onchange=()=>{emailConfig.user.to_field=s.value;sync();};document.getElementById('df-user-email-settings').hidden=!userConfirmation.checked;sync();}
function renderTokens(){const p=document.getElementById('df-token-picker');const base=[['{form_title}','Titolo modulo'],['{form_id}','ID modulo'],['{reference}','Riferimento invio'],['{riferimento}','Riferimento pagamento'],['{data}','Data'],['{anno}','Anno'],['{all_fields}','Tutti i campi']];p.innerHTML=[...base,...selected.map(x=>[`{${x.key}}`,x.label])].map(([v,l])=>`<option value="${esc(v)}">${esc(l)} — ${esc(v)}</option>`).join('');}
document.getElementById('df-token-insert').onclick=()=>{if(!lastTokenTarget)return;const token=document.getElementById('df-token-picker').value;const s=lastTokenTarget.selectionStart??lastTokenTarget.value.length,e=lastTokenTarget.selectionEnd??s;lastTokenTarget.value=lastTokenTarget.value.slice(0,s)+token+lastTokenTarget.value.slice(e);lastTokenTarget.dispatchEvent(new Event('input',{bubbles:true}));lastTokenTarget.focus();};
function renderEmailPickers(loadFrames=emailPickersRendered){document.querySelectorAll('[data-email-picker]').forEach(box=>{const audience=box.dataset.emailPicker,config=emailConfig[audience];box.innerHTML='';templateDefs.forEach(([key,label])=>{const card=document.createElement('div'),special=['custom','html','chatgpt'].includes(key);card.className='df-email-choice'+((config.template||'standard')===key?' is-active':'');card.dataset.special=special?'1':'0';card.dataset.template=key;card.innerHTML=`<button type="button" class="df-email-thumb" title="Apri anteprima" aria-label="Apri anteprima: ${esc(label)}"><iframe class="df-email-thumb-frame" title="" tabindex="-1" sandbox></iframe><span class="df-email-preview-label" aria-hidden="true">◉ Anteprima</span></button><div class="df-email-choice-foot"><label class="df-email-radio"><input type="radio" name="df-email-template-${audience}" value="${key}" ${(config.template||'standard')===key?'checked':''}><span>${esc(label)}</span></label><button type="button" class="df-email-preview-btn">◉ Anteprima</button></div>`;const openPreview=e=>{e.preventDefault();e.stopPropagation();showEmailPreview(audience,key);};card.querySelector('.df-email-thumb').onclick=openPreview;card.querySelector('.df-email-preview-btn').onclick=openPreview;card.querySelector('input').onchange=()=>{config.template=key;renderEmailPickers(emailPickersRendered);renderEmailSpecial(audience);sync();};box.appendChild(card);const frame=card.querySelector('iframe');if(loadFrames)requestAnimationFrame(()=>{try{frame.srcdoc=emailPreviewHtml(audience,key);}catch{frame.srcdoc='<div style="font-family:Arial;padding:20px">Anteprima non disponibile</div>';}});else frame.srcdoc='<div style="font-family:Arial;padding:18px;color:#667085">Anteprima</div>';});renderEmailSpecial(audience);});}
function renderEmailSpecial(audience){const box=document.querySelector(`[data-email-special="${audience}"]`),cfg=emailConfig[audience],t=cfg.template||'standard';box.hidden=!['custom','html','chatgpt'].includes(t);if(box.hidden){box.innerHTML='';return;}if(t==='custom'){const c=cfg.custom||{};box.innerHTML=`<div class="df-grid"><div class="df-field"><label><?php echo addslashes(Text::_('COM_DECAROFORMS_BASE_TEMPLATE')); ?></label><select data-special="base">${templateDefs.slice(0,7).map(([k,l])=>`<option value="${k}" ${(c.base||'standard')===k?'selected':''}>${esc(l)}</option>`).join('')}</select></div><div class="df-field"><label><?php echo addslashes(Text::_('COM_DECAROFORMS_RADIUS')); ?> px</label><input type="number" min="0" max="40" data-special="radius" value="${esc(c.radius??8)}"></div>${[['primary','<?php echo addslashes(Text::_('COM_DECAROFORMS_PRIMARY_COLOR')); ?>'],['secondary','<?php echo addslashes(Text::_('COM_DECAROFORMS_SECONDARY_COLOR')); ?>'],['background','<?php echo addslashes(Text::_('COM_DECAROFORMS_BACKGROUND_COLOR')); ?>'],['text','<?php echo addslashes(Text::_('COM_DECAROFORMS_TEXT_COLOR')); ?>'],['button','<?php echo addslashes(Text::_('COM_DECAROFORMS_BUTTON_COLOR')); ?>'],['border','<?php echo addslashes(Text::_('COM_DECAROFORMS_BORDER_COLOR')); ?>']].map(([k,l])=>`<div class="df-field"><label>${l}</label><input type="color" data-special="${k}" value="${esc(c[k]||'#e60046')}"></div>`).join('')}</div><button class="df-btn df-small" type="button" data-reset-colors><?php echo addslashes(Text::_('COM_DECAROFORMS_RESET_COLORS')); ?></button>`;box.querySelectorAll('[data-special]').forEach(el=>el.oninput=()=>{cfg.custom=cfg.custom||{};cfg.custom[el.dataset.special]=el.type==='number'?Number(el.value):el.value;sync();});box.querySelector('[data-reset-colors]').onclick=()=>{cfg.custom={base:'standard',primary:'#e60046',secondary:'#26364a',background:'#ffffff',text:'#20262d',button:'#e60046',border:'#dfe3e7',radius:8};renderEmailSpecial(audience);sync();};}
if(t==='html'){box.innerHTML=`<label class="df-label">HTML libero</label><textarea class="df-codearea" data-email-html placeholder="<div>...</div>">${esc(cfg.html||'')}</textarea><div class="df-note"><?php echo addslashes(Text::_('COM_DECAROFORMS_HTML_VARIABLE_NOTE')); ?></div>`;box.querySelector('[data-email-html]').oninput=e=>{cfg.html=e.target.value;lastTokenTarget=e.target;sync();};box.querySelector('[data-email-html]').onfocus=e=>lastTokenTarget=e.target;}
if(t==='chatgpt'){box.innerHTML=`<div class="df-field"><label><?php echo addslashes(Text::_('COM_DECAROFORMS_CHATGPT_INSTRUCTIONS')); ?></label><textarea data-chatgpt-instructions placeholder="<?php echo addslashes(Text::_('COM_DECAROFORMS_CHATGPT_PLACEHOLDER')); ?>">${esc(cfg.chatgpt_instructions||'')}</textarea></div><div class="df-inline"><button class="df-btn df-small" type="button" data-copy-chatgpt>${esc(tr.copyPrompt)}</button><span class="df-note" data-copy-status></span></div><div class="df-field" style="margin-top:10px"><label><?php echo addslashes(Text::_('COM_DECAROFORMS_CHATGPT_HTML_RESULT')); ?></label><textarea class="df-codearea" data-chatgpt-html placeholder="<?php echo addslashes(Text::_('COM_DECAROFORMS_CHATGPT_PASTE_HTML')); ?>">${esc(cfg.html||'')}</textarea></div>`;box.querySelector('[data-chatgpt-instructions]').oninput=e=>{cfg.chatgpt_instructions=e.target.value;sync();};box.querySelector('[data-chatgpt-html]').oninput=e=>{cfg.html=e.target.value;sync();};box.querySelector('[data-copy-chatgpt]').onclick=async()=>{const prompt=buildChatGptPrompt(audience);try{await navigator.clipboard.writeText(prompt);box.querySelector('[data-copy-status]').textContent=tr.copied;}catch{box.querySelector('[data-copy-status]').textContent=prompt;}};}}
function buildChatGptPrompt(audience){const title=document.querySelector('[name="title"]')?.value||'Modulo';const cfg=emailConfig[audience];return `Crea un template HTML email responsive per il modulo "${title}".\nDestinatario: ${audience==='admin'?'amministrazione':'utente'}.\nIstruzioni: ${cfg.chatgpt_instructions||'Stile professionale, accessibile e compatibile con client email.'}\n\nCampi del modulo:\n${selected.map(x=>`- ${x.label}: {${x.key}} (${x.type})`).join('\n')}\n\nVariabili di sistema: {form_title}, {form_id}, {reference}, {riferimento}, {data}, {anno}, {all_fields}.\nRestituisci solo HTML inline-CSS, senza script e senza dati personali reali.`;}
function exampleValue(f){const map={first_name:'Mario',last_name:'Rossi',full_name:'Mario Rossi',email:'mario.rossi@example.com',phone:'+39 333 123 4567',mobile:'+39 333 123 4567',city:'Roma',region:'Lazio',postcode:'00100',nationality:'Italiana',member_number:'001234',role:'Consigliere'};return map[f.key]||f.options?.[0]||(['file','upload'].includes(f.type)?'documento.pdf':f.type==='date'?'04/09/2026':f.type==='number'?'1':'Esempio');}
function previewRows(){return selected.filter(f=>!['separator','pagebreak','page','heading','info','fieldset'].includes(f.type)).map(f=>`<tr><td style="padding:7px 9px;border-bottom:1px solid #e8ebef;font-weight:700;vertical-align:top">${esc(f.label)}</td><td style="padding:7px 9px;border-bottom:1px solid #e8ebef">${esc(exampleValue(f))}</td></tr>`).join('');}
function emailPreviewHtml(audience,template){const cfg=emailConfig[audience],title=document.querySelector('[name="title"]')?.value||'Modulo',subject=(cfg.subject|| (audience==='user'?'Abbiamo ricevuto il tuo invio – {form_title}':'Nuovo invio – {form_title}')).replaceAll('{form_title}',title),rows=`<table role="presentation" style="width:100%;border-collapse:collapse">${previewRows()}</table>`,intro=audience==='user'?`<p>Abbiamo ricevuto correttamente il tuo invio.</p>`:`<p>È stato ricevuto un nuovo invio.</p>`,content=`<h2 style="margin:0 0 6px">${esc(title)}</h2><p style="margin:0 0 14px;color:#667085">Riferimento: <strong>FRM-20260904-DEMO</strong></p>${intro}${rows}`,accent='#e60046';if(template==='html'||template==='chatgpt'){return cfg.html||`<div style="background:#fff;padding:22px;font-family:Arial">${content}</div>`;}if(template==='custom'){const c=cfg.custom||{},base=c.base||'standard';const inner=emailPreviewHtml(audience,base);return `<div style="background:${esc(c.background||'#fff')};color:${esc(c.text||'#20262d')};border:1px solid ${esc(c.border||'#dfe3e7')};border-radius:${Number(c.radius||8)}px;overflow:hidden"><div style="height:8px;background:${esc(c.primary||accent)}"></div>${inner}</div>`;}if(template==='minimal')return `<div style="font-family:Arial;background:#fff;padding:24px;color:#20262d">${content}</div>`;if(template==='institutional')return `<div style="font-family:Arial;background:#fff"><div style="background:#26364a;color:#fff;padding:15px 20px;font-weight:800">${esc(subject)}</div><div style="padding:22px">${content}</div></div>`;if(template==='card')return `<div style="font-family:Arial;padding:24px;background:#f2f4f7"><div style="background:#fff;border-radius:10px;padding:22px;box-shadow:0 4px 18px rgba(0,0,0,.1)">${content}</div></div>`;if(template==='compact')return `<div style="font-family:Arial;background:#fff;border-left:5px solid ${accent};padding:18px 20px">${content}</div>`;if(template==='modern')return `<div style="font-family:Arial;background:linear-gradient(135deg,#f7f8fa,#fff);padding:24px"><div style="background:#fff;border-radius:14px;padding:24px"><div style="width:54px;height:5px;background:${accent};border-radius:999px;margin-bottom:17px"></div>${content}</div></div>`;if(template==='elegant')return `<div style="font-family:Georgia,serif;background:#fbfaf7;border:1px solid #d8ccb0;padding:28px;color:#2d2922"><div style="text-align:center;letter-spacing:.08em;margin-bottom:18px">${esc(subject)}</div>${content}</div>`;if(template==='professional')return `<div style="font-family:Arial;background:#eef2f7;padding:24px"><div style="background:#fff;border-top:7px solid #26364a;padding:24px;box-shadow:0 3px 12px rgba(15,23,42,.08)"><div style="color:#26364a;font-size:12px;text-transform:uppercase;letter-spacing:.08em;margin-bottom:14px">${esc(subject)}</div>${content}</div></div>`;if(template==='receipt')return `<div style="font-family:ui-monospace,monospace;background:#fff;padding:22px;border:1px dashed #aab2bc"><strong>${esc(subject)}</strong><hr style="border:0;border-top:1px dashed #aab2bc;margin:14px 0">${content}</div>`;return `<div style="font-family:Arial;background:#f4f5f7;padding:22px"><div style="background:#fff"><div style="background:${accent};color:#fff;padding:16px 20px;font-weight:800">${esc(subject)}</div><div style="padding:22px">${content}</div></div></div>`;}
let previewModal=null;function closeEmailPreview(){if(!previewModal)return;previewModal.remove();previewModal=null;document.body.style.overflow='';}function showEmailPreview(audience,template){closeEmailPreview();let html='';try{html=emailPreviewHtml(audience,template);}catch(err){console.error('Forms email preview error',err);html='<div style="background:#fff;color:#1f2937;padding:24px;font-family:Arial,sans-serif"><h2 style="margin-top:0">Anteprima email</h2><p>Impossibile generare i dati di esempio.</p></div>';}const label=templateDefs.find(x=>x[0]===template)?.[1]||template;previewModal=document.createElement('div');previewModal.className='df-live-preview-modal';previewModal.innerHTML=`<div class="df-live-preview-backdrop"></div><div class="df-live-preview-dialog" role="dialog" aria-modal="true" aria-label="Anteprima ${esc(label)}"><div class="df-live-preview-head"><div><strong>${esc(label)}</strong><div class="df-note">${audience==='admin'?'Email amministrazione':'Email utente'}</div></div><button type="button" class="df-live-preview-close" aria-label="Chiudi">×</button></div><div class="df-live-preview-body">${html}</div><div class="df-live-preview-foot"><button type="button" class="df-btn df-live-preview-close">Chiudi</button></div></div>`;document.body.appendChild(previewModal);document.body.style.overflow='hidden';previewModal.querySelectorAll('.df-live-preview-close,.df-live-preview-backdrop').forEach(el=>el.addEventListener('click',closeEmailPreview));requestAnimationFrame(()=>previewModal.querySelector('.df-live-preview-close')?.focus());}document.addEventListener('keydown',e=>{if(e.key==='Escape'&&previewModal)closeEmailPreview();});

// Additional emails.
function newAdditional(){return {name:'',enabled:true,to:'',reply_to:'',reply_name:'',cc:'',bcc:'',subject:'Nuovo invio – {form_title}',template:'standard',html:'',auto_message:true,attach_uploads:false,condition:{field:'',operator:'eq',value:''}};}
function renderAdditional(){const box=document.getElementById('df-additional-list');box.innerHTML='';if(!additionalEmails.length){box.innerHTML=`<div class="df-note">${esc(tr.noAdditional)}</div>`;sync();return;}additionalEmails.forEach((m,i)=>{m.condition=m.condition||{field:'',operator:'eq',value:''};const d=document.createElement('div');d.className='df-additional-card';d.innerHTML=`<div class="df-additional-head"><strong>${esc(m.name||`${tr.newEmail} #${i+1}`)}</strong><div class="df-inline"><label class="df-check"><input type="checkbox" data-a-enabled ${m.enabled!==false?'checked':''}> Attiva</label><button class="df-btn df-small" type="button" data-a-remove>${esc(tr.remove)}</button></div></div><div class="df-additional-grid"><div class="df-field"><label>${esc(tr.emailName)}</label><input data-a="name" value="${esc(m.name||'')}"></div><div class="df-field"><label>To</label><input data-a="to" value="${esc(m.to||'')}"></div><div class="df-field"><label>Reply-To</label><input data-a="reply_to" value="${esc(m.reply_to||'')}"></div><div class="df-field"><label>CC / BCC</label><input data-a="cc" value="${esc(m.cc||'')}" placeholder="CC"><input data-a="bcc" value="${esc(m.bcc||'')}" placeholder="BCC" style="margin-top:5px"></div><div class="df-field full"><label><?php echo addslashes(Text::_('COM_DECAROFORMS_EMAIL_SUBJECT')); ?></label><input data-a="subject" value="${esc(m.subject||'')}"></div><div class="df-field"><label>${esc(tr.template)}</label><select data-a="template">${templateDefs.map(([k,l])=>`<option value="${k}" ${m.template===k?'selected':''}>${esc(l)}</option>`).join('')}</select></div><div class="df-field"><label class="df-check"><input type="checkbox" data-a-check="attach_uploads" ${m.attach_uploads?'checked':''}> <?php echo addslashes(Text::_('COM_DECAROFORMS_ATTACH_UPLOADS')); ?></label></div><div class="df-field full"><label>${esc(tr.condition)}</label><div class="df-condition-row"><select data-a-cond="field"><option value="">Sempre</option>${fieldSelectOptions(m.condition.field||'')}</select><select data-a-cond="operator"><option value="eq" ${m.condition.operator==='eq'?'selected':''}>=</option><option value="neq" ${m.condition.operator==='neq'?'selected':''}>≠</option><option value="contains" ${m.condition.operator==='contains'?'selected':''}>contiene</option><option value="not_empty" ${m.condition.operator==='not_empty'?'selected':''}>non vuoto</option></select><input data-a-cond="value" value="${esc(m.condition.value||'')}" placeholder="Valore"><span></span></div></div>${['html','chatgpt'].includes(m.template)?`<div class="df-field full"><label>HTML</label><textarea class="df-codearea" data-a="html">${esc(m.html||'')}</textarea></div>`:''}</div>`;d.querySelector('[data-a-enabled]').onchange=e=>{m.enabled=e.target.checked;sync();};d.querySelector('[data-a-remove]').onclick=()=>confirmDelete(`l’email aggiuntiva “${m.name||('Email #'+(i+1))}”`,()=>{additionalEmails.splice(i,1);renderAdditional();});d.querySelectorAll('[data-a]').forEach(el=>{const ev=el.tagName==='SELECT'?'change':'input';el.addEventListener(ev,()=>{m[el.dataset.a]=el.value;if(el.dataset.a==='template')renderAdditional();sync();});});d.querySelectorAll('[data-a-check]').forEach(el=>el.onchange=()=>{m[el.dataset.aCheck]=el.checked;sync();});d.querySelectorAll('[data-a-cond]').forEach(el=>{const ev=el.tagName==='SELECT'?'change':'input';el.addEventListener(ev,()=>{m.condition[el.dataset.aCond]=el.value;sync();});});box.appendChild(d);});sync();}
document.getElementById('df-additional-add').onclick=()=>{additionalEmails.push(newAdditional());renderAdditional();};

// Builder configuration controls.
const controls={ajax:'df-validation-ajax',scroll_error:'df-validation-scroll',required_marker:'df-required-marker',error_message:'df-error-message'};document.getElementById(controls.ajax).checked=builderConfig.validation.ajax!==false;document.getElementById(controls.scroll_error).checked=builderConfig.validation.scroll_error!==false;document.getElementById(controls.required_marker).value=builderConfig.validation.required_marker||'*';document.getElementById(controls.error_message).value=builderConfig.validation.error_message||'';document.getElementById(controls.ajax).onchange=e=>{builderConfig.validation.ajax=e.target.checked;sync();};document.getElementById(controls.scroll_error).onchange=e=>{builderConfig.validation.scroll_error=e.target.checked;sync();};document.getElementById(controls.required_marker).oninput=e=>{builderConfig.validation.required_marker=e.target.value;sync();};document.getElementById(controls.error_message).oninput=e=>{builderConfig.validation.error_message=e.target.value;sync();};
const conf={enabled:document.getElementById('df-confirm-enabled'),position:document.getElementById('df-confirm-position'),scroll:document.getElementById('df-confirm-scroll'),cont:document.getElementById('df-confirm-continue'),label:document.getElementById('df-confirm-continue-label'),url:document.getElementById('df-confirm-continue-url')};const successFormat=document.getElementById('df-success-format'),successModal=document.getElementById('df-success-modal');conf.enabled.checked=builderConfig.confirmation.enabled!==false;conf.position.value=builderConfig.confirmation.position||'below';successFormat.value=builderConfig.confirmation.format==='html'?'html':'text';successModal.checked=conf.position.value==='modal';conf.scroll.checked=!!builderConfig.confirmation.scroll;conf.cont.checked=!!builderConfig.confirmation.continue;conf.label.value=builderConfig.confirmation.continue_label||'Continua';conf.url.value=builderConfig.confirmation.continue_url||'';conf.enabled.onchange=e=>{builderConfig.confirmation.enabled=e.target.checked;sync();};conf.position.onchange=e=>{builderConfig.confirmation.position=e.target.value;successModal.checked=e.target.value==='modal';sync();};successFormat.onchange=e=>{builderConfig.confirmation.format=e.target.value==='html'?'html':'text';sync();};successModal.onchange=e=>{builderConfig.confirmation.position=e.target.checked?'modal':(builderConfig.confirmation.position==='modal'?'below':builderConfig.confirmation.position);conf.position.value=builderConfig.confirmation.position;sync();};conf.scroll.onchange=e=>{builderConfig.confirmation.scroll=e.target.checked;sync();};conf.cont.onchange=e=>{builderConfig.confirmation.continue=e.target.checked;sync();};conf.label.oninput=e=>{builderConfig.confirmation.continue_label=e.target.value;sync();};conf.url.oninput=e=>{builderConfig.confirmation.continue_url=e.target.value;sync();};
const enabledToggle=document.querySelector('[name="enabled"]'),closedBox=document.querySelector('.df-closed-box');function syncClosedBox(){if(closedBox)closedBox.hidden=!!enabledToggle?.checked;}enabledToggle?.addEventListener('change',syncClosedBox);syncClosedBox();
const minSeconds=document.getElementById('df-min-seconds'),rateSeconds=document.getElementById('df-rate-seconds');minSeconds.value=builderConfig.security.min_seconds??2;rateSeconds.value=builderConfig.security.rate_seconds??8;minSeconds.oninput=e=>{builderConfig.security.min_seconds=Math.max(0,Number(e.target.value||0));sync();};rateSeconds.oninput=e=>{builderConfig.security.rate_seconds=Math.max(0,Number(e.target.value||0));sync();};
const sheetsEnabled=document.getElementById('df-sheets-enabled'),sheetsWebhook=document.getElementById('df-sheets-webhook'),sheetsSecret=document.getElementById('df-sheets-secret'),sheetsFiles=document.getElementById('df-sheets-files');
if(sheetsEnabled&&sheetsWebhook&&sheetsSecret&&sheetsFiles){
  sheetsEnabled.checked=!!integrations.google_sheets.enabled;sheetsWebhook.value=integrations.google_sheets.webhook_url||'';sheetsSecret.value=integrations.google_sheets.secret||'';sheetsFiles.checked=!!integrations.google_sheets.include_files;
  sheetsEnabled.onchange=e=>{integrations.google_sheets.enabled=e.target.checked;sync();};sheetsWebhook.oninput=e=>{integrations.google_sheets.webhook_url=e.target.value;sync();};sheetsSecret.oninput=e=>{integrations.google_sheets.secret=e.target.value;sync();};sheetsFiles.onchange=e=>{integrations.google_sheets.include_files=e.target.checked;sync();};
}
document.getElementById('df-add-calculation')?.addEventListener('click',()=>add({key:'calculation',type:'calculated',category:'values',label:'<?php echo addslashes(Text::_('COM_DECAROFORMS_FIELD_CALCULATION')); ?>',placeholder:'',help:'',default:'',options:[],required:false,config:{formula:'',decimals:2,prefix:'',suffix:'',visible:true}}));

// Quick templates.
const libByKey=()=>Object.fromEntries(library.map(x=>[x.key,x]));

function openBuilderSection(index,scroll=false){const sections=[...document.querySelectorAll('[data-accordion]')],section=sections[index];if(!section)return;section.classList.add('is-open');section.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','true');if(scroll)setTimeout(()=>section.scrollIntoView({behavior:'smooth',block:'start'}),80);}


// Draft recovery and robust AJAX save.
const draftStorageKey='decaroforms_builder_draft_v2_<?php echo (int) $id; ?>';let draftReady=false,draftTimer=null,emailPickersRendered=false;
function readDraft(){try{const d=JSON.parse(localStorage.getItem(draftStorageKey)||'null');return d&&d.state?d:null;}catch{return null;}}
function clearDraft(){try{localStorage.removeItem(draftStorageKey);}catch{}document.getElementById('df-draft-banner')?.setAttribute('hidden','');}
function saveDraftNow(){if(!draftReady)return;try{localStorage.setItem(draftStorageKey,JSON.stringify({savedAt:Date.now(),state:captureHistoryState()}));}catch(e){console.warn('Forms draft save failed',e);}}
function scheduleDraft(){if(!draftReady)return;clearTimeout(draftTimer);draftTimer=setTimeout(saveDraftNow,350);}
function applyDraftState(s){historyApplying=true;selected=clone(s.selected||[]);statuses=clone(s.statuses||[]);columns=clone(s.columns||[]);builderConfig=clone(s.builderConfig||{});emailConfig=clone(s.emailConfig||{});additionalEmails=clone(s.additionalEmails||[]);integrations=clone(s.integrations||{});activeFieldKey=s.activeFieldKey||selected[0]?.key||null;renderSelected();renderLayout();renderStatuses();renderColumns();renderTokens();renderUserEmailFields();if(emailPickersRendered)renderEmailPickers();renderAdditional();const controls=[...document.querySelectorAll('#df-builder-form [name]:not([type="hidden"])')];(s.form||[]).forEach((v,i)=>{const el=controls[i];if(el&&el.name===v.name){if(el.type==='checkbox'||el.type==='radio')el.checked=!!v.value;else el.value=v.value;}});syncClosedBox();successFormat.value=builderConfig.confirmation?.format==='html'?'html':'text';conf.position.value=builderConfig.confirmation?.position||'below';successModal.checked=conf.position.value==='modal';historyApplying=false;historyStates=[captureHistoryState()];historyIndex=0;sync();applyLockState();updateHistoryButtons();}
function showDraftBanner(){const d=readDraft(),bar=document.getElementById('df-draft-banner');if(!d||!bar)return false;if(Date.now()-Number(d.savedAt||0)>1000*60*60*24*14){clearDraft();return false;}if(historySignature(d.state)===historySignature(captureHistoryState())){clearDraft();return false;}bar.hidden=false;const tm=document.getElementById('df-draft-time');if(tm)tm.textContent=' · '+new Date(d.savedAt).toLocaleString();document.getElementById('df-draft-restore').onclick=()=>{applyDraftState(d.state);bar.hidden=true;draftReady=true;saveDraftNow();};document.getElementById('df-draft-discard').onclick=()=>{clearDraft();draftReady=true;};return true;}
function setSaveNotice(message,type='info',reload=false){const box=document.getElementById('df-save-notice');if(!box)return;box.className='df-save-notice is-'+type;box.hidden=false;box.innerHTML=`<span>${esc(message)}</span>${reload?'<button type="button" class="df-btn df-small" data-save-reload>Ricarica pagina</button>':''}`;box.querySelector('[data-save-reload]')?.addEventListener('click',()=>{saveDraftNow();window.dfAllowDraftReload=true;location.reload();});}
function clearSaveNotice(){const box=document.getElementById('df-save-notice');if(box)box.hidden=true;}
window.dfSetSaveNotice=setSaveNotice;
window.dfBuilderSaveDraft=saveDraftNow;
window.dfBuilderClearDraft=clearDraft;
window.dfBuilderSync=sync;
window.dfBuilderRuntime={version:'1.3.25',draft:true,ensureRender:typeof window.dfBuilderEnsureRender==='function'};

const builderRoot=document.querySelector('.df-builder'),builderForm=document.getElementById('df-builder-form');let editorLocked=<?php echo $id ? 'true' : 'false'; ?>;
function applyLockState(){if(!builderRoot)return;builderRoot.classList.toggle('is-locked',editorLocked);document.querySelectorAll('.df-lock-toggle').forEach(b=>b.classList.toggle('is-active',(b.dataset.lock==='1')===editorLocked));document.querySelectorAll('.df-save-top').forEach(b=>b.disabled=editorLocked);builderForm.querySelectorAll('input:not([type="hidden"]),select,textarea,button:not(.df-section-toggle):not(.df-info)').forEach(el=>{if(!el.dataset.lockOriginal)el.dataset.lockOriginal=el.disabled?'1':'0';el.disabled=editorLocked||el.dataset.lockOriginal==='1';});updateHistoryButtons();}
function hasUnsavedChanges(){return historyReady&&historyIndex>=0&&historySignature(historyStates[historyIndex])!==initialHistorySignature;}
function setEditorLocked(locked,ask=true){if(locked===editorLocked)return;if(locked&&ask&&hasUnsavedChanges()&&!confirm('Ci sono modifiche non salvate. Vuoi bloccare comunque la modifica?'))return;editorLocked=locked;applyLockState();}
document.querySelectorAll('.df-lock-toggle').forEach(b=>b.onclick=()=>setEditorLocked(b.dataset.lock==='1'));
document.getElementById('df-undo').onclick=()=>restoreHistory(historyIndex-1);document.getElementById('df-redo').onclick=()=>restoreHistory(historyIndex+1);
document.addEventListener('keydown',e=>{if(editorLocked)return;const mod=e.ctrlKey||e.metaKey;if(!mod)return;if(e.key.toLowerCase()==='z'){e.preventDefault();restoreHistory(historyIndex+(e.shiftKey?1:-1));}else if(e.key.toLowerCase()==='y'){e.preventDefault();restoreHistory(historyIndex+1);}});
builderForm.addEventListener('input',scheduleHistory,true);builderForm.addEventListener('change',scheduleHistory,true);window.addEventListener('beforeunload',e=>{if(hasUnsavedChanges()&&!window.dfAllowDraftReload){e.preventDefault();e.returnValue='';}});
ensureInitialFieldWorkspace();renderLayout();renderTokens();renderUserEmailFields();renderAdditional();renderEmailPickers(false);sync();historyReady=true;historyStates=[captureHistoryState()];historyIndex=0;initialHistorySignature=historySignature(historyStates[0]);applyLockState();updateHistoryButtons();const emailSection=[...document.querySelectorAll('[data-accordion]')][5];const ensureEmailPickers=()=>{if(emailPickersRendered)return;emailPickersRendered=true;renderEmailPickers(true);};emailSection?.querySelector('.df-section-toggle')?.addEventListener('click',()=>setTimeout(()=>{if(emailSection.classList.contains('is-open'))ensureEmailPickers();},0));const pendingDraft=showDraftBanner();draftReady=!pendingDraft;builderForm.addEventListener('input',scheduleDraft,true);builderForm.addEventListener('change',scheduleDraft,true);document.addEventListener('dragend',scheduleDraft,true);document.addEventListener('click',e=>{if(e.target.closest('.df-builder'))scheduleDraft();},true);
})();
</script>
