#!/usr/bin/env bash
set -euo pipefail

ROOT=/tmp/forms129
OUTER="$ROOT/outer"
COMP="$ROOT/component"
PLUGIN="$ROOT/plugin"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP" "$PLUGIN" releases/1.2.9

unzip -q releases/1.2.8/pkg_decaroforms_1.2.8.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
PLG_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'plg_*decaroforms*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
unzip -q "$PLG_ZIP" -d "$PLUGIN"

cat > "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php" <<'PHP'
<?php

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\FormHelper;
use Joomla\CMS\Router\Route;
use Joomla\CMS\Language\Text;
use Joomla\CMS\HTML\HTMLHelper;
?>
<style>
.df-wrap{--df:#e60046;--df-dark:#b40038;--df-panel:var(--bs-body-bg,#fff);--df-panel-alt:var(--bs-tertiary-bg,#f6f7f9);--df-field:var(--bs-body-bg,#fff);--df-border:var(--bs-border-color,#dfe3e7);max-width:none;color:var(--bs-body-color,#1f2937);container-type:inline-size;container-name:formslist}
.df-head{display:flex;justify-content:space-between;gap:16px;align-items:flex-end;margin:4px 0 18px}.df-head h2{margin:0;font-size:27px}.df-head p{margin:5px 0 0;color:var(--bs-secondary-color,#667085)}
.df-actions{display:flex;gap:9px;flex-wrap:wrap;align-items:center}.df-actions form,.df-card-actions form{margin:0}.df-btn{display:inline-flex;align-items:center;justify-content:center;min-height:40px;padding:0 14px;border:1px solid var(--df-border);border-radius:6px;background:var(--df-field);color:inherit!important;text-decoration:none;font-weight:700;cursor:pointer;text-align:center;line-height:1.2}.df-btn-primary{background:var(--df);border-color:var(--df);color:#fff!important}.df-btn-primary:hover{background:var(--df-dark);border-color:var(--df-dark)}
.df-actions-dialog{width:min(420px,calc(100vw - 28px));padding:0;border:1px solid var(--df-border);border-radius:10px;background:var(--df-panel);color:inherit;box-shadow:0 24px 70px rgba(0,0,0,.32)}.df-actions-dialog::backdrop{background:rgba(0,0,0,.56)}.df-dialog-head{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:16px 18px;border-bottom:1px solid var(--df-border)}.df-dialog-head h3{margin:0;font-size:20px;background:transparent!important}.df-dialog-close{width:36px;height:36px;padding:0;border:1px solid var(--df-border);border-radius:6px;background:var(--df-field);color:inherit;font-size:23px;cursor:pointer}.df-dialog-links{display:grid;grid-template-columns:1fr;gap:9px;padding:18px}.df-dialog-links .df-btn{width:100%;min-height:48px;justify-content:center}
.df-filter-toggle{display:none;width:100%;margin-bottom:10px;justify-content:space-between}.df-filter-toggle .df-chevron{transition:transform .16s ease}.df-filter-toggle[aria-expanded="true"] .df-chevron{transform:rotate(180deg)}
.df-tools{display:grid;grid-template-columns:minmax(260px,2fr) minmax(155px,1fr) minmax(185px,1fr) 120px auto;gap:10px;align-items:end;padding:15px 16px;margin-bottom:14px;border:1px solid var(--df-border);border-radius:8px;background:var(--df-panel);min-width:0}.df-tool{display:flex;flex-direction:column;gap:6px;min-width:0}.df-tool label{font-weight:800}.df-tool input,.df-tool select{width:100%;min-width:0;min-height:42px;border:1px solid var(--df-border);border-radius:6px;background:var(--df-field);color:inherit;padding:0 12px}.df-tool input::placeholder{font-style:italic;color:var(--bs-secondary-color,#87909b)}
.df-list{display:flex;flex-direction:column;gap:12px;min-width:0}.df-card{width:100%;max-width:100%;min-width:0;border:1px solid var(--df-border);border-radius:8px;background:var(--df-panel);box-shadow:0 2px 8px rgba(0,0,0,.04);overflow:hidden}.df-card-main{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:14px;align-items:start;padding:17px 18px;background:transparent}.df-card h3{margin:0 0 4px;font-size:19px;overflow-wrap:anywhere;background:transparent!important;background-color:transparent!important;padding:0!important;border:0!important;box-shadow:none!important}.df-card p{margin:0;color:var(--bs-secondary-color,#667085);overflow-wrap:anywhere}.df-badge{display:inline-flex;align-items:center;justify-content:center;padding:4px 9px;border-radius:999px;font-size:12px;font-weight:800;white-space:nowrap;align-self:start}.df-on{background:#e8f7ee;color:#176b3a}.df-off{background:#fdebec;color:#9f2430}
.df-card-meta{display:grid;grid-template-columns:minmax(0,1fr) auto auto;gap:18px;align-items:center;padding:11px 18px;border-top:1px solid var(--df-border);background:var(--df-panel-alt);min-width:0}.df-code{min-width:0}.df-code small,.df-count small{display:block;color:var(--bs-secondary-color,#667085);font-size:11px;font-weight:800;text-transform:uppercase}.df-code code{font-weight:700;overflow-wrap:anywhere}.df-count{text-align:right}.df-count strong{display:block;font-size:21px}.df-card-actions{display:flex;gap:8px;justify-content:flex-end;align-items:center;min-width:0}.df-card-actions>*{min-width:0}
.df-empty{padding:38px 20px;text-align:center;border:1px dashed var(--df-border);border-radius:8px}.df-admin-footer{margin:28px 0 10px;padding-top:16px;border-top:1px solid var(--df-border);text-align:center;color:var(--bs-secondary-color,#667085);font-size:12px}
html[data-bs-theme="dark"] .df-wrap,html[data-color-scheme="dark"] .df-wrap{--df:#9f1239;--df-dark:#7f0d2e;--df-panel:#1a232d;--df-panel-alt:#202b37;--df-field:#121a23;--df-border:#3b4857;color:#f3f6fa}
html[data-bs-theme="dark"] .df-wrap .df-head p,html[data-color-scheme="dark"] .df-wrap .df-head p,html[data-bs-theme="dark"] .df-wrap .df-card p,html[data-color-scheme="dark"] .df-wrap .df-card p{color:#b5c0cc}
html[data-bs-theme="dark"] .df-wrap .df-on,html[data-color-scheme="dark"] .df-wrap .df-on{background:#163b29;color:#a8e5bd}html[data-bs-theme="dark"] .df-wrap .df-off,html[data-color-scheme="dark"] .df-wrap .df-off{background:#4a1f28;color:#ffb5c0}
html[data-bs-theme="dark"] .df-wrap code,html[data-color-scheme="dark"] .df-wrap code{color:#f07a9b}html[data-bs-theme="dark"] .df-wrap .df-btn-primary,html[data-color-scheme="dark"] .df-wrap .df-btn-primary{background:#9f1239;border-color:#9f1239}html[data-bs-theme="dark"] .df-wrap .df-btn-primary:hover,html[data-color-scheme="dark"] .df-wrap .df-btn-primary:hover{background:#7f0d2e;border-color:#7f0d2e}
@container formslist (max-width:920px){.df-tools{grid-template-columns:repeat(3,minmax(0,1fr))}.df-tools>.df-btn{width:100%}.df-card-meta{grid-template-columns:minmax(0,1fr) auto}.df-card-actions{grid-column:1/-1;justify-content:flex-end}}
@container formslist (max-width:680px){.df-tools{grid-template-columns:repeat(2,minmax(0,1fr))}.df-head{align-items:flex-start}.df-card-meta{grid-template-columns:1fr}.df-count{text-align:left}.df-card-actions{justify-content:flex-start}}
@container formslist (max-width:560px){.df-head{flex-direction:column;align-items:stretch;gap:10px}.df-actions{width:100%;display:grid;grid-template-columns:1fr}.df-actions>.df-btn{width:100%;min-height:44px}.df-filter-toggle{display:flex}.df-tools{display:none;grid-template-columns:1fr;margin-bottom:14px}.df-tools.is-open{display:grid}.df-card-main{padding:15px 16px;gap:10px}.df-card-meta{padding:12px 16px}.df-card-actions{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:8px;width:100%}.df-card-actions>*{width:100%}.df-card-actions .df-btn,.df-card-actions form .df-btn,.df-card-actions>a{width:100%;height:44px;min-height:44px;padding:0 7px;white-space:nowrap;font-size:12.5px;align-items:center;justify-content:center;text-align:center}.df-card-actions>*:nth-child(3){grid-column:1/-1}.df-card-actions>*:nth-child(3).df-btn{width:100%}.df-badge{margin-top:1px}}
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

  <button class="df-btn df-filter-toggle" type="button" id="df-filter-toggle" aria-expanded="false" aria-controls="df-tools"><span><?php echo Text::_('COM_DECAROFORMS_SEARCH_FILTER'); ?></span><span class="df-chevron" aria-hidden="true">▾</span></button>
  <div class="df-tools" id="df-tools">
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
  <?php foreach ($this->forms as $form):
      $enabled=(int)$form['enabled']===1;
      $updated=(int)(strtotime((string)($form['updated_at']??''))?:0);
      $id=(int)$form['id'];
      $titleSort=mb_strtolower((string)$form['title'],'UTF-8');
      $searchText=mb_strtolower((string)$form['title'].' '.(string)$form['description'].' '.(string)$form['slug'].' '.$id.' form id="'.$id.'" {form id="'.$id.'"}', 'UTF-8');
  ?>
    <article class="df-card" data-search="<?php echo htmlspecialchars($searchText,ENT_QUOTES,'UTF-8'); ?>" data-title="<?php echo htmlspecialchars($titleSort,ENT_QUOTES,'UTF-8'); ?>" data-status="<?php echo $enabled?'enabled':'disabled'; ?>" data-updated="<?php echo $updated; ?>" data-count="<?php echo (int)$form['submission_count']; ?>">
      <div class="df-card-main"><div><h3><?php echo htmlspecialchars($form['title'],ENT_QUOTES,'UTF-8'); ?></h3><p><?php echo htmlspecialchars((string)$form['description'],ENT_QUOTES,'UTF-8'); ?></p></div><span class="df-badge <?php echo $enabled?'df-on':'df-off'; ?>"><?php echo $enabled?Text::_('COM_DECAROFORMS_ENABLED'):Text::_('COM_DECAROFORMS_DISABLED'); ?></span></div>
      <div class="df-card-meta">
        <div class="df-code"><small><?php echo Text::_('COM_DECAROFORMS_SHORTCODE'); ?></small><code>{form id="<?php echo $id; ?>"}</code></div>
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
 const q=document.getElementById('df-search'),f=document.getElementById('df-filter'),sort=document.getElementById('df-sort'),limit=document.getElementById('df-limit'),clear=document.getElementById('df-clear'),list=document.getElementById('df-list'),cards=[...document.querySelectorAll('.df-card')],empty=document.getElementById('df-no-results');
 const dialog=document.getElementById('df-actions-dialog'),openActions=document.getElementById('df-open-actions'),closeActions=document.getElementById('df-close-actions'),filterToggle=document.getElementById('df-filter-toggle'),tools=document.getElementById('df-tools');
 openActions?.addEventListener('click',()=>dialog?.showModal());closeActions?.addEventListener('click',()=>dialog?.close());dialog?.addEventListener('click',event=>{if(event.target===dialog)dialog.close();});
 filterToggle?.addEventListener('click',()=>{const open=!tools.classList.contains('is-open');tools.classList.toggle('is-open',open);filterToggle.setAttribute('aria-expanded',open?'true':'false');});
 function cmp(a,b){const mode=sort.value;if(mode==='updated-asc')return Number(a.dataset.updated)-Number(b.dataset.updated);if(mode==='title-asc')return a.dataset.title.localeCompare(b.dataset.title);if(mode==='title-desc')return b.dataset.title.localeCompare(a.dataset.title);if(mode==='count-desc')return Number(b.dataset.count)-Number(a.dataset.count);if(mode==='count-asc')return Number(a.dataset.count)-Number(b.dataset.count);return Number(b.dataset.updated)-Number(a.dataset.updated);}
 function apply(){const s=(q.value||'').toLowerCase().trim(),st=f.value,max=limit.value==='all'?Infinity:parseInt(limit.value||'50',10);const ordered=[...cards].sort(cmp);ordered.forEach(card=>list.insertBefore(card,empty||null));let shown=0;ordered.forEach(card=>{const match=(!s||card.dataset.search.includes(s))&&(st==='all'||card.dataset.status===st);const visible=match&&shown<max;card.hidden=!visible;if(visible)shown++;});if(empty)empty.hidden=shown!==0;}
 let liveTimer=null;function schedule(){clearTimeout(liveTimer);liveTimer=setTimeout(apply,180);}q?.addEventListener('input',schedule);f?.addEventListener('change',apply);sort?.addEventListener('change',apply);limit?.addEventListener('change',apply);clear?.addEventListener('click',()=>{clearTimeout(liveTimer);q.value='';f.value='all';sort.value='updated-desc';limit.value='50';apply();});apply();
})();
</script>
PHP

for lang in it-IT en-GB fr-FR; do
  FILE="$COMP/administrator/components/com_decaroforms/language/$lang/com_decaroforms.ini"
  case "$lang" in
    it-IT) TEXT='Cerca e filtra' ;;
    en-GB) TEXT='Search and filter' ;;
    fr-FR) TEXT='Rechercher et filtrer' ;;
  esac
  grep -q '^COM_DECAROFORMS_SEARCH_FILTER=' "$FILE" || printf '\nCOM_DECAROFORMS_SEARCH_FILTER="%s"\n' "$TEXT" >> "$FILE"
done

# Bump version strings in component and plugin payloads.
while IFS= read -r -d '' file; do sed -i 's/1\.2\.8/1.2.9/g' "$file"; done < <(find "$COMP" "$PLUGIN" -type f \( -name '*.php' -o -name '*.xml' -o -name '*.ini' -o -name '*.js' -o -name '*.css' -o -name '*.txt' \) -print0)

COM_NEW="$OUTER/$(basename "$COM_ZIP" | sed 's/1\.2\.8/1.2.9/g')"
PLG_NEW="$OUTER/$(basename "$PLG_ZIP" | sed 's/1\.2\.8/1.2.9/g')"
rm -f "$COM_ZIP" "$PLG_ZIP"
(cd "$COMP" && zip -qr "$COM_NEW" .)
(cd "$PLUGIN" && zip -qr "$PLG_NEW" .)
while IFS= read -r -d '' file; do sed -i 's/1\.2\.8/1.2.9/g' "$file"; done < <(find "$OUTER" -maxdepth 1 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)

TARGET="$GITHUB_WORKSPACE/releases/1.2.9/pkg_decaroforms_1.2.9.zip"
rm -f "$TARGET"
(cd "$OUTER" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

# Automated checks.
find "$COMP" -type f -name '*.php' -print0 | xargs -0 -n1 php -l >/tmp/forms129-php.log
xmllint --noout "$COMP/com_decaroforms.xml"
unzip -tq "$TARGET" >/dev/null
grep -q 'data-search=' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q '{form id=' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q '@container formslist' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q 'df-filter-toggle' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q 'grid-template-columns:1fr;gap:9px' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q 'background:transparent!important' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q 'data-bs-theme="dark"' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"

cat > releases/1.2.9/README.md <<EOF
# Forms 1.2.9

Responsive e dark-mode maintenance release.

## Modifiche

- ricerca Elenco moduli estesa a ID, shortcode, titolo, descrizione e slug;
- ricerca in tempo reale anche scrivendo `{form id="3"}` o parti dello shortcode;
- responsive basato sulla larghezza reale del componente tramite container queries;
- filtri Elenco moduli in accordion su smartphone;
- Azioni e + Nuovo modulo su righe separate su smartphone;
- dialog Azioni con una voce per riga;
- pulsanti Modifica modulo e Duplica 50/50, stessa altezza e centratura verticale/orizzontale;
- Vedi invii al 100% sotto i due pulsanti su smartphone;
- dark mode Elenco moduli uniformato, senza pannelli bianchi o fascia dietro al titolo;
- variante dark più scura per i pulsanti accent e badge con contrasto migliorato;
- nessuna modifica allo schema database e nessuna perdita di dati.

SHA-256: $SHA
EOF

cat > updates/pkg_decaroforms.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.2.9</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.2.9/pkg_decaroforms_1.2.9.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF

python3 - <<'PY'
from pathlib import Path
p=Path('updates/changelog.xml')
s=p.read_text()
entry='''  <changelog>\n    <element>pkg_decaroforms</element><type>package</type><version>1.2.9</version>\n    <fix><item>Forms list search now includes ID and shortcode.</item><item>Responsive layout now follows the component container width and avoids horizontal overflow.</item><item>Dark mode no longer shows light title bands or light filter panels.</item></fix>\n    <change><item>Smartphone filters use an accordion and primary actions stack vertically.</item><item>Actions dialog uses one item per row.</item><item>Dark accent buttons use a darker variant for better contrast.</item></change>\n  </changelog>\n'''
s=s.replace('<changelogs>\n','<changelogs>\n'+entry,1)
p.write_text(s)
PY
xmllint --noout updates/pkg_decaroforms.xml updates/changelog.xml

rm -rf releases/_upload tools/release-1.2.9
printf 'Forms 1.2.9 build OK - %s\n' "$SHA"
