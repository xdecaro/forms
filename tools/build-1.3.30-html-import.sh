#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OLD="1.3.29"
NEW="1.3.30"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-html-1330-check.js' EXIT

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

# Add an HTML-file mode card to both the static modal and the runtime fallback modal.
api_card='<div class="df-ai-mode is-disabled" aria-disabled="true"><div class="df-ai-mode-head"><strong>⚡ Analizza direttamente</strong><span class="df-ai-badge df-ai-badge-soon">API opzionale · prossimamente</span></div><div class="df-ai-direct-note">In futuro potrà analizzare lo screenshot senza uscire dal Builder. Richiederà un provider API configurato.</div></div>'
html_card='''<div class="df-ai-mode df-ai-html-mode"><div class="df-ai-mode-head"><strong>📄 Da pagina HTML</strong><span class="df-ai-badge df-ai-badge-free">Senza API</span></div><div class="df-ai-direct-note">Carica una pagina .html salvata dal sito. Forms legge direttamente i campi, comprese select e possibili campi condizionali nascosti.</div><div class="df-ai-file-row"><input type="file" id="df-ai-html-file" accept="text/html,.html,.htm"><button class="df-btn df-small" type="button" id="df-ai-html-analyze">Analizza HTML</button><span class="df-note" id="df-ai-html-status">HTML massimo 5 MB</span></div></div>'''
count=s.count(api_card)
if count < 1:
    raise SystemExit('1.3.30: API mode card anchor missing')
s=s.replace(api_card,html_card+api_card)

# Three mode cards on desktop.
s=s.replace('.df-ai-modes{display:grid;grid-template-columns:1fr 1fr;', '.df-ai-modes{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));',1)

# Extend the downloaded ChatGPT instructions with conditional-field support.
prompt_anchor='Per una sezione interna reale del form puoi usare type=heading.\\nIgnora tutto ciò che non è un campo del modulo.\\n\\nIMPORTANTE:'
prompt_repl='Per una sezione interna reale del form puoi usare type=heading.\\nSe vengono forniti più screenshot dello stesso modulo in stati diversi, confrontali e riconosci i campi condizionali solo quando la relazione è chiaramente osservabile. Per una condizione usa "conditions":[{"field":"chiave_campo","operator":"eq","value":"valore"}], "condition_logic":"all", "condition_action":"show". Non inventare condizioni.\\nIgnora tutto ciò che non è un campo del modulo.\\n\\nIMPORTANTE:'
if prompt_anchor not in s:
    raise SystemExit('1.3.30: ChatGPT prompt anchor missing')
s=s.replace(prompt_anchor,prompt_repl,1)

# Add condition normalization to AI JSON and HTML imports.
anchor="function aiCategory(type){if(['email','tel','url'].includes(type))return'contact';if(['country','region','city','province','postcode','nationality'].includes(type))return'address';if(aiChoiceTypes.has(type)||['checkbox','toggle'].includes(type))return'choices';if(['number','member_number','tax_code'].includes(type))return'values';if(['date','time','datetime'].includes(type))return'datetime';if(['heading','fieldset','separator'].includes(type))return'structure';if(type==='consent')return'consent';return'personal';}"
cond_fn=anchor+"\nfunction aiConditions(v){const allowed=new Set(['eq','neq','contains','not_contains','empty','not_empty','gt','lt','checked','not_checked']);if(!Array.isArray(v))return[];return v.slice(0,12).map(r=>{if(!r||typeof r!=='object')return null;const field=aiSlug(r.field||r.key||r.name||''),operator=String(r.operator||'eq').toLowerCase(),value=String(r.value??'').replace(/[<>]/g,'').slice(0,180);if(!field||!allowed.has(operator))return null;return{field,operator,value};}).filter(Boolean);}"
if anchor not in s:
    raise SystemExit('1.3.30: aiCategory anchor missing')
s=s.replace(anchor,cond_fn,1)

old_field="const field={label,key:aiSlug(raw.key||raw.name||label),type,required:aiBool(raw.required),width:aiNearestWidth(raw.width),row:Math.max(0,parseInt(raw.row,10)||0),placeholder:String(raw.placeholder||'').replace(/[<>]/g,'').slice(0,255),options:aiOptions(raw.options),confidence:['high','medium','low'].includes(String(raw.confidence||'').toLowerCase())?String(raw.confidence).toLowerCase():'medium',warning:String(raw.warning||'').replace(/[<>]/g,'').slice(0,260),_include:true,_duplicate:null};"
new_field="const field={label,key:aiSlug(raw.key||raw.name||label),type,required:aiBool(raw.required),width:aiNearestWidth(raw.width),row:Math.max(0,parseInt(raw.row,10)||0),placeholder:String(raw.placeholder||'').replace(/[<>]/g,'').slice(0,255),options:aiOptions(raw.options),conditions:aiConditions(raw.conditions),condition_logic:String(raw.condition_logic||'all')==='any'?'any':'all',condition_action:['show','hide','require','disable'].includes(String(raw.condition_action||'show'))?String(raw.condition_action||'show'):'show',confidence:['high','medium','low'].includes(String(raw.confidence||'').toLowerCase())?String(raw.confidence).toLowerCase():'medium',warning:String(raw.warning||'').replace(/[<>]/g,'').slice(0,260),_include:true,_duplicate:null};"
if old_field not in s:
    raise SystemExit('1.3.30: aiNormalize field anchor missing')
s=s.replace(old_field,new_field,1)

warn_anchor="if(field.warning)warnings.push(field.warning);field._warnings=warnings;"
warn_repl="if(field.warning)warnings.push(field.warning);if(field.conditions.length)warnings.push(`Condizione rilevata: ${field.conditions.map(c=>`${c.field} ${c.operator==='neq'?'≠':'='} ${c.value}`).join(' · ')}`);field._warnings=warnings;"
if warn_anchor not in s:
    raise SystemExit('1.3.30: warning anchor missing')
s=s.replace(warn_anchor,warn_repl,1)

# Transfer conditions into the final Builder field.
old_build="function aiBuildImportedField(draft,row,col){const x=defaultFieldConfig({key:uniqueKey(draft.key||draft.label),type:draft.type,category:aiCategory(draft.type),label:draft.label,placeholder:draft.placeholder||'',help:'',default:'',options:Array.isArray(draft.options)?draft.options:[],required:!!draft.required,config:{}});x.config.layout={row,col,width:Number(draft.width||100)};return x;}"
new_build="function aiBuildImportedField(draft,row,col){const x=defaultFieldConfig({key:uniqueKey(draft.key||draft.label),type:draft.type,category:aiCategory(draft.type),label:draft.label,placeholder:draft.placeholder||'',help:'',default:'',options:Array.isArray(draft.options)?draft.options:[],required:!!draft.required,config:{conditions:aiConditions(draft.conditions),condition_logic:draft.condition_logic==='any'?'any':'all',condition_action:['show','hide','require','disable'].includes(draft.condition_action)?draft.condition_action:'show'}});x.config.layout={row,col,width:Number(draft.width||100)};return x;}"
if old_build not in s:
    raise SystemExit('1.3.30: aiBuildImportedField anchor missing')
s=s.replace(old_build,new_build,1)

# Direct, inert HTML parser. DOMParser does not execute scripts from the uploaded page.
insert_anchor="document.getElementById('df-ai-check')?.addEventListener('click',()=>{try{aiShowError('');aiPrepare(aiParse(aiLoadedJson));}catch(err){aiShowError(err?.message||'Impossibile controllare il risultato.');aiPreview.hidden=true;}});"
html_js=r'''
/* Forms 1.3.30 HTML import: local parser, no network and no script execution. */
function aiHtmlClean(v,max=150){return String(v??'').replace(/\s+/g,' ').trim().slice(0,max);}
function aiHtmlIsTechnical(el){if(!el||el.tagName!=='INPUT')return false;const type=String(el.getAttribute('type')||'text').toLowerCase();if(type==='hidden')return true;const idname=`${el.id||''} ${el.getAttribute('name')||''}`.toLowerCase();return /(^|[\s_\-])(csrf|token|honeypot|captcha|form_token|security_token)([\s_\-]|$)/.test(idname);}
function aiHtmlHiddenHint(el,root){let n=el,depth=0;while(n&&n!==root&&depth++<7){const cls=String(n.className||'').toLowerCase(),style=String(n.getAttribute?.('style')||'').toLowerCase();if(n.hasAttribute?.('hidden')||n.getAttribute?.('aria-hidden')==='true'||/(^|\s)(d-none|uk-hidden|is-hidden|conditional-hidden|js-hidden|hide)(\s|$)/.test(cls)||/(display\s*:\s*none|visibility\s*:\s*hidden)/.test(style))return true;n=n.parentElement;}return false;}
function aiHtmlLabelFor(el,root){let text='';if(el.id){const lab=[...root.querySelectorAll('label')].find(l=>l.htmlFor===el.id);if(lab)text=aiHtmlClean(lab.textContent);}if(!text){const wrap=el.closest('label');if(wrap)text=aiHtmlClean(wrap.textContent);}if(!text){let n=el.parentElement,depth=0;while(n&&n!==root&&depth++<5){const direct=[...n.children].find(c=>c.tagName==='LABEL'&&!c.contains(el));if(direct){text=aiHtmlClean(direct.textContent);if(text)break;}n=n.parentElement;}}return text||aiHtmlClean(el.getAttribute('aria-label'))||aiHtmlClean(el.getAttribute('placeholder'))||aiHtmlClean(el.getAttribute('name'))||aiHtmlClean(el.id);}
function aiHtmlGroupLabel(els,root){const first=els[0];let n=first?.parentElement,depth=0;while(n&&n!==root&&depth++<6){if(n.tagName==='FIELDSET'){const legend=[...n.children].find(c=>c.tagName==='LEGEND');const t=aiHtmlClean(legend?.textContent);if(t)return t;}const direct=[...n.children].find(c=>c.tagName==='LABEL'&&!els.some(e=>c.contains(e)));const t=aiHtmlClean(direct?.textContent);if(t)return t;n=n.parentElement;}return aiHtmlClean(first?.getAttribute('name'))||aiHtmlLabelFor(first,root);}
function aiHtmlOptionLabel(el,root){return aiHtmlLabelFor(el,root)||aiHtmlClean(el.value);}
function aiHtmlWidth(el,root){let n=el,depth=0,best=null,bestPriority=-1;while(n&&n!==root&&depth++<7){const data=Number(n.getAttribute?.('data-width')||0);if(data>0&&data<=100)return aiNearestWidth(data);const style=String(n.getAttribute?.('style')||'');const sm=style.match(/(?:width|flex-basis)\s*:\s*(\d+(?:\.\d+)?)%/i);if(sm)return aiNearestWidth(Number(sm[1]));const cls=String(n.className||'');for(const m of cls.matchAll(/(?:^|\s)col(?:-(xs|sm|md|lg|xl|xxl))?-(\d{1,2})(?=\s|$)/gi)){const p={xxl:6,xl:5,lg:4,md:3,sm:2,xs:1}[String(m[1]||'').toLowerCase()]||0,num=Number(m[2]);if(num>=1&&num<=12&&p>=bestPriority){best=100*num/12;bestPriority=p;}}const uk=cls.match(/uk-width-(\d+)-(\d+)(?:@[a-z]+)?/i);if(uk){const a=Number(uk[1]),b=Number(uk[2]);if(a>0&&b>0)return aiNearestWidth(100*a/b);}if(/\b(half|w-50|width-50)\b/i.test(cls))return 50;if(/\b(third|w-33|width-33)\b/i.test(cls))return 33;if(/\b(two-thirds|w-66|width-66)\b/i.test(cls))return 66;if(/\b(quarter|w-25|width-25)\b/i.test(cls))return 25;if(/\b(three-quarters|w-75|width-75)\b/i.test(cls))return 75;n=n.parentElement;}return best!=null?aiNearestWidth(best):100;}
function aiHtmlSemanticType(type,label,key){const txt=`${label} ${key}`.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();if(type==='text'){if(/nationalit|nationality/.test(txt))return'nationality';if(/(^|\s)(country|paese|stato)(\s|$)/.test(txt))return'country';if(/(^|\s)(province|provincia)(\s|$)/.test(txt))return'province';if(/(^|\s)(city|citta|localita|comune)(\s|$)/.test(txt))return'city';if(/postcode|postal|cap\b|code postal/.test(txt))return'postcode';if(/codice fiscale|tax code|fiscal code/.test(txt))return'tax_code';}return type;}
function aiHtmlExplicitConditions(el,root){const nodes=[];let n=el,depth=0;while(n&&n!==root&&depth++<7){nodes.push(n);n=n.parentElement;}for(const node of nodes){const get=(...names)=>{for(const name of names){const v=node.getAttribute?.(name);if(v!=null&&String(v).trim()!=='')return String(v).trim();}return'';};let field=get('data-condition-field','data-show-if-field','data-visible-if-field','data-depends-on','data-dependency-field');let value=get('data-condition-value','data-show-if-value','data-visible-if-value','data-dependency-value','data-value');let operator=get('data-condition-operator','data-operator')||'eq';let action=get('data-condition-action','data-action')||'show';if(field){operator={"=":'eq','==':'eq','!=':'neq','<>':'neq'}[operator]||operator;if(!['eq','neq','contains','not_contains','empty','not_empty','gt','lt','checked','not_checked'].includes(operator))operator='eq';if(!['show','hide','require','disable'].includes(action))action='show';return{conditions:[{field:aiSlug(field),operator,value:aiHtmlClean(value,180)}],condition_logic:'all',condition_action:action};}for(const attr of ['data-show-if','data-visible-if','data-condition','data-hide-if']){const expr=get(attr);if(!expr)continue;try{if(expr.trim().startsWith('{')){const j=JSON.parse(expr);const jf=j.field||j.key||j.name,jv=j.value??'',jo=j.operator||'eq';if(jf)return{conditions:[{field:aiSlug(jf),operator:['neq','!='].includes(jo)?'neq':'eq',value:aiHtmlClean(jv,180)}],condition_logic:j.logic==='any'?'any':'all',condition_action:attr==='data-hide-if'?'hide':(j.action||'show')};}}catch{}const m=expr.match(/^\s*([A-Za-z0-9_.\-\[\]]+)\s*(==|=|!=|:)\s*["']?(.+?)["']?\s*$/);if(m)return{conditions:[{field:aiSlug(m[1]),operator:m[2]==='!='?'neq':'eq',value:aiHtmlClean(m[3],180)}],condition_logic:'all',condition_action:attr==='data-hide-if'?'hide':'show'};}}
 }return{conditions:[],condition_logic:'all',condition_action:'show'};}
function aiHtmlControlType(el,label,key,groupCount=1){if(el.tagName==='TEXTAREA')return'textarea';if(el.tagName==='SELECT')return el.multiple?'multiselect':'select';let type=String(el.getAttribute('type')||'text').toLowerCase();const map={'datetime-local':'datetime','phone':'tel'};type=map[type]||type;if(type==='radio')return'radio';if(type==='checkbox'){const txt=`${label} ${key}`.toLowerCase();if(groupCount>1)return'checkboxes';if(/privacy|gdpr|consent|consenso|autorizz/.test(txt))return'consent';return'checkbox';}if(!aiAllowedTypes.has(type))type='text';return aiHtmlSemanticType(type,label,key);}
function aiHtmlRowToken(el,root){let n=el,depth=0;while(n&&n!==root&&depth++<6){const cls=String(n.className||'').toLowerCase();if(/(^|\s)(row|form-row|fields-row|uk-grid|grid)(\s|$)/.test(cls))return n;n=n.parentElement;}return null;}
function aiHtmlParsePage(html){const doc=new DOMParser().parseFromString(String(html||''),'text/html');const forms=[...doc.querySelectorAll('form')];const root=(forms.length?forms.sort((a,b)=>b.querySelectorAll('input,select,textarea').length-a.querySelectorAll('input,select,textarea').length)[0]:doc.body);if(!root)throw new Error('Il file HTML non contiene una pagina leggibile.');const all=[...root.querySelectorAll('input,select,textarea')].filter(el=>!aiHtmlIsTechnical(el)&&!['submit','reset','button','image'].includes(String(el.getAttribute('type')||'').toLowerCase()));if(!all.length)throw new Error('Non ho trovato campi di modulo importabili nel file HTML.');const groups=new Map();all.forEach(el=>{const t=String(el.getAttribute('type')||'').toLowerCase();if((t==='radio'||t==='checkbox')&&el.getAttribute('name')){const k=`${t}:${el.getAttribute('name')}`;if(!groups.has(k))groups.set(k,[]);groups.get(k).push(el);}});const processed=new Set(),raw=[];for(const el of all){if(processed.has(el))continue;const it=String(el.getAttribute('type')||'').toLowerCase(),gkey=(it==='radio'||it==='checkbox')&&el.getAttribute('name')?`${it}:${el.getAttribute('name')}`:'',group=gkey?(groups.get(gkey)||[el]):[el];group.forEach(x=>processed.add(x));const isGroup=group.length>1&&(it==='radio'||it==='checkbox');const label=isGroup?aiHtmlGroupLabel(group,root):aiHtmlLabelFor(el,root);const key=aiSlug(el.getAttribute('name')||el.id||label||`campo_${raw.length+1}`);const type=aiHtmlControlType(el,label,key,group.length);let options=[];if(el.tagName==='SELECT'){options=[...el.options].filter(o=>String(o.value||'').trim()!==''&&!o.disabled).map(o=>aiHtmlClean(o.textContent,180)).filter(Boolean).slice(0,100);}else if(isGroup){options=group.map(o=>aiHtmlOptionLabel(o,root)||aiHtmlClean(o.value,180)).filter(Boolean).slice(0,100);}let placeholder=aiHtmlClean(el.getAttribute('placeholder'),255);if(el.tagName==='SELECT'&&!placeholder){const empty=[...el.options].find(o=>String(o.value||'').trim()==='');if(empty)placeholder=aiHtmlClean(empty.textContent,255);}const hidden=group.some(x=>aiHtmlHiddenHint(x,root)),disabled=group.every(x=>x.disabled),cond=aiHtmlExplicitConditions(el,root),warnings=[];if(hidden&&cond.conditions.length)warnings.push('Campo nascosto con condizione esplicita rilevata nel markup.');else if(hidden)warnings.push('Campo nascosto nel markup: possibile condizionale, ma la regola non è esplicita.');if(disabled)warnings.push('Campo disabilitato nel file HTML.');const width=aiHtmlWidth(el,root);raw.push({label:label||key,key,type,required:group.some(x=>x.required||x.getAttribute('aria-required')==='true'),width,row:0,placeholder,options,conditions:cond.conditions,condition_logic:cond.condition_logic,condition_action:cond.condition_action,confidence:hidden&&!cond.conditions.length?'medium':'high',warning:warnings.join(' '),_rowToken:aiHtmlRowToken(el,root)});}
 const keys=new Set(raw.map(f=>f.key));raw.forEach(f=>{if(f.conditions?.length){const before=f.conditions.length;f.conditions=f.conditions.filter(c=>keys.has(aiSlug(c.field))&&aiSlug(c.field)!==f.key);if(before&&!f.conditions.length){f.warning=`${f.warning?f.warning+' ':''}Condizione trovata ma il campo sorgente non è importabile o non è presente.`;f.confidence='medium';}}});let row=1,sum=0,lastToken=null;raw.forEach(f=>{const token=f._rowToken;if(sum>0&&token&&lastToken&&token!==lastToken){row++;sum=0;}if(sum>0&&sum+Number(f.width||100)>100){row++;sum=0;}f.row=row;sum+=Number(f.width||100);lastToken=token||lastToken;if(sum>=99){row++;sum=0;lastToken=null;}delete f._rowToken;});return raw.slice(0,100);}
document.getElementById('df-ai-html-analyze')?.addEventListener('click',async()=>{const input=document.getElementById('df-ai-html-file'),file=input?.files?.[0],status=document.getElementById('df-ai-html-status');if(!file){aiShowError('Seleziona prima un file .html o .htm.');return;}if(file.size>5*1024*1024){aiShowError('Il file HTML supera 5 MB. Salva solo la pagina HTML o usa una versione più leggera.');return;}try{if(status)status.textContent='Analisi HTML…';const html=await file.text(),fields=aiHtmlParsePage(html);aiShowError('');aiPrepare(fields);if(status)status.textContent=`✓ ${fields.length} campi trovati`;}catch(err){if(status)status.textContent='Analisi non riuscita';aiShowError(err?.message||'Impossibile analizzare il file HTML.');}});
/* End Forms 1.3.30 HTML import. */
'''
if insert_anchor not in s:
    raise SystemExit('1.3.30: ai-check insertion anchor missing')
s=s.replace(insert_anchor,html_js+'\n'+insert_anchor,1)

# Reset HTML input/status after a successful import too.
reset_old="if(description)description.value='';if(aiPreview)aiPreview.hidden=true;"
reset_new="if(description)description.value='';const htmlFile=document.getElementById('df-ai-html-file'),htmlStatus=document.getElementById('df-ai-html-status');if(htmlFile)htmlFile.value='';if(htmlStatus)htmlStatus.textContent='HTML massimo 5 MB';if(aiPreview)aiPreview.hidden=true;"
if reset_old not in s:
    raise SystemExit('1.3.30: reset anchor missing')
s=s.replace(reset_old,reset_new,1)

s=s.replace('/* Forms 1.3.29: AI file-only ChatGPT flow + runtime guard. */','/* Forms 1.3.30: AI file workflow + direct HTML import + runtime guard. */',1)
s=s.replace("window.dfBuilderRuntime={version:'1.3.29'","window.dfBuilderRuntime={version:'1.3.30'",1)

assert '📄 Da pagina HTML' in s
assert 'id="df-ai-html-file"' in s
assert 'function aiHtmlParsePage' in s
assert 'function aiConditions' in s
assert 'conditions:aiConditions(draft.conditions)' in s
assert "version:'1.3.30'" in s
path.write_text(s,encoding='utf-8')
PY

# Update component metadata and package versions.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)

php -l "$BUILDER" >/dev/null
python3 - "$BUILDER" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
assert '📄 Da pagina HTML' in s
assert 'function aiHtmlParsePage' in s
assert 'id="df-ai-html-file"' in s
assert 'conditions:aiConditions(draft.conditions)' in s
a=s.index('/* Forms 1.3.30 HTML import:')
b=s.index('/* End Forms 1.3.30 HTML import. */',a)+len('/* End Forms 1.3.30 HTML import. */')
Path('/tmp/forms-html-1330-check.js').write_text(s[a:b],encoding='utf-8')
PY
node --check /tmp/forms-html-1330-check.js >/dev/null

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
<feature>Nuova modalità “Da pagina HTML” in Importa con AI, completamente locale e senza API.</feature>
<feature>Il parser HTML legge input, textarea, select, radio e checkbox; importa anche tutte le opzioni delle select presenti nel file.</feature>
<feature>Riconoscimento euristico delle larghezze da Bootstrap, UIkit, style percentuali e classi comuni.</feature>
<feature>I campi visibili ma nascosti nel markup vengono mantenuti e segnalati come possibili condizionali; i veri input type=hidden, token e honeypot restano esclusi.</feature>
<feature>Supporto conditions, condition_logic e condition_action nel formato AI e nell’importazione nel Builder.</feature>
<feature>Le condizioni HTML vengono importate solo quando il markup contiene una relazione esplicita semplice; altrimenti Forms mostra un avviso senza inventare la regola.</feature>
<feature>Il file istruzioni per ChatGPT ora spiega anche come restituire condizioni osservabili da più screenshot.</feature>
<security>L’HTML viene analizzato localmente con DOMParser senza eseguire script e senza richieste verso il sito origine.</security>
<language>it-IT</language>
</changelog></changelogs>
EOF

rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
