#!/usr/bin/env bash
set -euo pipefail

VERSION="1.2.8"
PREV="1.2.7"
ROOT=/tmp/forms128
rm -rf "$ROOT"
mkdir -p "$ROOT/outer" "$ROOT/component" "$ROOT/plugin"

unzip -q "releases/${PREV}/pkg_decaroforms_${PREV}.zip" -d "$ROOT/outer"
unzip -q "$ROOT/outer/com_decaroforms_${PREV}.zip" -d "$ROOT/component"
unzip -q "$ROOT/outer/plg_system_decaroforms_${PREV}.zip" -d "$ROOT/plugin"

cat > "$ROOT/component/administrator/components/com_decaroforms/tmpl/forms/default.php" <<'PHP'
<?php

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\FormHelper;
use Joomla\CMS\Router\Route;
use Joomla\CMS\Language\Text;
use Joomla\CMS\HTML\HTMLHelper;
?>
<style>
.df-wrap{--df:#e60046;--df-dark:#b40038;max-width:none;color:var(--bs-body-color,#1f2937)}
.df-head{display:flex;justify-content:space-between;gap:16px;align-items:flex-end;margin:4px 0 18px}.df-head h2{margin:0;font-size:27px}.df-head p{margin:5px 0 0;color:var(--bs-secondary-color,#667085)}
.df-actions{display:flex;gap:9px;flex-wrap:wrap;align-items:center}.df-actions form,.df-card-actions form{margin:0}.df-btn{display:inline-flex;align-items:center;justify-content:center;min-height:39px;padding:0 14px;border:1px solid var(--bs-border-color,#d9dee5);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit!important;text-decoration:none;font-weight:700;cursor:pointer}.df-btn-primary{background:var(--df);border-color:var(--df);color:#fff!important}.df-btn-primary:hover{background:var(--df-dark)}
.df-actions-dialog{width:min(460px,calc(100vw - 28px));padding:0;border:1px solid var(--bs-border-color,#d9dee5);border-radius:10px;background:var(--bs-body-bg,#fff);color:inherit;box-shadow:0 24px 70px rgba(0,0,0,.28)}.df-actions-dialog::backdrop{background:rgba(0,0,0,.5)}.df-dialog-head{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:16px 18px;border-bottom:1px solid var(--bs-border-color,#dfe3e7)}.df-dialog-head h3{margin:0;font-size:20px}.df-dialog-close{width:36px;height:36px;padding:0;border:1px solid var(--bs-border-color,#d9dee5);border-radius:6px;background:transparent;color:inherit;font-size:23px;cursor:pointer}.df-dialog-links{display:grid;grid-template-columns:1fr 1fr;gap:10px;padding:18px}.df-dialog-links .df-btn{min-height:48px;justify-content:flex-start}
.df-tools{display:grid;grid-template-columns:minmax(260px,2fr) minmax(155px,1fr) minmax(185px,1fr) 120px auto;gap:10px;align-items:end;padding:15px 16px;margin-bottom:14px;border:1px solid var(--bs-border-color,#dfe3e7);border-radius:8px;background:var(--bs-body-bg,#fff)}.df-tool{display:flex;flex-direction:column;gap:6px}.df-tool label{font-weight:800}.df-tool input,.df-tool select{width:100%;min-height:42px;border:1px solid var(--bs-border-color,#d9dee5);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit;padding:0 12px}.df-tool input::placeholder{font-style:italic;color:var(--bs-secondary-color,#87909b)}
.df-list{display:flex;flex-direction:column;gap:12px}.df-card{border:1px solid var(--bs-border-color,#dfe3e7);border-radius:8px;background:var(--bs-body-bg,#fff);box-shadow:0 2px 8px rgba(0,0,0,.04);overflow:hidden}.df-card-main{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:14px;align-items:start;padding:17px 18px}.df-card h3{margin:0 0 4px;font-size:19px;overflow-wrap:anywhere}.df-card p{margin:0;color:var(--bs-secondary-color,#667085);overflow-wrap:anywhere}.df-badge{display:inline-flex;align-items:center;justify-content:center;padding:4px 9px;border-radius:999px;font-size:12px;font-weight:800;white-space:nowrap;align-self:start}.df-on{background:#e8f7ee;color:#176b3a}.df-off{background:#fdebec;color:#9f2430}
.df-card-meta{display:grid;grid-template-columns:minmax(0,1fr) auto auto;gap:18px;align-items:center;padding:11px 18px;border-top:1px solid var(--bs-border-color,#dfe3e7);background:var(--bs-tertiary-bg,#f6f7f9)}.df-code small,.df-count small{display:block;color:var(--bs-secondary-color,#667085);font-size:11px;font-weight:800;text-transform:uppercase}.df-code code{font-weight:700}.df-count{text-align:right}.df-count strong{display:block;font-size:21px}.df-card-actions{display:flex;gap:8px;justify-content:flex-end;align-items:center}
.df-empty{padding:38px 20px;text-align:center;border:1px dashed var(--bs-border-color,#d9dee5);border-radius:8px}.df-admin-footer{margin:28px 0 10px;padding-top:16px;border-top:1px solid var(--bs-border-color,#d9dee5);text-align:center;color:var(--bs-secondary-color,#667085);font-size:12px}
@media(max-width:1050px){.df-tools{grid-template-columns:1fr 1fr 1fr}.df-tools>.df-btn{width:100%}}
@media(max-width:760px){.df-head{align-items:flex-start}.df-head>div:first-child{min-width:0}.df-actions{margin-left:auto;flex-wrap:nowrap}.df-actions .df-btn{padding-inline:11px}.df-tools{grid-template-columns:1fr}.df-dialog-links{grid-template-columns:1fr}.df-card-meta{grid-template-columns:1fr}.df-count{text-align:left}.df-card-actions{display:grid;grid-template-columns:1fr 1fr;gap:8px}.df-card-actions>*{width:100%}.df-card-actions form .df-btn,.df-card-actions>a{width:100%}.df-card-actions>*:nth-child(3){grid-column:1/-1}.df-card-actions>*:nth-child(3).df-btn{width:100%}}
@media(max-width:470px){.df-head{gap:10px}.df-head h2{font-size:24px}.df-head p{font-size:13px}.df-actions{width:100%;margin-left:0}.df-actions>.df-btn{flex:1}.df-card-main{padding:15px 16px;gap:10px}.df-card-meta{padding:12px 16px}.df-badge{margin-top:1px}}
</style>
<div class="df-wrap">
  <div class="df-head">
    <div><h2><?php echo Text::_('COM_DECAROFORMS_FORMS'); ?></h2><p><?php echo Text::_('COM_DECAROFORMS_PAGE_FORMS_DESC'); ?></p></div>
    <div class="df-actions">
      <button class="df-btn" type="button" id="df-open-actions"><?php echo Text::_('COM_DECAROFORMS_ACTIONS'); ?> ▾</button>
      <a class="df-btn df-btn-primary" href="<?php echo $this->builderUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_CREATE_FORM'); ?></a>
    </div>
  </div>

  <dialog class="df-actions-dialog" id="df-actions-dialog">
    <div class="df-dialog-head"><h3><?php echo Text::_('COM_DECAROFORMS_ACTIONS'); ?></h3><button type="button" class="df-dialog-close" id="df-close-actions" aria-label="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_CLOSE'),ENT_QUOTES,'UTF-8'); ?>">×</button></div>
    <div class="df-dialog-links">
      <a class="df-btn" href="<?php echo $this->dashboardUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_DASHBOARD'); ?></a>
      <a class="df-btn" href="<?php echo $this->recentUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_RECENT'); ?></a>
      <a class="df-btn" href="<?php echo $this->importUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_MENU_IMPORT'); ?></a>
      <a class="df-btn" href="<?php echo $this->informationUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_INFORMATION'); ?></a>
    </div>
  </dialog>

  <div class="df-tools">
    <div class="df-tool"><label for="df-search"><?php echo Text::_('COM_DECAROFORMS_SEARCH'); ?></label><input id="df-search" type="search" placeholder="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_SEARCH_FORMS'),ENT_QUOTES,'UTF-8'); ?>" autocomplete="off"></div>
    <div class="df-tool"><label for="df-filter"><?php echo Text::_('COM_DECAROFORMS_STATUS'); ?></label><select id="df-filter"><option value="all"><?php echo Text::_('COM_DECAROFORMS_ALL_STATUSES'); ?></option><option value="enabled"><?php echo Text::_('COM_DECAROFORMS_ENABLED'); ?></option><option value="disabled"><?php echo Text::_('COM_DECAROFORMS_DISABLED'); ?></option></select></div>
    <div class="df-tool"><label for="df-sort"><?php echo Text::_('COM_DECAROFORMS_SORT'); ?></label><select id="df-sort"><option value="updated-desc"><?php echo Text::_('COM_DECAROFORMS_SORT_UPDATED_DESC'); ?></option><option value="updated-asc"><?php echo Text::_('COM_DECAROFORMS_SORT_UPDATED_ASC'); ?></option><option value="title-asc"><?php echo Text::_('COM_DECAROFORMS_SORT_TITLE_ASC'); ?></option><option value="title-desc"><?php echo Text::_('COM_DECAROFORMS_SORT_TITLE_DESC'); ?></option><option value="count-desc"><?php echo Text::_('COM_DECAROFORMS_SORT_SUBMISSIONS_DESC'); ?></option><option value="count-asc"><?php echo Text::_('COM_DECAROFORMS_SORT_SUBMISSIONS_ASC'); ?></option></select></div>
    <div class="df-tool"><label for="df-limit"><?php echo Text::_('COM_DECAROFORMS_SHOW'); ?></label><select id="df-limit"><option>10</option><option>25</option><option selected>50</option><option>100</option><option value="all"><?php echo Text::_('COM_DECAROFORMS_ALL'); ?></option></select></div>
    <button class="df-btn" type="button" id="df-clear"><?php echo Text::_('COM_DECAROFORMS_CLEAR'); ?></button>
  </div>

  <div class="df-list" id="df-list">
  <?php if (!$this->forms): ?>
    <div class="df-empty"><?php echo Text::_('COM_DECAROFORMS_NO_FORMS'); ?></div>
  <?php endif; ?>
  <?php foreach ($this->forms as $form): $enabled=(int)$form['enabled']===1; $updated=(int)(strtotime((string)($form['updated_at']??''))?:0); ?>
    <article class="df-card" data-title="<?php echo htmlspecialchars(mb_strtolower($form['title'].' '.$form['slug'],'UTF-8'),ENT_QUOTES,'UTF-8'); ?>" data-status="<?php echo $enabled?'enabled':'disabled'; ?>" data-updated="<?php echo $updated; ?>" data-count="<?php echo (int)$form['submission_count']; ?>">
      <div class="df-card-main"><div><h3><?php echo htmlspecialchars($form['title'],ENT_QUOTES,'UTF-8'); ?></h3><p><?php echo htmlspecialchars((string)$form['description'],ENT_QUOTES,'UTF-8'); ?></p></div><span class="df-badge <?php echo $enabled?'df-on':'df-off'; ?>"><?php echo $enabled?Text::_('COM_DECAROFORMS_ENABLED'):Text::_('COM_DECAROFORMS_DISABLED'); ?></span></div>
      <div class="df-card-meta">
        <div class="df-code"><small><?php echo Text::_('COM_DECAROFORMS_SHORTCODE'); ?></small><code>{form id="<?php echo (int)$form['id']; ?>"}</code></div>
        <div class="df-count"><small><?php echo Text::_('COM_DECAROFORMS_SUBMISSIONS'); ?></small><strong><?php echo (int)$form['submission_count']; ?></strong></div>
        <div class="df-card-actions"><a class="df-btn" href="<?php echo Route::_('index.php?option=com_decaroforms&view=builder&id='.(int)$form['id'],false); ?>"><?php echo Text::_('COM_DECAROFORMS_EDIT'); ?></a><form method="post" action="index.php?option=com_decaroforms&task=builder.duplicate"><input type="hidden" name="id" value="<?php echo (int)$form['id']; ?>"><button class="df-btn" type="submit"><?php echo Text::_('COM_DECAROFORMS_DUPLICATE_FORM'); ?></button><?php echo HTMLHelper::_('form.token'); ?></form><a class="df-btn df-btn-primary" href="<?php echo Route::_('index.php?option=com_decaroforms&view=submissions&form_id='.(int)$form['id'],false); ?>"><?php echo Text::_('COM_DECAROFORMS_OPEN_SUBMISSIONS'); ?></a></div>
      </div>
    </article>
  <?php endforeach; ?>
  <?php if ($this->forms): ?><div class="df-empty" id="df-no-results" hidden><?php echo Text::_('COM_DECAROFORMS_NO_RESULTS'); ?></div><?php endif; ?>
  </div>
  <?php echo FormHelper::footer(); ?>
</div>
<script>
(()=>{
 const q=document.getElementById('df-search'),f=document.getElementById('df-filter'),sort=document.getElementById('df-sort'),limit=document.getElementById('df-limit'),clear=document.getElementById('df-clear'),list=document.getElementById('df-list'),cards=[...document.querySelectorAll('.df-card')],empty=document.getElementById('df-no-results');
 const dialog=document.getElementById('df-actions-dialog'),openActions=document.getElementById('df-open-actions'),closeActions=document.getElementById('df-close-actions');
 openActions?.addEventListener('click',()=>dialog?.showModal());closeActions?.addEventListener('click',()=>dialog?.close());dialog?.addEventListener('click',event=>{if(event.target===dialog)dialog.close();});
 function cmp(a,b){const mode=sort.value;if(mode==='updated-asc')return Number(a.dataset.updated)-Number(b.dataset.updated);if(mode==='title-asc')return a.dataset.title.localeCompare(b.dataset.title);if(mode==='title-desc')return b.dataset.title.localeCompare(a.dataset.title);if(mode==='count-desc')return Number(b.dataset.count)-Number(a.dataset.count);if(mode==='count-asc')return Number(a.dataset.count)-Number(b.dataset.count);return Number(b.dataset.updated)-Number(a.dataset.updated);}
 function apply(){const s=(q.value||'').toLowerCase().trim(),st=f.value,max=limit.value==='all'?Infinity:parseInt(limit.value||'50',10);const ordered=[...cards].sort(cmp);ordered.forEach(card=>list.insertBefore(card,empty||null));let shown=0;ordered.forEach(card=>{const match=(!s||card.dataset.title.includes(s))&&(st==='all'||card.dataset.status===st);const visible=match&&shown<max;card.hidden=!visible;if(visible)shown++;});if(empty)empty.hidden=shown!==0;}
 let liveTimer=null;function schedule(){clearTimeout(liveTimer);liveTimer=setTimeout(apply,180);}q?.addEventListener('input',schedule);f?.addEventListener('change',apply);sort?.addEventListener('change',apply);limit?.addEventListener('change',apply);clear?.addEventListener('click',()=>{clearTimeout(liveTimer);q.value='';f.value='all';sort.value='updated-desc';limit.value='50';apply();});apply();
})();
</script>
PHP

python3 - <<'PY'
from pathlib import Path
import re

root=Path('/tmp/forms128/component')
controller=root/'administrator/components/com_decaroforms/src/Controller/BuilderController.php'
text=controller.read_text(encoding='utf-8')
marker='    public function copy(): void\n'
if marker not in text:
    raise SystemExit('BuilderController copy marker not found')
method=r'''    public function duplicate(): void
    {
        $app = Factory::getApplication();
        if (!Session::checkToken('post') || !$app->getIdentity()->authorise('core.create', 'com_decaroforms')) {
            throw new \RuntimeException(Text::_('COM_DECAROFORMS_ERR_TOKEN_PERMISSIONS'), 403);
        }

        $sourceId = $app->getInput()->post->getInt('id', 0);
        /** @var DatabaseInterface $db */
        $db = Factory::getContainer()->get(DatabaseInterface::class);
        $q = $db->createQuery()->select('*')->from($db->quoteName('#__decaroforms_forms'))->where($db->quoteName('id') . ' = :id')->bind(':id', $sourceId);
        $db->setQuery($q);
        $source = $db->loadAssoc();
        if (!$source) {
            $app->enqueueMessage(Text::_('COM_DECAROFORMS_ERR_COPY_FORM_NOT_FOUND'), 'error');
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=forms', false));
            return;
        }

        $baseTitle = Text::sprintf('COM_DECAROFORMS_DUPLICATE_TITLE', (string) $source['title']);
        $title = $baseTitle;
        $titleIndex = 2;
        while ($this->formTitleExists($db, $title)) {
            $title = $baseTitle . ' ' . $titleIndex++;
        }
        $baseSlug = FormHelper::slugify((string) ($source['slug'] ?: $source['title'])) . '-copy';
        $slug = $baseSlug;
        $slugIndex = 2;
        while ($this->formSlugExists($db, $slug)) {
            $slug = $baseSlug . '-' . $slugIndex++;
        }

        try {
            $db->transactionStart();
            $clone = new \stdClass();
            foreach ($source as $key => $value) {
                if ($key !== 'id') {
                    $clone->{$key} = $value;
                }
            }
            $now = Factory::getDate()->toSql();
            $clone->title = $title;
            $clone->slug = $slug;
            $clone->created_at = $now;
            $clone->updated_at = $now;
            $db->insertObject('#__decaroforms_forms', $clone, 'id');
            $newId = (int) $clone->id;

            $q = $db->createQuery()->select('*')->from($db->quoteName('#__decaroforms_fields'))->where($db->quoteName('form_id') . ' = :fid')->bind(':fid', $sourceId)->order([$db->quoteName('sort_order') . ' ASC', $db->quoteName('id') . ' ASC']);
            $db->setQuery($q);
            foreach ($db->loadAssocList() ?: [] as $field) {
                $record = new \stdClass();
                foreach ($field as $key => $value) {
                    if ($key !== 'id') {
                        $record->{$key} = $value;
                    }
                }
                $record->form_id = $newId;
                $db->insertObject('#__decaroforms_fields', $record);
            }
            $db->transactionCommit();
        } catch (Throwable $e) {
            $db->transactionRollback();
            $app->enqueueMessage(Text::sprintf('COM_DECAROFORMS_ERR_DUPLICATE_FAILED', $e->getMessage()), 'error');
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=forms', false));
            return;
        }

        $app->enqueueMessage(Text::_('COM_DECAROFORMS_MSG_FORM_DUPLICATED'), 'message');
        $app->redirect(Route::_('index.php?option=com_decaroforms&view=builder&id=' . $newId, false));
    }

'''
text=text.replace(marker,method+marker,1)
controller.write_text(text,encoding='utf-8')

sub=root/'administrator/components/com_decaroforms/tmpl/submissions/default.php'
t=sub.read_text(encoding='utf-8')
old='''<form method="post" action="index.php?option=com_decaroforms&task=builder.copy"><input type="hidden" name="id" value="<?php echo (int) ($this->form['id'] ?? 0); ?>"><input type="hidden" name="return_view" value="submissions"><button class="df-btn" type="submit"><?php echo Text::_('COM_DECAROFORMS_COPY_FORM'); ?></button><?php echo HTMLHelper::_('form.token'); ?></form>'''
new='''<form method="post" action="index.php?option=com_decaroforms&task=builder.duplicate"><input type="hidden" name="id" value="<?php echo (int) ($this->form['id'] ?? 0); ?>"><button class="df-btn" type="submit"><?php echo Text::_('COM_DECAROFORMS_DUPLICATE_FORM'); ?></button><?php echo HTMLHelper::_('form.token'); ?></form>'''
if old not in t:
    raise SystemExit('submissions copy button marker not found')
t=t.replace(old,new,1)
sub.write_text(t,encoding='utf-8')

translations={
'it-IT':{
'COM_DECAROFORMS_ACTIONS':'Azioni','COM_DECAROFORMS_DUPLICATE_FORM':'Duplica','COM_DECAROFORMS_DUPLICATE_TITLE':'%s – copia','COM_DECAROFORMS_MSG_FORM_DUPLICATED':'Modulo duplicato. La copia è indipendente e non contiene gli invii del modulo originale.','COM_DECAROFORMS_ERR_DUPLICATE_FAILED':'Impossibile duplicare il modulo: %s','COM_DECAROFORMS_SORT':'Ordina','COM_DECAROFORMS_SORT_UPDATED_DESC':'Ultimi aggiornati','COM_DECAROFORMS_SORT_UPDATED_ASC':'Più vecchi','COM_DECAROFORMS_SORT_TITLE_ASC':'Titolo A–Z','COM_DECAROFORMS_SORT_TITLE_DESC':'Titolo Z–A','COM_DECAROFORMS_SORT_SUBMISSIONS_DESC':'Più invii','COM_DECAROFORMS_SORT_SUBMISSIONS_ASC':'Meno invii','COM_DECAROFORMS_ALL':'Tutti','COM_DECAROFORMS_NO_RESULTS':'Nessun modulo trovato.'},
'en-GB':{
'COM_DECAROFORMS_ACTIONS':'Actions','COM_DECAROFORMS_DUPLICATE_FORM':'Duplicate','COM_DECAROFORMS_DUPLICATE_TITLE':'%s – copy','COM_DECAROFORMS_MSG_FORM_DUPLICATED':'Form duplicated. The copy is independent and contains no submissions from the original form.','COM_DECAROFORMS_ERR_DUPLICATE_FAILED':'Unable to duplicate the form: %s','COM_DECAROFORMS_SORT':'Sort','COM_DECAROFORMS_SORT_UPDATED_DESC':'Recently updated','COM_DECAROFORMS_SORT_UPDATED_ASC':'Oldest updated','COM_DECAROFORMS_SORT_TITLE_ASC':'Title A–Z','COM_DECAROFORMS_SORT_TITLE_DESC':'Title Z–A','COM_DECAROFORMS_SORT_SUBMISSIONS_DESC':'Most submissions','COM_DECAROFORMS_SORT_SUBMISSIONS_ASC':'Fewest submissions','COM_DECAROFORMS_ALL':'All','COM_DECAROFORMS_NO_RESULTS':'No forms found.'},
'fr-FR':{
'COM_DECAROFORMS_ACTIONS':'Actions','COM_DECAROFORMS_DUPLICATE_FORM':'Dupliquer','COM_DECAROFORMS_DUPLICATE_TITLE':'%s – copie','COM_DECAROFORMS_MSG_FORM_DUPLICATED':'Formulaire dupliqué. La copie est indépendante et ne contient aucun envoi du formulaire original.','COM_DECAROFORMS_ERR_DUPLICATE_FAILED':'Impossible de dupliquer le formulaire : %s','COM_DECAROFORMS_SORT':'Trier','COM_DECAROFORMS_SORT_UPDATED_DESC':'Dernières mises à jour','COM_DECAROFORMS_SORT_UPDATED_ASC':'Plus anciennes mises à jour','COM_DECAROFORMS_SORT_TITLE_ASC':'Titre A–Z','COM_DECAROFORMS_SORT_TITLE_DESC':'Titre Z–A','COM_DECAROFORMS_SORT_SUBMISSIONS_DESC':'Plus d’envois','COM_DECAROFORMS_SORT_SUBMISSIONS_ASC':'Moins d’envois','COM_DECAROFORMS_ALL':'Tous','COM_DECAROFORMS_NO_RESULTS':'Aucun formulaire trouvé.'}
}
for tag,vals in translations.items():
    p=root/f'administrator/components/com_decaroforms/language/{tag}/com_decaroforms.ini'
    s=p.read_text(encoding='utf-8-sig')
    for k,v in vals.items():
        line=f'{k}="{v}"'
        rx=re.compile(rf'^{re.escape(k)}=.*$',re.M)
        if rx.search(s): s=rx.sub(line,s,1)
        else: s+='\n'+line
    p.write_text(s.rstrip()+'\n',encoding='utf-8')

# Update all visible version strings in component/plugin text files.
for base in [root,Path('/tmp/forms128/plugin')]:
    for p in base.rglob('*'):
        if p.is_file() and p.suffix.lower() in {'.php','.xml','.ini','.js','.css','.txt'}:
            try: s=p.read_text(encoding='utf-8-sig')
            except UnicodeDecodeError: continue
            if '1.2.7' in s:
                p.write_text(s.replace('1.2.7','1.2.8'),encoding='utf-8')
PY

# Package manifest and inner filenames.
sed -i 's/1\.2\.7/1.2.8/g' "$ROOT/outer/pkg_decaroforms.xml"
rm -f "$ROOT/outer/com_decaroforms_${PREV}.zip" "$ROOT/outer/plg_system_decaroforms_${PREV}.zip"
(cd "$ROOT/component" && zip -qr "$ROOT/outer/com_decaroforms_${VERSION}.zip" .)
(cd "$ROOT/plugin" && zip -qr "$ROOT/outer/plg_system_decaroforms_${VERSION}.zip" .)

# Validation before publishing.
while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$ROOT/component" "$ROOT/plugin" -type f -name '*.php' -print0)
python3 - <<'PY'
import xml.etree.ElementTree as ET
for p in ['/tmp/forms128/component/com_decaroforms.xml','/tmp/forms128/plugin/decaroforms.xml','/tmp/forms128/outer/pkg_decaroforms.xml']:
    ET.parse(p)
    print('XML OK',p)
PY
grep -q '<version>1.2.8</version>' "$ROOT/component/com_decaroforms.xml"
grep -q '<version>1.2.8</version>' "$ROOT/plugin/decaroforms.xml"
grep -q 'com_decaroforms_1.2.8.zip' "$ROOT/outer/pkg_decaroforms.xml"
grep -q 'plg_system_decaroforms_1.2.8.zip' "$ROOT/outer/pkg_decaroforms.xml"
grep -q 'public function duplicate' "$ROOT/component/administrator/components/com_decaroforms/src/Controller/BuilderController.php"
grep -q 'builder.duplicate' "$ROOT/component/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q 'df-actions-dialog' "$ROOT/component/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q 'df-sort' "$ROOT/component/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q 'grid-template-columns:1fr 1fr' "$ROOT/component/administrator/components/com_decaroforms/tmpl/forms/default.php"
! grep -q 'task=builder.paste' "$ROOT/component/administrator/components/com_decaroforms/tmpl/forms/default.php"
! grep -q 'task=builder.copy' "$ROOT/component/administrator/components/com_decaroforms/tmpl/forms/default.php"

mkdir -p "releases/${VERSION}"
rm -f "releases/${VERSION}/pkg_decaroforms_${VERSION}.zip"
(cd "$ROOT/outer" && zip -qr "$GITHUB_WORKSPACE/releases/${VERSION}/pkg_decaroforms_${VERSION}.zip" .)
unzip -t "releases/${VERSION}/pkg_decaroforms_${VERSION}.zip" >/dev/null
SHA=$(sha256sum "releases/${VERSION}/pkg_decaroforms_${VERSION}.zip" | awk '{print $1}')

cat > "releases/${VERSION}/README.md" <<EOF
# Forms ${VERSION}

Duplica, menu Azioni e filtri Elenco moduli.

## Modifiche

- sostituiti **Copia modulo / Incolla modulo** con un unico pulsante **Duplica**;
- Duplica crea subito un modulo indipendente con nuovo ID, slug e shortcode, senza copiare invii o allegati;
- nella testata di Elenco moduli restano **Azioni** e **+ Nuovo modulo**;
- Azioni apre un dialog con Riepilogo, Invii recenti, Importa dati e Guida su desktop, tablet e smartphone;
- Elenco moduli dispone di Cerca, Stato, Ordina, Mostra e Pulisci, tutti in tempo reale;
- ordinamento per aggiornamento, titolo e numero di invii;
- su smartphone il badge Attivo/Disattivato resta in alto a destra;
- su smartphone i comandi sono su due righe: Modifica modulo + Duplica, poi Vedi invii a tutta larghezza;
- il pulsante Duplica è disponibile anche nella pagina Invii del singolo modulo.

SHA-256: ${SHA}
EOF

cat > updates/pkg_decaroforms.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>${VERSION}</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/${VERSION}/pkg_decaroforms_${VERSION}.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>${SHA}</sha256>
</update></updates>
EOF

python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET
p=Path('updates/changelog.xml')
s=p.read_text(encoding='utf-8')
if '<version>1.2.8</version>' not in s:
    entry='''  <changelog>\n    <element>pkg_decaroforms</element><type>package</type><version>1.2.8</version>\n    <addition><item>One-click form duplication without copying submissions or files.</item><item>Actions dialog and real-time forms filters/sorting.</item></addition>\n    <change><item>Removed Copy/Paste form workflow from the administrator UI.</item><item>Improved smartphone form-card layout and action placement.</item></change>\n  </changelog>\n'''
    s=s.replace('<changelogs>\n','<changelogs>\n'+entry,1)
    p.write_text(s,encoding='utf-8')
ET.parse('updates/pkg_decaroforms.xml')
ET.parse('updates/changelog.xml')
print('Update XML OK')
PY

rm -rf releases/_upload tools/release-1.2.8

echo "Forms ${VERSION} built successfully: ${SHA}"
