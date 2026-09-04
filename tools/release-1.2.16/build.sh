#!/usr/bin/env bash
set -euo pipefail

ROOT=/tmp/forms1216
OUTER="$ROOT/outer"
COMP="$ROOT/component"
PLUGIN="$ROOT/plugin"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP" "$PLUGIN" releases/1.2.16

unzip -q releases/1.2.15/pkg_decaroforms_1.2.15.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
PLG_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'plg_*decaroforms*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
unzip -q "$PLG_ZIP" -d "$PLUGIN"

FORM_VIEW="$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"

python3 - <<'PY'
from pathlib import Path
p=Path('/tmp/forms1216/component/administrator/components/com_decaroforms/tmpl/forms/default.php')
s=p.read_text()

old_badges='''<div class="df-card-main"><div><h3><?php echo htmlspecialchars($form['title'],ENT_QUOTES,'UTF-8'); ?></h3><p><?php echo htmlspecialchars((string)$form['description'],ENT_QUOTES,'UTF-8'); ?></p></div><div class="df-card-badges"><span class="df-badge <?php echo $enabled?'df-on':'df-off'; ?>"><?php echo $enabled?Text::_('COM_DECAROFORMS_ENABLED'):Text::_('COM_DECAROFORMS_DISABLED'); ?></span><?php if(!$enabled): ?><span class="df-badge df-reason <?php echo htmlspecialchars($closedReasonClass,ENT_QUOTES,'UTF-8'); ?>"<?php echo $closedReasonTitle!==''?' title="'.htmlspecialchars($closedReasonTitle,ENT_QUOTES,'UTF-8').'"':''; ?>><?php echo htmlspecialchars($closedReasonLabel,ENT_QUOTES,'UTF-8'); ?></span><?php endif; ?></div></div>'''
new_badges='''<div class="df-card-main"><div><h3><?php echo htmlspecialchars($form['title'],ENT_QUOTES,'UTF-8'); ?></h3><p><?php echo htmlspecialchars((string)$form['description'],ENT_QUOTES,'UTF-8'); ?></p></div><div class="df-card-badges"><?php if($enabled): ?><span class="df-badge df-on"><?php echo Text::_('COM_DECAROFORMS_IN_PROGRESS'); ?></span><?php else: ?><span class="df-badge df-reason <?php echo htmlspecialchars($closedReasonClass,ENT_QUOTES,'UTF-8'); ?>"<?php echo $closedReasonTitle!==''?' title="'.htmlspecialchars($closedReasonTitle,ENT_QUOTES,'UTF-8').'"':''; ?>><?php echo htmlspecialchars($closedReasonLabel,ENT_QUOTES,'UTF-8'); ?></span><?php endif; ?></div></div>'''
if old_badges not in s:
    raise SystemExit('Badge block not found')
s=s.replace(old_badges,new_badges,1)

old_code='''<div class="df-code"><small><?php echo Text::_('COM_DECAROFORMS_SHORTCODE'); ?></small><code>{form id="<?php echo $id; ?>"}</code></div>'''
new_code='''<div class="df-code"><small><?php echo Text::_('COM_DECAROFORMS_SHORTCODE'); ?></small><div class="df-code-row"><code id="df-shortcode-<?php echo $id; ?>">{form id="<?php echo $id; ?>"}</code><button class="df-copy-btn" type="button" data-copy-target="df-shortcode-<?php echo $id; ?>" data-label="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_COPY_SHORTCODE'),ENT_QUOTES,'UTF-8'); ?>" data-copied-label="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_SHORTCODE_COPIED'),ENT_QUOTES,'UTF-8'); ?>" aria-label="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_COPY_SHORTCODE'),ENT_QUOTES,'UTF-8'); ?>" title="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_COPY_SHORTCODE'),ENT_QUOTES,'UTF-8'); ?>"><svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M8 7V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2h-2v2a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2h2Zm2 0h4a2 2 0 0 1 2 2v6h2V5h-8v2Zm4 2H6v10h8V9Z"/></svg></button></div></div>'''
if old_code not in s:
    raise SystemExit('Shortcode block not found')
s=s.replace(old_code,new_code,1)

# Slow the menu slightly and remove the old fixed filter animation.
s=s.replace('animation:df-menu-in .18s cubic-bezier(.2,.7,.2,1) both','animation:df-menu-in .22s cubic-bezier(.2,.7,.2,1) both')
s=s.replace('.df-tools.is-open{transform-origin:top center;animation:df-filter-in .2s ease both}', '.df-tools.is-open{transform-origin:top center}')
s=s.replace('.df-filter-toggle .df-chevron{transition:transform .16s ease}', '.df-filter-toggle .df-chevron{transition:transform .32s ease}')

mobile_old='.df-tools{display:none;grid-template-columns:1fr;margin-bottom:14px}.df-tools.is-open{display:grid}'
mobile_new='.df-tools{display:grid;grid-template-columns:1fr;max-height:0;opacity:0;overflow:hidden;visibility:hidden;pointer-events:none;transform:translateY(-6px);margin-bottom:0;padding-top:0;padding-bottom:0;border-width:0;transition:max-height .44s cubic-bezier(.22,.8,.24,1),opacity .28s ease,transform .44s cubic-bezier(.22,.8,.24,1),padding .44s ease,margin .44s ease,visibility 0s linear .44s}.df-tools.is-open{max-height:460px;opacity:1;visibility:visible;pointer-events:auto;transform:translateY(0);margin-bottom:14px;padding-top:15px;padding-bottom:15px;border-width:1px;transition:max-height .44s cubic-bezier(.22,.8,.24,1),opacity .28s ease,transform .44s cubic-bezier(.22,.8,.24,1),padding .44s ease,margin .44s ease,visibility 0s linear 0s}'
if mobile_old not in s:
    raise SystemExit('Mobile filter display block not found')
s=s.replace(mobile_old,mobile_new,1)

# Copy button + filter-card motion.
css='''
/* Forms 1.2.16: concise status, quick shortcode copy and smoother filtering */
.df-code-row{display:flex;align-items:center;gap:8px;min-width:0;margin-top:1px}.df-code-row code{min-width:0}.df-copy-btn{width:32px;height:32px;min-width:32px;display:inline-flex;align-items:center;justify-content:center;border:1px solid var(--df-border);border-radius:6px;background:var(--df-field);color:inherit;cursor:pointer;transition:background-color .18s ease,border-color .18s ease,transform .18s ease}.df-copy-btn:hover{background:var(--df-hover);border-color:var(--df-border-strong)}.df-copy-btn:active{transform:scale(.95)}.df-copy-btn:focus-visible{outline:2px solid #1683d8;outline-offset:2px}.df-copy-btn svg{width:17px;height:17px;fill:currentColor}.df-copy-btn.is-copied{background:#e8f7ee!important;border-color:#b7e3c8!important;color:#176b3a!important}.df-copy-btn.is-copied svg{display:none}.df-copy-btn.is-copied::before{content:"✓";font-size:18px;font-weight:900;line-height:1}
.df-card-filter-out{animation:df-card-out .24s ease forwards;pointer-events:none}.df-card-filter-in{animation:df-card-in .26s cubic-bezier(.2,.7,.2,1) both}@keyframes df-card-out{from{opacity:1;transform:translateY(0) scale(1)}to{opacity:0;transform:translateY(-5px) scale(.992)}}@keyframes df-card-in{from{opacity:0;transform:translateY(6px) scale(.992)}to{opacity:1;transform:translateY(0) scale(1)}}
@media (prefers-reduced-motion:reduce){.df-card-filter-out,.df-card-filter-in{animation:none!important}.df-copy-btn{transition:none!important}}
'''
if '</style>' not in s:
    raise SystemExit('Style close not found')
s=s.replace('</style>',css+'\n</style>',1)

old_apply="""function apply(){const s=(q.value||'').toLowerCase().trim(),st=f.value,max=limit.value==='all'?Infinity:parseInt(limit.value||'50',10);const ordered=[...cards].sort(cmp);ordered.forEach(card=>list.insertBefore(card,empty||null));let shown=0;ordered.forEach(card=>{const match=(!s||card.dataset.search.includes(s))&&(st==='all'||card.dataset.status===st);const visible=match&&shown<max;card.hidden=!visible;if(visible)shown++;});if(empty)empty.hidden=shown!==0;}
 let liveTimer=null;function schedule(){clearTimeout(liveTimer);liveTimer=setTimeout(apply,180);}q?.addEventListener('input',schedule);f?.addEventListener('change',apply);sort?.addEventListener('change',apply);limit?.addEventListener('change',apply);clear?.addEventListener('click',()=>{clearTimeout(liveTimer);q.value='';f.value='all';sort.value='updated-desc';limit.value='50';apply();});apply();"""
new_apply="""const reducedMotion=window.matchMedia('(prefers-reduced-motion: reduce)');
 function showCard(card){clearTimeout(card._dfHideTimer);card.dataset.dfVisible='1';if(card.hidden){card.hidden=false;if(!reducedMotion.matches){card.classList.remove('df-card-filter-out');card.classList.add('df-card-filter-in');clearTimeout(card._dfInTimer);card._dfInTimer=setTimeout(()=>card.classList.remove('df-card-filter-in'),280);}}else if(card.classList.contains('df-card-filter-out')){card.classList.remove('df-card-filter-out');if(!reducedMotion.matches){card.classList.add('df-card-filter-in');clearTimeout(card._dfInTimer);card._dfInTimer=setTimeout(()=>card.classList.remove('df-card-filter-in'),280);}}}
 function hideCard(card){clearTimeout(card._dfInTimer);card.dataset.dfVisible='0';if(card.hidden)return;if(reducedMotion.matches){card.hidden=true;card.classList.remove('df-card-filter-in','df-card-filter-out');return;}card.classList.remove('df-card-filter-in');card.classList.add('df-card-filter-out');clearTimeout(card._dfHideTimer);card._dfHideTimer=setTimeout(()=>{if(card.dataset.dfVisible==='0'){card.hidden=true;card.classList.remove('df-card-filter-out');}},240);}
 function apply(){const s=(q.value||'').toLowerCase().trim(),st=f.value,max=limit.value==='all'?Infinity:parseInt(limit.value||'50',10);const ordered=[...cards].sort(cmp);ordered.forEach(card=>list.insertBefore(card,empty||null));let shown=0;ordered.forEach(card=>{const match=(!s||card.dataset.search.includes(s))&&(st==='all'||card.dataset.status===st);const visible=match&&shown<max;if(visible){shown++;showCard(card);}else hideCard(card);});if(empty)empty.hidden=shown!==0;}
 let liveTimer=null;function schedule(){clearTimeout(liveTimer);liveTimer=setTimeout(apply,110);}q?.addEventListener('input',schedule);f?.addEventListener('change',apply);sort?.addEventListener('change',apply);limit?.addEventListener('change',apply);clear?.addEventListener('click',()=>{clearTimeout(liveTimer);q.value='';f.value='all';sort.value='updated-desc';limit.value='50';apply();});apply();"""
if old_apply not in s:
    raise SystemExit('Search apply block not found')
s=s.replace(old_apply,new_apply,1)

copy_js='''
 const fallbackCopy=text=>{const ta=document.createElement('textarea');ta.value=text;ta.setAttribute('readonly','');ta.style.position='fixed';ta.style.opacity='0';document.body.appendChild(ta);ta.select();let ok=false;try{ok=document.execCommand('copy');}catch(e){}ta.remove();return ok;};
 document.querySelectorAll('.df-copy-btn').forEach(btn=>btn.addEventListener('click',async()=>{const target=document.getElementById(btn.dataset.copyTarget||'');if(!target)return;const text=target.textContent||'';let ok=false;try{if(navigator.clipboard?.writeText){await navigator.clipboard.writeText(text);ok=true;}else ok=fallbackCopy(text);}catch(e){ok=fallbackCopy(text);}if(!ok)return;const original=btn.dataset.label||btn.getAttribute('aria-label')||'';const copied=btn.dataset.copiedLabel||'Copied';btn.classList.add('is-copied');btn.setAttribute('aria-label',copied);btn.setAttribute('title',copied);clearTimeout(btn._dfCopyTimer);btn._dfCopyTimer=setTimeout(()=>{btn.classList.remove('is-copied');btn.setAttribute('aria-label',original);btn.setAttribute('title',original);},1400);}));
'''
anchor="\n const menuNav=document.getElementById('df-actions-menu')"
if anchor not in s:
    raise SystemExit('Menu JS anchor not found')
s=s.replace(anchor,copy_js+anchor,1)

for needle in ['COM_DECAROFORMS_IN_PROGRESS','df-copy-btn','df-card-filter-out','liveTimer=setTimeout(apply,110)','max-height:460px']:
    if needle not in s:
        raise SystemExit('Missing expected marker: '+needle)
p.write_text(s)
PY

# Add dedicated labels without changing the technical Enabled/Disabled strings used by filters.
python3 - <<'PY'
from pathlib import Path
labels={
'it-IT':('In corso','Copia shortcode','Copiato'),
'en-GB':('In progress','Copy shortcode','Copied'),
'fr-FR':('En cours','Copier le shortcode','Copié'),
}
base=Path('/tmp/forms1216/component/administrator/components/com_decaroforms/language')
for lang,(progress,copy,copied) in labels.items():
    p=base/lang/'com_decaroforms.ini'
    s=p.read_text()
    additions=f'\nCOM_DECAROFORMS_IN_PROGRESS="{progress}"\nCOM_DECAROFORMS_COPY_SHORTCODE="{copy}"\nCOM_DECAROFORMS_SHORTCODE_COPIED="{copied}"\n'
    if 'COM_DECAROFORMS_IN_PROGRESS=' not in s:
        s += additions
    p.write_text(s)
PY

# Version bump in package/component/plugin metadata and displayed version references.
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.15/1.2.16/g' "$file"
done < <(find "$COMP" "$PLUGIN" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.15/1.2.16/g' "$file"
done < <(find "$OUTER" -maxdepth 1 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)

COM_NEW="$OUTER/com_decaroforms_1.2.16.zip"
PLG_BASENAME="$(basename "$PLG_ZIP")"
PLG_NEW="$OUTER/${PLG_BASENAME/1.2.15/1.2.16}"
rm -f "$COM_ZIP" "$PLG_ZIP"
(cd "$COMP" && zip -qr "$COM_NEW" .)
(cd "$PLUGIN" && zip -qr "$PLG_NEW" .)

TARGET="$GITHUB_WORKSPACE/releases/1.2.16/pkg_decaroforms_1.2.16.zip"
rm -f "$TARGET"
(cd "$OUTER" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

# Automated checks.
find "$COMP" -type f -name '*.php' -print0 | xargs -0 -n1 php -l >/tmp/forms1216-php.log
python3 - <<'PY'
import xml.etree.ElementTree as ET
ET.parse('/tmp/forms1216/component/com_decaroforms.xml')
PY
unzip -tq "$TARGET" >/dev/null
grep -q 'COM_DECAROFORMS_IN_PROGRESS' "$FORM_VIEW"
grep -q 'df-copy-btn' "$FORM_VIEW"
grep -q 'df-card-filter-out' "$FORM_VIEW"
grep -q 'max-height:460px' "$FORM_VIEW"
grep -q 'liveTimer=setTimeout(apply,110)' "$FORM_VIEW"
grep -q 'COM_DECAROFORMS_IN_PROGRESS="In corso"' "$COMP/administrator/components/com_decaroforms/language/it-IT/com_decaroforms.ini"
# JS syntax check: the template script contains no PHP in this block.
python3 - <<'PY'
from pathlib import Path
s=Path('/tmp/forms1216/component/administrator/components/com_decaroforms/tmpl/forms/default.php').read_text()
js=s.split('<script>',1)[1].split('</script>',1)[0]
Path('/tmp/forms1216/forms.js').write_text(js)
PY
node --check /tmp/forms1216/forms.js

cat > releases/1.2.16/README.md <<EOF
# Forms 1.2.16

Rifinitura dell'Elenco moduli: stato più semplice, copia rapida shortcode e animazioni più naturali.

## Modifiche

- il badge dei moduli attivi mostra "In corso";
- i moduli disattivati mostrano direttamente il motivo (es. "Iscrizioni chiuse") senza il badge tecnico "Disattivato" duplicato;
- aggiunta icona copia accanto allo shortcode con conferma visiva "Copiato";
- la ricerca live mantiene il filtro immediato ma le card escluse sfumano prima di scomparire e quelle ritrovate rientrano dolcemente;
- debounce ricerca ridotto a 110 ms per mantenere la sensazione di tempo reale;
- l'accordion mobile "Cerca e filtra" usa una transizione di circa 440 ms calibrata sull'altezza dei 5 controlli, invece di display none/grid immediato;
- animazione Menu leggermente più morbida;
- rispettata prefers-reduced-motion;
- nessuna modifica allo schema database e nessuna perdita di dati.

SHA-256: $SHA
EOF

cat > updates/pkg_decaroforms.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.2.16</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.2.16/pkg_decaroforms_1.2.16.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF

python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET
p=Path('updates/changelog.xml')
s=p.read_text()
entry='''  <changelog>\n    <element>pkg_decaroforms</element><type>package</type><version>1.2.16</version>\n    <change><item>Simplified form status badges: In progress for enabled forms and only the configured closed reason for disabled forms.</item><item>Added one-click shortcode copy with visual confirmation.</item><item>Added smooth live-search card transitions and a slower five-row mobile filter accordion.</item></change>\n  </changelog>\n'''
if '<changelogs>\n' not in s:
    raise SystemExit('Changelog root not found')
s=s.replace('<changelogs>\n','<changelogs>\n'+entry,1)
p.write_text(s)
ET.parse('updates/pkg_decaroforms.xml')
ET.parse('updates/changelog.xml')
PY

rm -rf releases/_upload releases/_inspect-1.2.15-forms.txt
