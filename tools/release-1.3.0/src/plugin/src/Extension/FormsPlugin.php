<?php

namespace DeCaro\Plugin\System\Forms\Extension;

defined('_JEXEC') or die;

use Joomla\CMS\Component\ComponentHelper;
use Joomla\CMS\Event\Application\AfterRenderEvent;
use Joomla\CMS\Event\Application\AfterRouteEvent;
use Joomla\CMS\Factory;
use Joomla\CMS\Http\HttpFactory;
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
    private const DEFAULT_MAX_FILE_BYTES = 5242880;

    public static function getSubscribedEvents(): array
    {
        return ['onAfterRoute' => 'onAfterRoute', 'onAfterRender' => 'onAfterRender'];
    }

    private function ensureLanguages(): void
    {
        if ($this->formsLanguagesLoaded) {
            return;
        }
        $this->loadLanguage();
        $this->getApplication()->getLanguage()->load('com_decaroforms', JPATH_ADMINISTRATOR . '/components/com_decaroforms', null, true);
        $this->formsLanguagesLoaded = true;
    }

    private function getDb(): DatabaseInterface
    {
        return $this->getDatabase();
    }

    private function jsonObject(mixed $value, array $default = []): array
    {
        $data = json_decode((string) $value, true);
        return is_array($data) ? $data : $default;
    }

    private function canonicalFieldKey(string $fieldKey): string
    {
        $aliases = [
            'prenom' => 'first_name', 'nom' => 'last_name', 'date_naissance' => 'birth_date', 'gsm' => 'phone',
            'adresse' => 'address', 'numero' => 'street_number', 'boite' => 'box', 'code_postal' => 'postcode',
            'localite' => 'city', 'nationalite' => 'nationality', 'sexe' => 'gender',
        ];
        $fieldKey = strtolower(trim($fieldKey));
        if (isset($aliases[$fieldKey])) {
            return $aliases[$fieldKey];
        }
        $base = preg_replace('/_\d+$/', '', $fieldKey) ?: $fieldKey;
        return $aliases[$base] ?? $base;
    }

    private function fieldLanguageKey(string $fieldKey): ?string
    {
        $map = [
            'first_name'=>'COM_DECAROFORMS_FIELD_FIRST_NAME','last_name'=>'COM_DECAROFORMS_FIELD_LAST_NAME','full_name'=>'COM_DECAROFORMS_FIELD_FULL_NAME','birth_date'=>'COM_DECAROFORMS_FIELD_BIRTH_DATE','gender'=>'COM_DECAROFORMS_FIELD_GENDER','nationality'=>'COM_DECAROFORMS_FIELD_NATIONALITY','tax_code'=>'COM_DECAROFORMS_FIELD_TAX_CODE','email'=>'COM_DECAROFORMS_FIELD_EMAIL','phone'=>'COM_DECAROFORMS_FIELD_PHONE','mobile'=>'COM_DECAROFORMS_FIELD_MOBILE','pec'=>'COM_DECAROFORMS_FIELD_PEC','website'=>'COM_DECAROFORMS_FIELD_WEBSITE','address'=>'COM_DECAROFORMS_FIELD_ADDRESS','street_number'=>'COM_DECAROFORMS_FIELD_STREET_NUMBER','box'=>'COM_DECAROFORMS_FIELD_BOX','postcode'=>'COM_DECAROFORMS_FIELD_POSTCODE','city'=>'COM_DECAROFORMS_FIELD_CITY','region'=>'COM_DECAROFORMS_FIELD_REGION','country'=>'COM_DECAROFORMS_FIELD_COUNTRY','organisation'=>'COM_DECAROFORMS_FIELD_ORGANISATION','club'=>'COM_DECAROFORMS_FIELD_CLUB','role'=>'COM_DECAROFORMS_FIELD_ROLE','member_number'=>'COM_DECAROFORMS_FIELD_MEMBER_NUMBER','sport'=>'COM_DECAROFORMS_FIELD_SPORT','team_name'=>'COM_DECAROFORMS_FIELD_TEAM_NAME','level'=>'COM_DECAROFORMS_FIELD_LEVEL','event_date'=>'COM_DECAROFORMS_FIELD_EVENT_DATE','arrival_date'=>'COM_DECAROFORMS_FIELD_ARRIVAL_DATE','departure_date'=>'COM_DECAROFORMS_FIELD_DEPARTURE_DATE','participants'=>'COM_DECAROFORMS_FIELD_PARTICIPANTS','subject'=>'COM_DECAROFORMS_FIELD_SUBJECT','message'=>'COM_DECAROFORMS_FIELD_MESSAGE','notes'=>'COM_DECAROFORMS_FIELD_NOTES','motivation'=>'COM_DECAROFORMS_FIELD_MOTIVATION','attachment'=>'COM_DECAROFORMS_FIELD_ATTACHMENT','identity_document'=>'COM_DECAROFORMS_FIELD_IDENTITY_DOCUMENT','photo'=>'COM_DECAROFORMS_FIELD_PHOTO','certificate'=>'COM_DECAROFORMS_FIELD_CERTIFICATE','payment_proof'=>'COM_DECAROFORMS_FIELD_PAYMENT_PROOF','payment'=>'COM_DECAROFORMS_PAYMENT','privacy_consent'=>'COM_DECAROFORMS_FIELD_PRIVACY','terms_consent'=>'COM_DECAROFORMS_FIELD_TERMS','newsletter_consent'=>'COM_DECAROFORMS_FIELD_NEWSLETTER','custom_text'=>'COM_DECAROFORMS_FIELD_CUSTOM_TEXT','custom_textarea'=>'COM_DECAROFORMS_FIELD_CUSTOM_TEXTAREA','custom_number'=>'COM_DECAROFORMS_FIELD_CUSTOM_NUMBER','custom_date'=>'COM_DECAROFORMS_FIELD_CUSTOM_DATE','custom_select'=>'COM_DECAROFORMS_FIELD_CUSTOM_SELECT','custom_radio'=>'COM_DECAROFORMS_FIELD_CUSTOM_RADIO','custom_checkboxes'=>'COM_DECAROFORMS_FIELD_CUSTOM_CHECKBOXES','map_location'=>'COM_DECAROFORMS_FIELD_MAP','calculation'=>'COM_DECAROFORMS_FIELD_CALCULATION'
        ];
        return $map[$this->canonicalFieldKey($fieldKey)] ?? null;
    }

    private function componentIniValues(string $key): array
    {
        static $cache = [];
        if (isset($cache[$key])) {
            return $cache[$key];
        }
        $values = [];
        foreach (['en-GB','it-IT','fr-FR'] as $tag) {
            $file = JPATH_ADMINISTRATOR . '/components/com_decaroforms/language/' . $tag . '/com_decaroforms.ini';
            if (!is_file($file)) {
                continue;
            }
            $ini = @parse_ini_file($file, false, INI_SCANNER_RAW);
            if (is_array($ini) && isset($ini[$key])) {
                $values[] = trim((string) $ini[$key], "\"'");
            }
        }
        return $cache[$key] = array_values(array_unique($values));
    }

    private function activeComponentIniValue(string $key): string
    {
        static $cache = [];
        $tag = $this->getApplication()->getLanguage()->getTag();
        $cacheKey = $tag . ':' . $key;
        if (isset($cache[$cacheKey])) {
            return $cache[$cacheKey];
        }
        foreach ([$tag, 'en-GB'] as $candidate) {
            $file = JPATH_ADMINISTRATOR . '/components/com_decaroforms/language/' . $candidate . '/com_decaroforms.ini';
            if (!is_file($file)) {
                continue;
            }
            $ini = @parse_ini_file($file, false, INI_SCANNER_RAW);
            if (is_array($ini) && isset($ini[$key])) {
                return $cache[$cacheKey] = trim((string) $ini[$key], "\"'");
            }
        }
        return $cache[$cacheKey] = Text::_($key);
    }

    private function localizedFieldLabel(array $field): string
    {
        $stored = (string) ($field['label'] ?? '');
        $key = $this->fieldLanguageKey((string) ($field['field_key'] ?? ''));
        if ($key === null) {
            return $stored;
        }
        return in_array($stored, $this->componentIniValues($key), true) ? $this->activeComponentIniValue($key) : $stored;
    }

    private function localizedSuccessMessage(string $stored): string
    {
        $known = ['Thank you. Your submission has been received.','Grazie. Il tuo invio è stato ricevuto.','Merci. Votre formulaire a bien été envoyé.'];
        return $stored === '' || in_array($stored, $known, true) ? Text::_('PLG_SYSTEM_DECAROFORMS_SUCCESS') : $stored;
    }

    public function onAfterRoute(AfterRouteEvent $event): void
    {
        $this->ensureLanguages();
        $app = $event->getApplication();
        if (!$app->isClient('site') || strtoupper($app->getInput()->getMethod()) !== 'POST') {
            return;
        }
        if ($app->getInput()->post->getInt('decaroforms_submit', 0) !== 1) {
            return;
        }
        $this->respond($this->handleSubmission());
    }

    public function onAfterRender(AfterRenderEvent $event): void
    {
        $this->ensureLanguages();
        $app = $event->getApplication();
        if (!$app->isClient('site')) {
            return;
        }
        $body = $app->getBody();
        if (strpos($body, '{forms}') !== false) {
            $body = str_replace('{forms}', $this->renderFormsList(), $body);
        }
        $body = preg_replace_callback('/\{form\s+(?:id=["\']?(\d+)["\']?|slug=["\']?([a-zA-Z0-9_-]+)["\']?)\s*\}/i', function (array $m) {
            return $this->renderForm(!empty($m[1]) ? (int) $m[1] : 0, !empty($m[2]) ? (string) $m[2] : '');
        }, $body) ?? $body;
        $app->setBody($body);
    }

    private function loadForm(int $id = 0, string $slug = ''): array
    {
        try {
            $db = $this->getDb();
            $q = $db->createQuery()->select('*')->from($db->quoteName('#__decaroforms_forms'));
            if ($id > 0) {
                $q->where($db->quoteName('id') . ' = :id')->bind(':id', $id);
            } elseif ($slug !== '') {
                $q->where($db->quoteName('slug') . ' = :slug')->bind(':slug', $slug);
            } else {
                return [];
            }
            $db->setQuery($q);
            return $db->loadAssoc() ?: [];
        } catch (Throwable) {
            return [];
        }
    }

    private function loadFields(int $formId): array
    {
        try {
            $db = $this->getDb();
            $q = $db->createQuery()->select('*')->from($db->quoteName('#__decaroforms_fields'))->where($db->quoteName('form_id') . ' = :id')->bind(':id', $formId)->order('sort_order ASC,id ASC');
            $db->setQuery($q);
            $rows = $db->loadAssocList() ?: [];
            foreach ($rows as &$row) {
                $row['options'] = $this->jsonObject($row['options_json'] ?? '[]', []);
                $row['config'] = $this->jsonObject($row['config_json'] ?? '{}', []);
            }
            unset($row);
            return $rows;
        } catch (Throwable) {
            return [];
        }
    }

    private function renderFormsList(): string
    {
        try {
            $db = $this->getDb();
            $q = $db->createQuery()->select('*')->from($db->quoteName('#__decaroforms_forms'))->where($db->quoteName('enabled') . ' = 1')->order('title ASC');
            $db->setQuery($q);
            $forms = $db->loadAssocList() ?: [];
        } catch (Throwable) {
            $forms = [];
        }
        if (!$forms) {
            return '<div class="df-public-empty">' . htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_NO_FORMS'), ENT_QUOTES, 'UTF-8') . '</div>';
        }
        $html = '<div class="df-public-list"><style>.df-public-list{display:flex;flex-direction:column;gap:12px}.df-public-list details{border:1px solid #dfe3e7;border-radius:8px;background:#fff;overflow:hidden}.df-public-list summary{cursor:pointer;padding:15px 17px;font-weight:800}.df-public-list .df-public-desc{padding:0 17px 13px;color:#667085}.df-public-list .df-public-form{padding:0 17px 17px}</style>';
        foreach ($forms as $form) {
            $html .= '<details><summary>' . htmlspecialchars((string) $form['title'], ENT_QUOTES, 'UTF-8') . '</summary>';
            if (trim((string) $form['description']) !== '') {
                $html .= '<div class="df-public-desc">' . nl2br(htmlspecialchars((string) $form['description'], ENT_QUOTES, 'UTF-8')) . '</div>';
            }
            $html .= '<div class="df-public-form">' . $this->renderForm((int) $form['id']) . '</div></details>';
        }
        return $html . '</div>';
    }

    private function renderForm(int $id = 0, string $slug = ''): string
    {
        $form = $this->loadForm($id, $slug);
        if (!$form) {
            return '<div class="alert alert-warning">' . htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_NOT_FOUND'), ENT_QUOTES, 'UTF-8') . '</div>';
        }
        if (!(bool) $form['enabled']) {
            return $this->renderClosed($form);
        }

        $fields = $this->loadFields((int) $form['id']);
        $builder = $this->jsonObject($form['builder_config_json'] ?? '', []);
        $layout = is_array($builder['layout'] ?? null) ? $builder['layout'] : [];
        $validation = is_array($builder['validation'] ?? null) ? $builder['validation'] : [];
        $confirmation = is_array($builder['confirmation'] ?? null) ? $builder['confirmation'] : [];
        $accent = (string) ComponentHelper::getParams('com_decaroforms')->get('accent_color', '#e60046');
        if (!preg_match('/^#[0-9a-fA-F]{6}$/', $accent)) {
            $accent = '#e60046';
        }
        $uid = 'df-form-' . (int) $form['id'] . '-' . substr(hash('crc32b', microtime(true) . random_int(1, 999999)), 0, 6);
        $action = htmlspecialchars((string) ($_SERVER['REQUEST_URI'] ?? ''), ENT_QUOTES, 'UTF-8');
        $marker = htmlspecialchars((string) ($validation['required_marker'] ?? '*'), ENT_QUOTES, 'UTF-8');
        $mobileStack = ($layout['mobile_stack'] ?? true) !== false;

        $baseCss = '#'.$uid.'{width:100%;font-family:inherit;--df-accent:' . $accent . '}#'.$uid.' *{box-sizing:border-box}#'.$uid.' .df-box{padding:22px;border:1px solid #dfe3e7;border-radius:8px;background:#fff;color:#20262d}#'.$uid.' h3{margin:0 0 16px;font-size:25px}#'.$uid.' .df-desc{margin:-7px 0 18px;color:#667085}#'.$uid.' .df-grid{display:flex;flex-wrap:wrap;margin:0 -7px}#'.$uid.' .df-field{width:var(--df-field-width,100%);padding:0 7px;margin-bottom:15px}#'.$uid.' label{display:block;margin-bottom:6px;font-weight:750}#'.$uid.' input[type=text],#'.$uid.' input[type=email],#'.$uid.' input[type=tel],#'.$uid.' input[type=url],#'.$uid.' input[type=number],#'.$uid.' input[type=date],#'.$uid.' input[type=time],#'.$uid.' input[type=datetime-local],#'.$uid.' select,#'.$uid.' textarea{width:100%;min-height:44px;border:1px solid #ccd3db;border-radius:6px;padding:9px 11px;background:#fff;color:#20262d;font:inherit}#'.$uid.' textarea{min-height:120px;resize:vertical}#'.$uid.' .df-help{margin-top:4px;color:#707a84;font-size:12px}#'.$uid.' .df-options{display:flex;flex-direction:column;gap:7px}#'.$uid.' .df-option{display:flex;align-items:flex-start;gap:8px}#'.$uid.' .df-option input{margin-top:4px}#'.$uid.' .df-submit{min-height:44px;padding:0 18px;border:0;border-radius:6px;background:var(--df-accent);color:#fff;font-weight:800;cursor:pointer}#'.$uid.' .df-msg{display:none;margin:13px 0 0;padding:11px 13px;border-radius:6px;background:#eef7f1;color:#176b3a}#'.$uid.' .df-msg.error{background:#fdebec;color:#9f2430}#'.$uid.' .df-step{display:none}#'.$uid.' .df-step.is-active{display:block}#'.$uid.' .df-step-head{margin:0 0 14px}#'.$uid.' .df-progress{height:6px;border-radius:999px;background:#e8ebef;overflow:hidden;margin:0 0 16px}#'.$uid.' .df-progress>span{display:block;height:100%;background:var(--df-accent);transition:width .25s ease}#'.$uid.' .df-step-actions{display:flex;gap:8px;justify-content:space-between;margin-top:8px}#'.$uid.' .df-step-actions button{min-height:40px;padding:0 14px;border:1px solid #ccd3db;border-radius:6px;background:#fff;color:#20262d;font-weight:800}#'.$uid.' .df-separator{border:0;border-top:var(--df-line-size,1px) var(--df-line-style,solid) var(--df-line-color,#dfe3e7);width:var(--df-line-width,100%);margin:var(--df-line-margin,20px) auto}#'.$uid.' .df-pagebreak{break-after:page;page-break-after:always}#'.$uid.' .df-range-wrap{display:grid;grid-template-columns:1fr auto;gap:10px;align-items:center}#'.$uid.' input[type=range]{width:100%}#'.$uid.' .df-range-value{min-width:70px;text-align:right;font-weight:800}#'.$uid.' .df-payment-info{padding:13px;border:1px solid #dfe3e7;border-radius:7px;background:#f7f8fa}#'.$uid.' .df-payment-result{margin-top:13px;padding:14px;border:1px solid #dfe3e7;border-left:4px solid var(--df-accent);border-radius:7px;background:#fff}#'.$uid.' .df-copy-row{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:7px 0;border-bottom:1px solid #edf0f3}#'.$uid.' .df-copy-row:last-child{border-bottom:0}#'.$uid.' .df-copy{min-height:31px;padding:0 9px;border:1px solid #ccd3db;border-radius:5px;background:#fff;font-weight:750}#'.$uid.' .df-map-frame{width:100%;height:240px;border:1px solid #dfe3e7;border-radius:7px;margin-top:8px}#'.$uid.' .df-geo{margin-top:7px;min-height:34px;padding:0 10px;border:1px solid #ccd3db;border-radius:5px;background:#fff;font-weight:700}#'.$uid.' .df-continue{display:inline-flex;margin-top:10px;min-height:38px;align-items:center;padding:0 12px;border:1px solid #ccd3db;border-radius:6px;color:inherit;text-decoration:none;font-weight:800}#'.$uid.' .df-hidden-condition{display:none!important}@media(max-width:640px){#'.$uid.' .df-box{padding:17px}' . ($mobileStack ? '#'.$uid.' .df-field{width:100%!important}' : '') . '}@media print{#'.$uid.' .df-pagebreak{display:block;break-after:page;page-break-after:always}}';
        $customCss = trim((string) ($form['custom_css'] ?? ''));
        $customCss = str_ireplace(['</style', '<style'], ['', ''], $customCss);
        if ($customCss !== '') {
            $baseCss .= '@scope (#' . $uid . '){' . $customCss . '}';
        }

        $html = '<div id="' . $uid . '" class="df-public-form-wrap"><style>' . $baseCss . '</style><div class="df-box">';
        if ((bool) $form['show_heading']) {
            $html .= '<h3>' . htmlspecialchars((string) $form['title'], ENT_QUOTES, 'UTF-8') . '</h3>';
            if (trim((string) $form['description']) !== '') {
                $html .= '<div class="df-desc">' . nl2br(htmlspecialchars((string) $form['description'], ENT_QUOTES, 'UTF-8')) . '</div>';
            }
        }
        $html .= '<form method="post" enctype="multipart/form-data" action="' . $action . '" novalidate><input type="hidden" name="decaroforms_submit" value="1"><input type="hidden" name="decaroforms_form_id" value="' . (int) $form['id'] . '"><input type="hidden" name="decaroforms_started" value="' . time() . '"><div style="position:absolute;left:-10000px" aria-hidden="true"><label>Website<input type="text" name="decaroforms_website" tabindex="-1" autocomplete="off"></label></div>';

        $pages = $this->splitPages($fields);
        $isMultipage = count($pages) > 1;
        if ($isMultipage) {
            $html .= '<div class="df-progress" data-df-progress><span style="width:' . round(100 / count($pages), 2) . '%"></span></div>';
        }
        foreach ($pages as $pageIndex => $page) {
            $pageConfig = $page['config'];
            $html .= '<section class="df-step' . ($pageIndex === 0 ? ' is-active' : '') . '" data-df-step="' . $pageIndex . '">';
            if ($isMultipage && (($pageConfig['page_title'] ?? '') !== '' || ($pageConfig['page_description'] ?? '') !== '')) {
                $html .= '<div class="df-step-head">';
                if (($pageConfig['page_title'] ?? '') !== '') {
                    $html .= '<strong>' . htmlspecialchars((string) $pageConfig['page_title'], ENT_QUOTES, 'UTF-8') . '</strong>';
                }
                if (($pageConfig['page_description'] ?? '') !== '') {
                    $html .= '<div class="df-help">' . htmlspecialchars((string) $pageConfig['page_description'], ENT_QUOTES, 'UTF-8') . '</div>';
                }
                $html .= '</div>';
            }
            $html .= '<div class="df-grid">';
            foreach ($page['fields'] as $field) {
                $html .= $this->renderField($field, $marker, $builder);
            }
            $html .= '</div>';
            if ($isMultipage) {
                $html .= '<div class="df-step-actions">' . ($pageIndex > 0 ? '<button type="button" data-df-prev>' . htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_PREVIOUS'), ENT_QUOTES, 'UTF-8') . '</button>' : '<span></span>') . ($pageIndex < count($pages) - 1 ? '<button type="button" data-df-next>' . htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_NEXT'), ENT_QUOTES, 'UTF-8') . '</button>' : '<span></span>') . '</div>';
            }
            $html .= '</section>';
        }
        $html .= '<input type="hidden" name="' . Session::getFormToken() . '" value="1"><button class="df-submit" type="submit">' . htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_SEND'), ENT_QUOTES, 'UTF-8') . '</button><div class="df-msg" aria-live="polite" data-df-msg></div><div data-df-payment-result></div></form></div></div>';

        $success = $this->localizedSuccessMessage((string) ($form['success_message'] ?? ''));
        $error = (string) ($validation['error_message'] ?? Text::_('PLG_SYSTEM_DECAROFORMS_ERROR'));
        $confirmationConfig = [
            'enabled' => ($confirmation['enabled'] ?? true) !== false,
            'position' => (string) ($confirmation['position'] ?? 'below'),
            'scroll' => !empty($confirmation['scroll']),
            'continue' => !empty($confirmation['continue']),
            'continue_label' => (string) ($confirmation['continue_label'] ?? Text::_('PLG_SYSTEM_DECAROFORMS_CONTINUE')),
            'continue_url' => (string) ($confirmation['continue_url'] ?? ''),
            'scroll_error' => ($validation['scroll_error'] ?? true) !== false,
        ];
        $jsConfig = [
            'uid' => $uid,
            'success' => $success,
            'error' => $error,
            'confirmation' => $confirmationConfig,
            'pages' => count($pages),
            'formId' => (int) $form['id'],
        ];
        $html .= '<script>' . $this->frontendScript($jsConfig, (string) ($form['custom_js'] ?? '')) . '</script>';
        return $html;
    }

    private function splitPages(array $fields): array
    {
        $hasPage = false;
        foreach ($fields as $field) {
            if (($field['field_type'] ?? '') === 'page') {
                $hasPage = true;
                break;
            }
        }
        if (!$hasPage) {
            return [['config' => [], 'fields' => array_values(array_filter($fields, static fn($f) => ($f['field_type'] ?? '') !== 'page'))]];
        }
        $pages = [];
        $current = ['config' => ['page_title' => '', 'page_description' => ''], 'fields' => []];
        foreach ($fields as $field) {
            if (($field['field_type'] ?? '') === 'page') {
                if ($current['fields'] || $pages) {
                    $pages[] = $current;
                }
                $cfg = is_array($field['config'] ?? null) ? $field['config'] : [];
                $current = ['config' => ['page_title' => (string) ($cfg['page_title'] ?? $field['label'] ?? ''), 'page_description' => (string) ($cfg['page_description'] ?? '')], 'fields' => []];
                continue;
            }
            $current['fields'][] = $field;
        }
        if ($current['fields'] || !$pages) {
            $pages[] = $current;
        }
        return $pages ?: [['config' => [], 'fields' => $fields]];
    }

    private function fieldWidth(array $field): int
    {
        $cfg = is_array($field['config'] ?? null) ? $field['config'] : [];
        $layout = is_array($cfg['layout'] ?? null) ? $cfg['layout'] : [];
        return max(1, min(100, (int) ($layout['width'] ?? 100)));
    }

    private function renderField(array $field, string $marker, array $builder): string
    {
        $key = (string) $field['field_key'];
        $type = (string) $field['field_type'];
        $cfg = is_array($field['config'] ?? null) ? $field['config'] : [];
        $name = 'df_fields[' . $key . ']';
        $id = 'df_' . preg_replace('/[^a-zA-Z0-9_]/', '_', $key) . '_' . (int) $field['id'];
        $label = htmlspecialchars($this->localizedFieldLabel($field), ENT_QUOTES, 'UTF-8');
        $required = (bool) $field['required'];
        $star = $required ? ' ' . $marker : '';
        $reqAttr = $required ? ' required' : '';
        $placeholder = htmlspecialchars((string) ($field['placeholder'] ?? ''), ENT_QUOTES, 'UTF-8');
        $value = htmlspecialchars((string) ($field['default_value'] ?? ''), ENT_QUOTES, 'UTF-8');
        $configJson = htmlspecialchars(json_encode($cfg, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES), ENT_QUOTES, 'UTF-8');
        $style = '--df-field-width:' . $this->fieldWidth($field) . '%';

        if ($type === 'hidden') {
            return '<input type="hidden" name="' . $name . '" value="' . $value . '" data-df-key="' . htmlspecialchars($key, ENT_QUOTES, 'UTF-8') . '">';
        }
        if ($type === 'separator' || $type === 'pagebreak') {
            $color = preg_match('/^#[0-9a-fA-F]{6}$/', (string) ($cfg['color'] ?? '')) ? (string) $cfg['color'] : '#dfe3e7';
            $lineStyle = in_array((string) ($cfg['border_style'] ?? 'solid'), ['solid','dashed','dotted','double'], true) ? (string) $cfg['border_style'] : 'solid';
            $lineSize = max(0, min(20, (int) ($cfg['border_width'] ?? 1)));
            $lineWidth = max(1, min(100, (int) ($cfg['line_width'] ?? 100)));
            $margin = max(0, min(200, (int) ($cfg['margin'] ?? 20)));
            $showLine = $type === 'separator' || ($cfg['show_line'] ?? true) !== false;
            return '<div class="df-field' . ($type === 'pagebreak' ? ' df-pagebreak' : '') . '" style="' . $style . '">' . ($showLine ? '<hr class="df-separator" style="--df-line-color:' . htmlspecialchars($color, ENT_QUOTES, 'UTF-8') . ';--df-line-size:' . $lineSize . 'px;--df-line-style:' . $lineStyle . ';--df-line-width:' . $lineWidth . '%;--df-line-margin:' . $margin . 'px">' : '') . '</div>';
        }
        if ($type === 'heading') {
            return '<div class="df-field" style="' . $style . '"><h4>' . $label . '</h4></div>';
        }
        if ($type === 'info' || $type === 'fieldset') {
            $content = trim((string) ($cfg['content'] ?? ''));
            return '<div class="df-field" style="' . $style . '"><div class="df-payment-info">' . ($label !== '' ? '<strong>' . $label . '</strong>' : '') . ($content !== '' ? '<div class="df-help">' . nl2br(htmlspecialchars($content, ENT_QUOTES, 'UTF-8')) . '</div>' : '') . '</div></div>';
        }

        $html = '<div class="df-field" style="' . $style . '" data-df-key="' . htmlspecialchars($key, ENT_QUOTES, 'UTF-8') . '" data-df-required="' . ($required ? '1' : '0') . '" data-df-config="' . $configJson . '">';
        if ($type === 'consent' || $type === 'checkbox' || $type === 'toggle') {
            $html .= '<label class="df-option"><input type="checkbox" id="' . $id . '" name="' . $name . '" value="1"' . $reqAttr . '><span>' . $label . $star . '</span></label>';
        } elseif (in_array($type, ['radio','checkboxes'], true)) {
            $html .= '<label>' . $label . $star . '</label><div class="df-options">';
            foreach (($field['options'] ?? []) as $option) {
                $safe = htmlspecialchars((string) $option, ENT_QUOTES, 'UTF-8');
                $inputName = $name . ($type === 'checkboxes' ? '[]' : '');
                $inputType = $type === 'radio' ? 'radio' : 'checkbox';
                $html .= '<label class="df-option"><input type="' . $inputType . '" name="' . $inputName . '" value="' . $safe . '"' . $reqAttr . '><span>' . $safe . '</span></label>';
            }
            $html .= '</div>';
        } elseif ($type === 'select' || $type === 'multiselect') {
            $multiple = $type === 'multiselect';
            $html .= '<label for="' . $id . '">' . $label . $star . '</label><select id="' . $id . '" name="' . $name . ($multiple ? '[]' : '') . '"' . ($multiple ? ' multiple' : '') . $reqAttr . '><option value="">—</option>';
            foreach (($field['options'] ?? []) as $option) {
                $safe = htmlspecialchars((string) $option, ENT_QUOTES, 'UTF-8');
                $html .= '<option value="' . $safe . '">' . $safe . '</option>';
            }
            $html .= '</select>';
        } elseif ($type === 'textarea') {
            $html .= '<label for="' . $id . '">' . $label . $star . '</label><textarea id="' . $id . '" name="' . $name . '" placeholder="' . $placeholder . '"' . $reqAttr . '>' . $value . '</textarea>';
        } elseif ($type === 'file' || $type === 'upload') {
            $accept = htmlspecialchars((string) ($cfg['accept'] ?? '.pdf,.jpg,.jpeg,.png,.webp,.doc,.docx'), ENT_QUOTES, 'UTF-8');
            $multiple = !empty($cfg['multiple']) || (int) ($cfg['max_files'] ?? 1) > 1;
            $maxMb = max(1, min(25, (int) ($cfg['max_mb'] ?? 5)));
            $html .= '<label for="' . $id . '">' . $label . $star . '</label><input id="' . $id . '" type="file" name="df_file_' . htmlspecialchars($key, ENT_QUOTES, 'UTF-8') . ($multiple ? '[]' : '') . '"' . ($multiple ? ' multiple' : '') . $reqAttr . ' accept="' . $accept . '"><div class="df-help">' . htmlspecialchars(Text::sprintf('PLG_SYSTEM_DECAROFORMS_UPLOAD_HELP', $accept, $maxMb), ENT_QUOTES, 'UTF-8') . '</div>';
        } elseif ($type === 'range') {
            $min = (float) ($cfg['min'] ?? 0); $max = (float) ($cfg['max'] ?? 100); $step = (float) ($cfg['step'] ?? 1); $unit = htmlspecialchars((string) ($cfg['unit'] ?? ''), ENT_QUOTES, 'UTF-8'); $dual = !empty($cfg['dual']);
            $html .= '<label>' . $label . $star . '</label>';
            if ($dual) {
                $html .= '<div class="df-range-wrap"><div><input type="range" name="' . $name . '[min]" min="' . $min . '" max="' . $max . '" step="' . $step . '" value="' . $min . '" data-df-range><input type="range" name="' . $name . '[max]" min="' . $min . '" max="' . $max . '" step="' . $step . '" value="' . $max . '" data-df-range></div><output class="df-range-value">' . $min . ' – ' . $max . ' ' . $unit . '</output></div>';
            } else {
                $start = is_numeric($field['default_value'] ?? null) ? (float) $field['default_value'] : $min;
                $html .= '<div class="df-range-wrap"><input type="range" name="' . $name . '" min="' . $min . '" max="' . $max . '" step="' . $step . '" value="' . $start . '" data-df-range><output class="df-range-value">' . $start . ' ' . $unit . '</output></div>';
            }
        } elseif ($type === 'map') {
            $lat = is_numeric($cfg['lat'] ?? null) ? (float) $cfg['lat'] : 41.9028; $lng = is_numeric($cfg['lng'] ?? null) ? (float) $cfg['lng'] : 12.4964; $zoom = max(2, min(19, (int) ($cfg['zoom'] ?? 12)));
            $bbox = $this->osmBbox($lat, $lng, $zoom);
            $html .= '<label for="' . $id . '">' . $label . $star . '</label><input id="' . $id . '" type="text" name="' . $name . '" value="' . $value . '" placeholder="' . $placeholder . '"' . $reqAttr . '><input type="hidden" name="df_meta[' . htmlspecialchars($key, ENT_QUOTES, 'UTF-8') . '][lat]" value="' . $lat . '" data-df-lat><input type="hidden" name="df_meta[' . htmlspecialchars($key, ENT_QUOTES, 'UTF-8') . '][lng]" value="' . $lng . '" data-df-lng><button class="df-geo" type="button" data-df-geo>' . htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_USE_LOCATION'), ENT_QUOTES, 'UTF-8') . '</button><iframe class="df-map-frame" loading="lazy" referrerpolicy="no-referrer-when-downgrade" src="https://www.openstreetmap.org/export/embed.html?bbox=' . rawurlencode($bbox) . '&layer=mapnik&marker=' . rawurlencode($lat . ',' . $lng) . '" data-df-map></iframe>';
        } elseif ($type === 'payment') {
            $iban = htmlspecialchars((string) ($cfg['iban'] ?? ''), ENT_QUOTES, 'UTF-8'); $holder = htmlspecialchars((string) ($cfg['holder'] ?? ''), ENT_QUOTES, 'UTF-8'); $amount = htmlspecialchars((string) ($cfg['amount'] ?? ''), ENT_QUOTES, 'UTF-8');
            $html .= '<div class="df-payment-info"><strong>' . htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_BANK_TRANSFER'), ENT_QUOTES, 'UTF-8') . '</strong>' . ($holder !== '' ? '<div>' . htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_HOLDER'), ENT_QUOTES, 'UTF-8') . ': ' . $holder . '</div>' : '') . ($iban !== '' ? '<div>IBAN: <code>' . $iban . '</code></div>' : '') . ($amount !== '' ? '<div>' . htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_AMOUNT'), ENT_QUOTES, 'UTF-8') . ': ' . $amount . '</div>' : '') . '<div class="df-help">Carta / PayPal — ' . htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_COMING_SOON'), ENT_QUOTES, 'UTF-8') . '</div></div>';
        } elseif ($type === 'calculated') {
            $prefix = htmlspecialchars((string) ($cfg['prefix'] ?? ''), ENT_QUOTES, 'UTF-8'); $suffix = htmlspecialchars((string) ($cfg['suffix'] ?? ''), ENT_QUOTES, 'UTF-8');
            $html .= '<label for="' . $id . '">' . $label . '</label><input id="' . $id . '" type="text" name="' . $name . '" value="" readonly data-df-calculated><div class="df-help">' . $prefix . '<span data-df-calculated-preview>0</span>' . $suffix . '</div>';
        } elseif ($type === 'nationality' || $type === 'country') {
            $listId = $id . '_countries';
            $html .= '<label for="' . $id . '">' . $label . $star . '</label><input id="' . $id . '" type="text" name="' . $name . '" value="' . $value . '" list="' . $listId . '" autocomplete="off" placeholder="' . $placeholder . '"' . $reqAttr . '><datalist id="' . $listId . '">' . $this->countryOptions() . '</datalist>';
        } elseif ($type === 'region') {
            $listId = $id . '_regions';
            $defaultRegion = (string) (($builder['geography']['default_region'] ?? '') ?: $field['default_value'] ?? '');
            $html .= '<label for="' . $id . '">' . $label . $star . '</label><input id="' . $id . '" type="text" name="' . $name . '" value="' . htmlspecialchars($defaultRegion, ENT_QUOTES, 'UTF-8') . '" list="' . $listId . '" autocomplete="off"' . $reqAttr . '><datalist id="' . $listId . '">' . $this->italianRegionOptions() . '</datalist>';
        } elseif ($type === 'city') {
            $listId = $id . '_cities';
            $html .= '<label for="' . $id . '">' . $label . $star . '</label><input id="' . $id . '" type="text" name="' . $name . '" value="' . $value . '" list="' . $listId . '" autocomplete="off" placeholder="' . $placeholder . '"' . $reqAttr . '><datalist id="' . $listId . '">';
            foreach (($field['options'] ?? []) as $option) {
                $html .= '<option value="' . htmlspecialchars((string) $option, ENT_QUOTES, 'UTF-8') . '"></option>';
            }
            $html .= '</datalist>';
        } elseif ($type === 'postcode') {
            $html .= '<label for="' . $id . '">' . $label . $star . '</label><input id="' . $id . '" type="text" inputmode="numeric" pattern="[0-9]{5}" maxlength="5" name="' . $name . '" value="' . $value . '" placeholder="' . $placeholder . '"' . $reqAttr . '>';
        } elseif ($type === 'member_number') {
            $minLen = max(1, min(30, (int) ($cfg['min_length'] ?? 1))); $maxLen = max($minLen, min(50, (int) ($cfg['max_length'] ?? 20)));
            $html .= '<label for="' . $id . '">' . $label . $star . '</label><input id="' . $id . '" type="text" inputmode="numeric" pattern="[0-9]{' . $minLen . ',' . $maxLen . '}" maxlength="' . $maxLen . '" name="' . $name . '" value="' . $value . '" placeholder="' . $placeholder . '"' . $reqAttr . '>';
        } else {
            $inputType = in_array($type, ['email','tel','url','number','date','time','datetime'], true) ? ($type === 'datetime' ? 'datetime-local' : $type) : 'text';
            $html .= '<label for="' . $id . '">' . $label . $star . '</label><input id="' . $id . '" type="' . $inputType . '" name="' . $name . '" value="' . $value . '" placeholder="' . $placeholder . '"' . $reqAttr . '>';
        }
        if (trim((string) ($field['help_text'] ?? '')) !== '') {
            $html .= '<div class="df-help">' . htmlspecialchars((string) $field['help_text'], ENT_QUOTES, 'UTF-8') . '</div>';
        }
        return $html . '</div>';
    }

    private function frontendScript(array $config, string $customJs): string
    {
        $cfg = json_encode($config, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
        $customEncoded = base64_encode($customJs);
        return <<<'JS'
(()=>{
const cfg=__CFG__,root=document.getElementById(cfg.uid),form=root?.querySelector('form'),msg=root?.querySelector('[data-df-msg]');if(!root||!form||!msg)return;
const fieldWraps=()=>[...form.querySelectorAll('[data-df-key]')].filter(x=>x.classList.contains('df-field'));
const valueOf=key=>{const wrap=form.querySelector(`.df-field[data-df-key="${CSS.escape(key)}"]`);if(!wrap)return '';const inputs=[...wrap.querySelectorAll('input,select,textarea')].filter(x=>!['hidden','file'].includes(x.type));if(!inputs.length)return '';if(inputs[0].type==='checkbox'||inputs[0].type==='radio'){const vals=inputs.filter(x=>x.checked).map(x=>x.value);return vals.length>1?vals:vals[0]||'';}if(inputs[0].tagName==='SELECT'&&inputs[0].multiple)return [...inputs[0].selectedOptions].map(o=>o.value);return inputs[0].value??'';};
const compare=(actual,op,expected)=>{const arr=Array.isArray(actual)?actual:[actual];const s=String(actual??''),e=String(expected??'');switch(op){case'neq':return s!==e;case'contains':return arr.some(v=>String(v).includes(e));case'not_contains':return !arr.some(v=>String(v).includes(e));case'empty':return s===''||arr.filter(Boolean).length===0;case'not_empty':return s!==''&&arr.filter(Boolean).length>0;case'gt':return Number(s)>Number(e);case'lt':return Number(s)<Number(e);case'checked':return arr.filter(Boolean).length>0;case'not_checked':return arr.filter(Boolean).length===0;default:return arr.map(String).includes(e);}};
function applyConditions(){fieldWraps().forEach(w=>{let c={};try{c=JSON.parse(w.dataset.dfConfig||'{}')}catch{}const rules=Array.isArray(c.conditions)?c.conditions:[];if(!rules.length)return;const results=rules.map(r=>compare(valueOf(r.field),r.operator||'eq',r.value||'')),ok=(c.condition_logic==='any'?results.some(Boolean):results.every(Boolean)),action=c.condition_action||'show';let visible=true,disabled=false,required=w.dataset.dfRequired==='1';if(action==='show')visible=ok;else if(action==='hide')visible=!ok;else if(action==='disable')disabled=ok;else if(action==='require')required=required||ok;w.classList.toggle('df-hidden-condition',!visible);w.querySelectorAll('input,select,textarea').forEach(el=>{if(!['hidden','submit','button'].includes(el.type)){el.disabled=!visible||disabled;if(el.dataset.dfCalculated===undefined)el.required=visible&&required;}});});}
function updateRanges(){root.querySelectorAll('.df-range-wrap').forEach(w=>{const rs=[...w.querySelectorAll('[data-df-range]')],out=w.querySelector('.df-range-value');if(!out||!rs.length)return;let c={};try{c=JSON.parse(w.closest('.df-field')?.dataset.dfConfig||'{}')}catch{}const unit=c.unit||'';if(rs.length===2){let a=Number(rs[0].value),b=Number(rs[1].value);if(a>b){if(document.activeElement===rs[0])b=a;else a=b;rs[0].value=a;rs[1].value=b;}out.textContent=`${a} – ${b}${unit?' '+unit:''}`;}else out.textContent=`${rs[0].value}${unit?' '+unit:''}`;});}
function evaluateFormula(expr){let e=String(expr||'').replace(/\{([a-zA-Z0-9_-]+)\}/g,(_,k)=>{const n=Number(String(valueOf(k)).replace(',','.'));return Number.isFinite(n)?String(n):'0';});if(!/^[0-9+\-*/().\s]+$/.test(e))return 0;try{return Function(`"use strict";return (${e})`)();}catch{return 0;}}
function updateCalculated(){root.querySelectorAll('[data-df-calculated]').forEach(input=>{const w=input.closest('.df-field');let c={};try{c=JSON.parse(w?.dataset.dfConfig||'{}')}catch{}const n=Number(evaluateFormula(c.formula||'')),d=Math.max(0,Math.min(6,Number(c.decimals??2))),v=Number.isFinite(n)?n.toFixed(d):'0';input.value=v;const p=w.querySelector('[data-df-calculated-preview]');if(p)p.textContent=v;});}
function updateAll(){applyConditions();updateRanges();updateCalculated();}
form.addEventListener('input',updateAll);form.addEventListener('change',updateAll);
root.querySelectorAll('[data-df-geo]').forEach(btn=>btn.addEventListener('click',()=>{if(!navigator.geolocation)return;navigator.geolocation.getCurrentPosition(pos=>{const w=btn.closest('.df-field'),lat=pos.coords.latitude.toFixed(6),lng=pos.coords.longitude.toFixed(6),a=w.querySelector('[data-df-lat]'),b=w.querySelector('[data-df-lng]'),frame=w.querySelector('[data-df-map]');if(a)a.value=lat;if(b)b.value=lng;if(frame){const z=14,delta=.04,bbox=`${Number(lng)-delta},${Number(lat)-delta},${Number(lng)+delta},${Number(lat)+delta}`;frame.src=`https://www.openstreetmap.org/export/embed.html?bbox=${encodeURIComponent(bbox)}&layer=mapnik&marker=${encodeURIComponent(lat+','+lng)}`;}});}));
let step=0;const steps=[...root.querySelectorAll('[data-df-step]')],progress=root.querySelector('[data-df-progress] span');function showStep(i){step=Math.max(0,Math.min(steps.length-1,i));steps.forEach((s,n)=>s.classList.toggle('is-active',n===step));if(progress)progress.style.width=`${((step+1)/steps.length)*100}%`;steps[step]?.scrollIntoView({behavior:'smooth',block:'start'});}function validateScope(scope){updateAll();const bad=[...scope.querySelectorAll('input,select,textarea')].find(el=>!el.disabled&&!el.checkValidity());if(bad){bad.reportValidity();if(cfg.confirmation.scroll_error)bad.scrollIntoView({behavior:'smooth',block:'center'});return false;}return true;}root.querySelectorAll('[data-df-next]').forEach(btn=>btn.addEventListener('click',()=>{if(validateScope(steps[step]))showStep(step+1);}));root.querySelectorAll('[data-df-prev]').forEach(btn=>btn.addEventListener('click',()=>showStep(step-1)));
function paymentResult(payment){const host=root.querySelector('[data-df-payment-result]');if(!host)return;if(!payment||!payment.reference){host.innerHTML='';return;}const rows=[['Riferimento',payment.reference],['IBAN',payment.iban],['Causale',payment.cause],['Importo',payment.amount]].filter(x=>x[1]);host.innerHTML=`<div class="df-payment-result"><strong>${payment.label||'Pagamento via bonifico'}</strong>${rows.map(([k,v])=>`<div class="df-copy-row"><span><small>${k}</small><br><strong>${String(v).replace(/[&<>]/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[m]))}</strong></span><button class="df-copy" type="button" data-copy="${String(v).replace(/"/g,'&quot;')}">Copia</button></div>`).join('')}</div>`;host.querySelectorAll('[data-copy]').forEach(b=>b.onclick=async()=>{try{await navigator.clipboard.writeText(b.dataset.copy||'');b.textContent='Copiato';setTimeout(()=>b.textContent='Copia',1200);}catch{}});}
form.addEventListener('submit',async e=>{e.preventDefault();if(steps.length&&step<steps.length-1){if(validateScope(steps[step]))showStep(step+1);return;}if(!validateScope(form))return;msg.style.display='none';const b=form.querySelector('button[type=submit]');if(b)b.disabled=true;try{const x=await fetch(form.action,{method:'POST',body:new FormData(form),credentials:'same-origin',headers:{'X-Requested-With':'XMLHttpRequest'}});const j=await x.json();msg.classList.toggle('error',!j.success);msg.textContent=j.message||(j.success?cfg.success:cfg.error);if(cfg.confirmation.enabled||!j.success){msg.style.display='block';if(j.success&&cfg.confirmation.continue&&cfg.confirmation.continue_url){const a=document.createElement('a');a.className='df-continue';a.href=cfg.confirmation.continue_url;a.textContent=cfg.confirmation.continue_label||'Continua';msg.appendChild(document.createElement('br'));msg.appendChild(a);}if(j.success&&cfg.confirmation.position==='replace'){[...form.children].forEach(ch=>{if(ch!==msg&&!ch.matches('[data-df-payment-result]'))ch.style.display='none';});}if(j.success&&cfg.confirmation.position==='modal'){alert(msg.textContent);}if((j.success&&cfg.confirmation.scroll)||(!j.success&&cfg.confirmation.scroll_error))msg.scrollIntoView({behavior:'smooth',block:'center'});}if(j.success){paymentResult(j.payment);form.reset();showStep(0);updateAll();}}catch(_){msg.classList.add('error');msg.textContent=cfg.error;msg.style.display='block';}finally{if(b)b.disabled=false;}});
updateAll();if(steps.length)showStep(0);document.dispatchEvent(new CustomEvent('decaroforms:ready',{detail:{formElement:root,formId:cfg.formId}}));
const custom=atob('__CUSTOM__');if(custom.trim()){try{const fn=new Function('formElement','formId','form',custom);fn(root,cfg.formId,form);}catch(err){console.error('Forms custom JavaScript:',err);}}
})();
JS;
        return str_replace(['__CFG__','__CUSTOM__'], [$cfg, $customEncoded], $js);
    }

    private function osmBbox(float $lat, float $lng, int $zoom): string
    {
        $delta = max(0.005, 2.5 / max(1, $zoom));
        return ($lng - $delta) . ',' . ($lat - $delta) . ',' . ($lng + $delta) . ',' . ($lat + $delta);
    }

    private function countryOptions(): string
    {
        $countries = ['IT'=>'Italia','FR'=>'Francia','BE'=>'Belgio','DE'=>'Germania','ES'=>'Spagna','PT'=>'Portogallo','NL'=>'Paesi Bassi','LU'=>'Lussemburgo','AT'=>'Austria','CH'=>'Svizzera','GB'=>'Regno Unito','IE'=>'Irlanda','DK'=>'Danimarca','SE'=>'Svezia','NO'=>'Norvegia','FI'=>'Finlandia','IS'=>'Islanda','PL'=>'Polonia','CZ'=>'Repubblica Ceca','SK'=>'Slovacchia','HU'=>'Ungheria','SI'=>'Slovenia','HR'=>'Croazia','RO'=>'Romania','BG'=>'Bulgaria','GR'=>'Grecia','CY'=>'Cipro','MT'=>'Malta','EE'=>'Estonia','LV'=>'Lettonia','LT'=>'Lituania','AL'=>'Albania','BA'=>'Bosnia ed Erzegovina','ME'=>'Montenegro','MK'=>'Macedonia del Nord','RS'=>'Serbia','UA'=>'Ucraina','MD'=>'Moldova','TR'=>'Turchia','US'=>'Stati Uniti','CA'=>'Canada','MX'=>'Messico','BR'=>'Brasile','AR'=>'Argentina','CL'=>'Cile','PE'=>'Perù','CO'=>'Colombia','VE'=>'Venezuela','EC'=>'Ecuador','BO'=>'Bolivia','UY'=>'Uruguay','PY'=>'Paraguay','CN'=>'Cina','JP'=>'Giappone','KR'=>'Corea del Sud','IN'=>'India','PK'=>'Pakistan','BD'=>'Bangladesh','LK'=>'Sri Lanka','NP'=>'Nepal','PH'=>'Filippine','ID'=>'Indonesia','MY'=>'Malaysia','SG'=>'Singapore','TH'=>'Thailandia','VN'=>'Vietnam','AU'=>'Australia','NZ'=>'Nuova Zelanda','MA'=>'Marocco','DZ'=>'Algeria','TN'=>'Tunisia','EG'=>'Egitto','ZA'=>'Sudafrica','NG'=>'Nigeria','GH'=>'Ghana','SN'=>'Senegal','CI'=>'Costa d’Avorio','ET'=>'Etiopia','ER'=>'Eritrea','SO'=>'Somalia','KE'=>'Kenya','CM'=>'Camerun','CD'=>'Repubblica Democratica del Congo','CG'=>'Congo','AO'=>'Angola','MZ'=>'Mozambico','RU'=>'Russia','GE'=>'Georgia','AM'=>'Armenia','AZ'=>'Azerbaigian','IL'=>'Israele','PS'=>'Palestina','JO'=>'Giordania','LB'=>'Libano','SY'=>'Siria','IQ'=>'Iraq','IR'=>'Iran','SA'=>'Arabia Saudita','AE'=>'Emirati Arabi Uniti','QA'=>'Qatar','KW'=>'Kuwait'];
        $html = '';
        foreach ($countries as $code => $name) {
            $html .= '<option value="' . htmlspecialchars($name, ENT_QUOTES, 'UTF-8') . '" data-code="' . $code . '"></option>';
        }
        return $html;
    }

    private function italianRegionOptions(): string
    {
        $regions = ['Abruzzo','Basilicata','Calabria','Campania','Emilia-Romagna','Friuli-Venezia Giulia','Lazio','Liguria','Lombardia','Marche','Molise','Piemonte','Puglia','Sardegna','Sicilia','Toscana','Trentino-Alto Adige','Umbria','Valle d’Aosta','Veneto'];
        return implode('', array_map(static fn($r) => '<option value="' . htmlspecialchars($r, ENT_QUOTES, 'UTF-8') . '"></option>', $regions));
    }

    private function renderClosed(array $form): string
    {
        $reason = (string) ($form['closed_reason'] ?? 'closed');
        $custom = trim((string) ($form['closed_message'] ?? ''));
        $messages = ['closed'=>Text::_('PLG_SYSTEM_DECAROFORMS_CLOSED'),'limit'=>Text::_('PLG_SYSTEM_DECAROFORMS_LIMIT'),'deadline'=>Text::_('PLG_SYSTEM_DECAROFORMS_DEADLINE'),'temporary'=>Text::_('PLG_SYSTEM_DECAROFORMS_TEMPORARY'),'custom'=>$custom ?: Text::_('PLG_SYSTEM_DECAROFORMS_CLOSED')];
        $msg = $custom !== '' ? $custom : ($messages[$reason] ?? $messages['closed']);
        return '<div style="padding:18px 20px;border:1px solid #dfe3e7;border-left:5px solid #e60046;border-radius:7px;background:#fff"><strong>' . htmlspecialchars((string) $form['title'], ENT_QUOTES, 'UTF-8') . '</strong><div style="margin-top:5px">' . nl2br(htmlspecialchars($msg, ENT_QUOTES, 'UTF-8')) . '</div></div>';
    }

    private function handleSubmission(): array
    {
        $app = $this->getApplication();
        if (!Session::checkToken('post')) {
            return ['success' => false, 'message' => Text::_('JINVALID_TOKEN')];
        }
        $id = $app->getInput()->post->getInt('decaroforms_form_id', 0);
        $form = $this->loadForm($id);
        if (!$form) {
            return ['success' => false, 'message' => Text::_('PLG_SYSTEM_DECAROFORMS_NOT_FOUND')];
        }
        if (!(bool) $form['enabled']) {
            return ['success' => false, 'message' => strip_tags($this->renderClosed($form))];
        }
        if (trim($app->getInput()->post->getString('decaroforms_website', '')) !== '') {
            return ['success' => false, 'message' => Text::_('PLG_SYSTEM_DECAROFORMS_ERROR')];
        }

        $builder = $this->jsonObject($form['builder_config_json'] ?? '', []);
        $security = is_array($builder['security'] ?? null) ? $builder['security'] : [];
        $minSeconds = max(0, min(60, (int) ($security['min_seconds'] ?? 2)));
        $rateSeconds = max(0, min(3600, (int) ($security['rate_seconds'] ?? 8)));
        $started = $app->getInput()->post->getInt('decaroforms_started', 0);
        if ($started <= 0 || time() - $started < $minSeconds || time() - $started > 86400) {
            return ['success' => false, 'message' => Text::_('PLG_SYSTEM_DECAROFORMS_ERROR')];
        }
        $session = $app->getSession();
        $last = (int) $session->get('decaroforms.last.' . $id, 0);
        if ($rateSeconds > 0 && $last > 0 && time() - $last < $rateSeconds) {
            return ['success' => false, 'message' => Text::_('PLG_SYSTEM_DECAROFORMS_TOO_FAST')];
        }

        $fields = $this->loadFields($id);
        $posted = $app->getInput()->post->get('df_fields', [], 'array');
        $meta = $app->getInput()->post->get('df_meta', [], 'array');
        $payload = [];
        $values = [];
        $email = '';
        $files = [];
        $paymentField = null;

        foreach ($fields as $field) {
            $key = (string) $field['field_key'];
            $type = (string) $field['field_type'];
            $cfg = is_array($field['config'] ?? null) ? $field['config'] : [];
            if (in_array($type, ['separator','pagebreak','page','heading','info','fieldset'], true)) {
                continue;
            }
            if ($type === 'payment') {
                $paymentField = $field;
                continue;
            }
            if ($type === 'file' || $type === 'upload') {
                $uploadRaw = $app->getInput()->files->get('df_file_' . $key, null, 'raw');
                $uploads = $this->normaliseUploads($uploadRaw);
                $active = $this->fieldActive($field, $posted);
                if ($active && (bool) $field['required'] && !$uploads) {
                    return ['success'=>false,'message'=>Text::sprintf('PLG_SYSTEM_DECAROFORMS_REQUIRED', $this->localizedFieldLabel($field))];
                }
                $maxFiles = max(1, min(10, (int) ($cfg['max_files'] ?? 1)));
                if (count($uploads) > $maxFiles) {
                    return ['success'=>false,'message'=>Text::sprintf('PLG_SYSTEM_DECAROFORMS_TOO_MANY_FILES', $maxFiles)];
                }
                foreach ($uploads as $upload) {
                    $check = $this->validateFile($upload, $cfg);
                    if ($check !== true) {
                        return ['success'=>false,'message'=>$check];
                    }
                    $files[] = ['field' => $field, 'file' => $upload];
                }
                $payload[$this->localizedFieldLabel($field)] = implode(', ', array_map(static fn($u) => (string) ($u['name'] ?? 'file'), $uploads));
                $values[$key] = $payload[$this->localizedFieldLabel($field)];
                continue;
            }

            $raw = $posted[$key] ?? (($type === 'consent' || $type === 'checkbox' || $type === 'toggle') ? '' : '');
            $value = $this->cleanPostedValue($raw);
            if ($type === 'calculated') {
                $value = $this->calculate((string) ($cfg['formula'] ?? ''), $posted);
            }
            $active = $this->fieldActive($field, $posted);
            $required = $active && $this->fieldRequired($field, $posted);
            if ($required && $this->isEmptyValue($value, $type)) {
                return ['success'=>false,'message'=>Text::sprintf('PLG_SYSTEM_DECAROFORMS_REQUIRED', $this->localizedFieldLabel($field))];
            }
            if (!$active) {
                continue;
            }
            if ($type === 'email' && $value !== '') {
                if (!is_string($value) || !filter_var($value, FILTER_VALIDATE_EMAIL)) {
                    return ['success'=>false,'message'=>Text::_('PLG_SYSTEM_DECAROFORMS_INVALID_EMAIL')];
                }
                if ($email === '') {
                    $email = $value;
                }
            }
            if ($type === 'number' && $value !== '' && !is_numeric($value)) {
                return ['success'=>false,'message'=>Text::sprintf('PLG_SYSTEM_DECAROFORMS_INVALID_FIELD', $this->localizedFieldLabel($field))];
            }
            if ($type === 'postcode' && $value !== '' && (!is_string($value) || !preg_match('/^\d{5}$/', $value))) {
                return ['success'=>false,'message'=>Text::_('PLG_SYSTEM_DECAROFORMS_INVALID_POSTCODE')];
            }
            if ($type === 'member_number' && $value !== '') {
                $min = max(1, min(30, (int) ($cfg['min_length'] ?? 1))); $max = max($min, min(50, (int) ($cfg['max_length'] ?? 20)));
                if (!is_string($value) || !preg_match('/^\d{' . $min . ',' . $max . '}$/', $value)) {
                    return ['success'=>false,'message'=>Text::_('PLG_SYSTEM_DECAROFORMS_INVALID_MEMBER_NUMBER')];
                }
            }
            if (in_array($type, ['select','radio'], true) && $value !== '' && !in_array($value, $field['options'] ?? [], true)) {
                return ['success'=>false,'message'=>Text::sprintf('PLG_SYSTEM_DECAROFORMS_INVALID_FIELD', $this->localizedFieldLabel($field))];
            }
            if (in_array($type, ['checkboxes','multiselect'], true) && is_array($value)) {
                foreach ($value as $item) {
                    if (!in_array($item, $field['options'] ?? [], true)) {
                        return ['success'=>false,'message'=>Text::sprintf('PLG_SYSTEM_DECAROFORMS_INVALID_FIELD', $this->localizedFieldLabel($field))];
                    }
                }
            }
            if ($type === 'map' && is_array($meta[$key] ?? null)) {
                $lat = trim((string) ($meta[$key]['lat'] ?? '')); $lng = trim((string) ($meta[$key]['lng'] ?? ''));
                if ($lat !== '' && $lng !== '' && is_numeric($lat) && is_numeric($lng)) {
                    $value = trim((string) $value) . ' | ' . $lat . ', ' . $lng;
                }
            }
            $values[$key] = $value;
            $payload[$this->localizedFieldLabel($field)] = $value;
        }

        $statusRows = $this->jsonObject($form['statuses_json'] ?? '', []);
        $defaultStatus = 'new';
        if (!empty($statusRows[0]['key'])) {
            $candidate = preg_replace('/[^a-z0-9_-]+/', '_', strtolower((string) $statusRows[0]['key']));
            if ($candidate !== '') {
                $defaultStatus = substr($candidate, 0, 30);
            }
        }
        $reference = 'FRM-' . date('Ymd') . '-' . strtoupper(substr(bin2hex(random_bytes(5)), 0, 8));
        $now = Factory::getDate()->toSql();
        $row = (object) ['form_id'=>$id,'reference'=>$reference,'email'=>$email,'status'=>$defaultStatus,'payload_json'=>json_encode($payload, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES),'payment_json'=>'','internal_note'=>'','created_at'=>$now,'updated_at'=>null];

        try {
            $db = $this->getDb();
            $db->insertObject('#__decaroforms_submissions', $row, 'id');
            $submissionId = (int) $row->id;
            foreach ($files as $pack) {
                $this->saveFile($submissionId, (string) $pack['field']['field_key'], $pack['file'], $now);
            }
            $payment = $paymentField ? $this->buildPayment($paymentField, $values, $reference, $submissionId) : [];
            if ($payment) {
                $update = (object) ['id' => $submissionId, 'payment_json' => json_encode($payment, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES)];
                $db->updateObject('#__decaroforms_submissions', $update, 'id');
            }
            $session->set('decaroforms.last.' . $id, time());
            $this->sendEmails($form, $reference, $submissionId, $payload, $values, $email, $files, $payment);
            $this->sendGoogleSheets($form, $submissionId, $reference, $payload, $values, $payment, $files);
            return ['success'=>true,'message'=>$this->localizedSuccessMessage((string) ($form['success_message'] ?? '')),'reference'=>$reference,'payment'=>$payment];
        } catch (Throwable $e) {
            Log::add('Forms submission error: ' . $e->getMessage(), Log::ERROR, 'com_decaroforms');
            return ['success'=>false,'message'=>Text::_('PLG_SYSTEM_DECAROFORMS_ERROR')];
        }
    }

    private function cleanPostedValue(mixed $raw): mixed
    {
        if (is_array($raw)) {
            $out = [];
            foreach ($raw as $k => $v) {
                $clean = trim(strip_tags((string) $v));
                if ($clean !== '') {
                    $out[is_string($k) ? $k : count($out)] = $clean;
                }
            }
            return $out;
        }
        return trim(strip_tags((string) $raw));
    }

    private function isEmptyValue(mixed $value, string $type): bool
    {
        if (in_array($type, ['consent','checkbox','toggle'], true)) {
            return (string) $value !== '1';
        }
        return is_array($value) ? count($value) === 0 : trim((string) $value) === '';
    }

    private function conditionResult(array $rule, array $posted): bool
    {
        $actual = $this->cleanPostedValue($posted[(string) ($rule['field'] ?? '')] ?? '');
        $expected = (string) ($rule['value'] ?? '');
        $operator = (string) ($rule['operator'] ?? 'eq');
        $values = is_array($actual) ? array_map('strval', $actual) : [(string) $actual];
        $string = is_array($actual) ? implode(',', $values) : (string) $actual;
        return match ($operator) {
            'neq' => $string !== $expected,
            'contains' => (bool) array_filter($values, static fn($v) => str_contains($v, $expected)),
            'not_contains' => !(bool) array_filter($values, static fn($v) => str_contains($v, $expected)),
            'empty' => trim($string) === '',
            'not_empty' => trim($string) !== '',
            'gt' => is_numeric($string) && (float) $string > (float) $expected,
            'lt' => is_numeric($string) && (float) $string < (float) $expected,
            'checked' => trim($string) !== '',
            'not_checked' => trim($string) === '',
            default => in_array($expected, $values, true),
        };
    }

    private function conditionsMatch(array $config, array $posted): bool
    {
        $rules = is_array($config['conditions'] ?? null) ? $config['conditions'] : [];
        if (!$rules) {
            return true;
        }
        $results = array_map(fn($r) => is_array($r) ? $this->conditionResult($r, $posted) : false, $rules);
        return ($config['condition_logic'] ?? 'all') === 'any' ? in_array(true, $results, true) : !in_array(false, $results, true);
    }

    private function fieldActive(array $field, array $posted): bool
    {
        $cfg = is_array($field['config'] ?? null) ? $field['config'] : [];
        $rules = is_array($cfg['conditions'] ?? null) ? $cfg['conditions'] : [];
        if (!$rules) {
            return true;
        }
        $match = $this->conditionsMatch($cfg, $posted);
        return match ((string) ($cfg['condition_action'] ?? 'show')) {
            'show' => $match,
            'hide' => !$match,
            'disable' => !$match,
            default => true,
        };
    }

    private function fieldRequired(array $field, array $posted): bool
    {
        $required = (bool) ($field['required'] ?? false);
        $cfg = is_array($field['config'] ?? null) ? $field['config'] : [];
        if (($cfg['condition_action'] ?? '') === 'require' && $this->conditionsMatch($cfg, $posted)) {
            return true;
        }
        return $required;
    }

    private function calculate(string $formula, array $posted): string
    {
        if ($formula === '') {
            return '0';
        }
        $expr = preg_replace_callback('/\{([a-zA-Z0-9_-]+)\}/', function (array $m) use ($posted) {
            $value = $posted[$m[1]] ?? 0;
            if (is_array($value)) {
                $value = reset($value) ?: 0;
            }
            $number = str_replace(',', '.', (string) $value);
            return is_numeric($number) ? (string) ((float) $number) : '0';
        }, $formula) ?? '0';
        if (!preg_match('/^[0-9+\-*\/().\s]+$/', $expr)) {
            return '0';
        }
        try {
            $value = eval('return (' . $expr . ');');
            return is_numeric($value) ? (string) $value : '0';
        } catch (Throwable) {
            return '0';
        }
    }

    private function normaliseUploads(mixed $raw): array
    {
        if (!is_array($raw)) {
            return [];
        }
        if (isset($raw['tmp_name']) && !is_array($raw['tmp_name'])) {
            return !empty($raw['tmp_name']) && is_uploaded_file((string) $raw['tmp_name']) ? [$raw] : [];
        }
        if (!isset($raw['tmp_name']) || !is_array($raw['tmp_name'])) {
            return [];
        }
        $out = [];
        foreach ($raw['tmp_name'] as $i => $tmp) {
            if (!$tmp || !is_uploaded_file((string) $tmp)) {
                continue;
            }
            $out[] = [
                'tmp_name' => $tmp,
                'name' => $raw['name'][$i] ?? 'file',
                'type' => $raw['type'][$i] ?? '',
                'size' => $raw['size'][$i] ?? 0,
                'error' => $raw['error'][$i] ?? 0,
            ];
        }
        return $out;
    }

    private function validateFile(array $file, array $config): true|string
    {
        $maxBytes = max(1, min(25, (int) ($config['max_mb'] ?? 5))) * 1024 * 1024;
        $size = (int) ($file['size'] ?? 0);
        if ($size <= 0 || $size > $maxBytes) {
            return Text::_('PLG_SYSTEM_DECAROFORMS_FILE_SIZE');
        }
        $tmp = (string) ($file['tmp_name'] ?? '');
        $finfo = new \finfo(FILEINFO_MIME_TYPE);
        $mime = (string) $finfo->file($tmp);
        $allowed = ['application/pdf','image/jpeg','image/png','image/webp','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document'];
        return in_array($mime, $allowed, true) ? true : Text::_('PLG_SYSTEM_DECAROFORMS_FILE_TYPE');
    }

    private function saveFile(int $submissionId, string $fieldKey, array $file, string $now): void
    {
        $tmp = (string) $file['tmp_name'];
        $data = file_get_contents($tmp);
        if ($data === false) {
            throw new RuntimeException(Text::_('PLG_SYSTEM_DECAROFORMS_UPLOAD_READ_ERROR'));
        }
        $finfo = new \finfo(FILEINFO_MIME_TYPE);
        $row = (object) ['submission_id'=>$submissionId,'field_key'=>$fieldKey,'file_name'=>substr(basename((string) $file['name']),0,190),'mime_type'=>(string) $finfo->file($tmp),'file_size'=>(int) $file['size'],'sha256'=>hash('sha256',$data),'data_blob'=>$data,'created_at'=>$now];
        $this->getDb()->insertObject('#__decaroforms_files', $row);
    }

    private function buildPayment(array $field, array $values, string $formReference, int $submissionId): array
    {
        $cfg = is_array($field['config'] ?? null) ? $field['config'] : [];
        if (($cfg['method'] ?? 'bank') !== 'bank') {
            return [];
        }
        $paymentReference = 'PAY-' . date('Ymd') . '-' . strtoupper(substr(bin2hex(random_bytes(4)), 0, 6));
        $vars = $values + [
            'form_id' => (string) ($field['form_id'] ?? ''),
            'submission_id' => (string) $submissionId,
            'reference' => $formReference,
            'riferimento' => $paymentReference,
            'data' => date('d/m/Y'),
            'anno' => date('Y'),
        ];
        $cause = $this->replaceTokens((string) ($cfg['cause'] ?? '{last_name} {first_name} - {riferimento}'), $vars, $formReference, $paymentReference, $submissionId);
        $amountRaw = $this->replaceTokens((string) ($cfg['amount'] ?? ''), $vars, $formReference, $paymentReference, $submissionId);
        return [
            'method' => 'bank',
            'label' => Text::_('PLG_SYSTEM_DECAROFORMS_BANK_TRANSFER'),
            'iban' => trim((string) ($cfg['iban'] ?? '')),
            'holder' => trim((string) ($cfg['holder'] ?? '')),
            'amount' => trim($amountRaw),
            'cause' => trim($cause),
            'reference' => $paymentReference,
            'status' => 'pending',
            'verified' => false,
        ];
    }

    private function replaceTokens(string $text, array $values, string $reference, string $paymentReference = '', int $submissionId = 0, string $allFields = ''): string
    {
        $replace = [
            '{form_title}' => '', '{reference}' => $reference, '{riferimento}' => $paymentReference, '{submission_id}' => (string) $submissionId,
            '{data}' => date('d/m/Y'), '{anno}' => date('Y'), '{all_fields}' => $allFields,
        ];
        foreach ($values as $key => $value) {
            $replace['{' . $key . '}'] = is_array($value) ? implode(', ', array_map('strval', $value)) : (string) $value;
        }
        $text = strtr($text, $replace);
        $text = preg_replace_callback('/\{random(4|6)\}/', static fn($m) => strtoupper(substr(bin2hex(random_bytes(4)), 0, (int) $m[1])), $text) ?? $text;
        return $text;
    }

    private function parseEmailList(string $value): array
    {
        $out = [];
        foreach (preg_split('/[,;\s]+/', $value) ?: [] as $email) {
            $email = trim($email);
            if ($email !== '' && filter_var($email, FILTER_VALIDATE_EMAIL)) {
                $out[] = $email;
            }
        }
        return array_values(array_unique($out));
    }

    private function sendEmails(array $form, string $reference, int $submissionId, array $payload, array $values, string $userEmail, array $files, array $payment): void
    {
        try {
            $params = ComponentHelper::getParams('com_decaroforms');
            $cfg = $this->jsonObject($form['email_config_json'] ?? '', []);
            $adminCfg = is_array($cfg['admin'] ?? null) ? $cfg['admin'] : [];
            $userCfg = is_array($cfg['user'] ?? null) ? $cfg['user'] : [];
            $additional = $this->jsonObject($form['additional_emails_json'] ?? '', []);
            $summary = $this->emailSummary($payload);
            $allText = $this->emailSummaryText($payload);
            $mailFactory = Factory::getContainer()->get(MailerFactoryInterface::class);
            $fromEmail = trim((string) ($adminCfg['from_email'] ?? '')) ?: trim((string) $params->get('default_from_email','')) ?: trim((string) Factory::getConfig()->get('mailfrom',''));
            $fromName = trim((string) ($adminCfg['from_name'] ?? '')) ?: trim((string) $params->get('default_from_name','')) ?: trim((string) Factory::getConfig()->get('fromname', Factory::getConfig()->get('sitename','Website')));
            $adminTo = trim((string) ($adminCfg['to'] ?? $form['admin_email'] ?? '')) ?: trim((string) $params->get('default_admin_email','')) ?: trim((string) Factory::getConfig()->get('mailfrom',''));
            $tokenValues = $values + ['form_id'=>(string) $form['id']];
            $paymentRef = (string) ($payment['reference'] ?? '');

            if (filter_var($adminTo, FILTER_VALIDATE_EMAIL)) {
                $subjectTemplate = (string) ($adminCfg['subject'] ?? $form['email_subject_admin'] ?? '');
                if ($subjectTemplate === '') {
                    $subjectTemplate = Text::_('PLG_SYSTEM_DECAROFORMS_EMAIL_ADMIN_SUBJECT');
                }
                $subject = $this->replaceTokens($subjectTemplate, $tokenValues, $reference, $paymentRef, $submissionId, $allText);
                $subject = str_replace('{form_title}', (string) $form['title'], $subject);
                $template = (string) ($adminCfg['template'] ?? $form['email_template_admin'] ?? 'standard');
                $html = $this->emailTemplate($template, $form, $reference, $submissionId, $summary, $tokenValues, $adminCfg, false, $paymentRef, $allText);
                $mailer = $mailFactory->createMailer();
                if (filter_var($fromEmail, FILTER_VALIDATE_EMAIL)) {
                    $mailer->setSender([$fromEmail, $fromName]);
                }
                $mailer->addRecipient($adminTo);
                $replyTo = $this->replaceTokens((string) ($adminCfg['reply_to'] ?? ''), $tokenValues, $reference, $paymentRef, $submissionId, $allText);
                if (!filter_var($replyTo, FILTER_VALIDATE_EMAIL) && filter_var($userEmail, FILTER_VALIDATE_EMAIL)) {
                    $replyTo = $userEmail;
                }
                if (filter_var($replyTo, FILTER_VALIDATE_EMAIL)) {
                    $mailer->addReplyTo($replyTo, $this->replaceTokens((string) ($adminCfg['reply_name'] ?? ''), $tokenValues, $reference, $paymentRef, $submissionId, $allText));
                }
                foreach ($this->parseEmailList((string) ($adminCfg['cc'] ?? '')) as $cc) { $mailer->addCc($cc); }
                foreach ($this->parseEmailList((string) ($adminCfg['bcc'] ?? '')) as $bcc) { $mailer->addBcc($bcc); }
                $mailer->setSubject($subject); $mailer->isHtml(true); $mailer->setBody($html);
                if (!empty($adminCfg['attach_uploads'])) { $this->attachTempFiles($mailer, $files); }
                $mailer->send();
            }

            $userEnabled = !empty($userCfg['enabled']) || (bool) ($form['user_confirmation'] ?? false);
            $userKey = (string) ($userCfg['to_field'] ?? 'email');
            $resolvedUser = (string) ($tokenValues[$userKey] ?? $userEmail);
            if ($userEnabled && filter_var($resolvedUser, FILTER_VALIDATE_EMAIL)) {
                $subjectTemplate = (string) ($userCfg['subject'] ?? $form['email_subject_user'] ?? '');
                if ($subjectTemplate === '') { $subjectTemplate = Text::_('PLG_SYSTEM_DECAROFORMS_EMAIL_USER_SUBJECT'); }
                $subject = $this->replaceTokens($subjectTemplate, $tokenValues, $reference, $paymentRef, $submissionId, $allText);
                $subject = str_replace('{form_title}', (string) $form['title'], $subject);
                $template = (string) ($userCfg['template'] ?? $form['email_template_user'] ?? 'standard');
                $html = $this->emailTemplate($template, $form, $reference, $submissionId, $summary, $tokenValues, $userCfg, true, $paymentRef, $allText);
                $mailer = $mailFactory->createMailer();
                if (filter_var($fromEmail, FILTER_VALIDATE_EMAIL)) { $mailer->setSender([$fromEmail, $fromName]); }
                $mailer->addRecipient($resolvedUser);
                $replyTo = $this->replaceTokens((string) ($userCfg['reply_to'] ?? ''), $tokenValues, $reference, $paymentRef, $submissionId, $allText);
                if (filter_var($replyTo, FILTER_VALIDATE_EMAIL)) { $mailer->addReplyTo($replyTo, $this->replaceTokens((string) ($userCfg['reply_name'] ?? ''), $tokenValues, $reference, $paymentRef, $submissionId, $allText)); }
                $mailer->setSubject($subject); $mailer->isHtml(true); $mailer->setBody($html);
                if (!empty($userCfg['attach_uploads'])) { $this->attachTempFiles($mailer, $files); }
                $mailer->send();
            }

            foreach ($additional as $extra) {
                if (!is_array($extra) || ($extra['enabled'] ?? true) === false || !$this->additionalCondition($extra['condition'] ?? [], $values)) { continue; }
                $to = $this->replaceTokens((string) ($extra['to'] ?? ''), $tokenValues, $reference, $paymentRef, $submissionId, $allText);
                if (!filter_var($to, FILTER_VALIDATE_EMAIL)) { continue; }
                $subject = $this->replaceTokens((string) ($extra['subject'] ?? 'Nuovo invio – {form_title}'), $tokenValues, $reference, $paymentRef, $submissionId, $allText);
                $subject = str_replace('{form_title}', (string) $form['title'], $subject);
                $html = $this->emailTemplate((string) ($extra['template'] ?? 'standard'), $form, $reference, $submissionId, $summary, $tokenValues, $extra, false, $paymentRef, $allText);
                $mailer = $mailFactory->createMailer();
                if (filter_var($fromEmail, FILTER_VALIDATE_EMAIL)) { $mailer->setSender([$fromEmail, $fromName]); }
                $mailer->addRecipient($to);
                $replyTo = $this->replaceTokens((string) ($extra['reply_to'] ?? ''), $tokenValues, $reference, $paymentRef, $submissionId, $allText);
                if (filter_var($replyTo, FILTER_VALIDATE_EMAIL)) { $mailer->addReplyTo($replyTo, $this->replaceTokens((string) ($extra['reply_name'] ?? ''), $tokenValues, $reference, $paymentRef, $submissionId, $allText)); }
                foreach ($this->parseEmailList((string) ($extra['cc'] ?? '')) as $cc) { $mailer->addCc($cc); }
                foreach ($this->parseEmailList((string) ($extra['bcc'] ?? '')) as $bcc) { $mailer->addBcc($bcc); }
                $mailer->setSubject($subject); $mailer->isHtml(true); $mailer->setBody($html);
                if (!empty($extra['attach_uploads'])) { $this->attachTempFiles($mailer, $files); }
                $mailer->send();
            }
        } catch (Throwable $e) {
            try { Log::add('Forms email error: ' . $e->getMessage(), Log::WARNING, 'com_decaroforms'); } catch (Throwable) {}
        }
    }

    private function additionalCondition(mixed $condition, array $values): bool
    {
        if (!is_array($condition) || trim((string) ($condition['field'] ?? '')) === '') { return true; }
        $actual = $values[(string) $condition['field']] ?? '';
        $actual = is_array($actual) ? implode(',', array_map('strval', $actual)) : (string) $actual;
        $expected = (string) ($condition['value'] ?? '');
        return match ((string) ($condition['operator'] ?? 'eq')) {
            'neq' => $actual !== $expected,
            'contains' => str_contains($actual, $expected),
            'not_empty' => trim($actual) !== '',
            default => $actual === $expected,
        };
    }

    private function attachTempFiles(object $mailer, array $files): void
    {
        foreach ($files as $pack) {
            $tmp = (string) ($pack['file']['tmp_name'] ?? '');
            if ($tmp !== '' && is_file($tmp)) {
                $mailer->addAttachment($tmp, basename((string) ($pack['file']['name'] ?? 'file')));
            }
        }
    }

    private function emailSummary(array $payload): string
    {
        $rows = '';
        foreach ($payload as $key => $value) {
            $text = is_array($value) ? implode(', ', array_map('strval', $value)) : (string) $value;
            $rows .= '<tr><td style="padding:7px 9px;border-bottom:1px solid #e8ebef;font-weight:700;vertical-align:top">' . htmlspecialchars((string) $key, ENT_QUOTES, 'UTF-8') . '</td><td style="padding:7px 9px;border-bottom:1px solid #e8ebef">' . nl2br(htmlspecialchars($text, ENT_QUOTES, 'UTF-8')) . '</td></tr>';
        }
        return '<table role="presentation" style="width:100%;border-collapse:collapse">' . $rows . '</table>';
    }

    private function emailSummaryText(array $payload): string
    {
        $out = [];
        foreach ($payload as $key => $value) {
            $out[] = $key . ': ' . (is_array($value) ? implode(', ', array_map('strval', $value)) : (string) $value);
        }
        return implode("\n", $out);
    }

    private function cleanEmailHtml(string $html): string
    {
        $html = preg_replace('#<script\b[^>]*>.*?</script>#is', '', $html) ?? $html;
        $html = preg_replace('/\son[a-z]+\s*=\s*(["\']).*?\1/is', '', $html) ?? $html;
        return $html;
    }

    private function emailTemplate(string $template, array $form, string $reference, int $submissionId, string $summary, array $values, array $config, bool $forUser, string $paymentReference, string $allText): string
    {
        $accent = (string) ComponentHelper::getParams('com_decaroforms')->get('accent_color','#e60046');
        if (!preg_match('/^#[0-9a-fA-F]{6}$/', $accent)) { $accent = '#e60046'; }
        $brand = trim((string) ComponentHelper::getParams('com_decaroforms')->get('brand_name','')) ?: (string) Factory::getConfig()->get('sitename','Website');
        $safeBrand = htmlspecialchars($brand, ENT_QUOTES, 'UTF-8'); $safeTitle = htmlspecialchars((string) $form['title'], ENT_QUOTES, 'UTF-8'); $safeRef = htmlspecialchars($reference, ENT_QUOTES, 'UTF-8');
        $intro = $forUser ? '<p style="margin:0 0 15px">' . htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_EMAIL_USER_INTRO'), ENT_QUOTES, 'UTF-8') . '</p>' : '';
        $content = $intro . '<h2 style="margin:0 0 6px">' . $safeTitle . '</h2><p style="margin:0 0 18px;color:#667085">' . htmlspecialchars(Text::_('PLG_SYSTEM_DECAROFORMS_REFERENCE'), ENT_QUOTES, 'UTF-8') . ': <strong>' . $safeRef . '</strong></p>' . $summary;
        if (in_array($template, ['html','chatgpt'], true) && trim((string) ($config['html'] ?? '')) !== '') {
            $html = $this->replaceTokens((string) $config['html'], $values + ['form_id'=>(string) $form['id']], $reference, $paymentReference, $submissionId, $allText);
            $html = str_replace('{form_title}', (string) $form['title'], $html);
            return $this->cleanEmailHtml($html);
        }
        if ($template === 'custom') {
            $custom = is_array($config['custom'] ?? null) ? $config['custom'] : [];
            $base = in_array((string) ($custom['base'] ?? 'standard'), ['standard','minimal','institutional','card','compact','modern','elegant','receipt'], true) ? (string) $custom['base'] : 'standard';
            $primary = preg_match('/^#[0-9a-fA-F]{6}$/', (string) ($custom['primary'] ?? '')) ? (string) $custom['primary'] : $accent;
            $background = preg_match('/^#[0-9a-fA-F]{6}$/', (string) ($custom['background'] ?? '')) ? (string) $custom['background'] : '#ffffff';
            $text = preg_match('/^#[0-9a-fA-F]{6}$/', (string) ($custom['text'] ?? '')) ? (string) $custom['text'] : '#20262d';
            $border = preg_match('/^#[0-9a-fA-F]{6}$/', (string) ($custom['border'] ?? '')) ? (string) $custom['border'] : '#dfe3e7';
            $radius = max(0, min(40, (int) ($custom['radius'] ?? 8)));
            $inner = $this->emailTemplate($base, $form, $reference, $submissionId, $summary, $values, $config + ['custom'=>[]], $forUser, $paymentReference, $allText);
            return '<div style="background:' . $background . ';color:' . $text . ';border:1px solid ' . $border . ';border-radius:' . $radius . 'px;overflow:hidden"><div style="height:7px;background:' . $primary . '"></div>' . $inner . '</div>';
        }
        return match ($template) {
            'minimal' => '<div style="font-family:Arial,sans-serif;color:#20262d;max-width:680px;margin:auto">' . $content . '<p style="margin-top:22px;color:#8a929b;font-size:12px">' . $safeBrand . '</p></div>',
            'institutional' => '<div style="font-family:Arial,sans-serif;background:#f2f4f7;padding:22px"><div style="max-width:680px;margin:auto;background:#fff"><div style="background:#27364a;color:#fff;padding:15px 20px;font-weight:800">' . $safeBrand . '</div><div style="padding:22px">' . $content . '</div></div></div>',
            'card' => '<div style="font-family:Arial,sans-serif;background:#f4f5f7;padding:25px"><div style="max-width:650px;margin:auto;background:#fff;border-radius:10px;box-shadow:0 4px 18px rgba(0,0,0,.09);padding:24px">' . $content . '</div></div>',
            'compact' => '<div style="font-family:Arial,sans-serif;max-width:680px;margin:auto;border-left:5px solid ' . $accent . ';padding:16px 20px">' . $content . '</div>',
            'modern' => '<div style="font-family:Arial,sans-serif;background:linear-gradient(135deg,#f5f7fa,#ffffff);padding:25px"><div style="max-width:680px;margin:auto;background:#fff;border-radius:14px;padding:25px"><div style="width:58px;height:5px;background:' . $accent . ';border-radius:99px;margin-bottom:18px"></div>' . $content . '</div></div>',
            'elegant' => '<div style="font-family:Georgia,serif;max-width:680px;margin:auto;background:#fbfaf7;border:1px solid #d8ccb0;padding:28px;color:#2d2922"><div style="text-align:center;letter-spacing:.08em;margin-bottom:20px">' . $safeBrand . '</div>' . $content . '</div>',
            'receipt' => '<div style="font-family:Courier New,monospace;max-width:680px;margin:auto;background:#fff;border:1px dashed #aab2bc;padding:22px"><strong>' . $safeBrand . '</strong><hr style="border:0;border-top:1px dashed #aab2bc;margin:14px 0">' . $content . '</div>',
            default => '<div style="font-family:Arial,sans-serif;background:#f4f5f7;padding:22px"><div style="max-width:680px;margin:auto;background:#fff"><div style="background:' . $accent . ';color:#fff;padding:16px 20px;font-weight:800">' . $safeBrand . '</div><div style="padding:22px">' . $content . '</div></div></div>',
        };
    }

    private function sendGoogleSheets(array $form, int $submissionId, string $reference, array $payload, array $values, array $payment, array $files): void
    {
        $integrations = $this->jsonObject($form['integrations_json'] ?? '', []);
        $sheets = is_array($integrations['google_sheets'] ?? null) ? $integrations['google_sheets'] : [];
        if (empty($sheets['enabled'])) { return; }
        $url = trim((string) ($sheets['webhook_url'] ?? ''));
        if ($url === '' || !preg_match('#^https://#i', $url)) { return; }
        $body = [
            'source' => 'decaroforms', 'form_id' => (int) $form['id'], 'form_title' => (string) $form['title'], 'submission_id' => $submissionId,
            'reference' => $reference, 'submitted_at' => gmdate('c'), 'fields' => $payload, 'field_values' => $values, 'payment' => $payment,
        ];
        if (!empty($sheets['include_files'])) {
            $body['files'] = array_map(static fn($p) => ['field_key'=>(string) ($p['field']['field_key'] ?? ''),'name'=>(string) ($p['file']['name'] ?? ''),'size'=>(int) ($p['file']['size'] ?? 0)], $files);
        }
        $secret = trim((string) ($sheets['secret'] ?? ''));
        $headers = ['Content-Type' => 'application/json', 'Accept' => 'application/json'];
        if ($secret !== '') { $headers['X-DecaroForms-Secret'] = $secret; }
        try {
            HttpFactory::getHttp()->post($url, json_encode($body, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES), $headers, 8);
        } catch (Throwable $e) {
            try { Log::add('Forms Google Sheets webhook error: ' . $e->getMessage(), Log::WARNING, 'com_decaroforms'); } catch (Throwable) {}
        }
    }

    private function respond(array $data): void
    {
        $app = $this->getApplication();
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($data, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
        $app->close();
    }
}
