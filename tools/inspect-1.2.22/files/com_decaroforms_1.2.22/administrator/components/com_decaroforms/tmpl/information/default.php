<?php

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\FormHelper;
use Joomla\CMS\Language\Text;
?>
<style>
.df-info{--df:#e60046;max-width:none;}.df-info-head{display:flex;justify-content:space-between;align-items:flex-end;gap:14px;margin:4px 0 18px}.df-info-head h2{margin:0;font-size:27px}.df-info-head p{margin:5px 0 0;color:var(--bs-secondary-color,#667085)}.df-actions{display:flex;gap:8px;flex-wrap:wrap}.df-btn{display:inline-flex;align-items:center;justify-content:center;min-height:39px;padding:0 14px;border:1px solid var(--bs-border-color,#d9dee5);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit!important;text-decoration:none;font-weight:700}.df-btn-primary{background:var(--df);border-color:var(--df);color:#fff!important}.df-card{margin-bottom:14px;border:1px solid var(--bs-border-color,#dfe3e7);border-radius:8px;background:var(--bs-body-bg,#fff);overflow:hidden}.df-card h3{margin:0;padding:14px 16px;background:var(--bs-tertiary-bg,#f7f8fa);border-bottom:1px solid var(--bs-border-color,#dfe3e7);font-size:18px}.df-body{padding:16px}.df-grid{display:grid;grid-template-columns:1fr 1fr;gap:0 26px}.df-row{display:grid;grid-template-columns:180px minmax(0,1fr);gap:10px;padding:9px 0;border-bottom:1px solid var(--bs-border-color,#edf0f3)}.df-row b{font-size:12px;text-transform:uppercase;color:var(--bs-secondary-color,#667085)}.df-code{font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace}.df-list{margin:0;padding-left:20px}.df-list li{margin:6px 0}.df-note{padding:12px 14px;border-left:4px solid var(--df);background:var(--bs-tertiary-bg,#f7f8fa);border-radius:4px}.df-badge{display:inline-flex;padding:4px 9px;border-radius:999px;background:#e8f7ee;color:#176b3a;font-size:12px;font-weight:800}@media(max-width:760px){.df-info-head{flex-direction:column;align-items:flex-start}.df-grid{grid-template-columns:1fr}.df-row{grid-template-columns:1fr}.df-actions{width:100%}.df-btn{flex:1}}
</style>
<div class="df-info">
  <div class="df-info-head">
    <div><h2><?php echo Text::_('COM_DECAROFORMS_INFO_TITLE'); ?></h2><p><?php echo Text::_('COM_DECAROFORMS_INFO_DESC'); ?></p></div>
    <div class="df-actions"><a class="df-btn" href="<?php echo $this->formsUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_MENU_FORMS'); ?></a><a class="df-btn" href="<?php echo $this->importUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_MENU_IMPORT'); ?></a><a class="df-btn df-btn-primary" href="<?php echo $this->builderUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_CREATE_FORM'); ?></a></div>
  </div>

  <section class="df-card"><h3><?php echo Text::_('COM_DECAROFORMS_EXTENSION'); ?></h3><div class="df-body"><div class="df-grid">
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_NAME'); ?></b><span>Forms</span></div>
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_VERSION'); ?></b><span><span class="df-badge"><?php echo FormHelper::VERSION; ?></span></span></div>
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_DEVELOPER'); ?></b><span>Luca De Caro</span></div>
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_COPYRIGHT'); ?></b><span><?php echo htmlspecialchars(Text::sprintf('COM_DECAROFORMS_FOOTER',FormHelper::VERSION),ENT_QUOTES,'UTF-8'); ?></span></div>
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_COMPONENT'); ?></b><span class="df-code">com_decaroforms</span></div>
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_SYSTEM_PLUGIN'); ?></b><span class="df-code">plg_system_decaroforms</span></div>
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_PACKAGE'); ?></b><span class="df-code">pkg_decaroforms</span></div>
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_LICENSE'); ?></b><span>GNU GPL v2 or later</span></div>
  </div></div></section>

  <section class="df-card"><h3><?php echo Text::_('COM_DECAROFORMS_REQUIREMENTS'); ?></h3><div class="df-body"><div class="df-grid">
    <div class="df-row"><b>Joomla</b><span>6.0 or later</span></div>
    <div class="df-row"><b>PHP</b><span>8.3 or later</span></div>
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_DATABASE'); ?></b><span>MySQL / MariaDB supported by Joomla</span></div>
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_UPLOADS'); ?></b><span>PDF, JPG, PNG, WebP, DOC, DOCX — max 5 MB</span></div>
  </div></div></section>

  <section class="df-card"><h3><?php echo Text::_('COM_DECAROFORMS_SHORTCODES'); ?></h3><div class="df-body">
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_FORM_BY_ID'); ?></b><span class="df-code">{form id="1"}</span></div>
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_FORM_BY_SLUG'); ?></b><span class="df-code">{form slug="contact"}</span></div>
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_MENU_FORMS'); ?></b><span class="df-code">{forms}</span></div>
    <p class="df-note"><?php echo Text::_('COM_DECAROFORMS_INFO_SHORTCODE_NOTE'); ?></p>
  </div></section>

  <section class="df-card"><h3><?php echo Text::_('COM_DECAROFORMS_MAIN_FEATURES'); ?></h3><div class="df-body"><ul class="df-list">
    <li><?php echo Text::_('COM_DECAROFORMS_FEATURE_1'); ?></li>
    <li><?php echo Text::_('COM_DECAROFORMS_FEATURE_2'); ?></li>
    <li><?php echo Text::_('COM_DECAROFORMS_FEATURE_3'); ?></li>
    <li><?php echo Text::_('COM_DECAROFORMS_FEATURE_4'); ?></li>
    <li><?php echo Text::_('COM_DECAROFORMS_FEATURE_5'); ?></li>
    <li><?php echo Text::_('COM_DECAROFORMS_FEATURE_6'); ?></li>
    <li><?php echo Text::_('COM_DECAROFORMS_FEATURE_7'); ?></li>
    <li><?php echo Text::_('COM_DECAROFORMS_FEATURE_8'); ?></li>
    <li><?php echo Text::_('COM_DECAROFORMS_FEATURE_9'); ?></li>
    <li><?php echo Text::_('COM_DECAROFORMS_FEATURE_10'); ?></li>
    <li><?php echo Text::_('COM_DECAROFORMS_FEATURE_11'); ?></li>
  </ul></div></section>

  <section class="df-card"><h3><?php echo Text::_('COM_DECAROFORMS_DATABASE_TABLES'); ?></h3><div class="df-body"><div class="df-grid">
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_FORMS'); ?></b><span class="df-code">#__decaroforms_forms</span></div>
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_FIELDS'); ?></b><span class="df-code">#__decaroforms_fields</span></div>
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_SUBMISSIONS'); ?></b><span class="df-code">#__decaroforms_submissions</span></div>
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_FILES'); ?></b><span class="df-code">#__decaroforms_files</span></div>
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_MIGRATION_MAP'); ?></b><span class="df-code">#__decaroforms_migrations</span></div>
    <div class="df-row"><b><?php echo Text::_('COM_DECAROFORMS_IMPORT_LOG'); ?></b><span class="df-code">#__decaroforms_import_log</span></div>
  </div></div></section>

  <?php echo FormHelper::footer(); ?>
</div>
