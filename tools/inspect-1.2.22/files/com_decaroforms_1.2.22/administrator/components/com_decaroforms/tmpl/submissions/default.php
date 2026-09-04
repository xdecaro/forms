<?php

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\FormHelper;
use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\Router\Route;
use Joomla\CMS\HTML\HTMLHelper;

$title = $this->form['title'] ?? Text::_('COM_DECAROFORMS_SUBMISSIONS');
$fieldMap = [];
foreach ($this->fields as $field) {
    $fieldMap[(string) $field['field_key']] = $field;
}
$columnLabel = static function (string $key) use ($fieldMap): string {
    return match ($key) {
        '_reference' => Text::_('COM_DECAROFORMS_REFERENCE'),
        '_email' => Text::_('COM_DECAROFORMS_EMAIL'),
        '_status' => Text::_('COM_DECAROFORMS_STATUS'),
        '_created_at' => Text::_('COM_DECAROFORMS_DATE'),
        default => isset($fieldMap[$key]) ? FormHelper::localizedFieldLabel($key, (string) $fieldMap[$key]['label']) : $key,
    };
};
$columnValue = static function (array $submission, string $key) use ($fieldMap): string {
    return match ($key) {
        '_reference' => (string) ($submission['reference'] ?? ''),
        '_email' => (string) ($submission['email'] ?? ''),
        '_status' => (string) ($submission['status'] ?? ''),
        '_created_at' => (string) ($submission['created_at'] ?? ''),
        default => isset($fieldMap[$key]) ? FormHelper::payloadValueForField($submission['payload'] ?? [], $fieldMap[$key]) : '',
    };
};
?>
<style>
.df-submissions{--df:#e60046;--df-blue:#087fb7;width:100%;max-width:none}.df-sub-head{display:flex;justify-content:space-between;gap:16px;align-items:flex-end;margin:0 0 18px}.df-sub-head h2{margin:0;font-size:30px}.df-sub-head p{margin:5px 0 0;color:var(--bs-secondary-color,#667085)}.df-actions{display:flex;gap:8px;flex-wrap:wrap;align-items:center}.df-actions form{margin:0}.df-btn{display:inline-flex;align-items:center;justify-content:center;min-height:40px;padding:0 14px;border:1px solid var(--bs-border-color,#d4dbe4);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit!important;text-decoration:none;font-weight:800;cursor:pointer}.df-btn[disabled]{opacity:.48;cursor:not-allowed}.df-btn-select{background:var(--df-blue);border-color:var(--df-blue);color:#fff!important}.df-btn-export,.df-btn-primary{background:var(--df);border-color:var(--df);color:#fff!important}.df-selection-count{font-weight:750;color:var(--bs-secondary-color,#667085);padding:0 4px}
.df-sub-stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(155px,1fr));gap:12px;margin-bottom:18px}.df-sub-stat{appearance:none;width:100%;min-height:104px;padding:18px 19px;border:1px solid var(--bs-border-color,#d9e0e8);border-top:4px solid var(--stat-color,var(--bs-border-color,#d9e0e8));border-radius:8px;background:var(--bs-body-bg,#fff);color:inherit;text-align:left;font:inherit;cursor:pointer;transition:box-shadow .15s ease,transform .15s ease,border-color .15s ease}.df-sub-stat:hover{transform:translateY(-1px);box-shadow:0 5px 16px rgba(0,0,0,.08)}.df-sub-stat.is-active{box-shadow:0 0 0 3px color-mix(in srgb,var(--stat-color,#087fb7) 26%,transparent);border-color:var(--stat-color,#087fb7)}.df-sub-stat strong{display:block;font-size:29px;line-height:1;margin-bottom:11px}.df-sub-stat span{display:block;color:var(--bs-secondary-color,#667085);font-weight:800}
.df-filter-panel{display:grid;grid-template-columns:minmax(260px,2fr) minmax(190px,1fr) 140px auto auto;gap:12px;align-items:end;padding:17px 18px;margin-bottom:18px;border:1px solid var(--bs-border-color,#d9e0e8);border-radius:8px;background:var(--bs-body-bg,#fff)}.df-filter-field{display:flex;flex-direction:column;gap:7px}.df-filter-field label{font-weight:800}.df-filter-field input,.df-filter-field select{width:100%;min-height:42px;padding:0 11px;border:1px solid var(--bs-border-color,#ccd5df);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit}.df-filter-field input::placeholder{font-style:italic;color:var(--bs-secondary-color,#87909b)}
.df-export-wrap{position:relative}.df-export-menu{position:absolute;right:0;top:calc(100% + 6px);z-index:30;min-width:190px;padding:6px;border:1px solid var(--bs-border-color,#d5dce5);border-radius:7px;background:var(--bs-body-bg,#fff);box-shadow:0 10px 30px rgba(0,0,0,.16)}.df-export-menu[hidden]{display:none}.df-export-menu button{display:flex;width:100%;align-items:center;gap:10px;padding:10px 11px;border:0;border-radius:5px;background:transparent;color:inherit;text-align:left;font-weight:750;cursor:pointer}.df-export-menu button:hover{background:var(--bs-tertiary-bg,#f2f5f8)}.df-export-icon{width:17px;height:17px;display:inline-flex;align-items:center;justify-content:center;flex:0 0 17px}.df-export-icon svg{display:block;width:17px;height:17px;fill:none;stroke:currentColor;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}.df-export-format{display:inline-flex;align-items:center;gap:8px}
.df-tablewrap{width:100%;overflow:auto;border:1px solid var(--bs-border-color,#dde3ea);border-radius:8px}.df-table{width:100%;border-collapse:collapse;background:var(--bs-body-bg,#fff)}.df-table th,.df-table td{padding:11px 12px;border-bottom:1px solid var(--bs-border-color,#e5e9ee);text-align:left;vertical-align:middle}.df-table th{background:var(--bs-tertiary-bg,#f5f7fa);font-size:12px;text-transform:uppercase;white-space:nowrap}.df-table tbody tr:last-child td{border-bottom:0}.df-table td{max-width:330px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.df-table td:last-child{width:1%;white-space:nowrap}.df-check-col{width:42px!important;min-width:42px;text-align:center!important}.df-check-col input{width:17px;height:17px;cursor:pointer}.df-badge{display:inline-flex;align-items:center;padding:4px 9px;border-radius:999px;font-size:12px;font-weight:800}.df-empty{padding:28px;text-align:center;color:var(--bs-secondary-color,#667085)}
@media(max-width:1050px){.df-filter-panel{grid-template-columns:1fr 1fr 1fr}.df-filter-panel>.df-btn{width:100%}}
@media(max-width:780px){.df-sub-head{align-items:flex-start;flex-direction:column}.df-filter-panel{grid-template-columns:1fr}.df-actions{width:100%}.df-actions>.df-btn,.df-export-wrap{flex:1}.df-export-wrap>.df-btn{width:100%}.df-selection-count{width:100%}.df-sub-stats{grid-template-columns:1fr 1fr}}
</style>
<div class="df-submissions">
  <div class="df-sub-head">
    <div><h2><?php echo htmlspecialchars($title, ENT_QUOTES, 'UTF-8'); ?></h2><p><?php echo Text::_('COM_DECAROFORMS_SUBMISSIONS'); ?></p></div>
    <div class="df-actions">
      <button class="df-btn df-btn-select" type="button" id="df-select-visible"><?php echo Text::_('COM_DECAROFORMS_SELECT_ALL'); ?></button>
      <span class="df-selection-count" id="df-selection-count">0 <?php echo Text::_('COM_DECAROFORMS_SELECTED'); ?></span>
      <div class="df-export-wrap">
        <button class="df-btn df-btn-export" type="button" id="df-export-toggle" disabled><span class="df-export-icon" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M12 3v12"></path><path d="m7 10 5 5 5-5"></path><path d="M5 21h14"></path></svg></span><?php echo Text::_('COM_DECAROFORMS_EXPORT'); ?> ▾</button>
        <div class="df-export-menu" id="df-export-menu" hidden>
          <button type="button" data-format="csv"><span class="df-export-icon" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M6 3h9l3 3v15H6z"></path><path d="M15 3v4h4"></path><path d="M9 12h6"></path><path d="M9 16h6"></path></svg></span><span>CSV</span></button>
          <button type="button" data-format="xlsx"><span class="df-export-icon" aria-hidden="true"><svg viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="1"></rect><path d="M4 10h16M10 4v16M15 4v16"></path></svg></span><span>Excel</span></button>
          <button type="button" data-format="pdf"><span class="df-export-icon" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M6 3h9l3 3v15H6z"></path><path d="M15 3v4h4"></path><path d="M9 13h6M9 17h4"></path></svg></span><span>PDF</span></button>
        </div>
      </div>
      <form method="post" action="index.php?option=com_decaroforms&task=builder.duplicate"><input type="hidden" name="id" value="<?php echo (int) ($this->form['id'] ?? 0); ?>"><button class="df-btn" type="submit"><?php echo Text::_('COM_DECAROFORMS_DUPLICATE_FORM'); ?></button><?php echo HTMLHelper::_('form.token'); ?></form>
      <a class="df-btn" href="index.php?option=com_decaroforms&view=forms">← <?php echo Text::_('COM_DECAROFORMS_FORMS_LIST'); ?></a>
    </div>
  </div>

  <div class="df-sub-stats">
    <button type="button" class="df-sub-stat is-active" data-status-filter="all" style="--stat-color:#087fb7"><strong><?php echo (int) ($this->stats['total'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_TOTAL_SHORT'); ?></span></button>
    <?php foreach (($this->stats['statuses'] ?? []) as $stat): ?>
      <button type="button" class="df-sub-stat" data-status-filter="<?php echo htmlspecialchars((string) ($stat['key'] ?? ''), ENT_QUOTES, 'UTF-8'); ?>" style="--stat-color:<?php echo htmlspecialchars((string) $stat['color'], ENT_QUOTES, 'UTF-8'); ?>"><strong><?php echo (int) $stat['count']; ?></strong><span><?php echo htmlspecialchars((string) $stat['label'], ENT_QUOTES, 'UTF-8'); ?></span></button>
    <?php endforeach; ?>
  </div>

  <div class="df-filter-panel">
    <div class="df-filter-field"><label for="df-s"><?php echo Text::_('COM_DECAROFORMS_SEARCH'); ?></label><input id="df-s" type="search" placeholder="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_SEARCH_ALL'), ENT_QUOTES, 'UTF-8'); ?>"></div>
    <div class="df-filter-field"><label for="df-f"><?php echo Text::_('COM_DECAROFORMS_STATUS'); ?></label><select id="df-f"><option value="all"><?php echo Text::_('COM_DECAROFORMS_ALL_STATUSES'); ?></option><?php foreach ($this->statuses as $status): ?><option value="<?php echo htmlspecialchars((string) $status['key'], ENT_QUOTES, 'UTF-8'); ?>"><?php echo htmlspecialchars((string) $status['label'], ENT_QUOTES, 'UTF-8'); ?></option><?php endforeach; ?></select></div>
    <div class="df-filter-field"><label for="df-limit"><?php echo Text::_('COM_DECAROFORMS_SHOW'); ?></label><select id="df-limit"><option>10</option><option>25</option><option selected>50</option><option>100</option><option>250</option></select></div>
    <button class="df-btn df-btn-primary" type="button" id="df-filter-btn"><?php echo Text::_('COM_DECAROFORMS_FILTER'); ?></button>
    <button class="df-btn" type="button" id="df-clear-btn"><?php echo Text::_('COM_DECAROFORMS_CLEAR'); ?></button>
  </div>

  <div class="df-tablewrap">
    <table class="df-table">
      <thead><tr><th class="df-check-col"><input type="checkbox" id="df-select-head" aria-label="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_SELECT_ALL'), ENT_QUOTES, 'UTF-8'); ?>"></th><?php foreach ($this->columns as $column): ?><th><?php echo htmlspecialchars($columnLabel($column), ENT_QUOTES, 'UTF-8'); ?></th><?php endforeach; ?><th></th></tr></thead>
      <tbody>
      <?php foreach ($this->submissions as $submission):
          $searchParts = [(string) ($submission['reference'] ?? ''), (string) ($submission['email'] ?? '')];
          foreach (($submission['payload'] ?? []) as $key => $value) {
              $searchParts[] = (string) $key;
              $searchParts[] = is_array($value) ? implode(' ', array_map('strval', $value)) : (string) $value;
          }
          $searchText = mb_strtolower(implode(' ', $searchParts), 'UTF-8');
          $statusKey = (string) ($submission['status'] ?? '');
      ?>
        <tr data-text="<?php echo htmlspecialchars($searchText, ENT_QUOTES, 'UTF-8'); ?>" data-status="<?php echo htmlspecialchars($statusKey, ENT_QUOTES, 'UTF-8'); ?>">
          <td class="df-check-col"><input class="df-row-select" type="checkbox" value="<?php echo (int) $submission['id']; ?>" aria-label="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_SELECT_SUBMISSION'), ENT_QUOTES, 'UTF-8'); ?>"></td>
          <?php foreach ($this->columns as $column): ?><td><?php if ($column === '_status'): ?><span class="df-badge" style="<?php echo htmlspecialchars(FormHelper::statusBadgeStyle($statusKey, $this->statuses), ENT_QUOTES, 'UTF-8'); ?>"><?php echo htmlspecialchars(FormHelper::statusLabel($statusKey, $this->statuses), ENT_QUOTES, 'UTF-8'); ?></span><?php else: ?><?php echo htmlspecialchars($columnValue($submission, $column), ENT_QUOTES, 'UTF-8'); ?><?php endif; ?></td><?php endforeach; ?>
          <td><a class="df-btn" href="<?php echo Route::_('index.php?option=com_decaroforms&view=submission&id=' . (int) $submission['id'], false); ?>"><?php echo Text::_('COM_DECAROFORMS_OPEN'); ?></a></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
    <div class="df-empty" id="df-sub-empty" hidden><?php echo Text::_('COM_DECAROFORMS_NO_SUBMISSIONS'); ?></div>
  </div>
  <?php echo FormHelper::footer(); ?>
</div>
<script>
(()=>{
 const search=document.getElementById('df-s'),filter=document.getElementById('df-f'),limit=document.getElementById('df-limit'),rows=[...document.querySelectorAll('.df-table tbody tr')],head=document.getElementById('df-select-head'),allBtn=document.getElementById('df-select-visible'),exportBtn=document.getElementById('df-export-toggle'),menu=document.getElementById('df-export-menu'),counter=document.getElementById('df-selection-count'),empty=document.getElementById('df-sub-empty'),statButtons=[...document.querySelectorAll('[data-status-filter]')];
 const selects=rows.map(row=>row.querySelector('.df-row-select'));
 const labelSelect=<?php echo json_encode(Text::_('COM_DECAROFORMS_SELECT_ALL')); ?>,labelDeselect=<?php echo json_encode(Text::_('COM_DECAROFORMS_DESELECT_ALL')); ?>,labelSelected=<?php echo json_encode(Text::_('COM_DECAROFORMS_SELECTED')); ?>;
 function visibleRows(){return rows.filter(row=>!row.hidden)}
 function updateSelection(){const chosen=selects.filter(input=>input.checked);counter.textContent=chosen.length+' '+labelSelected;exportBtn.disabled=chosen.length===0;if(!chosen.length)menu.hidden=true;const visible=visibleRows(),checkedVisible=visible.length>0&&visible.every(row=>row.querySelector('.df-row-select').checked);head.checked=checkedVisible;head.indeterminate=!checkedVisible&&visible.some(row=>row.querySelector('.df-row-select').checked);allBtn.textContent=checkedVisible?labelDeselect:labelSelect;}
 function updateActiveStat(){statButtons.forEach(button=>button.classList.toggle('is-active',button.dataset.statusFilter===filter.value));}
 function apply(){const query=(search.value||'').trim().toLowerCase(),status=filter.value,max=parseInt(limit.value||'50',10);let shown=0;rows.forEach(row=>{const match=(!query||row.dataset.text.includes(query))&&(status==='all'||row.dataset.status===status);const visible=match&&shown<max;row.hidden=!visible;if(visible)shown++;});empty.hidden=shown!==0;updateActiveStat();updateSelection();}
 function toggleVisible(force){const visible=visibleRows(),all=visible.length>0&&visible.every(row=>row.querySelector('.df-row-select').checked);visible.forEach(row=>row.querySelector('.df-row-select').checked=typeof force==='boolean'?force:!all);updateSelection();}
 let liveTimer=null;function scheduleApply(){clearTimeout(liveTimer);liveTimer=setTimeout(apply,180);}
document.getElementById('df-filter-btn').addEventListener('click',()=>{clearTimeout(liveTimer);apply();});
document.getElementById('df-clear-btn').addEventListener('click',()=>{clearTimeout(liveTimer);search.value='';filter.value='all';limit.value='50';apply();});
statButtons.forEach(button=>button.addEventListener('click',()=>{filter.value=button.dataset.statusFilter||'all';apply();}));
search.addEventListener('input',scheduleApply);search.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();clearTimeout(liveTimer);apply();}});filter.addEventListener('change',apply);limit.addEventListener('change',apply);
 selects.forEach(input=>input.addEventListener('change',updateSelection));head.addEventListener('change',()=>toggleVisible(head.checked));allBtn.addEventListener('click',()=>toggleVisible());
 exportBtn.addEventListener('click',event=>{event.stopPropagation();if(exportBtn.disabled)return;menu.hidden=!menu.hidden;});document.addEventListener('click',()=>menu.hidden=true);menu.addEventListener('click',event=>event.stopPropagation());
 menu.querySelectorAll('[data-format]').forEach(button=>button.addEventListener('click',()=>{const ids=selects.filter(input=>input.checked).map(input=>input.value);if(!ids.length){alert(<?php echo json_encode(Text::_('COM_DECAROFORMS_EXPORT_SELECT_REQUIRED')); ?>);return;}const url=new URL(window.location.href);url.search='';url.searchParams.set('option','com_decaroforms');url.searchParams.set('task','submission.export');url.searchParams.set('form_id',<?php echo json_encode((string) (int) ($this->form['id'] ?? 0)); ?>);url.searchParams.set('export_format',button.dataset.format||'csv');url.searchParams.set('ids',ids.join(','));url.searchParams.set(<?php echo json_encode(Factory::getSession()->getFormToken()); ?>,'1');window.location.href=url.toString();menu.hidden=true;}));
 apply();
})();
</script>
