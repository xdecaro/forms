<?php

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\FormHelper;
use Joomla\CMS\Factory;
use Joomla\CMS\HTML\HTMLHelper;
use Joomla\CMS\Language\Text;
use Joomla\CMS\Router\Route;

$s=$this->submission;
$form=$this->form;
$formId=(int)($s['form_id']??0);
?>
<style>
.df-detail{--df:#e60046;width:100%;max-width:none}.df-detail-back{margin:5px 0 14px}.df-btn{display:inline-flex;align-items:center;justify-content:center;min-height:40px;padding:0 14px;border:1px solid var(--bs-border-color,#d4dce5);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit!important;text-decoration:none;font-weight:800;cursor:pointer}.df-btn-primary{background:var(--df);border-color:var(--df);color:#fff!important}.df-detail-grid{display:grid;grid-template-columns:minmax(0,2.15fr) minmax(330px,1fr);gap:16px;align-items:start}.df-detail-main,.df-manage{border:1px solid var(--bs-border-color,#dbe2e9);border-radius:8px;background:var(--bs-body-bg,#fff)}.df-detail-main{padding:16px}.df-reference{padding:9px 12px;margin-bottom:13px;border-left:4px solid var(--df);background:var(--bs-tertiary-bg,#f5f7fa)}.df-reference small{display:block;color:var(--bs-secondary-color,#667085);font-size:11px}.df-reference strong{display:block;margin-top:2px;font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace}.df-detail-title{margin:0 0 18px;padding-bottom:15px;border-bottom:1px solid var(--bs-border-color,#e2e7ed);font-size:23px}.df-section{padding:0 0 17px;margin:0 0 17px;border-bottom:1px solid var(--bs-border-color,#e2e7ed)}.df-section:last-child{padding-bottom:0;margin-bottom:0;border-bottom:0}.df-section h3{margin:0 0 9px;font-size:13px;text-transform:uppercase;letter-spacing:.03em;color:var(--bs-secondary-color,#667085)}.df-data-grid{display:grid;grid-template-columns:1fr 1fr;gap:0 20px}.df-item{padding:9px 0;border-bottom:1px solid var(--bs-border-color,#e7ebef)}.df-item small{display:block;margin-bottom:3px;color:var(--bs-secondary-color,#667085);font-size:11px}.df-item div{font-weight:700;white-space:pre-wrap;overflow-wrap:anywhere}.df-file{display:flex;align-items:center;justify-content:space-between;gap:14px;padding:12px;border:1px solid var(--bs-border-color,#dce2e8);border-radius:6px}.df-file+.df-file{margin-top:8px}.df-file-info{min-width:0}.df-file-info strong{display:block;overflow-wrap:anywhere}.df-file-info small{display:block;margin-top:3px;color:var(--bs-secondary-color,#667085)}.df-tracking{display:grid;grid-template-columns:1fr 1fr;gap:18px}.df-tracking small{display:block;color:var(--bs-secondary-color,#667085)}.df-tracking strong{display:block;margin-top:3px}
.df-manage{position:sticky;top:12px;padding:16px}.df-manage-head{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:16px}.df-manage h3{margin:0;font-size:19px}.df-field{display:flex;flex-direction:column;gap:6px;margin-bottom:14px}.df-field label{font-weight:800}.df-field select,.df-field textarea{width:100%;border:1px solid var(--bs-border-color,#d2dae4);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit;padding:10px 11px}.df-field textarea{min-height:150px;resize:vertical}.df-note{font-size:12px;color:var(--bs-secondary-color,#667085)}.df-status-preview{display:inline-flex;align-items:center;justify-content:center;min-height:34px;padding:7px 13px;border-radius:999px;font-size:14px;line-height:1;font-weight:850;white-space:nowrap;box-shadow:0 2px 7px rgba(0,0,0,.12)}.df-manage .df-btn-primary{width:100%}
@media(max-width:980px){.df-detail-grid{grid-template-columns:1fr}.df-manage{position:static}.df-data-grid{grid-template-columns:1fr 1fr}}
@media(max-width:640px){.df-data-grid,.df-tracking{grid-template-columns:1fr}.df-detail-main,.df-manage{padding:13px}.df-file{align-items:flex-start;flex-direction:column}.df-file .df-btn{width:100%}.df-manage-head{align-items:flex-start;flex-direction:column}.df-status-preview{font-size:13px}}
</style>
<div class="df-detail">
  <div class="df-detail-back"><a class="df-btn" href="<?php echo Route::_('index.php?option=com_decaroforms&view=submissions&form_id='.$formId,false); ?>">← <?php echo Text::_('COM_DECAROFORMS_BACK_SUBMISSIONS'); ?></a></div>

  <div class="df-detail-grid">
    <main class="df-detail-main">
      <div class="df-reference"><small><?php echo Text::_('COM_DECAROFORMS_REFERENCE'); ?></small><strong><?php echo htmlspecialchars((string)($s['reference']??''),ENT_QUOTES,'UTF-8'); ?></strong></div>
      <h2 class="df-detail-title"><?php echo htmlspecialchars((string)($form['title']??Text::_('COM_DECAROFORMS_SUBMISSION')),ENT_QUOTES,'UTF-8'); ?></h2>

      <section class="df-section">
        <h3><?php echo Text::_('COM_DECAROFORMS_SUBMITTED_DATA'); ?></h3>
        <div class="df-data-grid">
          <?php foreach($this->payload as $k=>$v): $displayKey=FormHelper::localizedPayloadLabel((string)$k); $displayValue=FormHelper::localizedPayloadValue((string)$k,$v); ?>
          <div class="df-item"><small><?php echo htmlspecialchars($displayKey,ENT_QUOTES,'UTF-8'); ?></small><div><?php echo htmlspecialchars($displayValue,ENT_QUOTES,'UTF-8'); ?></div></div>
          <?php endforeach; ?>
        </div>
      </section>

      <?php if($this->files): ?>
      <section class="df-section">
        <h3><?php echo Text::_('COM_DECAROFORMS_ATTACHMENTS'); ?></h3>
        <?php foreach($this->files as $file): ?>
        <div class="df-file">
          <div class="df-file-info"><strong><?php echo htmlspecialchars((string)$file['file_name'],ENT_QUOTES,'UTF-8'); ?></strong><small><?php echo htmlspecialchars(FormHelper::localizedPayloadLabel((string)$file['field_key']),ENT_QUOTES,'UTF-8'); ?> · <?php echo number_format(((int)$file['file_size'])/1024,1); ?> KB</small></div>
          <a class="df-btn df-btn-primary" href="<?php echo Route::_('index.php?option=com_decaroforms&task=file.download&id='.(int)$file['id'].'&'.Factory::getSession()->getFormToken().'=1',false); ?>"><?php echo Text::_('COM_DECAROFORMS_DOWNLOAD'); ?></a>
        </div>
        <?php endforeach; ?>
      </section>
      <?php endif; ?>

      <section class="df-section">
        <h3><?php echo Text::_('COM_DECAROFORMS_SUBMISSION_INFO'); ?></h3>
        <div class="df-tracking">
          <div><small><?php echo Text::_('COM_DECAROFORMS_RECEIVED_AT'); ?></small><strong><?php echo htmlspecialchars((string)($s['created_at']??''),ENT_QUOTES,'UTF-8'); ?></strong></div>
          <div><small><?php echo Text::_('COM_DECAROFORMS_LAST_UPDATE'); ?></small><strong><?php echo htmlspecialchars((string)($s['updated_at']??'—'),ENT_QUOTES,'UTF-8'); ?></strong></div>
        </div>
      </section>
    </main>

    <aside class="df-manage">
      <div class="df-manage-head"><h3><?php echo Text::_('COM_DECAROFORMS_MANAGE_SUBMISSION'); ?></h3><span class="df-status-preview" id="df-status-preview" style="<?php echo htmlspecialchars(FormHelper::statusBadgeStyle((string)($s['status']??'new'),$this->statuses),ENT_QUOTES,'UTF-8'); ?>"><?php echo htmlspecialchars(FormHelper::statusLabel((string)($s['status']??'new'),$this->statuses),ENT_QUOTES,'UTF-8'); ?></span></div>
      <form method="post" action="index.php?option=com_decaroforms&task=submission.save">
        <input type="hidden" name="id" value="<?php echo (int)($s['id']??0); ?>">
        <div class="df-field"><label for="df-status"><?php echo Text::_('COM_DECAROFORMS_STATUS'); ?></label><select id="df-status" name="status"><?php foreach($this->statuses as $st): $k=(string)$st['key']; $n=(string)$st['label']; ?><option value="<?php echo htmlspecialchars($k,ENT_QUOTES,'UTF-8'); ?>" <?php echo ($s['status']??'new')===$k?'selected':''; ?>><?php echo htmlspecialchars($n,ENT_QUOTES,'UTF-8'); ?></option><?php endforeach; ?></select></div>
        <div class="df-field"><label for="df-note"><?php echo Text::_('COM_DECAROFORMS_INTERNAL_NOTE'); ?></label><textarea id="df-note" name="internal_note" placeholder="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_INTERNAL_NOTE_PLACEHOLDER'),ENT_QUOTES,'UTF-8'); ?>"><?php echo htmlspecialchars((string)($s['internal_note']??''),ENT_QUOTES,'UTF-8'); ?></textarea><span class="df-note"><?php echo Text::_('COM_DECAROFORMS_INTERNAL_NOTE_PRIVATE'); ?></span></div>
        <button class="df-btn df-btn-primary" type="submit"><?php echo Text::_('COM_DECAROFORMS_SAVE_CLOSE'); ?></button>
        <?php echo HTMLHelper::_('form.token'); ?>
      </form>
    </aside>
  </div>
  <?php echo FormHelper::footer(); ?>
</div>

<script>
(()=>{const select=document.getElementById('df-status'),badge=document.getElementById('df-status-preview');if(!select||!badge)return;const statuses=<?php echo json_encode(array_map(fn($st)=>['key'=>(string)($st['key']??''),'label'=>(string)($st['label']??''),'style'=>FormHelper::statusBadgeStyle((string)($st['key']??''),$this->statuses)],$this->statuses),JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;select.addEventListener('change',()=>{const st=statuses.find(item=>item.key===select.value);if(!st)return;badge.textContent=st.label;badge.setAttribute('style',st.style);});})();
</script>
