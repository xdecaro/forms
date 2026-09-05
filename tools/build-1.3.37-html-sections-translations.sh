#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.36"
NEW="1.3.37"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1337-check.js' EXIT
mkdir -p "$TMP/outer" "$TMP/component" "$TARGET_DIR"
unzip -q "$BASE" -d "$TMP/outer"
COMP_OLD="$TMP/outer/com_decaroforms_$OLD.zip"
test -f "$COMP_OLD"
unzip -q "$COMP_OLD" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
test -f "$B"

python3 - "$B" "$TMP/component" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); root=Path(sys.argv[2]); s=p.read_text(encoding='utf-8')

# 1) Fix the remaining mixed-language Builder accordion labels in Italian.
replacements={
    '2. Quick templates':'2. Modelli rapidi',
    '4. Field library':'4. Libreria campi',
    '6. Email settings':'6. Impostazioni email',
    '7. Validation and confirmation':'7. Validazione e conferma',
    '8. Custom code':'8. Codice personalizzato',
    'Stack fields at 100% on smartphones':'Campi al 100% su smartphone',
    'Expand all':'Espandi tutto',
    'Collapse all':'Comprimi tutto',
    'Row settings':'Impostazioni riga',
    'Section settings':'Impostazioni sezione',
}
for a,b in replacements.items():
    s=s.replace(a,b)

# 2) If the premium file enhancer ran before the mode selector, move its action row
#    together with the upload control into the lower "Da pagina salvata" panel.
old="if(pageFileRow)pagePanel.appendChild(pageFileRow);const directPanel=document.createElement('div');"
new="if(pageFileRow)pagePanel.appendChild(pageFileRow);const pageActions=pageCard.querySelector('.df-ai-page-actions');if(pageActions)pagePanel.appendChild(pageActions);const directPanel=document.createElement('div');"
if old not in s:
    raise SystemExit('1.3.37: page panel action anchor missing')
s=s.replace(old,new,1)

# 3) HTML/ZIP section detection. The parser keeps the existing field/width/condition/upload
#    logic, but now scans semantic headings and strong section-title patterns inside the form.
helpers=r'''
function aiHtmlSectionCandidates(root,raw){
 const fieldLabels=new Set(raw.map(f=>aiSlug(f.label||''))),nodes=[],seen=new Set();
 const add=node=>{if(node&&!seen.has(node)){seen.add(node);nodes.push(node);}};
 root.querySelectorAll('legend,h2,h3,h4,h5,h6,[role="heading"],[data-section-title],.form-section-title,.section-title,.fieldset-title,.field-section-title,.group-title,.block-title,.uk-heading-line,.uk-heading-bullet,.uk-heading-small,.uk-heading-medium,.uk-heading-large,.uk-heading-xlarge').forEach(add);
 root.querySelectorAll('div,p,strong,span').forEach(el=>{
  if(el.closest('label,button,option'))return;
  if(el.querySelector('input,select,textarea,button'))return;
  let text=aiHtmlClean(el.textContent,120);if(!text||text.length<3||text.length>100)return;
  const meta=`${el.id||''} ${el.className||''} ${el.getAttribute?.('data-role')||''}`.toLowerCase();
  if(/form-title|page-title|article-title|module-title/.test(meta))return;
  const letters=(text.match(/[A-Za-zÀ-ÖØ-öø-ÿ]/g)||[]),upper=letters.length>=4&&letters.filter(ch=>ch===ch.toLocaleUpperCase()&&ch!==ch.toLocaleLowerCase()).length/letters.length>=.82;
  const named=/(^|[-_\s])(section|fieldset|heading|headline|legend|group-title|block-title|section-title)([-_\s]|$)|uk-heading/.test(meta);
  if(named||upper)add(el);
 });
 const order=[...root.querySelectorAll('*')],index=new Map(order.map((n,i)=>[n,i])),out=[];
 for(const node of nodes){
  if(node.closest('label,button,option'))continue;
  if(node.querySelector('input,select,textarea,button'))continue;
  let title=aiHtmlClean(node.textContent,120).replace(/\s*[*:]+\s*$/,'').trim();
  if(!title||title.length<3||title.length>100)continue;
  const slug=aiSlug(title);if(!slug||fieldLabels.has(slug))continue;
  if(/^(invia|submit|send|continua|continue|indietro|back|next|previous|seleziona file|select file)$/i.test(title))continue;
  const words=title.split(/\s+/).filter(Boolean);const tag=node.tagName||'';const semantic=/^(LEGEND|H2|H3|H4|H5|H6)$/.test(tag);
  if(words.length>10&&!semantic)continue;
  const pos=index.get(node);if(pos==null)continue;
  const meta=`${node.id||''} ${node.className||''}`.toLowerCase(),confidence=(semantic||/(section|fieldset|heading|legend|uk-heading)/.test(meta))?'high':'medium';
  out.push({node,index:pos,title,id:`section_${pos}_${slug}`,confidence});
 }
 out.sort((a,b)=>a.index-b.index);
 return{items:out,index};
}
function aiHtmlNearestSection(node,sectionInfo){
 const idx=sectionInfo?.index?.get(node);if(idx==null)return null;let found=null;
 for(const item of sectionInfo.items){if(item.index>=idx)break;found=item;}
 return found;
}
'''
anchor='function aiHtmlParsePage(html,assets={}){'
if anchor not in s: raise SystemExit('1.3.37: aiHtmlParsePage anchor missing')
s=s.replace(anchor,helpers+'\n'+anchor,1)

# Replace the parser as one block so section ordering remains deterministic.
pattern=r"function aiHtmlParsePage\(html,assets=\{\}\)\{.*?\}\n\nfunction aiZipU16"
m=re.search(pattern,s,re.S)
if not m: raise SystemExit('1.3.37: aiHtmlParsePage full block missing')
parser=r'''function aiHtmlParsePage(html,assets={}){const doc=new DOMParser().parseFromString(String(html||''),'text/html');const forms=[...doc.querySelectorAll('form')];const root=(forms.length?forms.sort((a,b)=>b.querySelectorAll('input,select,textarea').length-a.querySelectorAll('input,select,textarea').length)[0]:doc.body);if(!root)throw new Error('Il file HTML non contiene una pagina leggibile.');const all=[...root.querySelectorAll('input,select,textarea')].filter(el=>!aiHtmlIsTechnical(el)&&!['submit','reset','button','image'].includes(String(el.getAttribute('type')||'').toLowerCase()));if(!all.length)throw new Error('Non ho trovato campi di modulo importabili nel file HTML.');const groups=new Map();all.forEach(el=>{const t=String(el.getAttribute('type')||'').toLowerCase();if((t==='radio'||t==='checkbox')&&el.getAttribute('name')){const k=`${t}:${el.getAttribute('name')}`;if(!groups.has(k))groups.set(k,[]);groups.get(k).push(el);}});const processed=new Set(),raw=[];for(const el of all){if(processed.has(el))continue;const it=String(el.getAttribute('type')||'').toLowerCase(),gkey=(it==='radio'||it==='checkbox')&&el.getAttribute('name')?`${it}:${el.getAttribute('name')}`:'',group=gkey?(groups.get(gkey)||[el]):[el];group.forEach(x=>processed.add(x));const isGroup=group.length>1&&(it==='radio'||it==='checkbox');const label=isGroup?aiHtmlGroupLabel(group,root):aiHtmlLabelFor(el,root);const key=aiSlug(el.getAttribute('name')||el.id||label||`campo_${raw.length+1}`);const type=aiHtmlControlType(el,label,key,group.length);let options=[];if(el.tagName==='SELECT'){options=[...el.options].filter(o=>String(o.value||'').trim()!==''&&!o.disabled).map(o=>aiHtmlClean(o.textContent,180)).filter(Boolean).slice(0,100);}else if(isGroup){options=group.map(o=>aiHtmlOptionLabel(o,root)||aiHtmlClean(o.value,180)).filter(Boolean).slice(0,100);}let placeholder=aiHtmlClean(el.getAttribute('placeholder'),255);if(el.tagName==='SELECT'&&!placeholder){const empty=[...el.options].find(o=>String(o.value||'').trim()==='');if(empty)placeholder=aiHtmlClean(empty.textContent,255);}const hidden=group.some(x=>aiHtmlHiddenHint(x,root)),disabled=group.every(x=>x.disabled),cond=aiHtmlExplicitConditions(el,root),warnings=[];if(hidden&&cond.conditions.length)warnings.push('Campo nascosto con condizione esplicita rilevata nel markup.');else if(hidden)warnings.push('Campo nascosto nel markup: possibile condizionale, ma la regola non è esplicita.');if(disabled)warnings.push('Campo disabilitato nel file HTML.');const width=aiHtmlWidth(el,root,assets.css||'');raw.push({label:label||key,key,type,required:group.some(x=>x.required||x.getAttribute('aria-required')==='true'),width,row:0,placeholder,options,config:type==='upload'?aiHtmlUploadConfig(el,root):{},conditions:cond.conditions,condition_logic:cond.condition_logic,condition_action:cond.condition_action,confidence:hidden&&!cond.conditions.length?'medium':'high',warning:warnings.join(' '),_disabled:disabled,_rowToken:aiHtmlRowToken(el,root),_node:group[0]||el});}
 const uploadLabels=new Set(raw.filter(f=>f.type==='upload').map(f=>aiSlug(f.label)));for(let i=raw.length-1;i>=0;i--){const f=raw[i];if(f.type==='text'&&f._disabled&&uploadLabels.has(aiSlug(f.label)))raw.splice(i,1);}const keys=new Set(raw.map(f=>f.key));raw.forEach(f=>{if(f.conditions?.length){const before=f.conditions.length;f.conditions=f.conditions.filter(c=>keys.has(aiSlug(c.field))&&aiSlug(c.field)!==f.key);if(before&&!f.conditions.length){f.warning=`${f.warning?f.warning+' ':''}Condizione trovata ma il campo sorgente non è importabile o non è presente.`;f.confidence='medium';}}});
 const sectionInfo=aiHtmlSectionCandidates(root,raw);raw.forEach(f=>{f._section=aiHtmlNearestSection(f._node,sectionInfo);});
 const out=[];let row=1,sum=0,lastToken=null,lastSection='';let sectionCounter=0;for(const f of raw){const sec=f._section,secId=sec?.id||'';if(secId&&secId!==lastSection){if(sum>0){row++;sum=0;}out.push({label:sec.title,key:`section_${aiSlug(sec.title)}_${++sectionCounter}`,type:'heading',required:false,width:100,row,placeholder:'',options:[],config:{builder_role:'section',content:''},conditions:[],condition_logic:'all',condition_action:'show',confidence:sec.confidence||'high',warning:''});row++;lastToken=null;lastSection=secId;}const token=f._rowToken;if(sum>0&&token&&lastToken&&token!==lastToken){row++;sum=0;}if(sum>0&&sum+Number(f.width||100)>100){row++;sum=0;}f.row=row;out.push(f);sum+=Number(f.width||100);lastToken=token||lastToken;if(sum>=99){row++;sum=0;lastToken=null;}delete f._rowToken;delete f._disabled;delete f._node;delete f._section;}return out.slice(0,100);}

function aiZipU16'''
s=s[:m.start()]+parser+s[m.end():]

# 4) Runtime version.
s=s.replace("window.dfBuilderRuntime={version:'1.3.36'","window.dfBuilderRuntime={version:'1.3.37'",1)

# 5) Install the missing language strings in every packaged language location, not only a component-local folder.
lang_values={
'it-IT':{
 'COM_DECAROFORMS_QUICK_TEMPLATES':'Modelli rapidi','COM_DECAROFORMS_FIELD_LIBRARY':'Libreria campi','COM_DECAROFORMS_EMAIL_SETTINGS':'Impostazioni email','COM_DECAROFORMS_VALIDATION_CONFIRMATION':'Validazione e conferma','COM_DECAROFORMS_CUSTOM_CODE':'Codice personalizzato','COM_DECAROFORMS_EXPAND_ALL':'Espandi tutto','COM_DECAROFORMS_COLLAPSE_ALL':'Comprimi tutto','COM_DECAROFORMS_GENERAL_SECTION':'Generale','COM_DECAROFORMS_ROW_SETTINGS':'Impostazioni riga','COM_DECAROFORMS_SECTION_SETTINGS':'Impostazioni sezione','COM_DECAROFORMS_TITLE':'Titolo','COM_DECAROFORMS_DESCRIPTION':'Descrizione'},
'en-GB':{
 'COM_DECAROFORMS_QUICK_TEMPLATES':'Quick templates','COM_DECAROFORMS_FIELD_LIBRARY':'Field library','COM_DECAROFORMS_EMAIL_SETTINGS':'Email settings','COM_DECAROFORMS_VALIDATION_CONFIRMATION':'Validation and confirmation','COM_DECAROFORMS_CUSTOM_CODE':'Custom code','COM_DECAROFORMS_EXPAND_ALL':'Expand all','COM_DECAROFORMS_COLLAPSE_ALL':'Collapse all','COM_DECAROFORMS_GENERAL_SECTION':'General','COM_DECAROFORMS_ROW_SETTINGS':'Row settings','COM_DECAROFORMS_SECTION_SETTINGS':'Section settings','COM_DECAROFORMS_TITLE':'Title','COM_DECAROFORMS_DESCRIPTION':'Description'},
'fr-FR':{
 'COM_DECAROFORMS_QUICK_TEMPLATES':'Modèles rapides','COM_DECAROFORMS_FIELD_LIBRARY':'Bibliothèque de champs','COM_DECAROFORMS_EMAIL_SETTINGS':'Paramètres e-mail','COM_DECAROFORMS_VALIDATION_CONFIRMATION':'Validation et confirmation','COM_DECAROFORMS_CUSTOM_CODE':'Code personnalisé','COM_DECAROFORMS_EXPAND_ALL':'Tout développer','COM_DECAROFORMS_COLLAPSE_ALL':'Tout réduire','COM_DECAROFORMS_GENERAL_SECTION':'Général','COM_DECAROFORMS_ROW_SETTINGS':'Paramètres de ligne','COM_DECAROFORMS_SECTION_SETTINGS':'Paramètres de section','COM_DECAROFORMS_TITLE':'Titre','COM_DECAROFORMS_DESCRIPTION':'Description'}}
for ini in root.rglob('com_decaroforms.ini'):
    lang=ini.parent.name
    vals=lang_values.get(lang)
    if not vals: continue
    t=ini.read_text(encoding='utf-8')
    for k,v in vals.items():
        line=f'{k}="{v}"'
        if re.search(r'^'+re.escape(k)+r'=.*$',t,re.M): t=re.sub(r'^'+re.escape(k)+r'=.*$',line,t,flags=re.M)
        else: t+='\n'+line
    ini.write_text(t+'\n' if not t.endswith('\n') else t,encoding='utf-8')

# Guardrails.
checks=['function aiHtmlSectionCandidates','function aiHtmlNearestSection',"type:'heading'",'sectionInfo=aiHtmlSectionCandidates','pageActions=pageCard.querySelector',"version:'1.3.37'",'2. Modelli rapidi','4. Libreria campi','6. Impostazioni email','7. Validazione e conferma','8. Codice personalizzato']
for c in checks:
    if c not in s: raise SystemExit('1.3.37 missing '+c)
p.write_text(s,encoding='utf-8')
PY

# Update package/component metadata.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)
php -l "$B" >/dev/null

# Syntax-check the changed browser-JS area after neutralising PHP output expressions.
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
assert "version:'1.3.37'" in s
assert 'function aiHtmlSectionCandidates' in s
assert 'pageActions=pageCard.querySelector' in s
a=s.index('const aiAllowedTypes=')
b=s.index('/* Forms 1.3.6: bind quick templates',a)
js=s[a:b]
js=re.sub(r"<\?php.*?\?>","X",js,flags=re.S)
Path('/tmp/forms-1337-check.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1337-check.js >/dev/null

# Rebuild component and package.
rm -f "$COMP_OLD"
(cd "$TMP/component" && zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .)
for z in "$TMP/outer"/*_"$OLD".zip; do
 [ -e "$z" ] || continue
 work="$TMP/sub-$(basename "$z" .zip)"; mkdir -p "$work"; unzip -q "$z" -d "$work"
 while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$work" || true)
 newz="${z/$OLD/$NEW}"; rm -f "$newz"; (cd "$work" && zip -qr "$newz" .); rm -f "$z"
done
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -Il -- "$OLD" "$TMP/outer"/* 2>/dev/null || true)
rm -f "$TARGET"; (cd "$TMP/outer" && zip -qr "$TARGET" .); unzip -tq "$TARGET" >/dev/null
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update><name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description><element>pkg_decaroforms</element><type>package</type><client>site</client><version>$NEW</version><downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/$NEW/pkg_decaroforms_$NEW.zip</downloadurl></downloads><changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags><maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl><targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256></update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog><element>pkg_decaroforms</element><type>package</type><version>$NEW</version><feature>Importazione HTML/ZIP: riconoscimento automatico delle sezioni interne del modulo da legend, heading e titoli strutturali della pagina.</feature><feature>I campi importati vengono ora raggruppati sotto le sezioni riconosciute invece di finire tutti in General.</feature><improvement>Il pulsante Analizza pagina è mostrato soltanto nel pannello Da pagina salvata, sotto il caricamento del file.</improvement><improvement>Completata la traduzione italiana dei titoli principali del Builder: Modelli rapidi, Libreria campi, Impostazioni email, Validazione e conferma, Codice personalizzato e controlli struttura.</improvement><note>Mantenute tutte le funzioni 1.3.36: drag intelligente di campi, righe e sezioni, upload HTML/ZIP e condizioni.</note><language>it-IT</language></changelog></changelogs>
EOF
rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
