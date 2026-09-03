<?php

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\FormHelper;
use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\Router\Route;

$title=$this->form['title']??Text::_('COM_DECAROFORMS_SUBMISSIONS');
$fieldMap=[]; foreach($this->fields as $field){$fieldMap[(string)$field['field_key']]=$field;}
$columnLabel=static function(string $key) use($fieldMap): string { return match($key){'_reference'=>Text::_('COM_DECAROFORMS_REFERENCE'),'_email'=>Text::_('COM_DECAROFORMS_EMAIL'),'_status'=>Text::_('COM_DECAROFORMS_STATUS'),'_created_at'=>Text::_('COM_DECAROFORMS_DATE'),default=>isset($fieldMap[$key])?FormHelper::localizedFieldLabel($key,(string)$fieldMap[$key]['label']):$key};};
$columnValue=static function(array $s,string $key) use($fieldMap): string { return match($key){'_reference'=>(string)($s['reference']??''),'_email'=>(string)($s['email']??''),'_status'=>(string)($s['status']??''),'_created_at'=>(string)($s['created_at']??''),default=>isset($fieldMap[$key])?FormHelper::payloadValueForField($s['payload']??[],$fieldMap[$key]):''};};
?>
<style>
.df-submissions{--df:#e60046;--df-blue:#087fb7;width:100%;max-width:none}.df-sub-head{display:flex;justify-content:space-between;gap:16px;align-items:flex-end;margin:5px 0 20px}.df-sub-head h2{margin:0;font-size:30px}.df-sub-head p{margin:5px 0 0;color:var(--bs-secondary-color,#667085)}.df-actions{display:flex;gap:8px;flex-wrap:wrap;align-items:center}.df-btn{display:inline-flex;align-items:center;justify-content:center;min-height:40px;padding:0 14px;border:1px solid var(--bs-border-color,#d4dbe4);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit!important;text-decoration:none;font-weight:800;cursor:pointer}.df-btn[disabled]{opacity:.48;cursor:not-allowed}.df-btn-select{background:var(--df-blue);border-color:var(--df-blue);color:#fff!important}.df-btn-export{background:var(--df);border-color:var(--df);color:#fff!important}.df-selection-count{font-weight:750;color:var(--bs-secondary-color,#667085);padding:0 4px}
.df-export-wrap{position:relative}.df-export-menu{position:absolute;right:0;top:calc(100% + 6px);z-index:30;min-width:190px;padding:6px;border:1px solid var(--bs-border-color,#d5dce5);border-radius:7px;background:var(--bs-body-bg,#fff);box-shadow:0 10px 30px rgba(0,0,0,.16)}.df-export-menu[hidden]{display:none}.df-export-menu button{display:block;width:100%;padding:10px 11px;border:0;border-radius:5px;background:transparent;color:inherit;text-align:left;font-weight:750;cursor:pointer}.df-export-menu button:hover{background:var(--bs-tertiary-bg,#f2f5f8)}
.df-tools{display:grid;grid-template-columns:minmax(260px,1fr) 240px;gap:10px;margin-bottom:12px}.df-tools input,.df-tools select{min-height:42px;border:1px solid var(--bs-border-color,#d6dde6);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit;padding:0 11px}.df-tablewrap{width:100%;overflow:auto;border:1px solid var(--bs-border-color,#dde3ea);border-radius:8px}.df-table{width:100%;border-collapse:collapse;background:var(--bs-body-bg,#fff)}.df-table th,.df-table td{padding:11px 12px;border-bottom:1px solid var(--bs-border-color,#e5e9ee);text-align:left;vertical-align:middle}.df-table th{background:var(--bs-tertiary-bg,#f5f7fa);font-size:12px;text-transform:uppercase;white-space:nowrap}.df-table tbody tr:last-child td{border-bottom:0}.df-table td{max-width:330px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.df-table td:last-child{width:1%;white-space:nowrap}.df-check-col{width:42px!important;min-width:42px;text-align:center!important}.df-check-col input{width:17px;height:17px;cursor:pointer}.df-badge{display:inline-flex;padding:3px 8px;border-radius:999px;background:var(--bs-tertiary-bg,#eef2f6);font-size:12px;font-weight:800}.df-empty{padding:28px;text-align:center;color:var(--bs-secondary-color,#667085)}
@media(max-width:780px){.df-sub-head{align-items:flex-start;flex-direction:column}.df-tools{grid-template-columns:1fr}.df-actions{width:100%}.df-actions>.df-btn,.df-export-wrap{flex:1}.df-export-wrap>.df-btn{width:100%}.df-selection-count{width:100%}}
</style>
<div class="df-submissions">
  <div class="df-sub-head">
    <div><h2><?php echo htmlspecialchars($title,ENT_QUOTES,'UTF-8'); ?></h2><p><?php echo Text::_('COM_DECAROFORMS_SUBMISSIONS'); ?></p></div>
    <div class="df-actions">
      <button class="df-btn df-btn-select" type="button" id="df-select-visible"><?php echo Text::_('COM_DECAROFORMS_SELECT_ALL'); ?></button>
      <span class="df-selection-count" id="df-selection-count">0 <?php echo Text::_('COM_DECAROFORMS_SELECTED'); ?></span>
      <div class="df-export-wrap">
        <button class="df-btn df-btn-export" type="button" id="df-export-toggle" disabled><?php echo Text::_('COM_DECAROFORMS_EXPORT'); ?> ▾</button>
        <div class="df-export-menu" id="df-export-menu" hidden>
          <button type="button" data-format="csv">CSV</button>
          <button type="button" data-format="xlsx">Excel</button>
          <button type="button" data-format="pdf">PDF</button>
        </div>
      </div>
      <a class="df-btn" href="index.php?option=com_decaroforms&view=forms"><?php echo Text::_('COM_DECAROFORMS_FORMS_LIST'); ?></a>
    </div>
  </div>

  <div class="df-tools">
    <input id="df-s" type="search" placeholder="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_SEARCH_ALL'),ENT_QUOTES,'UTF-8'); ?>">
    <select id="df-f"><option value="all"><?php echo Text::_('COM_DECAROFORMS_ALL_STATUSES'); ?></option><?php foreach($this->statuses as $st): ?><option value="<?php echo htmlspecialchars($st['key'],ENT_QUOTES,'UTF-8'); ?>"><?php echo htmlspecialchars($st['label'],ENT_QUOTES,'UTF-8'); ?></option><?php endforeach; ?></select>
  </div>

  <div class="df-tablewrap">
    <table class="df-table">
      <thead><tr><th class="df-check-col"><input type="checkbox" id="df-select-head" aria-label="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_SELECT_ALL'),ENT_QUOTES,'UTF-8'); ?>"></th><?php foreach($this->columns as $col): ?><th><?php echo htmlspecialchars($columnLabel($col),ENT_QUOTES,'UTF-8'); ?></th><?php endforeach; ?><th></th></tr></thead>
      <tbody>
      <?php foreach($this->submissions as $s):
        $searchParts=[(string)($s['reference']??''),(string)($s['email']??'')];
        foreach(($s['payload']??[]) as $k=>$v){$searchParts[]=(string)$k;$searchParts[]=is_array($v)?implode(' ',array_map('strval',$v)):(string)$v;}
        $searchText=mb_strtolower(implode(' ',$searchParts),'UTF-8');
      ?>
        <tr data-text="<?php echo htmlspecialchars($searchText,ENT_QUOTES,'UTF-8'); ?>" data-status="<?php echo htmlspecialchars((string)$s['status'],ENT_QUOTES,'UTF-8'); ?>">
          <td class="df-check-col"><input class="df-row-select" type="checkbox" value="<?php echo (int)$s['id']; ?>" aria-label="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_SELECT_SUBMISSION'),ENT_QUOTES,'UTF-8'); ?>"></td>
          <?php foreach($this->columns as $col): ?><td><?php if($col==='_status'): ?><span class="df-badge"><?php echo htmlspecialchars(FormHelper::statusLabel((string)$s['status'],$this->statuses),ENT_QUOTES,'UTF-8'); ?></span><?php else: ?><?php echo htmlspecialchars($columnValue($s,$col),ENT_QUOTES,'UTF-8'); ?><?php endif; ?></td><?php endforeach; ?>
          <td><a class="df-btn" href="<?php echo Route::_('index.php?option=com_decaroforms&view=submission&id='.(int)$s['id'],false); ?>"><?php echo Text::_('COM_DECAROFORMS_OPEN'); ?></a></td>
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
 const search=document.getElementById('df-s'),filter=document.getElementById('df-f'),rows=[...document.querySelectorAll('.df-table tbody tr')],head=document.getElementById('df-select-head'),allBtn=document.getElementById('df-select-visible'),exportBtn=document.getElementById('df-export-toggle'),menu=document.getElementById('df-export-menu'),counter=document.getElementById('df-selection-count'),empty=document.getElementById('df-sub-empty');
 const selects=rows.map(r=>r.querySelector('.df-row-select'));
 const labelSelect=<?php echo json_encode(Text::_('COM_DECAROFORMS_SELECT_ALL')); ?>,labelDeselect=<?php echo json_encode(Text::_('COM_DECAROFORMS_DESELECT_ALL')); ?>,labelSelected=<?php echo json_encode(Text::_('COM_DECAROFORMS_SELECTED')); ?>;
 function visibleRows(){return rows.filter(r=>!r.hidden)}
 function updateSelection(){const chosen=selects.filter(x=>x.checked);counter.textContent=chosen.length+' '+labelSelected;exportBtn.disabled=chosen.length===0;if(!chosen.length)menu.hidden=true;const vis=visibleRows(),checkedVis=vis.length>0&&vis.every(r=>r.querySelector('.df-row-select').checked);head.checked=checkedVis;head.indeterminate=!checkedVis&&vis.some(r=>r.querySelector('.df-row-select').checked);allBtn.textContent=checkedVis?labelDeselect:labelSelect;}
 function apply(){const q=(search.value||'').toLowerCase(),st=filter.value;let shown=0;rows.forEach(r=>{const ok=(!q||r.dataset.text.includes(q))&&(st==='all'||r.dataset.status===st);r.hidden=!ok;if(ok)shown++;});empty.hidden=shown!==0;updateSelection();}
 function toggleVisible(force){const vis=visibleRows();const all=vis.length>0&&vis.every(r=>r.querySelector('.df-row-select').checked);vis.forEach(r=>r.querySelector('.df-row-select').checked=typeof force==='boolean'?force:!all);updateSelection();}
 search.addEventListener('input',apply);filter.addEventListener('change',apply);selects.forEach(x=>x.addEventListener('change',updateSelection));head.addEventListener('change',()=>toggleVisible(head.checked));allBtn.addEventListener('click',()=>toggleVisible());
 exportBtn.addEventListener('click',e=>{e.stopPropagation();if(exportBtn.disabled)return;menu.hidden=!menu.hidden;});
 document.addEventListener('click',()=>menu.hidden=true);menu.addEventListener('click',e=>e.stopPropagation());
 menu.querySelectorAll('[data-format]').forEach(b=>b.addEventListener('click',()=>{const ids=selects.filter(x=>x.checked).map(x=>x.value);if(!ids.length){alert(<?php echo json_encode(Text::_('COM_DECAROFORMS_EXPORT_SELECT_REQUIRED')); ?>);return;}const u=new URL(window.location.href);u.search='';u.searchParams.set('option','com_decaroforms');u.searchParams.set('task','submission.export');u.searchParams.set('form_id',<?php echo json_encode((string)(int)($this->form['id']??0)); ?>);u.searchParams.set('export_format',b.dataset.format||'csv');u.searchParams.set('ids',ids.join(','));u.searchParams.set(<?php echo json_encode(Factory::getSession()->getFormToken()); ?>,'1');window.location.href=u.toString();menu.hidden=true;}));
 apply();
})();
</script>
