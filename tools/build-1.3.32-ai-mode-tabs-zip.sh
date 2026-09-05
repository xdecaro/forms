#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OLD="1.3.31"
NEW="1.3.32"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-ai-1332-check.js' EXIT

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

# Saved-page mode now accepts a normal HTML file or a ZIP produced from
# "Pagina web, completa". Keep the upload local in the browser.
s=s.replace('Da pagina HTML','Da pagina salvata')
s=s.replace('Carica una pagina .html salvata dal sito. Forms legge direttamente i campi, comprese select e possibili campi condizionali nascosti.',
            'Carica una pagina salvata dal sito in formato HTML oppure ZIP. Forms legge i campi e usa anche le risorse locali disponibili per ricostruire meglio layout e struttura.')
s=s.replace('accept="text/html,.html,.htm"',
            'accept="text/html,.html,.htm,.zip,application/zip,application/x-zip-compressed"')
s=s.replace('title="Rimuovi file HTML" aria-label="Rimuovi file HTML"',
            'title="Rimuovi pagina" aria-label="Rimuovi pagina"')
s=s.replace('>Analizza HTML</button>','>Analizza pagina</button>')
s=s.replace('HTML massimo 5 MB','HTML/ZIP massimo 25 MB')

# Dynamic three-card selector: active mode 50%, the other two 25% each.
css_anchor='</style>'
css=r'''

/* Forms 1.3.32: three-mode AI selector, active 50% + 25% + 25%. */
.df-ai-modes.is-chatgpt{grid-template-columns:minmax(0,2fr) minmax(0,1fr) minmax(0,1fr)}
.df-ai-modes.is-page{grid-template-columns:minmax(0,1fr) minmax(0,2fr) minmax(0,1fr)}
.df-ai-modes.is-direct{grid-template-columns:minmax(0,1fr) minmax(0,1fr) minmax(0,2fr)}
.df-ai-mode[data-ai-mode-select]{cursor:pointer;min-width:0;transition:grid-column .18s ease,border-color .18s ease,box-shadow .18s ease,background .18s ease,opacity .18s ease}
.df-ai-mode[data-ai-mode-select]:not(.is-active){opacity:.78}
.df-ai-mode[data-ai-mode-select]:hover,.df-ai-mode[data-ai-mode-select]:focus-visible{opacity:1;border-color:#7c3aed;outline:none}
.df-ai-mode[data-ai-mode-select].is-active{opacity:1;border-color:#7c3aed;box-shadow:0 0 0 2px color-mix(in srgb,#7c3aed 12%,transparent)}
.df-ai-mode-panels{margin-top:14px}.df-ai-mode-panel[hidden]{display:none!important}.df-ai-mode-panel{display:block}
.df-ai-mode-panel>.df-ai-workflow{margin:0}.df-ai-page-panel,.df-ai-direct-panel{border:1px solid var(--df-border);border-radius:10px;padding:14px;background:var(--bs-body-bg,#fff)}
.df-ai-page-panel h4,.df-ai-direct-panel h4{margin:0 0 7px;font-size:15px}.df-ai-page-panel .df-ai-file-row{margin:12px 0 0}
@media(max-width:820px){.df-ai-modes.is-chatgpt,.df-ai-modes.is-page,.df-ai-modes.is-direct{grid-template-columns:1fr}}
'''
if css_anchor not in s:
    raise SystemExit('1.3.32: style anchor missing')
s=s.replace(css_anchor,css+css_anchor,1)

# CSS resource hints from a complete-page ZIP. This supplements the existing
# inline/UIkit/Bootstrap width detection without executing foreign CSS/JS.
width_fn='function aiHtmlWidth(el,root){'
if width_fn not in s:
    raise SystemExit('1.3.32: aiHtmlWidth anchor missing')
css_hint=r'''
function aiRegexEscape(v){return String(v||'').replace(/[.*+?^${}()|[\]\\]/g,'\\$&');}
function aiCssWidthHint(el,root,cssText=''){if(!cssText)return null;let n=el,depth=0;while(n&&n!==root&&depth++<7){for(const cls of [...(n.classList||[])]){if(!/^[A-Za-z0-9_-]{1,80}$/.test(cls))continue;const re=new RegExp('\\.'+aiRegexEscape(cls)+'(?:[^,{]*)\\{([^}]*)\\}','gi');let m,found=null;while((m=re.exec(cssText))){const body=m[1]||'',wm=body.match(/(?:^|;)\\s*(?:width|flex-basis)\\s*:\\s*(\\d+(?:\\.\\d+)?)%/i);if(wm)found=Number(wm[1]);}if(found>0&&found<=100)return aiNearestWidth(found);}n=n.parentElement;}return null;}
'''
s=s.replace(width_fn,css_hint+'\nfunction aiHtmlWidth(el,root,cssText=\'\'){',1)

# UIkit parent utility such as uk-child-width-1-2@m means each child is 50%.
old_segment="const cls=String(n.className||'');for(const m of cls.matchAll(/(?:^|\\s)col(?:-(xs|sm|md|lg|xl|xxl))?-(\\d{1,2})(?=\\s|$)/gi))"
new_segment="const cls=String(n.className||'');const childUk=cls.match(/(?:^|\\s)uk-child-width-(\\d+)-(\\d+)(?:@[a-z]+)?(?=\\s|$)/i);if(childUk){const a=Number(childUk[1]),b=Number(childUk[2]);if(a>0&&b>0)return aiNearestWidth(100*a/b);}for(const m of cls.matchAll(/(?:^|\\s)col(?:-(xs|sm|md|lg|xl|xxl))?-(\\d{1,2})(?=\\s|$)/gi))"
if old_segment not in s:
    raise SystemExit('1.3.32: width class segment missing')
s=s.replace(old_segment,new_segment,1)

old_width_tail='return best!=null?aiNearestWidth(best):100;}'
new_width_tail="const cssHint=aiCssWidthHint(el,root,cssText);if(cssHint)return cssHint;return best!=null?aiNearestWidth(best):100;}"
# Only the aiHtmlWidth occurrence should match this exact tail.
idx=s.find(old_width_tail,s.find('function aiHtmlWidth('))
if idx<0:
    raise SystemExit('1.3.32: aiHtmlWidth tail missing')
s=s[:idx]+new_width_tail+s[idx+len(old_width_tail):]

# Let the HTML parser receive extracted CSS text.
s=s.replace('function aiHtmlParsePage(html){','function aiHtmlParsePage(html,assets={}){',1)
s=s.replace('const width=aiHtmlWidth(el,root);','const width=aiHtmlWidth(el,root,assets.css||\'\');',1)

# Local ZIP reader. It reads only text resources needed for form reconstruction,
# ignores images/fonts, and never executes scripts from the foreign page.
insert_before="document.getElementById('df-ai-html-analyze')?.addEventListener('click',async()=>{"
if insert_before not in s:
    raise SystemExit('1.3.32: saved-page analyze handler anchor missing')
zip_js=r'''
function aiZipU16(view,pos){return view.getUint16(pos,true)}
function aiZipU32(view,pos){return view.getUint32(pos,true)}
async function aiZipInflateRaw(bytes){if(typeof DecompressionStream==='undefined')throw new Error('Questo browser non supporta la decompressione ZIP locale. Usa un file HTML oppure aggiorna il browser.');let stream;try{stream=new Blob([bytes]).stream().pipeThrough(new DecompressionStream('deflate-raw'));}catch{throw new Error('Impossibile decomprimere il file ZIP in questo browser.');}return new Uint8Array(await new Response(stream).arrayBuffer());}
function aiZipFindEnd(view){const min=Math.max(0,view.byteLength-65557);for(let p=view.byteLength-22;p>=min;p--){if(view.getUint32(p,true)===0x06054b50)return p;}return-1;}
async function aiReadZipPage(file){const buffer=await file.arrayBuffer(),view=new DataView(buffer),bytes=new Uint8Array(buffer),end=aiZipFindEnd(view);if(end<0)throw new Error('Il file ZIP non è valido o non contiene una directory ZIP leggibile.');const count=aiZipU16(view,end+10),central=aiZipU32(view,end+16);if(count>3000)throw new Error('Lo ZIP contiene troppi file. Salva soltanto la pagina web completa.');let pos=central,totalText=0;const decoder=new TextDecoder('utf-8'),htmlFiles=[],cssFiles=[],jsFiles=[];for(let i=0;i<count;i++){if(pos+46>view.byteLength||view.getUint32(pos,true)!==0x02014b50)break;const flags=aiZipU16(view,pos+8),method=aiZipU16(view,pos+10),compSize=aiZipU32(view,pos+20),rawSize=aiZipU32(view,pos+24),nameLen=aiZipU16(view,pos+28),extraLen=aiZipU16(view,pos+30),commentLen=aiZipU16(view,pos+32),local=aiZipU32(view,pos+42),name=decoder.decode(bytes.slice(pos+46,pos+46+nameLen));pos+=46+nameLen+extraLen+commentLen;if(!name||name.endsWith('/')||(flags&1))continue;const lower=name.toLowerCase(),kind=/\.html?$/.test(lower)?'html':/\.css$/.test(lower)?'css':/\.js$/.test(lower)?'js':'';if(!kind)continue;if(rawSize>4*1024*1024||totalText+rawSize>12*1024*1024)continue;if(local+30>view.byteLength||view.getUint32(local,true)!==0x04034b50)continue;const ln=aiZipU16(view,local+26),le=aiZipU16(view,local+28),start=local+30+ln+le,endData=start+compSize;if(endData>view.byteLength)continue;let out;if(method===0)out=bytes.slice(start,endData);else if(method===8)out=await aiZipInflateRaw(bytes.slice(start,endData));else continue;totalText+=out.byteLength;const text=decoder.decode(out);if(kind==='html')htmlFiles.push({name,text});else if(kind==='css')cssFiles.push({name,text});else jsFiles.push({name,text});}if(!htmlFiles.length)throw new Error('Nello ZIP non è stato trovato alcun file .html o .htm.');const score=x=>{const t=x.text||'';return((t.match(/<form\b/gi)||[]).length*10000)+((t.match(/<(?:input|select|textarea)\b/gi)||[]).length*100)+Math.min(t.length,500000)/1000;};htmlFiles.sort((a,b)=>score(b)-score(a));const css=cssFiles.map(x=>x.text).join('\n').slice(0,3*1024*1024),js=jsFiles.map(x=>x.text).join('\n').slice(0,2*1024*1024);return{html:htmlFiles[0].text,css,js,mainName:htmlFiles[0].name,resourceCount:cssFiles.length+jsFiles.length};}
async function aiReadSavedPage(file){const lower=String(file?.name||'').toLowerCase();if(lower.endsWith('.zip')||/zip/.test(String(file?.type||'')))return aiReadZipPage(file);return{html:await file.text(),css:'',js:'',mainName:file.name||'pagina.html',resourceCount:0};}
'''
s=s.replace(insert_before,zip_js+'\n'+insert_before,1)

# Replace the old HTML-only analysis handler with HTML/ZIP handling.
old_handler="document.getElementById('df-ai-html-analyze')?.addEventListener('click',async()=>{const input=document.getElementById('df-ai-html-file'),file=input?.files?.[0],status=document.getElementById('df-ai-html-status');if(!file){aiShowError('Seleziona prima un file .html o .htm.');return;}if(file.size>5*1024*1024){aiShowError('Il file HTML supera 5 MB. Salva solo la pagina HTML o usa una versione più leggera.');return;}try{if(status)status.textContent='Analisi HTML…';const html=await file.text(),fields=aiHtmlParsePage(html);aiShowError('');aiPrepare(fields);if(status)status.textContent=`✓ ${fields.length} campi trovati`;}catch(err){if(status)status.textContent='Analisi non riuscita';aiShowError(err?.message||'Impossibile analizzare il file HTML.');}});"
new_handler="document.getElementById('df-ai-html-analyze')?.addEventListener('click',async()=>{const input=document.getElementById('df-ai-html-file'),file=input?.files?.[0],status=document.getElementById('df-ai-html-status');if(!file){aiShowError('Seleziona prima un file HTML oppure ZIP.');return;}if(file.size>25*1024*1024){aiShowError('Il file supera 25 MB. Crea uno ZIP più leggero oppure carica soltanto il file HTML.');return;}try{if(status)status.textContent='Analisi pagina…';const page=await aiReadSavedPage(file),fields=aiHtmlParsePage(page.html,{css:page.css,js:page.js});aiShowError('');aiPrepare(fields);if(status)status.textContent=`✓ ${fields.length} campi trovati${page.resourceCount?` · ${page.resourceCount} risorse CSS/JS lette`:''}`;}catch(err){if(status)status.textContent='Analisi non riuscita';aiShowError(err?.message||'Impossibile analizzare la pagina salvata.');}});"
if old_handler not in s:
    raise SystemExit('1.3.32: old HTML-only handler missing')
s=s.replace(old_handler,new_handler,1)

# Update clear/reset status text for page mode.
s=s.replace("if(status)status.textContent='HTML massimo 5 MB';","if(status)status.textContent='HTML/ZIP massimo 25 MB';")
s=s.replace("if(htmlStatus)htmlStatus.textContent='HTML massimo 5 MB';","if(htmlStatus)htmlStatus.textContent='HTML/ZIP massimo 25 MB';")

# Insert the mode selector after the 1.3.31 clear-button wiring. It restructures
# the existing DOM instead of duplicating the proven ChatGPT/page workflows.
mode_anchor="document.getElementById('df-ai-html-clear')?.addEventListener('click',()=>{const input=document.getElementById('df-ai-html-file'),status=document.getElementById('df-ai-html-status');if(input)input.value='';if(status)status.textContent='HTML/ZIP massimo 25 MB';aiClearPreparedPreview();aiRefreshFileClearButtons();});"
if mode_anchor not in s:
    raise SystemExit('1.3.32: clear-button anchor missing')
mode_js=r'''
function aiInitModeSelector(){const modal=document.getElementById('df-ai-import-modal');if(!modal)return;const modes=modal.querySelector('.df-ai-modes');if(!modes||modes.dataset.aiModesReady==='1')return;const pageCard=modes.querySelector('.df-ai-html-mode'),directCard=[...modes.querySelectorAll('.df-ai-mode')].find(x=>x.textContent.includes('Analizza direttamente')),workflow=modal.querySelector('.df-ai-workflow');if(!pageCard||!directCard||!workflow)return;modes.dataset.aiModesReady='1';const chatCard=document.createElement('div');chatCard.className='df-ai-mode is-active';chatCard.dataset.aiModeSelect='chatgpt';chatCard.tabIndex=0;chatCard.setAttribute('role','button');chatCard.innerHTML='<div class="df-ai-mode-head"><strong>✨ Usa ChatGPT</strong><span class="df-ai-badge df-ai-badge-free">Senza API</span></div><div class="df-ai-direct-note">Screenshot + file istruzioni → JSON pronto per Forms.</div>';modes.insertBefore(chatCard,pageCard);pageCard.dataset.aiModeSelect='page';pageCard.tabIndex=0;pageCard.setAttribute('role','button');const pageTitle=pageCard.querySelector('strong');if(pageTitle)pageTitle.textContent='📄 Da pagina salvata';const pageNote=pageCard.querySelector('.df-ai-direct-note');if(pageNote)pageNote.textContent='HTML o ZIP della pagina completa, con struttura e risorse locali.';const pageFileRow=pageCard.querySelector('.df-ai-file-row');if(pageFileRow)pageFileRow.remove();directCard.classList.remove('is-disabled');directCard.removeAttribute('aria-disabled');directCard.dataset.aiModeSelect='direct';directCard.tabIndex=0;directCard.setAttribute('role','button');const panels=document.createElement('div');panels.className='df-ai-mode-panels';const chatPanel=document.createElement('div');chatPanel.className='df-ai-mode-panel';chatPanel.dataset.aiPanel='chatgpt';chatPanel.appendChild(workflow);const pagePanel=document.createElement('div');pagePanel.className='df-ai-mode-panel df-ai-page-panel';pagePanel.dataset.aiPanel='page';pagePanel.hidden=true;pagePanel.innerHTML='<h4>Da pagina salvata</h4><div class="df-ai-direct-note">Carica <strong>.html / .htm / .zip</strong>. Con uno ZIP di “Pagina web, completa”, Forms prova a usare anche CSS e risorse locali per riconoscere meglio il layout.</div>';if(pageFileRow)pagePanel.appendChild(pageFileRow);const directPanel=document.createElement('div');directPanel.className='df-ai-mode-panel df-ai-direct-panel';directPanel.dataset.aiPanel='direct';directPanel.hidden=true;directPanel.innerHTML='<h4>⚡ Analizza direttamente</h4><div class="df-ai-direct-note">Funzione API opzionale prevista per una versione futura. Al momento non effettua chiamate esterne.</div>';panels.append(chatPanel,pagePanel,directPanel);modes.after(panels);const cards={chatgpt:chatCard,page:pageCard,direct:directCard};function selectMode(name){modes.classList.remove('is-chatgpt','is-page','is-direct');modes.classList.add('is-'+name);Object.entries(cards).forEach(([k,c])=>{c.classList.toggle('is-active',k===name);c.setAttribute('aria-pressed',k===name?'true':'false');});panels.querySelectorAll('[data-ai-panel]').forEach(p=>p.hidden=p.dataset.aiPanel!==name);}Object.entries(cards).forEach(([name,card])=>{card.addEventListener('click',()=>selectMode(name));card.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();selectMode(name);}});});selectMode('chatgpt');}
aiInitModeSelector();
document.getElementById('df-open-ai-import')?.addEventListener('click',()=>queueMicrotask(aiInitModeSelector),true);
'''
s=s.replace(mode_anchor,mode_anchor+'\n'+mode_js,1)

s=s.replace('/* Forms 1.3.31: AI import single-column UX + file clear controls + runtime guard. */','/* Forms 1.3.32: AI mode selector + saved-page ZIP import + runtime guard. */',1)
s=s.replace("window.dfBuilderRuntime={version:'1.3.31'","window.dfBuilderRuntime={version:'1.3.32'",1)

# Build-time guards.
assert 'Da pagina salvata' in s
assert '.zip,application/zip' in s
assert 'Analizza pagina' in s
assert 'function aiReadZipPage' in s
assert 'function aiInitModeSelector' in s
assert 'uk-child-width-' in s
assert 'grid-template-columns:minmax(0,2fr)' in s
assert "version:'1.3.32'" in s
path.write_text(s,encoding='utf-8')
PY

# Update component metadata/version strings.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)

php -l "$BUILDER" >/dev/null
python3 - "$BUILDER" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
assert 'Da pagina salvata' in s
assert 'function aiReadZipPage' in s
assert 'function aiInitModeSelector' in s
assert 'HTML/ZIP massimo 25 MB' in s
assert "version:'1.3.32'" in s
a=s.index('/* Forms 1.3.32: AI mode selector')
b=s.index('/* Forms 1.3.6: bind quick templates',a)
Path('/tmp/forms-ai-1332-check.js').write_text(s[a:b],encoding='utf-8')
PY
node --check /tmp/forms-ai-1332-check.js >/dev/null

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
<improvement>Importa con AI: tre modalità sempre visibili con larghezza dinamica 50/25/25; la modalità selezionata occupa metà riga.</improvement>
<improvement>Sotto le tre modalità viene mostrato soltanto il pannello relativo alla scelta corrente, eliminando i blocchi ripetuti e rendendo il flusso più ordinato.</improvement>
<feature>“Da pagina salvata” accetta HTML, HTM e ZIP creati da “Pagina web, completa”. Lo ZIP viene letto localmente nel browser senza inviare file a servizi esterni.</feature>
<improvement>Il parser riconosce anche utility UIkit come uk-child-width-1-2@m e usa semplici regole di larghezza presenti nei CSS inclusi nello ZIP.</improvement>
<security>I file ZIP vengono trattati come dati: script e stili della pagina originale non vengono eseguiti. Sono letti solo file testuali HTML/CSS/JS entro limiti di dimensione.</security>
<language>it-IT</language>
</changelog></changelogs>
EOF

rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
