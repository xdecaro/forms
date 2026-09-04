<?php

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\FormHelper;
use Joomla\CMS\Language\Text;
use Joomla\CMS\Router\Route;
?>
<style>
.df-recent{--df:#e60046;--df-blue:#0789c8;width:100%;max-width:none}.df-recent-head{display:flex;align-items:flex-end;justify-content:space-between;gap:18px;margin:6px 0 24px}.df-recent-head h2{margin:0;font-size:34px;line-height:1.1}.df-recent-head p{margin:7px 0 0;color:var(--bs-secondary-color,#667085);font-size:17px}.df-head-actions{display:flex;gap:8px;align-items:center;flex-wrap:wrap}.df-btn{display:inline-flex;align-items:center;justify-content:center;min-height:42px;padding:0 16px;border:1px solid var(--bs-border-color,#d3dae3);border-radius:7px;background:var(--bs-body-bg,#fff);color:inherit!important;text-decoration:none;font-weight:800;cursor:pointer}.df-btn-primary{background:var(--df);border-color:var(--df);color:#fff!important}.df-btn:hover{filter:brightness(.98)}
.df-columns-wrap{position:relative}.df-columns-menu{position:absolute;right:0;top:calc(100% + 7px);z-index:40;width:245px;padding:10px;border:1px solid var(--bs-border-color,#d4dce5);border-radius:8px;background:var(--bs-body-bg,#fff);box-shadow:0 12px 32px rgba(0,0,0,.18)}.df-columns-menu[hidden]{display:none}.df-columns-title{padding:3px 5px 8px;font-weight:850}.df-columns-menu label{display:flex;align-items:center;gap:9px;padding:8px 7px;border-radius:5px;cursor:pointer}.df-columns-menu label:hover{background:var(--bs-tertiary-bg,#f2f5f8)}.df-columns-menu input{width:17px;height:17px}.df-columns-reset{width:100%;margin-top:7px;min-height:37px;border:1px solid var(--bs-border-color,#d4dce5);border-radius:5px;background:var(--bs-body-bg,#fff);color:inherit;font-weight:800;cursor:pointer}
.df-recent-stats{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:14px;margin-bottom:20px}.df-recent-stat{appearance:none;width:100%;min-height:112px;padding:20px 22px;border:1px solid var(--bs-border-color,#d9e0e8);border-top:4px solid var(--stat-color,var(--bs-border-color,#d9e0e8));border-radius:9px;background:var(--bs-body-bg,#fff);color:inherit;text-align:left;font:inherit;cursor:pointer;transition:box-shadow .15s ease,transform .15s ease,border-color .15s ease}.df-recent-stat:hover{transform:translateY(-1px);box-shadow:0 5px 16px rgba(0,0,0,.08)}.df-recent-stat.is-active{box-shadow:0 0 0 3px color-mix(in srgb,var(--stat-color,#0789c8) 26%,transparent);border-color:var(--stat-color,#0789c8)}.df-recent-stat strong{display:block;font-size:30px;line-height:1;margin-bottom:12px}.df-recent-stat span{display:block;color:var(--bs-secondary-color,#667085);font-weight:750}
.df-filter-panel{display:grid;grid-template-columns:minmax(260px,2.1fr) minmax(190px,1fr) minmax(190px,1fr) 140px auto auto;gap:12px;align-items:end;padding:18px 20px;margin-bottom:18px;border:1px solid var(--bs-border-color,#d9e0e8);border-radius:9px;background:var(--bs-body-bg,#fff)}.df-filter-field{display:flex;flex-direction:column;gap:7px}.df-filter-field label{font-weight:800}.df-filter-field input,.df-filter-field select{width:100%;min-height:44px;padding:0 12px;border:1px solid var(--bs-border-color,#ccd5df);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit}.df-filter-field input::placeholder{font-style:italic;color:var(--bs-secondary-color,#87909b)}
.df-tablewrap{width:100%;overflow:auto;border:1px solid var(--bs-border-color,#dce2e9);border-radius:8px}.df-table{width:100%;border-collapse:collapse;background:var(--bs-body-bg,#fff)}.df-table th,.df-table td{padding:12px 13px;border-bottom:1px solid var(--bs-border-color,#e6eaf0);text-align:left;vertical-align:middle}.df-table th{background:var(--bs-tertiary-bg,#f5f7fa);font-size:11px;text-transform:uppercase;white-space:nowrap}.df-table tbody tr:last-child td{border-bottom:0}.df-table td{max-width:360px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.df-table td:last-child{width:1%}.df-badge{display:inline-flex;align-items:center;padding:4px 9px;border-radius:999px;font-size:12px;font-weight:800}.df-empty{padding:28px;text-align:center;color:var(--bs-secondary-color,#667085)}
@media(max-width:1180px){.df-recent-stats{grid-template-columns:repeat(3,1fr)}.df-filter-panel{grid-template-columns:1fr 1fr 1fr}.df-filter-panel>.df-btn{width:100%}}
@media(max-width:760px){.df-recent-head{align-items:flex-start;flex-direction:column}.df-recent-head h2{font-size:28px}.df-head-actions{width:100%}.df-head-actions>.df-btn,.df-columns-wrap{flex:1}.df-columns-wrap>.df-btn{width:100%}.df-columns-menu{left:0;right:auto}.df-recent-stats{grid-template-columns:1fr 1fr}.df-filter-panel{grid-template-columns:1fr}.df-recent-stat{min-height:auto}.df-filter-panel>.df-btn{width:100%}}
</style>
<div class="df-recent">
  <div class="df-recent-head">
    <div>
      <h2><?php echo Text::_('COM_DECAROFORMS_RECENT'); ?></h2>
      <p><?php echo Text::_('COM_DECAROFORMS_RECENT_DESC'); ?></p>
    </div>
    <div class="df-head-actions">
      <div class="df-columns-wrap">
        <button class="df-btn" type="button" id="df-columns-toggle"><?php echo Text::_('COM_DECAROFORMS_COLUMNS'); ?> ▾</button>
        <div class="df-columns-menu" id="df-columns-menu" hidden>
          <div class="df-columns-title"><?php echo Text::_('COM_DECAROFORMS_TABLE_COLUMNS'); ?></div>
          <label><input type="checkbox" data-column-choice="form" checked> <?php echo Text::_('COM_DECAROFORMS_FORM'); ?></label>
          <label><input type="checkbox" data-column-choice="reference" checked> <?php echo Text::_('COM_DECAROFORMS_REFERENCE'); ?></label>
          <label><input type="checkbox" data-column-choice="email" checked> <?php echo Text::_('COM_DECAROFORMS_EMAIL'); ?></label>
          <label><input type="checkbox" data-column-choice="status" checked> <?php echo Text::_('COM_DECAROFORMS_STATUS'); ?></label>
          <label><input type="checkbox" data-column-choice="date" checked> <?php echo Text::_('COM_DECAROFORMS_DATE'); ?></label>
          <button class="df-columns-reset" type="button" id="df-columns-reset"><?php echo Text::_('COM_DECAROFORMS_RESET_DEFAULTS'); ?></button>
        </div>
      </div>
      <a class="df-btn" href="index.php?option=com_decaroforms&view=forms"><?php echo Text::_('COM_DECAROFORMS_FORMS_LIST'); ?></a>
    </div>
  </div>

  <div class="df-recent-stats">
    <button type="button" class="df-recent-stat is-active" data-recent-status-filter="all" style="--stat-color:#0789c8"><strong><?php echo (int) ($this->stats['total'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_TOTAL_SHORT'); ?></span></button>
    <button type="button" class="df-recent-stat" data-recent-status-filter="new" style="--stat-color:#0d6efd"><strong><?php echo (int) ($this->stats['new'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_NEW'); ?></span></button>
    <button type="button" class="df-recent-stat" data-recent-status-filter="processing" style="--stat-color:#f59e0b"><strong><?php echo (int) ($this->stats['processing'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_PROCESSING'); ?></span></button>
    <button type="button" class="df-recent-stat" data-recent-status-filter="replied" style="--stat-color:#198754"><strong><?php echo (int) ($this->stats['replied'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_REPLIED'); ?></span></button>
    <button type="button" class="df-recent-stat" data-recent-status-filter="closed" style="--stat-color:#6c757d"><strong><?php echo (int) ($this->stats['closed'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_CLOSED'); ?></span></button>
    <button type="button" class="df-recent-stat" data-recent-status-filter="spam" style="--stat-color:#dc3545"><strong><?php echo (int) ($this->stats['spam'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_SPAM'); ?></span></button>
  </div>

  <div class="df-filter-panel">
    <div class="df-filter-field"><label for="df-r-search"><?php echo Text::_('COM_DECAROFORMS_SEARCH'); ?></label><input id="df-r-search" type="search" placeholder="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_SEARCH_ALL'), ENT_QUOTES, 'UTF-8'); ?>"></div>
    <div class="df-filter-field"><label for="df-r-form"><?php echo Text::_('COM_DECAROFORMS_FORM'); ?></label><select id="df-r-form"><option value="all"><?php echo Text::_('COM_DECAROFORMS_ALL_FORMS'); ?></option><?php foreach ($this->forms as $form): ?><option value="<?php echo (int) $form['id']; ?>"><?php echo htmlspecialchars((string) $form['title'], ENT_QUOTES, 'UTF-8'); ?></option><?php endforeach; ?></select></div>
    <div class="df-filter-field"><label for="df-r-status"><?php echo Text::_('COM_DECAROFORMS_STATUS'); ?></label><select id="df-r-status"><option value="all"><?php echo Text::_('COM_DECAROFORMS_ALL_STATUSES'); ?></option><?php foreach ($this->statusOptions as $status): ?><option value="<?php echo htmlspecialchars((string) $status['key'], ENT_QUOTES, 'UTF-8'); ?>"><?php echo htmlspecialchars((string) $status['label'], ENT_QUOTES, 'UTF-8'); ?></option><?php endforeach; ?></select></div>
    <div class="df-filter-field"><label for="df-r-limit"><?php echo Text::_('COM_DECAROFORMS_SHOW'); ?></label><select id="df-r-limit"><option>10</option><option>25</option><option selected>50</option><option>100</option><option>250</option></select></div>
    <button class="df-btn df-btn-primary" type="button" id="df-r-filter"><?php echo Text::_('COM_DECAROFORMS_FILTER'); ?></button>
    <button class="df-btn" type="button" id="df-r-clear"><?php echo Text::_('COM_DECAROFORMS_CLEAR'); ?></button>
  </div>

  <div class="df-tablewrap">
    <table class="df-table" id="df-recent-table">
      <thead><tr><th data-column="form"><?php echo Text::_('COM_DECAROFORMS_FORM'); ?></th><th data-column="reference"><?php echo Text::_('COM_DECAROFORMS_REFERENCE'); ?></th><th data-column="email"><?php echo Text::_('COM_DECAROFORMS_EMAIL'); ?></th><th data-column="status"><?php echo Text::_('COM_DECAROFORMS_STATUS'); ?></th><th data-column="date"><?php echo Text::_('COM_DECAROFORMS_DATE'); ?></th><th></th></tr></thead>
      <tbody id="df-r-body">
      <?php foreach ($this->submissions as $submission): ?>
        <tr data-form="<?php echo (int) ($submission['form_id'] ?? 0); ?>" data-status="<?php echo htmlspecialchars((string) ($submission['status'] ?? ''), ENT_QUOTES, 'UTF-8'); ?>" data-text="<?php echo htmlspecialchars((string) ($submission['_search_text'] ?? ''), ENT_QUOTES, 'UTF-8'); ?>">
          <td data-column="form"><?php echo htmlspecialchars((string) ($submission['form_title'] ?? ''), ENT_QUOTES, 'UTF-8'); ?></td>
          <td data-column="reference"><strong><?php echo htmlspecialchars((string) ($submission['reference'] ?? ''), ENT_QUOTES, 'UTF-8'); ?></strong></td>
          <td data-column="email"><?php echo htmlspecialchars((string) ($submission['email'] ?? ''), ENT_QUOTES, 'UTF-8'); ?></td>
          <td data-column="status"><span class="df-badge" style="<?php echo htmlspecialchars((string) ($submission['_status_badge_style'] ?? ''), ENT_QUOTES, 'UTF-8'); ?>"><?php echo htmlspecialchars((string) ($submission['_status_label'] ?? $submission['status'] ?? ''), ENT_QUOTES, 'UTF-8'); ?></span></td>
          <td data-column="date"><?php echo htmlspecialchars((string) ($submission['created_at'] ?? ''), ENT_QUOTES, 'UTF-8'); ?></td>
          <td><a class="df-btn" href="<?php echo Route::_('index.php?option=com_decaroforms&view=submission&id=' . (int) $submission['id'], false); ?>"><?php echo Text::_('COM_DECAROFORMS_OPEN'); ?></a></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
    <div class="df-empty" id="df-r-empty" hidden><?php echo Text::_('COM_DECAROFORMS_NO_SUBMISSIONS'); ?></div>
  </div>
  <?php echo FormHelper::footer(); ?>
</div>
<script>
(()=>{
 const search=document.getElementById('df-r-search'),form=document.getElementById('df-r-form'),status=document.getElementById('df-r-status'),limit=document.getElementById('df-r-limit'),rows=[...document.querySelectorAll('#df-r-body tr')],empty=document.getElementById('df-r-empty'),statButtons=[...document.querySelectorAll('[data-recent-status-filter]')];
 function updateActiveStat(){statButtons.forEach(button=>button.classList.toggle('is-active',button.dataset.recentStatusFilter===status.value));}
 function apply(){const query=(search.value||'').trim().toLowerCase(),formId=form.value,statusKey=status.value,max=parseInt(limit.value||'50',10);let shown=0;rows.forEach(row=>{const match=(!query||row.dataset.text.includes(query))&&(formId==='all'||row.dataset.form===formId)&&(statusKey==='all'||row.dataset.status===statusKey);const visible=match&&shown<max;row.hidden=!visible;if(visible)shown++;});empty.hidden=shown!==0;updateActiveStat();}
 let liveTimer=null;function scheduleApply(){clearTimeout(liveTimer);liveTimer=setTimeout(apply,180);}document.getElementById('df-r-filter').addEventListener('click',()=>{clearTimeout(liveTimer);apply();});document.getElementById('df-r-clear').addEventListener('click',()=>{clearTimeout(liveTimer);search.value='';form.value='all';status.value='all';limit.value='50';apply();});search.addEventListener('input',scheduleApply);search.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();clearTimeout(liveTimer);apply();}});form.addEventListener('change',apply);status.addEventListener('change',apply);limit.addEventListener('change',apply);statButtons.forEach(button=>button.addEventListener('click',()=>{status.value=button.dataset.recentStatusFilter||'all';apply();}));

 const columnsToggle=document.getElementById('df-columns-toggle'),columnsMenu=document.getElementById('df-columns-menu'),choices=[...document.querySelectorAll('[data-column-choice]')],storageKey='decaroforms.recent.columns.v1',defaults=['form','reference','email','status','date'];
 function loadColumns(){try{const value=JSON.parse(localStorage.getItem(storageKey)||'null');return Array.isArray(value)?value.filter(item=>defaults.includes(item)):defaults.slice();}catch(e){return defaults.slice();}}
 function applyColumns(columns){document.querySelectorAll('[data-column]').forEach(cell=>cell.hidden=!columns.includes(cell.dataset.column));choices.forEach(choice=>choice.checked=columns.includes(choice.dataset.columnChoice));}
 function saveColumns(){const columns=choices.filter(choice=>choice.checked).map(choice=>choice.dataset.columnChoice);localStorage.setItem(storageKey,JSON.stringify(columns));applyColumns(columns);}
 columnsToggle.addEventListener('click',event=>{event.stopPropagation();columnsMenu.hidden=!columnsMenu.hidden;});columnsMenu.addEventListener('click',event=>event.stopPropagation());document.addEventListener('click',()=>columnsMenu.hidden=true);choices.forEach(choice=>choice.addEventListener('change',saveColumns));document.getElementById('df-columns-reset').addEventListener('click',()=>{localStorage.removeItem(storageKey);applyColumns(defaults);});
 applyColumns(loadColumns());apply();
})();
</script>
