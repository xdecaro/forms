#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OLD="1.3.26"
NEW="1.3.27"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

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

old_button = '''            <button class="df-add-field-main" type="button" id="df-open-library"><span aria-hidden="true">＋</span> Aggiungi campo</button>'''
new_button = '''            <div class="df-field-entry-actions">
              <button class="df-add-field-main" type="button" id="df-open-library"><span aria-hidden="true">＋</span> Aggiungi campo</button>
              <button class="df-ai-import-main" type="button" id="df-open-ai-import"><span aria-hidden="true">✨</span> Importa con AI</button>
            </div>'''
if old_button not in s:
    raise SystemExit('AI patch: Aggiungi campo anchor not found')
s = s.replace(old_button, new_button, 1)

css_anchor = '</style>'
ai_css = r'''

/* Forms 1.3.27: importazione campi con AI, senza API obbligatoria. */
.df-field-entry-actions{display:flex;gap:9px;align-items:stretch;margin-top:10px}.df-field-entry-actions>.df-add-field-main,.df-field-entry-actions>.df-ai-import-main{flex:1;min-width:0}.df-ai-import-main{display:flex;align-items:center;justify-content:center;gap:7px;min-height:43px;border:1px solid color-mix(in srgb,#7c3aed 72%,var(--df-border));border-radius:7px;background:color-mix(in srgb,#7c3aed 7%,var(--bs-body-bg,#fff));color:color-mix(in srgb,#7c3aed 84%,var(--bs-body-color,#1f2937));font-weight:850;cursor:pointer;transition:background .16s ease,border-color .16s ease,transform .16s ease}.df-ai-import-main:hover,.df-ai-import-main:focus-visible{background:color-mix(in srgb,#7c3aed 13%,var(--bs-body-bg,#fff));border-color:#7c3aed;outline:none}.df-ai-modal[hidden]{display:none!important}.df-ai-modal{position:fixed;inset:0;z-index:2147483600;display:grid;place-items:center;padding:18px}.df-ai-backdrop{position:absolute;inset:0;background:rgba(15,23,42,.70);backdrop-filter:blur(2px)}.df-ai-dialog{position:relative;z-index:1;width:min(1060px,calc(100vw - 30px));max-height:calc(100vh - 30px);display:flex;flex-direction:column;background:var(--bs-body-bg,#fff);color:var(--bs-body-color,#1f2937);border:1px solid var(--bs-border-color,#d9dee5);border-radius:14px;box-shadow:0 26px 80px rgba(0,0,0,.30);overflow:hidden}.df-ai-head,.df-ai-foot{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:14px 17px;background:var(--bs-tertiary-bg,#f6f7f9);border-bottom:1px solid var(--bs-border-color,#d9dee5)}.df-ai-foot{justify-content:flex-end;border-top:1px solid var(--bs-border-color,#d9dee5);border-bottom:0}.df-ai-head-title{display:flex;flex-direction:column;gap:2px}.df-ai-head-title strong{font-size:18px}.df-ai-close{width:38px;height:38px;border:1px solid var(--bs-border-color,#d9dee5);border-radius:8px;background:var(--bs-body-bg,#fff);color:inherit;font-size:22px;line-height:1;cursor:pointer}.df-ai-body{padding:17px;overflow:auto}.df-ai-intro{margin:0 0 14px;color:var(--bs-secondary-color,#667085)}.df-ai-modes{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:14px}.df-ai-mode{border:1px solid var(--df-border);border-radius:10px;padding:13px;background:var(--bs-body-bg,#fff)}.df-ai-mode.is-active{border-color:#7c3aed;box-shadow:0 0 0 2px color-mix(in srgb,#7c3aed 12%,transparent)}.df-ai-mode.is-disabled{opacity:.72;background:var(--bs-tertiary-bg,#f7f8fa)}.df-ai-mode-head{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-bottom:5px}.df-ai-badge{display:inline-flex;align-items:center;min-height:22px;padding:0 8px;border-radius:999px;background:var(--bs-tertiary-bg,#f1f3f5);font-size:11px;font-weight:850}.df-ai-badge-free{background:color-mix(in srgb,#198754 12%,transparent);color:#198754}.df-ai-badge-soon{background:color-mix(in srgb,#6c757d 12%,transparent);color:var(--bs-secondary-color,#667085)}.df-ai-workflow{display:grid;grid-template-columns:minmax(0,.95fr) minmax(0,1.05fr);gap:14px}.df-ai-box{border:1px solid var(--df-border);border-radius:10px;padding:14px;background:var(--bs-body-bg,#fff)}.df-ai-box h4{margin:0 0 8px;font-size:15px}.df-ai-steps{margin:0 0 12px;padding-left:20px;color:var(--bs-secondary-color,#667085)}.df-ai-steps li+li{margin-top:4px}.df-ai-actions{display:flex;gap:8px;flex-wrap:wrap}.df-ai-actions .df-btn{min-height:38px}.df-ai-json,.df-ai-description{width:100%;min-height:150px;border:1px solid var(--df-border);border-radius:7px;background:var(--bs-body-bg,#fff);color:inherit;padding:10px 11px;font:12px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace;resize:vertical}.df-ai-description{min-height:84px;font:inherit}.df-ai-file-row{display:flex;align-items:center;gap:9px;flex-wrap:wrap;margin:9px 0}.df-ai-file-row input[type=file]{max-width:100%}.df-ai-error{margin-top:9px;padding:9px 10px;border:1px solid color-mix(in srgb,#dc3545 45%,var(--df-border));border-radius:7px;background:color-mix(in srgb,#dc3545 7%,var(--bs-body-bg,#fff));color:#b42332;font-weight:750}.df-ai-preview{margin-top:15px;border-top:1px solid var(--df-border);padding-top:14px}.df-ai-preview-head{display:flex;align-items:flex-start;justify-content:space-between;gap:12px;flex-wrap:wrap;margin-bottom:10px}.df-ai-preview-summary{font-weight:850}.df-ai-preview-tools{display:flex;align-items:center;gap:7px;flex-wrap:wrap}.df-ai-preview-tools select{min-height:36px;border:1px solid var(--df-border);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit;padding:0 8px}.df-ai-preview-list{display:flex;flex-direction:column;gap:8px}.df-ai-row{display:grid;grid-template-columns:32px minmax(160px,1.4fr) minmax(120px,.9fr) 96px 92px 96px 76px;gap:8px;align-items:center;border:1px solid var(--df-border);border-radius:9px;padding:10px;background:var(--bs-body-bg,#fff)}.df-ai-row.is-duplicate{border-color:color-mix(in srgb,#f59e0b 65%,var(--df-border));background:color-mix(in srgb,#f59e0b 4%,var(--bs-body-bg,#fff))}.df-ai-row.is-low{border-style:dashed}.df-ai-row input[type=text],.df-ai-row select,.df-ai-row textarea{width:100%;min-height:36px;border:1px solid var(--df-border);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit;padding:7px 8px}.df-ai-row-check{display:grid;place-items:center}.df-ai-row-check input{width:18px;height:18px}.df-ai-required{display:flex;align-items:center;justify-content:center;gap:5px;font-size:12px}.df-ai-required input{width:17px;height:17px}.df-ai-confidence{display:inline-flex;justify-content:center;align-items:center;min-height:25px;padding:0 7px;border-radius:999px;font-size:11px;font-weight:850}.df-ai-confidence.high{background:color-mix(in srgb,#198754 12%,transparent);color:#198754}.df-ai-confidence.medium{background:color-mix(in srgb,#f59e0b 14%,transparent);color:#9a6700}.df-ai-confidence.low{background:color-mix(in srgb,#dc3545 11%,transparent);color:#b42332}.df-ai-order{display:flex;gap:4px;justify-content:flex-end}.df-ai-order button{width:32px;height:32px;border:1px solid var(--df-border);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit;cursor:pointer}.df-ai-row-extra{grid-column:2/-1;display:grid;grid-template-columns:1fr 1fr;gap:8px}.df-ai-row-extra .df-ai-options-wrap.is-hidden{display:none}.df-ai-row-extra label{display:flex;flex-direction:column;gap:4px;font-size:11px;font-weight:800}.df-ai-row-extra textarea{min-height:58px;resize:vertical}.df-ai-warning{grid-column:2/-1;font-size:11px;color:#9a6700;font-weight:750}.df-ai-quick{margin-top:12px;border:1px dashed var(--df-border);border-radius:8px;padding:10px}.df-ai-quick summary{cursor:pointer;font-weight:850}.df-ai-quick-body{margin-top:10px}.df-ai-import-count{font-weight:850}.df-ai-direct-note{font-size:12px;color:var(--bs-secondary-color,#667085)}
[data-bs-theme="dark"] .df-ai-confidence.medium,html[data-bs-theme="dark"] .df-ai-confidence.medium{color:#ffd166}.df-builder.is-locked .df-ai-import-main{opacity:.55;cursor:not-allowed}
@media(max-width:820px){.df-ai-workflow,.df-ai-modes{grid-template-columns:1fr}.df-ai-row{grid-template-columns:30px minmax(0,1fr) minmax(110px,.7fr) 86px}.df-ai-row>.df-ai-required,.df-ai-row>.df-ai-confidence,.df-ai-row>.df-ai-order{grid-row:auto}.df-ai-row-extra,.df-ai-warning{grid-column:2/-1}.df-ai-row-extra{grid-template-columns:1fr}.df-field-entry-actions{flex-direction:column}}
@media(max-width:560px){.df-ai-modal{padding:8px}.df-ai-dialog{width:calc(100vw - 16px);max-height:calc(100vh - 16px)}.df-ai-head,.df-ai-foot,.df-ai-body{padding:12px}.df-ai-row{grid-template-columns:30px 1fr}.df-ai-row>*{grid-column:2}.df-ai-row-check{grid-column:1;grid-row:1/5}.df-ai-row-extra,.df-ai-warning{grid-column:2}.df-ai-order{justify-content:flex-start}.df-ai-foot{flex-wrap:wrap}.df-ai-foot .df-btn{flex:1}}
'''
if css_anchor not in s:
    raise SystemExit('AI patch: style anchor not found')
s = s.replace(css_anchor, ai_css + '\n' + css_anchor, 1)

modal_anchor = '''  <div class="df-preview-modal" id="df-email-preview-modal" hidden><div class="df-preview-backdrop" data-preview-close></div><div class="df-preview-dialog" role="dialog" aria-modal="true"><div class="df-preview-head"><div><strong id="df-preview-title"></strong><div class="df-note" id="df-preview-subject"></div></div><button class="df-preview-x" type="button" data-preview-close>×</button></div><div class="df-preview-body"><div class="df-preview-canvas" id="df-preview-canvas"></div></div><div class="df-preview-foot"><button class="df-btn" type="button" data-preview-close><?php echo Text::_('COM_DECAROFORMS_CLOSE'); ?></button></div></div></div>'''
ai_modal = r'''

  <div class="df-ai-modal" id="df-ai-import-modal" hidden aria-hidden="true">
    <div class="df-ai-backdrop" data-ai-close></div>
    <div class="df-ai-dialog" role="dialog" aria-modal="true" aria-labelledby="df-ai-title">
      <div class="df-ai-head"><div class="df-ai-head-title"><strong id="df-ai-title">✨ Importa campi con AI</strong><span class="df-note">L’AI prepara una bozza: i campi entrano nel modulo solo dopo la tua conferma.</span></div><button class="df-ai-close" type="button" data-ai-close aria-label="Chiudi">×</button></div>
      <div class="df-ai-body">
        <p class="df-ai-intro">Ricrea solo i campi del modulo. Template, CSS, colori, immagini, pulsanti decorativi e contenuti del sito originale non vengono importati.</p>
        <div class="df-ai-modes">
          <div class="df-ai-mode is-active"><div class="df-ai-mode-head"><strong>✨ Usa ChatGPT</strong><span class="df-ai-badge df-ai-badge-free">Senza API</span></div><div class="df-ai-direct-note">Carica lo screenshot nella normale chat ChatGPT, usa il prompt di Forms e riporta qui il JSON generato.</div></div>
          <div class="df-ai-mode is-disabled" aria-disabled="true"><div class="df-ai-mode-head"><strong>⚡ Analizza direttamente</strong><span class="df-ai-badge df-ai-badge-soon">API opzionale · prossimamente</span></div><div class="df-ai-direct-note">In futuro potrà analizzare lo screenshot senza uscire dal Builder. Richiederà un provider API configurato.</div></div>
        </div>
        <div class="df-ai-workflow">
          <div class="df-ai-box"><h4>1. Prepara il risultato con ChatGPT</h4><ol class="df-ai-steps"><li>Copia il prompt di Forms.</li><li>Apri ChatGPT e allega lo screenshot del modulo.</li><li>Incolla il prompt e chiedi di generare il JSON.</li><li>Copia il JSON e torna qui.</li></ol><div class="df-ai-actions"><button class="df-btn df-primary" type="button" id="df-ai-copy-prompt">Copia prompt per ChatGPT</button><a class="df-btn" href="https://chatgpt.com/" target="_blank" rel="noopener noreferrer">Apri ChatGPT</a><button class="df-btn" type="button" id="df-ai-download-example">Scarica esempio JSON</button></div><details class="df-ai-quick"><summary>Descrizione rapida senza AI</summary><div class="df-ai-quick-body"><p class="df-note">Per moduli semplici puoi evitare anche ChatGPT. Esempio: “nome, cognome, email, telefono, data di nascita, corso, privacy e note”.</p><textarea class="df-ai-description" id="df-ai-description" placeholder="Descrivi i campi del modulo..."></textarea><div class="df-ai-actions" style="margin-top:8px"><button class="df-btn" type="button" id="df-ai-description-build">Prepara campi</button></div></div></details></div>
          <div class="df-ai-box"><h4>2. Incolla o carica il risultato</h4><textarea class="df-ai-json" id="df-ai-json" spellcheck="false" placeholder='{"format":"xdecaro-forms-ai","schema_version":1,"fields":[...]}'></textarea><div class="df-ai-file-row"><input type="file" id="df-ai-file" accept="application/json,.json"><span class="df-note">Solo JSON · massimo 1 MB</span></div><div class="df-ai-actions"><button class="df-btn df-primary" type="button" id="df-ai-check">Controlla e mostra anteprima</button></div><div class="df-ai-error" id="df-ai-error" hidden></div></div>
        </div>
        <div class="df-ai-preview" id="df-ai-preview" hidden>
          <div class="df-ai-preview-head"><div><div class="df-ai-preview-summary" id="df-ai-preview-summary"></div><div class="df-note">Correggi i campi prima dell’importazione. I duplicati e i riconoscimenti poco sicuri sono evidenziati.</div></div><div class="df-ai-preview-tools"><button class="df-btn df-small" type="button" id="df-ai-select-all">Seleziona tutti</button><button class="df-btn df-small" type="button" id="df-ai-select-safe">Solo sicuri</button><label><span class="df-note">Posizione</span> <select id="df-ai-position"><option value="append">In fondo al modulo</option><option value="current">Dopo la riga del campo corrente</option></select></label></div></div>
          <div class="df-ai-preview-list" id="df-ai-preview-list"></div>
        </div>
      </div>
      <div class="df-ai-foot"><button class="df-btn" type="button" data-ai-close>Annulla</button><button class="df-btn df-primary" type="button" id="df-ai-import" disabled>Importa nel modulo <span class="df-ai-import-count" id="df-ai-import-count">· 0 campi</span></button></div>
    </div>
  </div>'''
if modal_anchor not in s:
    raise SystemExit('AI patch: modal anchor not found')
s = s.replace(modal_anchor, modal_anchor + ai_modal, 1)

js_anchor = '''/* Forms 1.3.6: bind quick templates early so unrelated later initializers cannot disable them. */'''
ai_js = r'''
/* Forms 1.3.27: AI field import. ChatGPT/file flow is local; no API call is made here. */
const aiModal=document.getElementById('df-ai-import-modal'),aiJson=document.getElementById('df-ai-json'),aiError=document.getElementById('df-ai-error'),aiPreview=document.getElementById('df-ai-preview'),aiPreviewList=document.getElementById('df-ai-preview-list'),aiImportButton=document.getElementById('df-ai-import'),aiImportCount=document.getElementById('df-ai-import-count');
const aiAllowedTypes=new Set(['text','email','tel','url','number','date','time','datetime','textarea','select','multiselect','radio','checkboxes','checkbox','toggle','consent','nationality','country','region','city','province','tax_code','postcode','member_number','heading','fieldset','separator']);
const aiWidths=[100,75,66,50,33,25];
const aiChoiceTypes=new Set(['select','multiselect','radio','checkboxes']);
const aiIgnoredTypes=new Set(['button','submit','reset','image','img','html','script','style','hidden','map','payment','calculated','page','pagebreak']);
const aiAliases={phone:'tel',telephone:'tel',telefono:'tel',mail:'email','e-mail':'email',integer:'number',numeric:'number',decimal:'number,birthdate':'date','date_of_birth':'date',multiline:'textarea,'text-area':'textarea',dropdown:'select,combo:'select,combobox:'select,checkbox_group:'checkboxes',checkboxgroup:'checkboxes',checkgroup:'checkboxes',privacy:'consent',gdpr:'consent',section:'heading',title:'heading'};
let aiDraftFields=[];
function aiPromptText(){return `Sei un convertitore di moduli per il componente Joomla Forms di xdecaro.\n\nAnalizza SOLO i campi del modulo presenti nello screenshot allegato. Non copiare template, CSS, colori, font, immagini, logo, menu, pulsanti Invia/Continua/Indietro, testi decorativi del sito, hidden field, token, honeypot o codice. Un titolo va incluso solo se è chiaramente una sezione interna del modulo.\n\nRiconosci quando possibile: etichetta, tipo, obbligatorio, placeholder, opzioni, ordine, riga e larghezza. Non inventare opzioni, testi legali o dati che non si vedono. Se un dato è incerto lascialo vuoto e segnala confidence=low o warning. Se nel campo è già scritto un dato personale, non trasformarlo automaticamente in placeholder.\n\nRestituisci SOLO JSON valido, senza Markdown e senza spiegazioni, con questo formato:\n{\n  "format": "xdecaro-forms-ai",\n  "schema_version": 1,\n  "source": "screenshot",\n  "fields": [\n    {\n      "label": "Nome",\n      "key": "nome",\n      "type": "text",\n      "required": true,\n      "width": 50,\n      "row": 1,\n      "placeholder": "",\n      "options": [],\n      "confidence": "high",\n      "warning": ""\n    }\n  ]\n}\n\nTipi consentiti: ${[...aiAllowedTypes].join(', ')}.\nLarghezze consentite: ${aiWidths.join(', ')}. Usa solo questi valori e scegli quello più vicino al layout visibile.\nconfidence deve essere high, medium oppure low.\nPer select, radio, checkboxes e multiselect inserisci options solo se sono realmente visibili o fornite.\nPer un consenso/privacy usa type=consent oppure checkbox.\nPer una sezione interna reale del form puoi usare type=heading.\nIgnora tutto ciò che non è un campo del modulo.`;}
function aiShowError(message=''){if(!aiError)return;aiError.hidden=!message;aiError.textContent=message;}
function aiOpen(){if(editorLocked)return;aiShowError('');aiModal.hidden=false;aiModal.setAttribute('aria-hidden','false');document.body.style.overflow='hidden';requestAnimationFrame(()=>document.getElementById('df-ai-copy-prompt')?.focus());}
function aiClose(){aiModal.hidden=true;aiModal.setAttribute('aria-hidden','true');document.body.style.overflow='';}
document.getElementById('df-open-ai-import')?.addEventListener('click',aiOpen);aiModal?.querySelectorAll('[data-ai-close]').forEach(x=>x.addEventListener('click',aiClose));document.addEventListener('keydown',e=>{if(e.key==='Escape'&&aiModal&&!aiModal.hidden)aiClose();});
async function aiCopyPrompt(){const btn=document.getElementById('df-ai-copy-prompt'),text=aiPromptText(),old=btn.textContent;try{await navigator.clipboard.writeText(text);}catch{const t=document.createElement('textarea');t.value=text;t.style.position='fixed';t.style.opacity='0';document.body.appendChild(t);t.select();document.execCommand('copy');t.remove();}btn.textContent='✓ Prompt copiato';setTimeout(()=>btn.textContent=old,1500);}
document.getElementById('df-ai-copy-prompt')?.addEventListener('click',aiCopyPrompt);
document.getElementById('df-ai-download-example')?.addEventListener('click',()=>{const example={format:'xdecaro-forms-ai',schema_version:1,source:'screenshot',fields:[{label:'Nome',key:'nome',type:'text',required:true,width:50,row:1,placeholder:'',options:[],confidence:'high',warning:''},{label:'Cognome',key:'cognome',type:'text',required:true,width:50,row:1,placeholder:'',options:[],confidence:'high',warning:''},{label:'Email',key:'email',type:'email',required:true,width:100,row:2,placeholder:'',options:[],confidence:'high',warning:''}]};const blob=new Blob([JSON.stringify(example,null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='forms-ai-example.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),500);});
document.getElementById('df-ai-file')?.addEventListener('change',async e=>{const file=e.target.files?.[0];if(!file)return;if(file.size>1024*1024){aiShowError('Il file JSON supera 1 MB.');e.target.value='';return;}try{aiJson.value=await file.text();aiShowError('');}catch{aiShowError('Impossibile leggere il file JSON.');}});
function aiNorm(v){return String(v||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,'').trim();}
function aiSlug(v){return String(v||'field').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,'_').replace(/^_+|_+$/g,'').slice(0,60)||'field';}
function aiNearestWidth(v){const n=Number(v||100);return aiWidths.reduce((a,b)=>Math.abs(b-n)<Math.abs(a-n)?b:a,100);}
function aiBool(v){if(typeof v==='boolean')return v;if(typeof v==='number')return v===1;return ['1','true','yes','si','sì','required','obbligatorio'].includes(String(v||'').trim().toLowerCase());}
function aiOptions(v){if(Array.isArray(v))return v.map(x=>String(x||'').trim().slice(0,180)).filter(Boolean).slice(0,100);if(typeof v==='string')return v.split(/\r?\n|\s*\|\s*/).map(x=>x.trim().slice(0,180)).filter(Boolean).slice(0,100);return [];}
function aiCategory(type){if(['email','tel','url'].includes(type))return'contact';if(['country','region','city','province','postcode','nationality'].includes(type))return'address';if(aiChoiceTypes.has(type)||['checkbox','toggle'].includes(type))return'choices';if(['number','member_number','tax_code'].includes(type))return'values';if(['date','time','datetime'].includes(type))return'datetime';if(['heading','fieldset','separator'].includes(type))return'structure';if(type==='consent')return'consent';return'personal';}
function aiFindDuplicate(field){const l=aiNorm(field.label),k=aiNorm(field.key);return selected.find(x=>(l&&aiNorm(x.label)===l)||(k&&aiNorm(x.key)===k))||null;}
function aiParse(raw){let text=String(raw||'').trim();if(!text)throw new Error('Incolla il JSON generato da ChatGPT oppure carica un file JSON.');text=text.replace(/^```(?:json)?\s*/i,'').replace(/\s*```$/,'').trim();let data;try{data=JSON.parse(text);}catch{const a=text.indexOf('{'),b=text.lastIndexOf('}');if(a>=0&&b>a){try{data=JSON.parse(text.slice(a,b+1));}catch{}}}if(!data)throw new Error('Il contenuto non è un JSON valido. Chiedi a ChatGPT di restituire solo JSON, senza testo aggiuntivo.');if(data.format&&data.format!=='xdecaro-forms-ai')throw new Error('Il file non usa il formato xdecaro-forms-ai.');const fields=Array.isArray(data)?data:Array.isArray(data.fields)?data.fields:null;if(!fields)throw new Error('Nel JSON manca l’elenco fields.');if(fields.length>100)throw new Error('Il file contiene più di 100 campi. Riduci il modulo prima di importarlo.');return fields;}
function aiNormalizeField(raw,index){if(!raw||typeof raw!=='object')return null;let type=String(raw.type||'text').trim().toLowerCase().replace(/\s+/g,'_');type=aiAliases[type]||type;if(aiIgnoredTypes.has(type))return null;const warnings=[];if(!aiAllowedTypes.has(type)){warnings.push(`Tipo “${type}” non supportato: convertito in Testo.`);type='text';}let label=String(raw.label||raw.name||raw.title||`Campo ${index+1}`).trim().replace(/[<>]/g,'').slice(0,150)||`Campo ${index+1}`;const field={label,key:aiSlug(raw.key||raw.name||label),type,required:aiBool(raw.required),width:aiNearestWidth(raw.width),row:Math.max(0,parseInt(raw.row,10)||0),placeholder:String(raw.placeholder||'').replace(/[<>]/g,'').slice(0,255),options:aiOptions(raw.options),confidence:['high','medium','low'].includes(String(raw.confidence||'').toLowerCase())?String(raw.confidence).toLowerCase():'medium',warning:String(raw.warning||'').replace(/[<>]/g,'').slice(0,260),_include:true,_duplicate:null};if(aiChoiceTypes.has(type)&&!field.options.length)warnings.push('Controlla le opzioni: non sono state fornite.');if(field.warning)warnings.push(field.warning);field._warnings=warnings;field._duplicate=aiFindDuplicate(field);if(field._duplicate){field._warnings.push(`Possibile duplicato di “${field._duplicate.label}” già presente.`);field._include=false;}if(field.confidence==='low'){field._warnings.push('Riconoscimento con poca sicurezza: verifica questo campo.');field._include=false;}return field;}
function aiPrepare(fields){const ignored=fields.length;aiDraftFields=fields.map(aiNormalizeField).filter(Boolean);const skipped=ignored-aiDraftFields.length;if(!aiDraftFields.length)throw new Error('Non ho trovato campi importabili nel risultato.');aiDraftFields.forEach(f=>{f._duplicate=aiFindDuplicate(f);});aiRenderPreview(skipped);}
function aiTypeOptions(current){return [...aiAllowedTypes].map(t=>`<option value="${esc(t)}" ${t===current?'selected':''}>${esc(tr.types[t]||t)}</option>`).join('');}
function aiWidthOptions(current){return aiWidths.map(w=>`<option value="${w}" ${Number(current)===w?'selected':''}>${w}%</option>`).join('');}
function aiRefreshDuplicates(){aiDraftFields.forEach(f=>{f._duplicate=aiFindDuplicate(f);});}
function aiUpdateImportCount(){const n=aiDraftFields.filter(f=>f._include).length;if(aiImportCount)aiImportCount.textContent=`· ${n} camp${n===1?'o':'i'}`;if(aiImportButton)aiImportButton.disabled=n===0;const dup=aiDraftFields.filter(f=>f._duplicate).length,low=aiDraftFields.filter(f=>f.confidence==='low').length,mid=aiDraftFields.filter(f=>f.confidence==='medium').length;const summary=document.getElementById('df-ai-preview-summary');if(summary)summary.textContent=`${aiDraftFields.length} campi riconosciuti · ${dup} duplicat${dup===1?'o':'i'} · ${low+mid} da controllare`;}
function aiRenderPreview(skipped=0){aiRefreshDuplicates();aiPreview.hidden=false;aiPreviewList.innerHTML='';aiDraftFields.forEach((f,i)=>{const row=document.createElement('div');row.className='df-ai-row'+(f._duplicate?' is-duplicate':'')+(f.confidence==='low'?' is-low':'');const warnings=[...new Set(f._warnings||[])];const choice=aiChoiceTypes.has(f.type);row.innerHTML=`<div class="df-ai-row-check"><input type="checkbox" data-ai-include ${f._include?'checked':''} aria-label="Importa ${esc(f.label)}"></div><input type="text" data-ai-label value="${esc(f.label)}" aria-label="Etichetta"><select data-ai-type aria-label="Tipo">${aiTypeOptions(f.type)}</select><label class="df-ai-required"><input type="checkbox" data-ai-required ${f.required?'checked':''}> Obbl.</label><select data-ai-width aria-label="Larghezza">${aiWidthOptions(f.width)}</select><span class="df-ai-confidence ${esc(f.confidence)}">${f.confidence==='high'?'Alta':f.confidence==='low'?'Bassa':'Media'}</span><div class="df-ai-order"><button type="button" data-ai-up title="Sposta su">↑</button><button type="button" data-ai-down title="Sposta giù">↓</button></div><div class="df-ai-row-extra"><label>Placeholder<input type="text" data-ai-placeholder value="${esc(f.placeholder)}"></label><label class="df-ai-options-wrap ${choice?'':'is-hidden'}">Opzioni<textarea data-ai-options>${esc((f.options||[]).join('\n'))}</textarea></label></div>${warnings.length?`<div class="df-ai-warning">⚠ ${warnings.map(esc).join(' · ')}</div>`:''}`;const include=row.querySelector('[data-ai-include]');include.onchange=()=>{f._include=include.checked;aiUpdateImportCount();};row.querySelector('[data-ai-label]').oninput=e=>{f.label=e.target.value.slice(0,150);f.key=aiSlug(f.label);aiRefreshDuplicates();aiRenderPreview(skipped);};row.querySelector('[data-ai-type]').onchange=e=>{f.type=e.target.value;f._warnings=(f._warnings||[]).filter(x=>!x.startsWith('Controlla le opzioni'));if(aiChoiceTypes.has(f.type)&&!f.options.length)f._warnings.push('Controlla le opzioni: non sono state fornite.');aiRenderPreview(skipped);};row.querySelector('[data-ai-required]').onchange=e=>{f.required=e.target.checked;};row.querySelector('[data-ai-width]').onchange=e=>{f.width=Number(e.target.value);};row.querySelector('[data-ai-placeholder]').oninput=e=>{f.placeholder=e.target.value.slice(0,255);};row.querySelector('[data-ai-options]').oninput=e=>{f.options=aiOptions(e.target.value);};row.querySelector('[data-ai-up]').onclick=()=>{if(i<1)return;[aiDraftFields[i-1],aiDraftFields[i]]=[aiDraftFields[i],aiDraftFields[i-1]];aiRenderPreview(skipped);};row.querySelector('[data-ai-down]').onclick=()=>{if(i>=aiDraftFields.length-1)return;[aiDraftFields[i+1],aiDraftFields[i]]=[aiDraftFields[i],aiDraftFields[i+1]];aiRenderPreview(skipped);};aiPreviewList.appendChild(row);});if(skipped){const note=document.createElement('div');note.className='df-note';note.textContent=`${skipped} elemento/i decorativo/i o non importabile/i ignorato/i automaticamente.`;aiPreviewList.appendChild(note);}aiUpdateImportCount();aiPreview.scrollIntoView({behavior:'smooth',block:'nearest'});}
document.getElementById('df-ai-check')?.addEventListener('click',()=>{try{aiShowError('');aiPrepare(aiParse(aiJson.value));}catch(err){aiShowError(err?.message||'Impossibile controllare il risultato.');aiPreview.hidden=true;}});
document.getElementById('df-ai-select-all')?.addEventListener('click',()=>{aiDraftFields.forEach(f=>f._include=true);aiRenderPreview();});document.getElementById('df-ai-select-safe')?.addEventListener('click',()=>{aiDraftFields.forEach(f=>f._include=!f._duplicate&&f.confidence==='high');aiRenderPreview();});
function aiQuickFromDescription(text){const v=String(text||'').toLowerCase(),defs=[[/\bnome\b/,'Nome','nome','text',50],[/\bcognome\b/,'Cognome','cognome','text',50],[/e-?mail/,'Email','email','email',100],[/telefono|cellulare|phone/,'Telefono','telefono','tel',100],[/data di nascita|nascita/,'Data di nascita','data_nascita','date',50],[/codice fiscale/,'Codice fiscale','codice_fiscale','tax_code',50],[/indirizzo/,'Indirizzo','indirizzo','text',100],[/\bcap\b|codice postale/,'CAP','cap','postcode',33],[/\bcitt[aà]\b|comune/,'Città','citta','city',33],[/provincia/,'Provincia','provincia','province',33],[/corso|scelta corso/,'Corso scelto','corso','select',100],[/privacy|consenso/,'Privacy','privacy','consent',100],[/note|messaggio|comment/,'Note','note','textarea',100]];const out=[];defs.forEach(([re,label,key,type,width])=>{if(re.test(v))out.push({label,key,type,width,required:['nome','cognome','email','privacy'].includes(key),options:[],confidence:'high',warning:type==='select'?'Inserisci le opzioni disponibili.':''});});return out;}
document.getElementById('df-ai-description-build')?.addEventListener('click',()=>{const text=document.getElementById('df-ai-description')?.value||'';try{const fields=aiQuickFromDescription(text);if(!fields.length)throw new Error('Non riconosco abbastanza campi nella descrizione. Usa nomi come nome, cognome, email, telefono, corso, privacy, note oppure usa ChatGPT.');aiShowError('');aiPrepare(fields);}catch(err){aiShowError(err?.message||'Impossibile preparare i campi.');}});
function aiLayoutGroups(drafts){const groups=[];let current=[],sum=0,lastRow=null;drafts.forEach((f,i)=>{const explicit=Number(f.row||0)>0?Number(f.row):null;if(current.length&&((explicit&&lastRow&&explicit!==lastRow)||sum+Number(f.width||100)>100)){groups.push(current);current=[];sum=0;}current.push(f);sum+=Number(f.width||100);if(explicit)lastRow=explicit;if(sum>=99){groups.push(current);current=[];sum=0;lastRow=null;}});if(current.length)groups.push(current);return groups;}
function aiBuildImportedField(draft,row,col){const x=defaultFieldConfig({key:uniqueKey(draft.key||draft.label),type:draft.type,category:aiCategory(draft.type),label:draft.label,placeholder:draft.placeholder||'',help:'',default:'',options:Array.isArray(draft.options)?draft.options:[],required:!!draft.required,config:{}});x.config.layout={row,col,width:Number(draft.width||100)};return x;}
function aiImportSelected(){if(editorLocked)return;const chosen=aiDraftFields.filter(f=>f._include);if(!chosen.length)return;const groups=aiLayoutGroups(chosen),position=document.getElementById('df-ai-position')?.value||'append';let startRow=Math.max(0,...selected.map(f=>Number(f.config?.layout?.row||0)))+1,insertIndex=selected.length;if(position==='current'&&activeFieldKey){const active=selected.find(f=>f.key===activeFieldKey);const activeRow=Number(active?.config?.layout?.row||0);if(activeRow>0){selected.forEach(f=>{defaultFieldConfig(f);if(Number(f.config.layout.row||0)>activeRow)f.config.layout.row=Number(f.config.layout.row)+groups.length;});startRow=activeRow+1;const indexes=selected.map((f,i)=>[f,i]).filter(([f])=>Number(f.config?.layout?.row||0)===activeRow).map(([,i])=>i);insertIndex=indexes.length?Math.max(...indexes)+1:selected.findIndex(f=>f.key===activeFieldKey)+1;}}const imported=[];groups.forEach((group,ri)=>group.forEach((draft,ci)=>imported.push(aiBuildImportedField(draft,startRow+ri,ci+1))));selected.splice(insertIndex,0,...imported);activeFieldKey=imported[0]?.key||activeFieldKey;openFieldKeys.clear();if(activeFieldKey)openFieldKeys.add(activeFieldKey);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();clearTimeout(historyTimer);pushHistory();aiClose();const fieldsSection=[...document.querySelectorAll('[data-accordion]')][2];fieldsSection?.classList.add('is-open');fieldsSection?.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','true');setTimeout(()=>document.querySelector(`[data-layout-key="${CSS.escape(activeFieldKey||'')}"]`)?.scrollIntoView({behavior:'smooth',block:'nearest'}),80);}
aiImportButton?.addEventListener('click',aiImportSelected);

'''
if js_anchor not in s:
    raise SystemExit('AI patch: JS anchor not found')
s = s.replace(js_anchor, ai_js + js_anchor, 1)

s = s.replace("window.dfBuilderRuntime={version:'1.3.26'", "window.dfBuilderRuntime={version:'1.3.27'", 1)
path.write_text(s, encoding='utf-8')
PY

# Aggiorna la versione del componente e ricrea il suo ZIP.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)
if command -v php >/dev/null 2>&1; then php -l "$BUILDER" >/dev/null; fi
rm -f "$COMP_OLD"
(cd "$TMP/component" && zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .)

# Mantiene coerenti anche gli altri sotto-pacchetti versionati (es. plugin editor-xtd).
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

# Aggiorna manifest/testi del pacchetto esterno.
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
<feature>Nuovo pulsante “Importa con AI” nel Form Builder, accanto ad “Aggiungi campo”.</feature>
<feature>Flusso gratuito senza API: copia prompt per ChatGPT, apertura ChatGPT, incolla JSON o carica file JSON.</feature>
<feature>Anteprima modificabile prima dell’importazione con etichetta, tipo, obbligatorio, larghezza, placeholder, opzioni e ordine.</feature>
<feature>Controllo duplicati, livelli di sicurezza Alta/Media/Bassa, esclusione automatica dei campi incerti o duplicati e selezione “Solo sicuri”.</feature>
<feature>Scelta fra importazione in fondo o dopo la riga corrente; tutta l’importazione entra nello storico come un’unica operazione annullabile.</feature>
<feature>Descrizione rapida senza AI per creare strutture semplici senza consumi esterni.</feature>
<security>Il JSON importato è validato con allowlist dei tipi, limiti di dimensione e quantità, sanificazione del testo e rifiuto degli elementi tecnici/decorativi.</security>
<note>“Analizza direttamente” è predisposto nell’interfaccia come funzione API opzionale futura e non utilizza la normale chat ChatGPT come API.</note>
<language>it-IT</language>
</changelog></changelogs>
EOF

rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
