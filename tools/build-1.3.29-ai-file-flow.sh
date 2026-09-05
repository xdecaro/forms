#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OLD="1.3.28"
NEW="1.3.29"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-ai-1329-check.js' EXIT

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

# UI: file-only workflow, no copy/paste JSON.
s=s.replace('Carica lo screenshot nella normale chat ChatGPT, usa il prompt di Forms e riporta qui il JSON generato.',
            'Scarica il file istruzioni di Forms e caricalo in ChatGPT insieme allo screenshot. ChatGPT ti restituisce il file JSON pronto da importare.')
s=s.replace('<li>Copia il prompt di Forms.</li><li>Apri ChatGPT e allega lo screenshot del modulo.</li><li>Incolla il prompt e chiedi di generare il JSON.</li><li>Copia il JSON e torna qui.</li>',
            '<li>Scarica il file istruzioni di Forms.</li><li>Apri ChatGPT e allega screenshot + file istruzioni.</li><li>ChatGPT genera <strong>forms-ai-import.json</strong>.</li><li>Scarica il JSON e caricalo qui sotto.</li>')
s=s.replace('<button class="df-btn df-primary" type="button" id="df-ai-copy-prompt">Copia prompt per ChatGPT</button><a class="df-btn" href="https://chatgpt.com/" target="_blank" rel="noopener noreferrer">Apri ChatGPT</a><button class="df-btn" type="button" id="df-ai-download-example">Scarica esempio JSON</button>',
            '<button class="df-btn df-primary" type="button" id="df-ai-download-instructions">⬇ Scarica file per ChatGPT</button><a class="df-btn" href="https://chatgpt.com/" target="_blank" rel="noopener noreferrer">Apri ChatGPT</a>')
s=s.replace('2. Incolla o carica il risultato','2. Carica il file generato')
s=s.replace('<textarea class="df-ai-json" id="df-ai-json" spellcheck="false" placeholder=\'{"format":"xdecaro-forms-ai","schema_version":1,"fields":[...]}\'></textarea>','')
s=s.replace('<span class="df-note">Solo JSON · massimo 1 MB</span>','<span class="df-note" id="df-ai-file-status">Nessun file selezionato · JSON massimo 1 MB</span>')
s=s.replace('.df-ai-json,.df-ai-description{','.df-ai-description{')

# Runtime references: use an in-memory JSON string loaded only from file.
s=s.replace(",aiJson=document.getElementById('df-ai-json')",'')
s=s.replace('let aiDraftFields=[];','let aiDraftFields=[];let aiLoadedJson=\'\';',1)
s=s.replace("requestAnimationFrame(()=>document.getElementById('df-ai-copy-prompt')?.focus());",
            "requestAnimationFrame(()=>document.getElementById('df-ai-download-instructions')?.focus());")

# Prompt stored inside the downloaded instruction file asks ChatGPT to create the final downloadable JSON.
old_tail='Ignora tutto ciò che non è un campo del modulo.`;}'
new_tail='Ignora tutto ciò che non è un campo del modulo.\\n\\nIMPORTANTE: crea un file scaricabile chiamato forms-ai-import.json contenente esclusivamente il JSON valido. Non aggiungere Markdown, spiegazioni o testo fuori dal file.`;}'
if old_tail not in s:
    raise SystemExit('1.3.29: prompt tail anchor missing')
s=s.replace(old_tail,new_tail,1)

# Remove old copy/example handlers and add one download-instructions action.
lines=s.splitlines()
out=[]
inserted=False
for line in lines:
    if line.startswith('async function aiCopyPrompt()'):
        continue
    if line.startswith("document.getElementById('df-ai-copy-prompt')?.addEventListener"):
        continue
    if line.startswith("document.getElementById('df-ai-download-example')?.addEventListener"):
        continue
    if line.startswith("document.getElementById('df-ai-file')?.addEventListener") and not inserted:
        out.append("document.getElementById('df-ai-download-instructions')?.addEventListener('click',()=>{const blob=new Blob([aiPromptText()],{type:'text/plain;charset=utf-8'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='forms-ai-chatgpt.txt';a.click();setTimeout(()=>URL.revokeObjectURL(url),500);});")
        inserted=True
        out.append("document.getElementById('df-ai-file')?.addEventListener('change',async e=>{const file=e.target.files?.[0],status=document.getElementById('df-ai-file-status');aiLoadedJson='';if(!file){if(status)status.textContent='Nessun file selezionato · JSON massimo 1 MB';return;}if(file.size>1024*1024){aiShowError('Il file JSON supera 1 MB.');e.target.value='';if(status)status.textContent='Nessun file selezionato · JSON massimo 1 MB';return;}try{aiLoadedJson=await file.text();aiShowError('');if(status)status.textContent=`✓ ${file.name}`;}catch{aiLoadedJson='';aiShowError('Impossibile leggere il file JSON.');if(status)status.textContent='Errore lettura file';}});")
        continue
    out.append(line)
s='\n'.join(out)+'\n'
if not inserted:
    raise SystemExit('1.3.29: file handler insertion point missing')

s=s.replace("if(!text)throw new Error('Incolla il JSON generato da ChatGPT oppure carica un file JSON.');",
            "if(!text)throw new Error('Carica il file forms-ai-import.json generato da ChatGPT.');",1)
s=s.replace("if(!data)throw new Error('Il contenuto non è un JSON valido. Chiedi a ChatGPT di restituire solo JSON, senza testo aggiuntivo.');",
            "if(!data)throw new Error('Il file non contiene un JSON valido. Genera di nuovo forms-ai-import.json con il file istruzioni di Forms.');",1)
s=s.replace("aiPrepare(aiParse(aiJson.value))","aiPrepare(aiParse(aiLoadedJson))",1)

# Clear AI draft only after a successful import; Cancel still keeps the current draft.
close_anchor="function aiClose(){if(!aiModal)return;aiModal.hidden=true;aiModal.setAttribute('aria-hidden','true');document.body.style.overflow='';}"
reset_code=close_anchor+"\nfunction aiResetAfterImport(){aiDraftFields=[];aiLoadedJson='';const file=document.getElementById('df-ai-file'),status=document.getElementById('df-ai-file-status'),description=document.getElementById('df-ai-description');if(file)file.value='';if(status)status.textContent='Nessun file selezionato · JSON massimo 1 MB';if(description)description.value='';if(aiPreview)aiPreview.hidden=true;if(aiPreviewList)aiPreviewList.innerHTML='';if(aiImportButton)aiImportButton.disabled=true;if(aiImportCount)aiImportCount.textContent='· 0 campi';aiShowError('');}"
if close_anchor not in s:
    raise SystemExit('1.3.29: aiClose anchor missing')
s=s.replace(close_anchor,reset_code,1)
s=s.replace('clearTimeout(historyTimer);pushHistory();aiClose();','clearTimeout(historyTimer);pushHistory();aiResetAfterImport();aiClose();',1)

# Version/comments.
s=s.replace('/* Forms 1.3.28: AI field import runtime guard + local ChatGPT/file flow. */','/* Forms 1.3.29: AI file-only ChatGPT flow + runtime guard. */',1)
s=s.replace("window.dfBuilderRuntime={version:'1.3.28'","window.dfBuilderRuntime={version:'1.3.29'",1)

# Hard assertions: no copy/paste controls remain.
assert 'Copia prompt per ChatGPT' not in s
assert 'Scarica esempio JSON' not in s
assert 'id="df-ai-json"' not in s
assert 'df-ai-copy-prompt' not in s
assert 'df-ai-download-example' not in s
assert 'Scarica file per ChatGPT' in s
assert 'forms-ai-chatgpt.txt' in s
assert 'forms-ai-import.json' in s
assert 'aiLoadedJson' in s
assert 'aiResetAfterImport' in s
assert "version:'1.3.29'" in s

path.write_text(s,encoding='utf-8')
PY

# Update component metadata and package versions.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)

php -l "$BUILDER" >/dev/null
python3 - "$BUILDER" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
assert 'Scarica file per ChatGPT' in s
assert 'id="df-ai-json"' not in s
assert 'forms-ai-chatgpt.txt' in s
assert 'aiResetAfterImport' in s
a=s.index('/* Forms 1.3.29: AI file-only ChatGPT flow')
b=s.index('/* Forms 1.3.6: bind quick templates',a)
Path('/tmp/forms-ai-1329-check.js').write_text(s[a:b],encoding='utf-8')
PY
node --check /tmp/forms-ai-1329-check.js >/dev/null

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
<targetplatform name="joomla" version="6\\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF

cat > "$ROOT/updates/changelog.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>$NEW</version>
<feature>Semplificato “Importa con AI”: eliminati copia/incolla del prompt e del JSON.</feature>
<feature>Nuovo pulsante unico “Scarica file per ChatGPT”, che genera forms-ai-chatgpt.txt con tutte le istruzioni e lo schema compatibile.</feature>
<feature>Il flusso ora è: screenshot + file istruzioni in ChatGPT → forms-ai-import.json → caricamento file in Forms → anteprima → importazione.</feature>
<feature>Dopo un’importazione completata, file, anteprima e bozza AI vengono svuotati automaticamente; Annulla conserva invece il lavoro non ancora importato.</feature>
<security>Restano attivi validazione JSON, allowlist dei tipi, limiti e sanificazione dell’importazione.</security>
<language>it-IT</language>
</changelog></changelogs>
EOF

rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
