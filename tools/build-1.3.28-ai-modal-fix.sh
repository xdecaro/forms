#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OLD="1.3.27"
NEW="1.3.28"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-ai-1328-check.js' EXIT

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

path = Path(sys.argv[1])
s = path.read_text(encoding='utf-8')

# Runtime fallback: if Joomla/browser has not rendered the static AI modal for any
# reason, create it synchronously before the AI references/listeners are bound.
anchor = """/* Forms 1.3.27: AI field import. ChatGPT/file flow is local; no API call is made here. */\nconst aiModal=document.getElementById('df-ai-import-modal'),aiJson=document.getElementById('df-ai-json'),aiError=document.getElementById('df-ai-error'),aiPreview=document.getElementById('df-ai-preview'),aiPreviewList=document.getElementById('df-ai-preview-list'),aiImportButton=document.getElementById('df-ai-import'),aiImportCount=document.getElementById('df-ai-import-count');"""
replacement = r'''/* Forms 1.3.28: AI field import runtime guard + local ChatGPT/file flow. */
function ensureAiImportDom(){
 if(document.getElementById('df-ai-import-modal'))return true;
 const host=document.querySelector('.df-builder')||document.body;
 if(!host)return false;
 host.insertAdjacentHTML('beforeend',`<div class="df-ai-modal" id="df-ai-import-modal" hidden aria-hidden="true">
  <div class="df-ai-backdrop" data-ai-close></div>
  <div class="df-ai-dialog" role="dialog" aria-modal="true" aria-labelledby="df-ai-title">
   <div class="df-ai-head"><div class="df-ai-head-title"><strong id="df-ai-title">✨ Importa campi con AI</strong><span class="df-note">L’AI prepara una bozza: i campi entrano nel modulo solo dopo la tua conferma.</span></div><button class="df-ai-close" type="button" data-ai-close aria-label="Chiudi">×</button></div>
   <div class="df-ai-body">
    <p class="df-ai-intro">Ricrea solo i campi del modulo. Template, CSS, colori, immagini, pulsanti decorativi e contenuti del sito originale non vengono importati.</p>
    <div class="df-ai-modes"><div class="df-ai-mode is-active"><div class="df-ai-mode-head"><strong>✨ Usa ChatGPT</strong><span class="df-ai-badge df-ai-badge-free">Senza API</span></div><div class="df-ai-direct-note">Carica lo screenshot nella normale chat ChatGPT, usa il prompt di Forms e riporta qui il JSON generato.</div></div><div class="df-ai-mode is-disabled" aria-disabled="true"><div class="df-ai-mode-head"><strong>⚡ Analizza direttamente</strong><span class="df-ai-badge df-ai-badge-soon">API opzionale · prossimamente</span></div><div class="df-ai-direct-note">In futuro potrà analizzare lo screenshot senza uscire dal Builder. Richiederà un provider API configurato.</div></div></div>
    <div class="df-ai-workflow">
     <div class="df-ai-box"><h4>1. Prepara il risultato con ChatGPT</h4><ol class="df-ai-steps"><li>Copia il prompt di Forms.</li><li>Apri ChatGPT e allega lo screenshot del modulo.</li><li>Incolla il prompt e chiedi di generare il JSON.</li><li>Copia il JSON e torna qui.</li></ol><div class="df-ai-actions"><button class="df-btn df-primary" type="button" id="df-ai-copy-prompt">Copia prompt per ChatGPT</button><a class="df-btn" href="https://chatgpt.com/" target="_blank" rel="noopener noreferrer">Apri ChatGPT</a><button class="df-btn" type="button" id="df-ai-download-example">Scarica esempio JSON</button></div><details class="df-ai-quick"><summary>Descrizione rapida senza AI</summary><div class="df-ai-quick-body"><p class="df-note">Per moduli semplici puoi evitare anche ChatGPT. Esempio: “nome, cognome, email, telefono, data di nascita, corso, privacy e note”.</p><textarea class="df-ai-description" id="df-ai-description" placeholder="Descrivi i campi del modulo..."></textarea><div class="df-ai-actions" style="margin-top:8px"><button class="df-btn" type="button" id="df-ai-description-build">Prepara campi</button></div></div></details></div>
     <div class="df-ai-box"><h4>2. Incolla o carica il risultato</h4><textarea class="df-ai-json" id="df-ai-json" spellcheck="false" placeholder='{"format":"xdecaro-forms-ai","schema_version":1,"fields":[...]}'></textarea><div class="df-ai-file-row"><input type="file" id="df-ai-file" accept="application/json,.json"><span class="df-note">Solo JSON · massimo 1 MB</span></div><div class="df-ai-actions"><button class="df-btn df-primary" type="button" id="df-ai-check">Controlla e mostra anteprima</button></div><div class="df-ai-error" id="df-ai-error" hidden></div></div>
    </div>
    <div class="df-ai-preview" id="df-ai-preview" hidden><div class="df-ai-preview-head"><div><div class="df-ai-preview-summary" id="df-ai-preview-summary"></div><div class="df-note">Correggi i campi prima dell’importazione. I duplicati e i riconoscimenti poco sicuri sono evidenziati.</div></div><div class="df-ai-preview-tools"><button class="df-btn df-small" type="button" id="df-ai-select-all">Seleziona tutti</button><button class="df-btn df-small" type="button" id="df-ai-select-safe">Solo sicuri</button><label><span class="df-note">Posizione</span> <select id="df-ai-position"><option value="append">In fondo al modulo</option><option value="current">Dopo la riga del campo corrente</option></select></label></div></div><div class="df-ai-preview-list" id="df-ai-preview-list"></div></div>
   </div>
   <div class="df-ai-foot"><button class="df-btn" type="button" data-ai-close>Annulla</button><button class="df-btn df-primary" type="button" id="df-ai-import" disabled>Importa nel modulo <span class="df-ai-import-count" id="df-ai-import-count">· 0 campi</span></button></div>
  </div>
 </div>`);
 return !!document.getElementById('df-ai-import-modal');
}
ensureAiImportDom();
const aiModal=document.getElementById('df-ai-import-modal'),aiJson=document.getElementById('df-ai-json'),aiError=document.getElementById('df-ai-error'),aiPreview=document.getElementById('df-ai-preview'),aiPreviewList=document.getElementById('df-ai-preview-list'),aiImportButton=document.getElementById('df-ai-import'),aiImportCount=document.getElementById('df-ai-import-count');'''
if anchor not in s:
    raise SystemExit('1.3.28 patch: AI runtime anchor not found')
s = s.replace(anchor, replacement, 1)

# Guard open/close too: never throw if markup is unavailable.
s = s.replace("function aiOpen(){if(editorLocked)return;aiShowError('');aiModal.hidden=false;aiModal.setAttribute('aria-hidden','false');document.body.style.overflow='hidden';requestAnimationFrame(()=>document.getElementById('df-ai-copy-prompt')?.focus());}",
              "function aiOpen(){if(editorLocked)return;if(!aiModal){console.error('Forms AI: modal non disponibile');return;}aiShowError('');aiModal.hidden=false;aiModal.setAttribute('aria-hidden','false');document.body.style.overflow='hidden';requestAnimationFrame(()=>document.getElementById('df-ai-copy-prompt')?.focus());}", 1)
s = s.replace("function aiClose(){aiModal.hidden=true;aiModal.setAttribute('aria-hidden','true');document.body.style.overflow='';}",
              "function aiClose(){if(!aiModal)return;aiModal.hidden=true;aiModal.setAttribute('aria-hidden','true');document.body.style.overflow='';}", 1)

# Undo/redo safety: old or partial history states must never make layout undefined.
old_restore = "builderConfig=s.builderConfig;emailConfig=s.emailConfig;"
new_restore = "builderConfig=s.builderConfig&&typeof s.builderConfig==='object'?s.builderConfig:{};builderConfig.layout={columns:1,widths:[100],mobile_stack:true,...(builderConfig.layout||{})};emailConfig=s.emailConfig;"
if old_restore not in s:
    raise SystemExit('1.3.28 patch: restoreHistory anchor not found')
s = s.replace(old_restore, new_restore, 1)

old_render = "function renderLayout(){let n=Math.max(1,Math.min(4,Number(builderConfig.layout.columns||1)));"
new_render = "function renderLayout(){builderConfig=builderConfig&&typeof builderConfig==='object'?builderConfig:{};builderConfig.layout={columns:1,widths:[100],mobile_stack:true,...(builderConfig.layout||{})};let n=Math.max(1,Math.min(4,Number(builderConfig.layout.columns||1)));"
if old_render not in s:
    raise SystemExit('1.3.28 patch: renderLayout anchor not found')
s = s.replace(old_render, new_render, 1)

s = s.replace("window.dfBuilderRuntime={version:'1.3.27'", "window.dfBuilderRuntime={version:'1.3.28'", 1)
path.write_text(s, encoding='utf-8')
PY

# Upgrade component metadata/version strings.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)

# Static checks before packaging.
php -l "$BUILDER" >/dev/null
python3 - "$BUILDER" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
assert 'id="df-ai-import-modal"' in s
assert 'function ensureAiImportDom()' in s
assert "version:'1.3.28'" in s
assert "builderConfig.layout={columns:1,widths:[100],mobile_stack:true,...(builderConfig.layout||{})}" in s
a=s.index('/* Forms 1.3.28: AI field import runtime guard')
b=s.index('/* Forms 1.3.6: bind quick templates', a)
Path('/tmp/forms-ai-1328-check.js').write_text(s[a:b], encoding='utf-8')
PY
node --check /tmp/forms-ai-1328-check.js >/dev/null

rm -f "$COMP_OLD"
(cd "$TMP/component" && zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .)

# Keep other versioned subpackages coherent.
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
<fix>Corretto il pulsante “Importa con AI”: la finestra AI viene ora garantita anche se il DOM non contiene il blocco statico atteso.</fix>
<fix>Il runtime AI ricrea in sicurezza la modal prima di collegare i controlli, evitando l’errore “Cannot set properties of null”.</fix>
<fix>Rafforzati Undo/Redo e renderLayout: builderConfig.layout viene sempre normalizzato prima dell’uso.</fix>
<security>Restano attivi validazione JSON, allowlist dei tipi, limiti di importazione e sanificazione già introdotti in 1.3.27.</security>
<language>it-IT</language>
</changelog></changelogs>
EOF

rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
