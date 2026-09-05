#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OLD="1.3.30"
NEW="1.3.31"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-ai-1331-check.js' EXIT

mkdir -p "$TMP/outer" "$TMP/component" "$TARGET_DIR"
unzip -q "$BASE" -d "$TMP/outer"
COMP_OLD="$TMP/outer/com_decaroforms_$OLD.zip"
test -f "$COMP_OLD"
unzip -q "$COMP_OLD" -d "$TMP/component"
BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
test -f "$BUILDER"

python3 - "$BUILDER" <<'PY'
from pathlib import Path
import sys

path=Path(sys.argv[1])
s=path.read_text(encoding='utf-8')

# Remove the duplicated top ChatGPT summary card. The full ChatGPT workflow below
# becomes the single authoritative ChatGPT block.
chat_card='<div class="df-ai-mode is-active"><div class="df-ai-mode-head"><strong>✨ Usa ChatGPT</strong><span class="df-ai-badge df-ai-badge-free">Senza API</span></div><div class="df-ai-direct-note">Scarica il file istruzioni di Forms e caricalo in ChatGPT insieme allo screenshot. ChatGPT ti restituisce il file JSON pronto da importare.</div></div>'
count=s.count(chat_card)
if count < 1:
    raise SystemExit('1.3.31: duplicated ChatGPT card anchor missing')
s=s.replace(chat_card,'')

# Remaining mode cards (HTML + future API) use two columns; the actual numbered
# workflow is deliberately stacked in a single column for readability.
s=s.replace('.df-ai-modes{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));',
            '.df-ai-modes{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));',1)
s=s.replace('.df-ai-workflow{display:grid;grid-template-columns:minmax(0,.95fr) minmax(0,1.05fr);gap:14px}',
            '.df-ai-workflow{display:grid;grid-template-columns:1fr;gap:14px}',1)

# Merge the old summary wording into step 1, avoiding repeated ChatGPT sections.
old_h='<div class="df-ai-box"><h4>1. Prepara il risultato con ChatGPT</h4><ol class="df-ai-steps">'
new_h='<div class="df-ai-box"><h4>1. Usa ChatGPT</h4><p class="df-ai-direct-note">Scarica il file istruzioni di Forms e caricalo in ChatGPT insieme allo screenshot. ChatGPT genera il JSON pronto per Forms.</p><ol class="df-ai-steps">'
if old_h not in s:
    raise SystemExit('1.3.31: ChatGPT step heading anchor missing')
s=s.replace(old_h,new_h)

# File clear buttons: icon-only, accessible, shown only when a file is selected.
trash_svg='<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M9 3h6l1 2h4v2h-1l-1 14H6L5 7H4V5h4l1-2zm-1.9 4 .86 12h8.08l.86-12H7.1zM10 9h2v8h-2V9zm4 0h2v8h-2V9z" fill="currentColor"/></svg>'
json_old='<div class="df-ai-file-row"><input type="file" id="df-ai-file" accept="application/json,.json"><span class="df-note" id="df-ai-file-status">Nessun file selezionato · JSON massimo 1 MB</span></div>'
json_new=f'<div class="df-ai-file-row"><input type="file" id="df-ai-file" accept="application/json,.json"><button class="df-ai-clear-file df-icon-only" type="button" id="df-ai-file-clear" title="Rimuovi file JSON" aria-label="Rimuovi file JSON" hidden>{trash_svg}</button><span class="df-note" id="df-ai-file-status">Nessun file selezionato · JSON massimo 1 MB</span></div>'
if json_old not in s:
    raise SystemExit('1.3.31: JSON file row anchor missing')
s=s.replace(json_old,json_new)

html_old='<input type="file" id="df-ai-html-file" accept="text/html,.html,.htm"><button class="df-btn df-small" type="button" id="df-ai-html-analyze">Analizza HTML</button><span class="df-note" id="df-ai-html-status">HTML massimo 5 MB</span>'
html_new=f'<input type="file" id="df-ai-html-file" accept="text/html,.html,.htm"><button class="df-ai-clear-file df-icon-only" type="button" id="df-ai-html-clear" title="Rimuovi file HTML" aria-label="Rimuovi file HTML" hidden>{trash_svg}</button><button class="df-btn df-small" type="button" id="df-ai-html-analyze">Analizza HTML</button><span class="df-note" id="df-ai-html-status">HTML massimo 5 MB</span>'
if html_old not in s:
    raise SystemExit('1.3.31: HTML file row anchor missing')
s=s.replace(html_old,html_new)

# Small icon sizing and hidden handling.
css_anchor='</style>'
css='''\n/* Forms 1.3.31: AI import UX cleanup. */\n.df-ai-clear-file[hidden]{display:none!important}.df-ai-clear-file{flex:0 0 auto;width:36px;height:36px;display:inline-grid;place-items:center}.df-ai-clear-file svg{width:17px;height:17px;display:block}\n'''
if css_anchor not in s:
    raise SystemExit('1.3.31: style closing anchor missing')
s=s.replace(css_anchor,css+css_anchor,1)

# Add clear/reset behavior without touching the proven parsing/import engine.
insert_anchor="document.getElementById('df-ai-check')?.addEventListener('click',()=>{try{aiShowError('');aiPrepare(aiParse(aiLoadedJson));}catch(err){aiShowError(err?.message||'Impossibile controllare il risultato.');aiPreview.hidden=true;}});"
extra_js=r'''
/* Forms 1.3.31: selected-file clear buttons. */
function aiClearPreparedPreview(){aiDraftFields=[];if(aiPreview)aiPreview.hidden=true;if(aiPreviewList)aiPreviewList.innerHTML='';if(aiImportButton)aiImportButton.disabled=true;if(aiImportCount)aiImportCount.textContent='· 0 campi';aiShowError('');}
function aiRefreshFileClearButtons(){const jf=document.getElementById('df-ai-file'),hf=document.getElementById('df-ai-html-file'),jc=document.getElementById('df-ai-file-clear'),hc=document.getElementById('df-ai-html-clear');if(jc)jc.hidden=!(jf?.files?.length);if(hc)hc.hidden=!(hf?.files?.length);}
document.getElementById('df-ai-file')?.addEventListener('change',()=>queueMicrotask(aiRefreshFileClearButtons));
document.getElementById('df-ai-html-file')?.addEventListener('change',()=>queueMicrotask(aiRefreshFileClearButtons));
document.getElementById('df-ai-file-clear')?.addEventListener('click',()=>{const input=document.getElementById('df-ai-file'),status=document.getElementById('df-ai-file-status');if(input)input.value='';aiLoadedJson='';if(status)status.textContent='Nessun file selezionato · JSON massimo 1 MB';aiClearPreparedPreview();aiRefreshFileClearButtons();});
document.getElementById('df-ai-html-clear')?.addEventListener('click',()=>{const input=document.getElementById('df-ai-html-file'),status=document.getElementById('df-ai-html-status');if(input)input.value='';if(status)status.textContent='HTML massimo 5 MB';aiClearPreparedPreview();aiRefreshFileClearButtons();});
'''
if insert_anchor not in s:
    raise SystemExit('1.3.31: ai-check JS anchor missing')
s=s.replace(insert_anchor,extra_js+'\n'+insert_anchor,1)

# After a successful import the existing reset also updates the new clear icons.
reset_tail="if(aiImportCount)aiImportCount.textContent='· 0 campi';aiShowError('');}"
reset_repl="if(aiImportCount)aiImportCount.textContent='· 0 campi';aiShowError('');aiRefreshFileClearButtons();}"
if reset_tail not in s:
    raise SystemExit('1.3.31: reset tail anchor missing')
s=s.replace(reset_tail,reset_repl,1)

s=s.replace('/* Forms 1.3.30: AI file workflow + direct HTML import + runtime guard. */','/* Forms 1.3.31: AI import single-column UX + file clear controls + runtime guard. */',1)
s=s.replace("window.dfBuilderRuntime={version:'1.3.30'","window.dfBuilderRuntime={version:'1.3.31'",1)

# Assertions guard against accidentally reintroducing the duplicated UI.
assert s.count('✨ Usa ChatGPT') == 0 or '1. Usa ChatGPT' in s
assert '1. Usa ChatGPT' in s
assert '1. Prepara il risultato con ChatGPT' not in s
assert 'grid-template-columns:1fr;gap:14px' in s
assert 'id="df-ai-file-clear"' in s
assert 'id="df-ai-html-clear"' in s
assert 'function aiClearPreparedPreview' in s
assert "version:'1.3.31'" in s
path.write_text(s,encoding='utf-8')
PY

# Update component metadata/version strings.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)

php -l "$BUILDER" >/dev/null
python3 - "$BUILDER" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
assert '1. Usa ChatGPT' in s
assert '1. Prepara il risultato con ChatGPT' not in s
assert 'id="df-ai-file-clear"' in s
assert 'id="df-ai-html-clear"' in s
assert 'function aiRefreshFileClearButtons' in s
# Check only the AI JS region for syntax.
a=s.index('/* Forms 1.3.31: AI import single-column UX')
b=s.index('/* Forms 1.3.6: bind quick templates',a)
Path('/tmp/forms-ai-1331-check.js').write_text(s[a:b],encoding='utf-8')
PY
node --check /tmp/forms-ai-1331-check.js >/dev/null

rm -f "$COMP_OLD"
(cd "$TMP/component" && zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .)

for z in "$TMP/outer"/*_"$OLD".zip; do
  [ -e "$z" ] || continue
  work="$TMP/sub-$(basename "$z" .zip)"
  mkdir -p "$work"
  unzip -q "$z" -d "$work"
  while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$work" || true)
  newz="${z/$OLD/$NEW}"
  rm -f "$newz"
  (cd "$work" && zip -qr "$newz" .)
  rm -f "$z"
done

while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -Il -- "$OLD" "$TMP/outer"/* 2>/dev/null || true)
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
unzip -tq "$TARGET" >/dev/null
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>$NEW</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/$NEW/pkg_decaroforms_$NEW.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF

cat > "$ROOT/updates/changelog.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>$NEW</version>
<improvement>Importa con AI: eliminata la duplicazione visiva tra la scheda “Usa ChatGPT” e il primo passaggio del flusso.</improvement>
<improvement>I passaggi 1 “Usa ChatGPT” e 2 “Carica il file generato” sono ora disposti in una singola colonna, più leggibile anche su schermi larghi.</improvement>
<improvement>Aggiunti pulsanti con icona cestino per rimuovere rapidamente il file JSON o HTML selezionato.</improvement>
<note>Il motore di parsing HTML, condizioni, anteprima e importazione resta invariato rispetto alla 1.3.30.</note>
<language>it-IT</language>
</changelog></changelogs>
EOF

rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
