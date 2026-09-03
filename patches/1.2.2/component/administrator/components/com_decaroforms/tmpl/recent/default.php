<?php

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\FormHelper;
use Joomla\CMS\Language\Text;
use Joomla\CMS\Router\Route;
?>
<style>
.df-recent{--df:#e60046;--df-blue:#0789c8;width:100%;max-width:none}.df-recent-head{display:flex;align-items:flex-end;justify-content:space-between;gap:18px;margin:6px 0 24px}.df-recent-head h2{margin:0;font-size:34px;line-height:1.1}.df-recent-head p{margin:7px 0 0;color:var(--bs-secondary-color,#667085);font-size:17px}.df-btn{display:inline-flex;align-items:center;justify-content:center;min-height:42px;padding:0 16px;border:1px solid var(--bs-border-color,#d3dae3);border-radius:7px;background:var(--bs-body-bg,#fff);color:inherit!important;text-decoration:none;font-weight:800;cursor:pointer}.df-btn-primary{background:var(--df);border-color:var(--df);color:#fff!important}.df-btn:hover{filter:brightness(.98)}
.df-recent-stats{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:14px;margin-bottom:20px}.df-recent-stat{min-height:112px;padding:20px 22px;border:1px solid var(--bs-border-color,#d9e0e8);border-radius:9px;background:var(--bs-body-bg,#fff)}.df-recent-stat strong{display:block;font-size:30px;line-height:1;margin-bottom:12px}.df-recent-stat span{display:block;color:var(--bs-secondary-color,#667085);font-weight:750}
.df-filter-panel{display:grid;grid-template-columns:minmax(260px,2.1fr) minmax(190px,1fr) minmax(190px,1fr) 140px auto auto;gap:12px;align-items:end;padding:18px 20px;margin-bottom:18px;border:1px solid var(--bs-border-color,#d9e0e8);border-radius:9px;background:var(--bs-body-bg,#fff)}.df-filter-field{display:flex;flex-direction:column;gap:7px}.df-filter-field label{font-weight:800}.df-filter-field input,.df-filter-field select{width:100%;min-height:44px;padding:0 12px;border:1px solid var(--bs-border-color,#ccd5df);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit}.df-filter-field input::placeholder{font-style:italic;color:var(--bs-secondary-color,#87909b)}
.df-tablewrap{width:100%;overflow:auto;border:1px solid var(--bs-border-color,#dce2e9);border-radius:8px}.df-table{width:100%;border-collapse:collapse;background:var(--bs-body-bg,#fff)}.df-table th,.df-table td{padding:12px 13px;border-bottom:1px solid var(--bs-border-color,#e6eaf0);text-align:left;vertical-align:middle}.df-table th{background:var(--bs-tertiary-bg,#f5f7fa);font-size:11px;text-transform:uppercase;white-space:nowrap}.df-table tbody tr:last-child td{border-bottom:0}.df-table td{max-width:360px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.df-table td:last-child{width:1%}.df-badge{display:inline-flex;align-items:center;padding:4px 9px;border-radius:999px;background:var(--bs-tertiary-bg,#edf1f5);font-size:12px;font-weight:800}.df-empty{padding:28px;text-align:center;color:var(--bs-secondary-color,#667085)}
@media(max-width:1180px){.df-recent-stats{grid-template-columns:repeat(3,1fr)}.df-filter-panel{grid-template-columns:1fr 1fr 1fr}.df-filter-panel>.df-btn{width:100%}}
@media(max-width:760px){.df-recent-head{align-items:flex-start;flex-direction:column}.df-recent-head h2{font-size:28px}.df-recent-stats{grid-template-columns:1fr 1fr}.df-filter-panel{grid-template-columns:1fr}.df-recent-stat{min-height:auto}.df-filter-panel>.df-btn{width:100%}}
</style>
<div class="df-recent">
  <div class="df-recent-head">
    <div>
      <h2><?php echo Text::_('COM_DECAROFORMS_RECENT'); ?></h2>
      <p><?php echo Text::_('COM_DECAROFORMS_RECENT_DESC'); ?></p>
    </div>
    <a class="df-btn" href="index.php?option=com_decaroforms&view=forms"><?php echo Text::_('COM_DECAROFORMS_FORMS_LIST'); ?></a>
  </div>

  <div class="df-recent-stats">
    <div class="df-recent-stat"><strong><?php echo (int)($this->stats['total']??0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_TOTAL_SHORT'); ?></span></div>
    <div class="df-recent-stat"><strong><?php echo (int)($this->stats['new']??0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_NEW'); ?></span></div>
    <div class="df-recent-stat"><strong><?php echo (int)($this->stats['processing']??0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_PROCESSING'); ?></span></div>
    <div class="df-recent-stat"><strong><?php echo (int)($this->stats['replied']??0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_REPLIED'); ?></span></div>
    <div class="df-recent-stat"><strong><?php echo (int)($this->stats['closed']??0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_CLOSED'); ?></span></div>
    <div class="df-recent-stat"><strong><?php echo (int)($this->stats['spam']??0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_SPAM'); ?></span></div>
  </div>

  <div class="df-filter-panel">
    <div class="df-filter-field"><label for="df-r-search"><?php echo Text::_('COM_DECAROFORMS_SEARCH'); ?></label><input id="df-r-search" type="search" placeholder="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_SEARCH_ALL'),ENT_QUOTES,'UTF-8'); ?>"></div>
    <div class="df-filter-field"><label for="df-r-form"><?php echo Text::_('COM_DECAROFORMS_FORM'); ?></label><select id="df-r-form"><option value="all"><?php echo Text::_('COM_DECAROFORMS_ALL_FORMS'); ?></option><?php foreach($this->forms as $form): ?><option value="<?php echo (int)$form['id']; ?>"><?php echo htmlspecialchars($form['title'],ENT_QUOTES,'UTF-8'); ?></option><?php endforeach; ?></select></div>
    <div class="df-filter-field"><label for="df-r-status"><?php echo Text::_('COM_DECAROFORMS_STATUS'); ?></label><select id="df-r-status"><option value="all"><?php echo Text::_('COM_DECAROFORMS_ALL_STATUSES'); ?></option><?php foreach($this->statusOptions as $status): ?><option value="<?php echo htmlspecialchars($status['key'],ENT_QUOTES,'UTF-8'); ?>"><?php echo htmlspecialchars($status['label'],ENT_QUOTES,'UTF-8'); ?></option><?php endforeach; ?></select></div>
    <div class="df-filter-field"><label for="df-r-limit"><?php echo Text::_('COM_DECAROFORMS_SHOW'); ?></label><select id="df-r-limit"><option>10</option><option>25</option><option selected>50</option><option>100</option><option>250</option></select></div>
    <button class="df-btn df-btn-primary" type="button" id="df-r-filter"><?php echo Text::_('COM_DECAROFORMS_FILTER'); ?></button>
    <button class="df-btn" type="button" id="df-r-clear"><?php echo Text::_('COM_DECAROFORMS_CLEAR'); ?></button>
  </div>

  <div class="df-tablewrap">
    <table class="df-table">
      <thead><tr><th><?php echo Text::_('COM_DECAROFORMS_FORM'); ?></th><th><?php echo Text::_('COM_DECAROFORMS_REFERENCE'); ?></th><th><?php echo Text::_('COM_DECAROFORMS_EMAIL'); ?></th><th><?php echo Text::_('COM_DECAROFORMS_STATUS'); ?></th><th><?php echo Text::_('COM_DECAROFORMS_DATE'); ?></th><th></th></tr></thead>
      <tbody id="df-r-body">
      <?php foreach($this->submissions as $s): ?>
        <tr data-form="<?php echo (int)($s['form_id']??0); ?>" data-status="<?php echo htmlspecialchars((string)($s['status']??''),ENT_QUOTES,'UTF-8'); ?>" data-text="<?php echo htmlspecialchars((string)($s['_search_text']??''),ENT_QUOTES,'UTF-8'); ?>">
          <td><?php echo htmlspecialchars((string)($s['form_title']??''),ENT_QUOTES,'UTF-8'); ?></td>
          <td><strong><?php echo htmlspecialchars((string)($s['reference']??''),ENT_QUOTES,'UTF-8'); ?></strong></td>
          <td><?php echo htmlspecialchars((string)($s['email']??''),ENT_QUOTES,'UTF-8'); ?></td>
          <td><span class="df-badge"><?php echo htmlspecialchars((string)($s['_status_label']??$s['status']??''),ENT_QUOTES,'UTF-8'); ?></span></td>
          <td><?php echo htmlspecialchars((string)($s['created_at']??''),ENT_QUOTES,'UTF-8'); ?></td>
          <td><a class="df-btn" href="<?php echo Route::_('index.php?option=com_decaroforms&view=submission&id='.(int)$s['id'],false); ?>"><?php echo Text::_('COM_DECAROFORMS_OPEN'); ?></a></td>
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
 const search=document.getElementById('df-r-search'),form=document.getElementById('df-r-form'),status=document.getElementById('df-r-status'),limit=document.getElementById('df-r-limit'),rows=[...document.querySelectorAll('#df-r-body tr')],empty=document.getElementById('df-r-empty');
 function apply(){const q=(search.value||'').trim().toLowerCase(),fid=form.value,st=status.value,max=parseInt(limit.value||'50',10);let shown=0;rows.forEach(row=>{const match=(!q||row.dataset.text.includes(q))&&(fid==='all'||row.dataset.form===fid)&&(st==='all'||row.dataset.status===st);const visible=match&&shown<max;row.hidden=!visible;if(visible)shown++;});empty.hidden=shown!==0;}
 document.getElementById('df-r-filter').addEventListener('click',apply);
 document.getElementById('df-r-clear').addEventListener('click',()=>{search.value='';form.value='all';status.value='all';limit.value='50';apply();});
 search.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();apply();}});
 limit.addEventListener('change',apply);
 apply();
})();
</script>
