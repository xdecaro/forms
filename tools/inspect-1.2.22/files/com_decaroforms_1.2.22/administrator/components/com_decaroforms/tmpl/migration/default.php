<?php

defined('_JEXEC') or die;
use DeCaro\Component\Forms\Administrator\Helper\FormHelper;
use Joomla\CMS\HTML\HTMLHelper;
use Joomla\CMS\Language\Text;
$s=$this->state;
?>
<style>
.df-mig{--df:#e60046;max-width:none;}.df-head{display:flex;justify-content:space-between;align-items:flex-end;gap:14px;margin:4px 0 18px}.df-head h2{margin:0;font-size:27px}.df-head p{margin:5px 0 0;color:var(--bs-secondary-color,#667085)}.df-actions{display:flex;gap:8px;flex-wrap:wrap}.df-btn{display:inline-flex;align-items:center;justify-content:center;min-height:40px;padding:0 14px;border:1px solid var(--bs-border-color,#d9dee5);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit!important;text-decoration:none;font-weight:750}.df-primary{background:var(--df);border-color:var(--df);color:#fff!important}.df-primary:disabled{opacity:.55}.df-card{margin-bottom:14px;border:1px solid var(--bs-border-color,#dfe3e7);border-radius:8px;background:var(--bs-body-bg,#fff);overflow:hidden}.df-card h3{margin:0;padding:14px 16px;background:var(--bs-tertiary-bg,#f7f8fa);border-bottom:1px solid var(--bs-border-color,#dfe3e7);font-size:18px}.df-body{padding:16px}.df-status{display:flex;gap:10px;align-items:center;flex-wrap:wrap}.df-badge{display:inline-flex;padding:5px 10px;border-radius:999px;font-size:12px;font-weight:800}.df-ok{background:#e8f7ee;color:#176b3a}.df-bad{background:#fdebec;color:#9f2430}.df-progress{height:10px;background:#edf0f3;border-radius:999px;overflow:hidden;margin:11px 0 3px}.df-progress span{display:block;height:100%;background:var(--df)}.df-table{width:100%;border-collapse:collapse}.df-table th,.df-table td{padding:11px 10px;border-bottom:1px solid var(--bs-border-color,#e7eaee);text-align:left;vertical-align:middle}.df-table th{font-size:11px;text-transform:uppercase;color:var(--bs-secondary-color,#667085)}.df-num{text-align:right!important;font-variant-numeric:tabular-nums}.df-note{padding:13px 14px;border-left:4px solid var(--df);background:var(--bs-tertiary-bg,#f7f8fa);border-radius:4px}.df-warning{border-left-color:#d58c00}.df-checks{display:flex;flex-direction:column;gap:7px;margin:12px 0}.df-check{display:flex;gap:8px;align-items:flex-start}.df-check input{margin-top:4px}.df-small{font-size:12px;color:var(--bs-secondary-color,#667085);margin-top:7px}@media(max-width:760px){.df-head{flex-direction:column;align-items:flex-start}.df-table{display:block;overflow:auto}.df-actions{width:100%}.df-btn{flex:1}}
</style>
<div class="df-mig">
  <div class="df-head"><div><h2><?php echo Text::_('COM_DECAROFORMS_MIG_TITLE'); ?></h2><p><?php echo Text::sprintf('COM_DECAROFORMS_MIG_DESC',FormHelper::VERSION); ?></p></div><div class="df-actions"><a class="df-btn" href="<?php echo $this->formsUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_MENU_FORMS'); ?></a><a class="df-btn" href="<?php echo $this->informationUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_INFORMATION'); ?></a></div></div>

  <section class="df-card"><h3><?php echo Text::_('COM_DECAROFORMS_SOURCE_DETECTION'); ?></h3><div class="df-body"><div class="df-status">
    <?php if($s['installed']): ?><span class="df-badge df-ok"><?php echo Text::_('COM_DECAROFORMS_LSFS_DETECTED'); ?></span><strong><?php echo Text::_('COM_DECAROFORMS_VERSION'); ?> <?php echo htmlspecialchars($s['version']?:Text::_('COM_DECAROFORMS_UNKNOWN'),ENT_QUOTES,'UTF-8'); ?></strong><?php else: ?><span class="df-badge df-bad"><?php echo Text::_('COM_DECAROFORMS_LSFS_NOT_DETECTED'); ?></span><?php endif; ?>
    <?php if($s['complete']): ?><span class="df-badge df-ok"><?php echo Text::_('COM_DECAROFORMS_MIG_COMPLETE'); ?></span><?php endif; ?>
  </div><?php $pct=$s['source_total']>0?(int)round(($s['migrated_total']/$s['source_total'])*100):0; ?><div class="df-progress"><span style="width:<?php echo max(0,min(100,$pct)); ?>%"></span></div><div class="df-small"><?php echo Text::sprintf('COM_DECAROFORMS_MIG_PROGRESS',(int)$s['migrated_total'],(int)$s['source_total'],$pct); ?></div></div></section>

  <section class="df-card"><h3><?php echo Text::_('COM_DECAROFORMS_MIG_PREVIEW'); ?></h3><div class="df-body" style="padding:0"><table class="df-table"><thead><tr><th><?php echo Text::_('COM_DECAROFORMS_LEGACY_FORM'); ?></th><th><?php echo Text::_('COM_DECAROFORMS_SOURCE_TABLE'); ?></th><th class="df-num">Records</th><th class="df-num">Migrated</th><th><?php echo Text::_('COM_DECAROFORMS_NEW_SHORTCODE'); ?></th></tr></thead><tbody>
  <?php foreach($s['items'] as $i): ?><tr><td><strong><?php echo htmlspecialchars($i['title'],ENT_QUOTES,'UTF-8'); ?></strong><br><?php echo $i['exists']?'<span class="df-badge df-ok">'.Text::_('COM_DECAROFORMS_AVAILABLE').'</span>':'<span class="df-badge df-bad">'.Text::_('COM_DECAROFORMS_MISSING').'</span>'; ?></td><td><code><?php echo htmlspecialchars($i['table'],ENT_QUOTES,'UTF-8'); ?></code></td><td class="df-num"><?php echo (int)$i['source_count']; ?></td><td class="df-num"><?php echo (int)$i['migrated_count']; ?></td><td><?php if((int)$i['form_id']>0): ?><code>{form id="<?php echo (int)$i['form_id']; ?>"}</code><?php else: ?><?php echo Text::_('COM_DECAROFORMS_CREATED_DURING_MIGRATION'); ?><?php endif; ?></td></tr><?php endforeach; ?>
  </tbody></table></div></section>

  <section class="df-card"><h3><?php echo Text::_('COM_DECAROFORMS_IMPORT_MIGRATE'); ?></h3><div class="df-body"><div class="df-checks">
    <label class="df-check"><input type="checkbox" checked disabled><span><?php echo Text::_('COM_DECAROFORMS_MIG_CHECK_1'); ?></span></label>
    <label class="df-check"><input type="checkbox" checked disabled><span><?php echo Text::_('COM_DECAROFORMS_MIG_CHECK_2'); ?></span></label>
    <label class="df-check"><input type="checkbox" checked disabled><span><?php echo Text::_('COM_DECAROFORMS_MIG_CHECK_3'); ?></span></label>
    <label class="df-check"><input type="checkbox" checked disabled><span><?php echo Text::_('COM_DECAROFORMS_MIG_CHECK_4'); ?></span></label>
    <label class="df-check"><input type="checkbox" checked disabled><span><?php echo Text::_('COM_DECAROFORMS_MIG_CHECK_5'); ?></span></label>
  </div>
  <p class="df-note"><strong><?php echo Text::_('COM_DECAROFORMS_SAFE'); ?>:</strong> <?php echo Text::_('COM_DECAROFORMS_MIG_SAFE_TEXT'); ?></p>
  <p class="df-note df-warning"><strong><?php echo Text::_('COM_DECAROFORMS_IMPORTANT'); ?>:</strong> <?php echo Text::_('COM_DECAROFORMS_MIG_IMPORTANT_TEXT'); ?></p>
  <form method="post" action="<?php echo $this->runUrl; ?>" onsubmit="return confirm(<?php echo htmlspecialchars(json_encode(Text::_('COM_DECAROFORMS_MIG_CONFIRM')),ENT_QUOTES,'UTF-8'); ?>);"><button class="df-btn df-primary" type="submit" <?php echo !$s['installed']?'disabled':''; ?>><?php echo $s['complete']?Text::_('COM_DECAROFORMS_IMPORT_NEW'):Text::_('COM_DECAROFORMS_IMPORT_MIGRATE'); ?></button><?php echo HTMLHelper::_('form.token'); ?></form>
  </div></section>
  <?php echo FormHelper::footer(); ?>
</div>
