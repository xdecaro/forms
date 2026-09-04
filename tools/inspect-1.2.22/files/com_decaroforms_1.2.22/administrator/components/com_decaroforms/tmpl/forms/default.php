<?php

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\FormHelper;
use Joomla\CMS\Router\Route;
use Joomla\CMS\Language\Text;
use Joomla\CMS\HTML\HTMLHelper;
?>
<style>
.df-wrap{--df:#e60046;--df-dark:#b40038;--df-panel:var(--bs-body-bg,#fff);--df-panel-alt:var(--bs-tertiary-bg,#f6f7f9);--df-field:var(--bs-body-bg,#fff);--df-border:var(--bs-border-color,#dfe3e7);--df-hover:var(--bs-tertiary-bg,#eef1f4);--df-border-strong:#b8c1cc;max-width:none;color:var(--bs-body-color,#1f2937);container-type:inline-size;container-name:formslist}
.df-head{display:flex;justify-content:space-between;gap:16px;align-items:flex-end;margin:4px 0 18px}.df-head h2{margin:0;font-size:27px}.df-head p{margin:5px 0 0;color:var(--bs-secondary-color,#667085)}
.df-actions{display:flex;gap:9px;flex-wrap:wrap;align-items:center}.df-actions form,.df-card-actions form{margin:0}.df-btn{display:inline-flex;align-items:center;justify-content:center;min-height:40px;padding:0 14px;border:1px solid var(--df-border);border-radius:6px;background:var(--df-field);color:inherit!important;text-decoration:none;font-weight:700;cursor:pointer;text-align:center;line-height:1.2;transition:background-color .16s ease,border-color .16s ease,color .16s ease,transform .16s ease}.df-btn:not(.df-btn-primary):hover{background:var(--df-hover);border-color:var(--df-border-strong)}.df-btn:focus-visible{outline:2px solid #1683d8;outline-offset:2px}.df-btn-primary{background:var(--df);border-color:var(--df);color:#fff!important}.df-btn-primary:hover{background:var(--df-dark);border-color:var(--df-dark)}
.df-actions-menu{position:fixed;z-index:1200;width:min(240px,calc(100vw - 24px));padding:8px;border:1px solid var(--df-border);border-radius:8px;background:var(--df-panel);color:inherit;box-shadow:0 14px 36px rgba(0,0,0,.28)}.df-actions-menu[hidden]{display:none!important}.df-dialog-links{display:grid;grid-template-columns:1fr;gap:6px;padding:0}.df-dialog-links .df-btn{width:100%;min-height:44px;justify-content:flex-start;padding-left:14px;padding-right:14px}
.df-filter-toggle{display:none;width:100%;margin-bottom:10px;justify-content:space-between}.df-filter-toggle .df-chevron{transition:transform .32s ease}.df-filter-toggle[aria-expanded="true"] .df-chevron{transform:rotate(180deg)}
.df-tools{display:grid;grid-template-columns:minmax(260px,2fr) minmax(155px,1fr) minmax(185px,1fr) 120px auto;gap:10px;align-items:end;padding:15px 16px;margin-bottom:14px;border:1px solid var(--df-border);border-radius:8px;background:var(--df-panel);min-width:0}.df-tool{display:flex;flex-direction:column;gap:6px;min-width:0}.df-tool label{font-weight:800}.df-tool input,.df-tool select{width:100%;min-width:0;min-height:42px;border:1px solid var(--df-border);border-radius:6px;background:var(--df-field);color:inherit;padding:0 12px}.df-tool input::placeholder{font-style:italic;color:var(--bs-secondary-color,#87909b)}
.df-list{display:flex;flex-direction:column;gap:12px;min-width:0}.df-card{width:100%;max-width:100%;min-width:0;border:1px solid var(--df-border);border-radius:8px;background:var(--df-panel);box-shadow:0 2px 8px rgba(0,0,0,.04);overflow:hidden}.df-card-main{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:14px;align-items:start;padding:17px 18px;background:transparent}.df-card-main>div{min-width:0;background:none!important}.df-card h3{margin:0 0 4px;font-size:19px;overflow-wrap:anywhere;background:none!important;padding:0!important;border:0!important;box-shadow:none!important}.df-card h3::before,.df-card h3::after{content:none!important;display:none!important}.df-card p{margin:0;color:var(--bs-secondary-color,#667085);overflow-wrap:anywhere}.df-badge{display:inline-flex;align-items:center;justify-content:center;padding:4px 9px;border-radius:999px;font-size:12px;font-weight:800;white-space:nowrap;align-self:start}
.df-card-meta{display:grid;grid-template-columns:minmax(0,1fr) auto auto;gap:18px;align-items:center;padding:11px 18px;border-top:1px solid var(--df-border);background:var(--df-panel-alt);min-width:0}.df-code{min-width:0}.df-code small,.df-count small{display:block;color:var(--bs-secondary-color,#667085);font-size:11px;font-weight:800;text-transform:uppercase}.df-code code{font-weight:700;overflow-wrap:anywhere}.df-count{text-align:right}.df-count strong{display:block;font-size:21px}.df-card-actions{display:flex;gap:8px;justify-content:flex-end;align-items:center;min-width:0}.df-card-actions>*{min-width:0}
.df-empty{padding:38px 20px;text-align:center;border:1px dashed var(--df-border);border-radius:8px}.df-admin-footer{margin:28px 0 10px;padding-top:16px;border-top:1px solid var(--df-border);text-align:center;color:var(--bs-secondary-color,#667085);font-size:12px}
html[data-bs-theme="dark"] .df-wrap,html[data-color-scheme="dark"] .df-wrap{--df:#9f1239;--df-dark:#7f0d2e;--df-panel:#1a232d;--df-panel-alt:#202b37;--df-field:#121a23;--df-border:#3b4857;--df-hover:#263443;--df-border-strong:#56677a;color:#f3f6fa}
html[data-bs-theme="dark"] .df-wrap .df-head p,html[data-color-scheme="dark"] .df-wrap .df-head p,html[data-bs-theme="dark"] .df-wrap .df-card p,html[data-color-scheme="dark"] .df-wrap .df-card p{color:#b5c0cc}

.df-wrap.df-dark-theme{--df:#9f1239;--df-dark:#7f0d2e;--df-panel:#1a232d;--df-panel-alt:#202b37;--df-field:#121a23;--df-border:#3b4857;--df-hover:#263443;--df-border-strong:#56677a;color:#f3f6fa}
.df-wrap.df-dark-theme .df-head p,.df-wrap.df-dark-theme .df-card p{color:#b5c0cc}.df-wrap.df-dark-theme code{color:#f07a9b}.df-wrap.df-dark-theme .df-btn-primary{background:#9f1239!important;border-color:#9f1239!important;color:#fff!important}.df-wrap.df-dark-theme .df-btn-primary:hover{background:#7f0d2e!important;border-color:#7f0d2e!important}.df-wrap.df-dark-theme .df-btn:not(.df-btn-primary):hover{background:#263443;border-color:#56677a}
html[data-bs-theme="dark"] .df-wrap code,html[data-color-scheme="dark"] .df-wrap code{color:#f07a9b}html[data-bs-theme="dark"] .df-wrap .df-btn-primary,html[data-color-scheme="dark"] .df-wrap .df-btn-primary{background:#9f1239;border-color:#9f1239}html[data-bs-theme="dark"] .df-wrap .df-btn-primary:hover,html[data-color-scheme="dark"] .df-wrap .df-btn-primary:hover{background:#7f0d2e;border-color:#7f0d2e}
@container formslist (max-width:920px){.df-tools{grid-template-columns:repeat(3,minmax(0,1fr))}.df-tools>.df-btn{width:100%}.df-card-meta{grid-template-columns:minmax(0,1fr) auto}.df-card-actions{grid-column:1/-1;justify-content:flex-end}}
@container formslist (max-width:680px){.df-tools{grid-template-columns:repeat(2,minmax(0,1fr))}.df-head{align-items:flex-start}.df-card-meta{grid-template-columns:1fr}.df-count{text-align:left}.df-card-actions{justify-content:flex-start}}
@container formslist (max-width:560px){.df-tools .df-tool input,.df-tools .df-tool select,.df-tools>.df-btn{height:46px;min-height:46px;line-height:normal}.df-tools .df-tool input,.df-tools .df-tool select{padding-top:0;padding-bottom:0}.df-head{flex-direction:column;align-items:stretch;gap:10px}.df-actions{width:100%;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}.df-actions>.df-btn{width:100%;height:46px;min-height:46px;padding:0 8px;white-space:nowrap;font-size:inherit;line-height:normal}.df-filter-toggle{display:flex;position:relative;height:46px;min-height:46px;padding:0 42px 0 12px;align-items:center;justify-content:center;text-align:center;font-size:inherit;line-height:normal}.df-filter-toggle .df-chevron{position:absolute;right:14px;top:50%;transform:translateY(-50%)}.df-filter-toggle[aria-expanded="true"] .df-chevron{transform:translateY(-50%) rotate(180deg)}.df-tools{display:grid;grid-template-columns:1fr;max-height:0;opacity:0;overflow:hidden;visibility:hidden;pointer-events:none;transform:translateY(-6px);margin-bottom:0;padding-top:0;padding-bottom:0;border-width:0;transition:max-height .44s cubic-bezier(.22,.8,.24,1),opacity .28s ease,transform .44s cubic-bezier(.22,.8,.24,1),padding .44s ease,margin .44s ease,visibility 0s linear .44s}.df-tools.is-open{max-height:460px;opacity:1;visibility:visible;pointer-events:auto;transform:translateY(0);margin-bottom:14px;padding-top:15px;padding-bottom:15px;border-width:1px;transition:max-height .44s cubic-bezier(.22,.8,.24,1),opacity .28s ease,transform .44s cubic-bezier(.22,.8,.24,1),padding .44s ease,margin .44s ease,visibility 0s linear 0s}.df-card-main{padding:15px 16px;gap:10px}.df-card-meta{padding:12px 16px}.df-card-actions{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:8px;width:100%}.df-card-actions>*{width:100%}.df-card-actions .df-btn,.df-card-actions form .df-btn,.df-card-actions>a{width:100%;height:46px;min-height:46px;padding:0 7px;white-space:nowrap;font-size:inherit;line-height:normal;align-items:center;justify-content:center;text-align:center}.df-card-actions>*:nth-child(3){grid-column:1/-1}.df-card-actions>*:nth-child(3).df-btn{width:100%}.df-badge{margin-top:1px}}

html[data-bs-theme="dark"] .df-wrap .df-btn-primary,
html[data-color-scheme="dark"] .df-wrap .df-btn-primary,
body[data-bs-theme="dark"] .df-wrap .df-btn-primary,
body[data-color-scheme="dark"] .df-wrap .df-btn-primary,
.df-wrap.df-dark-theme .df-btn-primary{background:#9f1239!important;border-color:#9f1239!important;color:#fff!important}
html[data-bs-theme="dark"] .df-wrap .df-btn-primary:hover,
html[data-color-scheme="dark"] .df-wrap .df-btn-primary:hover,
body[data-bs-theme="dark"] .df-wrap .df-btn-primary:hover,
body[data-color-scheme="dark"] .df-wrap .df-btn-primary:hover,
.df-wrap.df-dark-theme .df-btn-primary:hover{background:#7f0d2e!important;border-color:#7f0d2e!important;color:#fff!important}

/* Forms 1.2.22: canonical card title + semantic status colors */
.df-wrap .df-card-main>div,
.df-wrap .df-card h3,
html[data-bs-theme="dark"] .df-wrap .df-card-main>div,
html[data-bs-theme="dark"] .df-wrap .df-card h3,
html[data-color-scheme="dark"] .df-wrap .df-card-main>div,
html[data-color-scheme="dark"] .df-wrap .df-card h3,
.df-wrap.df-dark-theme .df-card-main>div,
.df-wrap.df-dark-theme .df-card h3{background:none!important;background-color:transparent!important}

.df-wrap .df-badge.df-on,
html[data-bs-theme="dark"] .df-wrap .df-badge.df-on,
html[data-color-scheme="dark"] .df-wrap .df-badge.df-on,
.df-wrap.df-dark-theme .df-badge.df-on{background:#e8f7ee!important;color:#176b3a!important;border-color:#b7e3c8!important}

.df-wrap .df-badge.df-off,
html[data-bs-theme="dark"] .df-wrap .df-badge.df-off,
html[data-color-scheme="dark"] .df-wrap .df-badge.df-off,
.df-wrap.df-dark-theme .df-badge.df-off{background:#fdebec!important;color:#9f2430!important;border-color:#f2c5ca!important}


/* Forms 1.2.22: disabled reason badge + lightweight motion */
.df-card-badges{display:flex;flex-wrap:wrap;align-items:flex-start;justify-content:flex-end;gap:6px;max-width:100%}
.df-badge.df-reason{border:1px solid transparent}
.df-badge.df-reason-closed{background:#fff0e5!important;color:#a33a00!important;border-color:#ffc79f!important}
.df-badge.df-reason-limit{background:#fff7d6!important;color:#805b00!important;border-color:#efd36c!important}
.df-badge.df-reason-deadline{background:#ffebe5!important;color:#a83214!important;border-color:#efb29f!important}
.df-badge.df-reason-temporary{background:#eef2f6!important;color:#475467!important;border-color:#cfd7e3!important}
.df-badge.df-reason-custom{background:#f4ebff!important;color:#6941c6!important;border-color:#d6bbfb!important}
.df-actions-menu:not([hidden]){transform-origin:top right;animation:df-menu-in .22s cubic-bezier(.2,.7,.2,1) both}
.df-tools.is-open{transform-origin:top center}
@keyframes df-menu-in{from{opacity:0;transform:translateY(-6px) scale(.98)}to{opacity:1;transform:translateY(0) scale(1)}}
@keyframes df-filter-in{from{opacity:0;transform:translateY(-4px)}to{opacity:1;transform:translateY(0)}}
html[data-bs-theme="dark"] .df-wrap .df-code small,
html[data-bs-theme="dark"] .df-wrap .df-count small,
html[data-color-scheme="dark"] .df-wrap .df-code small,
html[data-color-scheme="dark"] .df-wrap .df-count small,
.df-wrap.df-dark-theme .df-code small,
.df-wrap.df-dark-theme .df-count small{color:#b5c0cc}
@container formslist (max-width:560px){.df-card-badges{flex-direction:column;align-items:flex-end;justify-content:flex-start;flex-wrap:nowrap}.df-badge.df-reason{max-width:150px;white-space:normal;text-align:center;line-height:1.15}}
@media (prefers-reduced-motion:reduce){.df-actions-menu:not([hidden]),.df-tools.is-open{animation:none!important}.df-filter-toggle .df-chevron,.df-btn{transition:none!important}}


/* Forms 1.2.22: concise status, quick shortcode copy and smoother filtering */
.df-code-row{display:flex;align-items:center;gap:8px;min-width:0;margin-top:1px}.df-code-row code{min-width:0}.df-copy-btn{width:32px;height:32px;min-width:32px;display:inline-flex;align-items:center;justify-content:center;border:1px solid var(--df-border);border-radius:6px;background:var(--df-field);color:inherit;cursor:pointer;transition:background-color .18s ease,border-color .18s ease,transform .18s ease}.df-copy-btn:hover{background:var(--df-hover);border-color:var(--df-border-strong)}.df-copy-btn:active{transform:scale(.95)}.df-copy-btn:focus-visible{outline:2px solid #1683d8;outline-offset:2px}.df-copy-btn svg{width:17px;height:17px;fill:currentColor}.df-copy-btn.is-copied{background:#e8f7ee!important;border-color:#b7e3c8!important;color:#176b3a!important}.df-copy-btn.is-copied svg{display:none}.df-copy-btn.is-copied::before{content:"✓";font-size:18px;font-weight:900;line-height:1}
.df-card-filter-out{animation:df-card-out .24s ease forwards;pointer-events:none}.df-card-filter-in{animation:df-card-in .26s cubic-bezier(.2,.7,.2,1) both}@keyframes df-card-out{from{opacity:1;transform:translateY(0) scale(1)}to{opacity:0;transform:translateY(-5px) scale(.992)}}@keyframes df-card-in{from{opacity:0;transform:translateY(6px) scale(.992)}to{opacity:1;transform:translateY(0) scale(1)}}
@media (prefers-reduced-motion:reduce){.df-card-filter-out,.df-card-filter-in{animation:none!important}.df-copy-btn{transition:none!important}}


/* Forms 1.2.22: keep disabled-reason badges visibly filled in dark mode */
html[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-closed,
html[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-closed,
body[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-closed,
body[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-closed,
.df-wrap.df-dark-theme .df-badge.df-reason-closed{background:#fff0e5!important;color:#8f3600!important;border-color:#ffc79f!important}

html[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-limit,
html[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-limit,
body[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-limit,
body[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-limit,
.df-wrap.df-dark-theme .df-badge.df-reason-limit{background:#fff7d6!important;color:#725100!important;border-color:#efd36c!important}

html[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-deadline,
html[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-deadline,
body[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-deadline,
body[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-deadline,
.df-wrap.df-dark-theme .df-badge.df-reason-deadline{background:#ffebe5!important;color:#963216!important;border-color:#efb29f!important}

html[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-temporary,
html[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-temporary,
body[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-temporary,
body[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-temporary,
.df-wrap.df-dark-theme .df-badge.df-reason-temporary{background:#eef2f6!important;color:#344054!important;border-color:#cfd7e3!important}

html[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-custom,
html[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-custom,
body[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-custom,
body[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-custom,
.df-wrap.df-dark-theme .df-badge.df-reason-custom{background:#f4ebff!important;color:#5b35b2!important;border-color:#d6bbfb!important}


/* Forms 1.2.22: slightly more compact disabled-reason badges */
.df-wrap .df-badge.df-reason{font-size:13px!important;line-height:1.2;font-weight:800}


/* Forms 1.2.22: mobile card header — status above, title full width */
@container formslist (max-width:560px){
  .df-wrap .df-card-main{grid-template-columns:1fr!important;align-items:start}
  .df-wrap .df-card-main>.df-card-badges{grid-column:1!important;grid-row:1!important;justify-self:end;width:auto;max-width:100%;margin:0 0 2px}
  .df-wrap .df-card-main>div:not(.df-card-badges){grid-column:1!important;grid-row:2!important;width:100%;min-width:0}
  .df-wrap .df-card-main h3{width:100%;max-width:none}
}


/* Forms 1.2.22: smartphone card hierarchy — title, description, then status */
@container formslist (max-width:560px){
  .df-wrap .df-card-main{grid-template-columns:1fr!important;align-items:start!important}
  .df-wrap .df-card-main>div:not(.df-card-badges){grid-column:1!important;grid-row:1!important;width:100%!important;min-width:0!important}
  .df-wrap .df-card-main>.df-card-badges{grid-column:1!important;grid-row:2!important;justify-self:end!important;width:auto!important;max-width:100%!important;margin:8px 0 0!important}
  .df-wrap .df-card-main h3{width:100%!important;max-width:none!important}
}


/* Forms 1.2.22: smartphone status/reason badge aligned left */
@container formslist (max-width:560px){
  .df-wrap .df-card-main>.df-card-badges{
    justify-self:start!important;
    align-items:flex-start!important;
  }
}

</style>
<div class="df-wrap">
  <div class="df-head">
    <div><h2><?php echo Text::_('COM_DECAROFORMS_FORMS'); ?></h2><p><?php echo Text::_('COM_DECAROFORMS_PAGE_FORMS_DESC'); ?></p></div>
    <div class="df-actions">
      <button class="df-btn" type="button" id="df-open-actions" aria-haspopup="menu" aria-expanded="false" aria-controls="df-actions-menu"><?php echo Text::_('COM_DECAROFORMS_MENU_SHORT'); ?> ▾</button>
      <a class="df-btn df-btn-primary" href="<?php echo $this->builderUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_CREATE_FORM'); ?></a>
    </div>
  </div>
  <div class="df-actions-menu" id="df-actions-menu" role="menu" hidden>
    <div class="df-dialog-links">
      <a class="df-btn" role="menuitem" href="<?php echo $this->dashboardUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_DASHBOARD'); ?></a>
      <a class="df-btn" role="menuitem" href="<?php echo $this->recentUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_RECENT'); ?></a>
      <a class="df-btn" role="menuitem" href="<?php echo $this->importUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_MENU_IMPORT'); ?></a>
      <a class="df-btn" role="menuitem" href="<?php echo $this->informationUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_INFORMATION'); ?></a>
    </div>
  </div>

<button class="df-btn df-filter-toggle" type="button" id="df-filter-toggle" aria-expanded="false" aria-controls="df-tools"><span><?php echo Text::_('COM_DECAROFORMS_SEARCH_FILTER'); ?></span><span class="df-chevron" aria-hidden="true">▾</span></button>
  <div class="df-tools" id="df-tools">
    <div class="df-tool"><label for="df-search"><?php echo Text::_('COM_DECAROFORMS_SEARCH'); ?></label><input id="df-search" type="search" placeholder="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_SEARCH_FORMS'),ENT_QUOTES,'UTF-8'); ?>" autocomplete="off"></div>
    <div class="df-tool"><label for="df-filter"><?php echo Text::_('COM_DECAROFORMS_STATUS'); ?></label><select id="df-filter"><option value="all"><?php echo Text::_('COM_DECAROFORMS_ALL_STATUSES'); ?></option><option value="enabled"><?php echo Text::_('COM_DECAROFORMS_ENABLED'); ?></option><option value="disabled"><?php echo Text::_('COM_DECAROFORMS_DISABLED'); ?></option></select></div>
    <div class="df-tool"><label for="df-sort"><?php echo Text::_('COM_DECAROFORMS_SORT'); ?></label><select id="df-sort"><option value="updated-desc"><?php echo Text::_('COM_DECAROFORMS_SORT_UPDATED_DESC'); ?></option><option value="updated-asc"><?php echo Text::_('COM_DECAROFORMS_SORT_UPDATED_ASC'); ?></option><option value="title-asc"><?php echo Text::_('COM_DECAROFORMS_SORT_TITLE_ASC'); ?></option><option value="title-desc"><?php echo Text::_('COM_DECAROFORMS_SORT_TITLE_DESC'); ?></option><option value="count-desc"><?php echo Text::_('COM_DECAROFORMS_SORT_SUBMISSIONS_DESC'); ?></option><option value="count-asc"><?php echo Text::_('COM_DECAROFORMS_SORT_SUBMISSIONS_ASC'); ?></option></select></div>
    <div class="df-tool"><label for="df-limit"><?php echo Text::_('COM_DECAROFORMS_SHOW'); ?></label><select id="df-limit"><option>10</option><option>25</option><option selected>50</option><option>100</option><option value="all"><?php echo Text::_('COM_DECAROFORMS_ALL'); ?></option></select></div>
    <button class="df-btn" type="button" id="df-clear"><?php echo Text::_('COM_DECAROFORMS_CLEAR'); ?></button>
  </div>

<?php
$closedReasonLabels = [
    'closed' => Text::_('COM_DECAROFORMS_CLOSED_REGISTRATIONS'),
    'limit' => Text::_('COM_DECAROFORMS_LIMIT_REACHED'),
    'deadline' => Text::_('COM_DECAROFORMS_DEADLINE_EXPIRED'),
    'temporary' => Text::_('COM_DECAROFORMS_TEMPORARILY_CLOSED'),
    'custom' => Text::_('COM_DECAROFORMS_CUSTOM_MESSAGE'),
];
$closedReasonClasses = [
    'closed' => 'df-reason-closed',
    'limit' => 'df-reason-limit',
    'deadline' => 'df-reason-deadline',
    'temporary' => 'df-reason-temporary',
    'custom' => 'df-reason-custom',
];
?>
  <div class="df-list" id="df-list">
  <?php if (!$this->forms): ?>
    <div class="df-empty"><?php echo Text::_('COM_DECAROFORMS_NO_FORMS'); ?></div>
  <?php endif; ?>
  <?php foreach ($this->forms as $form):
      $enabled=(int)$form['enabled']===1;
      $closedReason=(string)($form['closed_reason']??'closed');
      if(!isset($closedReasonLabels[$closedReason])){$closedReason='closed';}
      $closedReasonLabel=$closedReasonLabels[$closedReason];
      $closedReasonClass=$closedReasonClasses[$closedReason];
      $closedReasonTitle=$closedReason==='custom'?trim((string)($form['closed_message']??'')):'';
      $updated=(int)(strtotime((string)($form['updated_at']??''))?:0);
      $id=(int)$form['id'];
      $titleSort=mb_strtolower((string)$form['title'],'UTF-8');
      $searchText=mb_strtolower((string)$form['title'].' '.(string)$form['description'].' '.(string)$form['slug'].' '.$id.' form id="'.$id.'" {form id="'.$id.'"}', 'UTF-8');
  ?>
    <article class="df-card" data-search="<?php echo htmlspecialchars($searchText,ENT_QUOTES,'UTF-8'); ?>" data-title="<?php echo htmlspecialchars($titleSort,ENT_QUOTES,'UTF-8'); ?>" data-status="<?php echo $enabled?'enabled':'disabled'; ?>" data-updated="<?php echo $updated; ?>" data-count="<?php echo (int)$form['submission_count']; ?>">
      <div class="df-card-main"><div><h3><?php echo htmlspecialchars($form['title'],ENT_QUOTES,'UTF-8'); ?></h3><p><?php echo htmlspecialchars((string)$form['description'],ENT_QUOTES,'UTF-8'); ?></p></div><div class="df-card-badges"><?php if($enabled): ?><span class="df-badge df-on"><?php echo Text::_('COM_DECAROFORMS_IN_PROGRESS'); ?></span><?php else: ?><span class="df-badge df-reason <?php echo htmlspecialchars($closedReasonClass,ENT_QUOTES,'UTF-8'); ?>"<?php echo $closedReasonTitle!==''?' title="'.htmlspecialchars($closedReasonTitle,ENT_QUOTES,'UTF-8').'"':''; ?>><?php echo htmlspecialchars($closedReasonLabel,ENT_QUOTES,'UTF-8'); ?></span><?php endif; ?></div></div>
      <div class="df-card-meta">
        <div class="df-code"><small><?php echo Text::_('COM_DECAROFORMS_SHORTCODE'); ?></small><div class="df-code-row"><code id="df-shortcode-<?php echo $id; ?>">{form id="<?php echo $id; ?>"}</code><button class="df-copy-btn" type="button" data-copy-target="df-shortcode-<?php echo $id; ?>" data-label="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_COPY_SHORTCODE'),ENT_QUOTES,'UTF-8'); ?>" data-copied-label="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_SHORTCODE_COPIED'),ENT_QUOTES,'UTF-8'); ?>" aria-label="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_COPY_SHORTCODE'),ENT_QUOTES,'UTF-8'); ?>" title="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_COPY_SHORTCODE'),ENT_QUOTES,'UTF-8'); ?>"><svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M8 7V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2h-2v2a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2h2Zm2 0h4a2 2 0 0 1 2 2v6h2V5h-8v2Zm4 2H6v10h8V9Z"/></svg></button></div></div>
        <div class="df-count"><small><?php echo Text::_('COM_DECAROFORMS_SUBMISSIONS'); ?></small><strong><?php echo (int)$form['submission_count']; ?></strong></div>
        <div class="df-card-actions"><a class="df-btn" href="<?php echo Route::_('index.php?option=com_decaroforms&view=builder&id='.$id,false); ?>"><?php echo Text::_('COM_DECAROFORMS_EDIT'); ?></a><form method="post" action="index.php?option=com_decaroforms&task=builder.duplicate"><input type="hidden" name="id" value="<?php echo $id; ?>"><button class="df-btn" type="submit"><?php echo Text::_('COM_DECAROFORMS_DUPLICATE_FORM'); ?></button><?php echo HTMLHelper::_('form.token'); ?></form><a class="df-btn df-btn-primary" href="<?php echo Route::_('index.php?option=com_decaroforms&view=submissions&form_id='.$id,false); ?>"><?php echo Text::_('COM_DECAROFORMS_OPEN_SUBMISSIONS'); ?></a></div>
      </div>
    </article>
  <?php endforeach; ?>
  <?php if ($this->forms): ?><div class="df-empty" id="df-no-results" hidden><?php echo Text::_('COM_DECAROFORMS_NO_RESULTS'); ?></div><?php endif; ?>
  </div>
  <?php echo FormHelper::footer(); ?>
</div>
<script>
(()=>{
 const wrap=document.querySelector('.df-wrap'),root=document.documentElement,body=document.body;
 const darkState=()=>{
   const values=[root?.dataset?.bsTheme,root?.dataset?.colorScheme,body?.dataset?.bsTheme,body?.dataset?.colorScheme].filter(Boolean).map(v=>String(v).toLowerCase());
   if(values.includes('dark')) return true;
   if(values.includes('light')) return false;
   const rgb=(getComputedStyle(body).backgroundColor.match(/[\d.]+/g)||[]).slice(0,3).map(Number);
   return rgb.length===3 && (0.2126*rgb[0]+0.7152*rgb[1]+0.0722*rgb[2])<128;
 };
 const syncTheme=()=>wrap?.classList.toggle('df-dark-theme',darkState());
 syncTheme();
 const observer=new MutationObserver(syncTheme);
 observer.observe(root,{attributes:true,attributeFilter:['data-bs-theme','data-color-scheme','class']});
 if(body) observer.observe(body,{attributes:true,attributeFilter:['data-bs-theme','data-color-scheme','class']});
 const q=document.getElementById('df-search'),f=document.getElementById('df-filter'),sort=document.getElementById('df-sort'),limit=document.getElementById('df-limit'),clear=document.getElementById('df-clear'),list=document.getElementById('df-list'),cards=[...document.querySelectorAll('.df-card')],empty=document.getElementById('df-no-results');
 const dialog=document.getElementById('df-actions-dialog'),openActions=document.getElementById('df-open-actions'),closeActions=document.getElementById('df-close-actions'),filterToggle=document.getElementById('df-filter-toggle'),tools=document.getElementById('df-tools');
 openActions?.addEventListener('click',()=>dialog?.showModal());closeActions?.addEventListener('click',()=>dialog?.close());dialog?.addEventListener('click',event=>{if(event.target===dialog)dialog.close();});
 filterToggle?.addEventListener('click',()=>{const open=!tools.classList.contains('is-open');tools.classList.toggle('is-open',open);filterToggle.setAttribute('aria-expanded',open?'true':'false');});
 function cmp(a,b){const mode=sort.value;if(mode==='updated-asc')return Number(a.dataset.updated)-Number(b.dataset.updated);if(mode==='title-asc')return a.dataset.title.localeCompare(b.dataset.title);if(mode==='title-desc')return b.dataset.title.localeCompare(a.dataset.title);if(mode==='count-desc')return Number(b.dataset.count)-Number(a.dataset.count);if(mode==='count-asc')return Number(a.dataset.count)-Number(b.dataset.count);return Number(b.dataset.updated)-Number(a.dataset.updated);}
 const reducedMotion=window.matchMedia('(prefers-reduced-motion: reduce)');
 function showCard(card){clearTimeout(card._dfHideTimer);card.dataset.dfVisible='1';if(card.hidden){card.hidden=false;if(!reducedMotion.matches){card.classList.remove('df-card-filter-out');card.classList.add('df-card-filter-in');clearTimeout(card._dfInTimer);card._dfInTimer=setTimeout(()=>card.classList.remove('df-card-filter-in'),280);}}else if(card.classList.contains('df-card-filter-out')){card.classList.remove('df-card-filter-out');if(!reducedMotion.matches){card.classList.add('df-card-filter-in');clearTimeout(card._dfInTimer);card._dfInTimer=setTimeout(()=>card.classList.remove('df-card-filter-in'),280);}}}
 function hideCard(card){clearTimeout(card._dfInTimer);card.dataset.dfVisible='0';if(card.hidden)return;if(reducedMotion.matches){card.hidden=true;card.classList.remove('df-card-filter-in','df-card-filter-out');return;}card.classList.remove('df-card-filter-in');card.classList.add('df-card-filter-out');clearTimeout(card._dfHideTimer);card._dfHideTimer=setTimeout(()=>{if(card.dataset.dfVisible==='0'){card.hidden=true;card.classList.remove('df-card-filter-out');}},240);}
 function apply(){const s=(q.value||'').toLowerCase().trim(),st=f.value,max=limit.value==='all'?Infinity:parseInt(limit.value||'50',10);const ordered=[...cards].sort(cmp);ordered.forEach(card=>list.insertBefore(card,empty||null));let shown=0;ordered.forEach(card=>{const match=(!s||card.dataset.search.includes(s))&&(st==='all'||card.dataset.status===st);const visible=match&&shown<max;if(visible){shown++;showCard(card);}else hideCard(card);});if(empty)empty.hidden=shown!==0;}
 let liveTimer=null;function schedule(){clearTimeout(liveTimer);liveTimer=setTimeout(apply,110);}q?.addEventListener('input',schedule);f?.addEventListener('change',apply);sort?.addEventListener('change',apply);limit?.addEventListener('change',apply);clear?.addEventListener('click',()=>{clearTimeout(liveTimer);q.value='';f.value='all';sort.value='updated-desc';limit.value='50';apply();});apply();

 const fallbackCopy=text=>{const ta=document.createElement('textarea');ta.value=text;ta.setAttribute('readonly','');ta.style.position='fixed';ta.style.opacity='0';document.body.appendChild(ta);ta.select();let ok=false;try{ok=document.execCommand('copy');}catch(e){}ta.remove();return ok;};
 document.querySelectorAll('.df-copy-btn').forEach(btn=>btn.addEventListener('click',async()=>{const target=document.getElementById(btn.dataset.copyTarget||'');if(!target)return;const text=target.textContent||'';let ok=false;try{if(navigator.clipboard?.writeText){await navigator.clipboard.writeText(text);ok=true;}else ok=fallbackCopy(text);}catch(e){ok=fallbackCopy(text);}if(!ok)return;const original=btn.dataset.label||btn.getAttribute('aria-label')||'';const copied=btn.dataset.copiedLabel||'Copied';btn.classList.add('is-copied');btn.setAttribute('aria-label',copied);btn.setAttribute('title',copied);clearTimeout(btn._dfCopyTimer);btn._dfCopyTimer=setTimeout(()=>{btn.classList.remove('is-copied');btn.setAttribute('aria-label',original);btn.setAttribute('title',original);},1400);}));

 const menuNav=document.getElementById('df-actions-menu'),menuBtnNav=document.getElementById('df-open-actions');
 const closeMenuNav=()=>{if(!menuNav)return;menuNav.hidden=true;menuBtnNav?.setAttribute('aria-expanded','false');};
 const placeMenuNav=()=>{if(!menuNav||!menuBtnNav||menuNav.hidden)return;const r=menuBtnNav.getBoundingClientRect();const w=menuNav.offsetWidth||240;const left=Math.max(12,Math.min(r.left,window.innerWidth-w-12));menuNav.style.left=`${left}px`;const maxTop=Math.max(12,window.innerHeight-menuNav.offsetHeight-12);menuNav.style.top=`${Math.min(r.bottom+8,maxTop)}px`;};
 menuBtnNav?.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();if(!menuNav)return;const opening=menuNav.hidden;if(opening){menuNav.hidden=false;menuBtnNav.setAttribute('aria-expanded','true');requestAnimationFrame(placeMenuNav);}else closeMenuNav();});
 menuNav?.addEventListener('click',e=>e.stopPropagation());
 menuNav?.querySelectorAll('a').forEach(a=>a.addEventListener('click',closeMenuNav));
 document.addEventListener('click',closeMenuNav);
 document.addEventListener('keydown',e=>{if(e.key==='Escape')closeMenuNav();});
 window.addEventListener('resize',placeMenuNav);
 window.addEventListener('scroll',placeMenuNav,true);
})();
</script>
