#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.33"
NEW="1.3.34"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1334-check.js' EXIT
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

# 1) Builder entry buttons: identical footprint and visible plus icon for AI.
s=s.replace('<button class="df-ai-import-main" type="button" id="df-open-ai-import"><span aria-hidden="true">✨</span> Importa con AI</button>',
            '<button class="df-ai-import-main" type="button" id="df-open-ai-import"><span aria-hidden="true">＋</span> Importa con AI</button>')

# 2) AI schema: Upload is a first-class canonical field type.
s=s.replace("const aiAllowedTypes=new Set(['text','email','tel','url','number','date','time','datetime','textarea','select','multiselect','radio','checkboxes','checkbox','toggle','consent','nationality','country','region','city','province','tax_code','postcode','member_number','heading','fieldset','separator']);",
            "const aiAllowedTypes=new Set(['text','email','tel','url','number','date','time','datetime','textarea','select','multiselect','radio','checkboxes','checkbox','toggle','consent','upload','nationality','country','region','city','province','tax_code','postcode','member_number','heading','fieldset','separator']);")
s=s.replace("const aiAliases={phone:'tel',telephone:'tel',telefono:'tel',mail:'email','e-mail':'email',integer:'number',numeric:'number',decimal:'number',birthdate:'date','date_of_birth':'date',multiline:'textarea','text-area':'textarea',dropdown:'select',combo:'select',combobox:'select',checkbox_group:'checkboxes',checkboxgroup:'checkboxes',checkgroup:'checkboxes',privacy:'consent',gdpr:'consent',section:'heading',title:'heading'};",
            "const aiAliases={phone:'tel',telephone:'tel',telefono:'tel',mail:'email','e-mail':'email',integer:'number',numeric:'number',decimal:'number',birthdate:'date','date_of_birth':'date',multiline:'textarea','text-area':'textarea',dropdown:'select',combo:'select',combobox:'select',checkbox_group:'checkboxes',checkboxgroup:'checkboxes',checkgroup:'checkboxes',privacy:'consent',gdpr:'consent',file:'upload',attachment:'upload',allegato:'upload',section:'heading',title:'heading'};")
s=s.replace("if(['date','time','datetime'].includes(type))return'datetime';if(['heading','fieldset','separator'].includes(type))return'structure';if(type==='consent')return'consent';return'personal';}",
            "if(['date','time','datetime'].includes(type))return'datetime';if(type==='upload')return'document';if(['heading','fieldset','separator'].includes(type))return'structure';if(type==='consent')return'consent';return'personal';}")

# Prompt explicitly teaches ChatGPT about uploads.
s=s.replace('Per un consenso/privacy usa type=consent oppure checkbox.\\nPer una sezione interna reale del form puoi usare type=heading.',
            'Per un consenso/privacy usa type=consent oppure checkbox.\\nPer allegati o caricamento documenti usa type=upload. Se visibili, puoi aggiungere config.accept, config.max_mb e config.multiple senza inventare valori.\\nPer una sezione interna reale del form puoi usare type=heading.')

# Preserve upload configuration in normalized AI fields.
old="const field={label,key:aiSlug(raw.key||raw.name||label),type,required:aiBool(raw.required),width:aiNearestWidth(raw.width),row:Math.max(0,parseInt(raw.row,10)||0),placeholder:String(raw.placeholder||'').replace(/[<>]/g,'').slice(0,255),options:aiOptions(raw.options),conditions:aiConditions(raw.conditions),condition_logic:String(raw.condition_logic||'all')==='any'?'any':'all',condition_action:['show','hide','require','disable'].includes(String(raw.condition_action||'show'))?String(raw.condition_action||'show'):'show',confidence:['high','medium','low'].includes(String(raw.confidence||'').toLowerCase())?String(raw.confidence).toLowerCase():'medium',warning:String(raw.warning||'').replace(/[<>]/g,'').slice(0,260),_include:true,_duplicate:null};"
new="const uploadCfg=type==='upload'?{accept:String(raw.config?.accept??raw.accept??'').replace(/[<>]/g,'').slice(0,500),max_mb:Math.max(1,Math.min(100,Number(raw.config?.max_mb??raw.max_mb??5)||5)),multiple:aiBool(raw.config?.multiple??raw.multiple),max_files:Math.max(1,Math.min(20,Number(raw.config?.max_files??raw.max_files??1)||1))}:{};const field={label,key:aiSlug(raw.key||raw.name||label),type,required:aiBool(raw.required),width:aiNearestWidth(raw.width),row:Math.max(0,parseInt(raw.row,10)||0),placeholder:String(raw.placeholder||'').replace(/[<>]/g,'').slice(0,255),options:aiOptions(raw.options),config:uploadCfg,conditions:aiConditions(raw.conditions),condition_logic:String(raw.condition_logic||'all')==='any'?'any':'all',condition_action:['show','hide','require','disable'].includes(String(raw.condition_action||'show'))?String(raw.condition_action||'show'):'show',confidence:['high','medium','low'].includes(String(raw.confidence||'').toLowerCase())?String(raw.confidence).toLowerCase():'medium',warning:String(raw.warning||'').replace(/[<>]/g,'').slice(0,260),_include:true,_duplicate:null};"
if old not in s: raise SystemExit('1.3.34: aiNormalize field anchor missing')
s=s.replace(old,new,1)

# HTML input[type=file] -> Upload, plus nearby upload settings.
oldfn="function aiHtmlControlType(el,label,key,groupCount=1){if(el.tagName==='TEXTAREA')return'textarea';if(el.tagName==='SELECT')return el.multiple?'multiselect':'select';let type=String(el.getAttribute('type')||'text').toLowerCase();const map={'datetime-local':'datetime','phone':'tel'};type=map[type]||type;if(type==='radio')return'radio';if(type==='checkbox'){const txt=`${label} ${key}`.toLowerCase();if(groupCount>1)return'checkboxes';if(/privacy|gdpr|consent|consenso|autorizz/.test(txt))return'consent';return'checkbox';}if(!aiAllowedTypes.has(type))type='text';return aiHtmlSemanticType(type,label,key);}"
newfn="function aiHtmlControlType(el,label,key,groupCount=1){if(el.tagName==='TEXTAREA')return'textarea';if(el.tagName==='SELECT')return el.multiple?'multiselect':'select';let type=String(el.getAttribute('type')||'text').toLowerCase();const map={'datetime-local':'datetime','phone':'tel',file:'upload'};type=map[type]||type;if(type==='radio')return'radio';if(type==='checkbox'){const txt=`${label} ${key}`.toLowerCase();if(groupCount>1)return'checkboxes';if(/privacy|gdpr|consent|consenso|autorizz/.test(txt))return'consent';return'checkbox';}if(!aiAllowedTypes.has(type))type='text';return aiHtmlSemanticType(type,label,key);}\nfunction aiHtmlUploadConfig(el,root){if(String(el?.getAttribute?.('type')||'').toLowerCase()!=='file')return{};const cfg={accept:aiHtmlClean(el.getAttribute('accept')||'',500),multiple:!!el.multiple,max_files:el.multiple?2:1};let n=el,depth=0,text='';while(n&&n!==root&&depth++<4){text+=' '+String(n.textContent||'').replace(/\\s+/g,' ').slice(0,1500);n=n.parentElement;}const m=text.match(/(?:massim[oa]|maximum|max(?:imum)?(?:\\s+size)?)[^0-9]{0,35}(\\d+(?:[.,]\\d+)?)\\s*MB/i)||text.match(/(\\d+(?:[.,]\\d+)?)\\s*MB/i);if(m)cfg.max_mb=Math.max(1,Math.min(100,Number(String(m[1]).replace(',','.'))||5));return cfg;}"
if oldfn not in s: raise SystemExit('1.3.34: aiHtmlControlType anchor missing')
s=s.replace(oldfn,newfn,1)

# Mark disabled auxiliary controls and keep upload config; dedupe disabled text helpers that mirror upload widgets.
s=s.replace("const processed=new Set(),raw=[];", "const processed=new Set(),raw=[];",1)
oldpush="raw.push({label:label||key,key,type,required:group.some(x=>x.required||x.getAttribute('aria-required')==='true'),width,row:0,placeholder,options,conditions:cond.conditions,condition_logic:cond.condition_logic,condition_action:cond.condition_action,confidence:hidden&&!cond.conditions.length?'medium':'high',warning:warnings.join(' '),_rowToken:aiHtmlRowToken(el,root)});"
newpush="raw.push({label:label||key,key,type,required:group.some(x=>x.required||x.getAttribute('aria-required')==='true'),width,row:0,placeholder,options,config:type==='upload'?aiHtmlUploadConfig(el,root):{},conditions:cond.conditions,condition_logic:cond.condition_logic,condition_action:cond.condition_action,confidence:hidden&&!cond.conditions.length?'medium':'high',warning:warnings.join(' '),_disabled:disabled,_rowToken:aiHtmlRowToken(el,root)});"
if oldpush not in s: raise SystemExit('1.3.34: HTML raw push anchor missing')
s=s.replace(oldpush,newpush,1)
oldkeys=" const keys=new Set(raw.map(f=>f.key));raw.forEach(f=>{if(f.conditions?.length){"
newkeys=" const uploadLabels=new Set(raw.filter(f=>f.type==='upload').map(f=>aiSlug(f.label)));for(let i=raw.length-1;i>=0;i--){const f=raw[i];if(f.type==='text'&&f._disabled&&uploadLabels.has(aiSlug(f.label)))raw.splice(i,1);}const keys=new Set(raw.map(f=>f.key));raw.forEach(f=>{if(f.conditions?.length){"
if oldkeys not in s: raise SystemExit('1.3.34: HTML dedupe anchor missing')
s=s.replace(oldkeys,newkeys,1)
s=s.replace("delete f._rowToken;});return raw.slice(0,100);}","delete f._rowToken;delete f._disabled;});return raw.slice(0,100);}",1)

# Imported Builder fields retain upload configuration.
oldbuild="config:{conditions:aiConditions(draft.conditions),condition_logic:draft.condition_logic==='any'?'any':'all',condition_action:['show','hide','require','disable'].includes(draft.condition_action)?draft.condition_action:'show'}});"
newbuild="config:{...(draft.config&&typeof draft.config==='object'?draft.config:{}),conditions:aiConditions(draft.conditions),condition_logic:draft.condition_logic==='any'?'any':'all',condition_action:['show','hide','require','disable'].includes(draft.condition_action)?draft.condition_action:'show'}});"
if oldbuild not in s: raise SystemExit('1.3.34: aiBuildImportedField config anchor missing')
s=s.replace(oldbuild,newbuild,1)

# 3) Preview: visible Etichetta caption, matching Placeholder/Opzioni captions.
s=s.replace('<input type="text" data-ai-label value="${esc(f.label)}" aria-label="Etichetta"><select data-ai-type aria-label="Tipo">',
            '<label class="df-ai-main-label"><span>Etichetta</span><input type="text" data-ai-label value="${esc(f.label)}" aria-label="Etichetta"></label><select data-ai-type aria-label="Tipo">',1)

# 4) Structure selection UI strings.
old="const structureUi={expandAll:'<?php echo addslashes(Text::_('COM_DECAROFORMS_EXPAND_ALL')); ?>',collapseAll:'<?php echo addslashes(Text::_('COM_DECAROFORMS_COLLAPSE_ALL')); ?>',general:'<?php echo addslashes(Text::_('COM_DECAROFORMS_GENERAL_SECTION')); ?>',section:'<?php echo addslashes(Text::_('COM_DECAROFORMS_SECTION')); ?>',row:'<?php echo addslashes(Text::_('COM_DECAROFORMS_ROW')); ?>',fields:'<?php echo addslashes(Text::_('COM_DECAROFORMS_FIELDS')); ?>',rows:'<?php echo addslashes(Text::_('COM_DECAROFORMS_ROWS')); ?>'};"
new="const structureUi={expandAll:'<?php echo addslashes(Text::_('COM_DECAROFORMS_EXPAND_ALL')); ?>',collapseAll:'<?php echo addslashes(Text::_('COM_DECAROFORMS_COLLAPSE_ALL')); ?>',general:'<?php echo addslashes(Text::_('COM_DECAROFORMS_GENERAL_SECTION')); ?>',section:'<?php echo addslashes(Text::_('COM_DECAROFORMS_SECTION')); ?>',row:'<?php echo addslashes(Text::_('COM_DECAROFORMS_ROW')); ?>',fields:'<?php echo addslashes(Text::_('COM_DECAROFORMS_FIELDS')); ?>',rows:'<?php echo addslashes(Text::_('COM_DECAROFORMS_ROWS')); ?>',sectionSettings:'<?php echo addslashes(Text::_('COM_DECAROFORMS_SECTION_SETTINGS')); ?>',rowSettings:'<?php echo addslashes(Text::_('COM_DECAROFORMS_ROW_SETTINGS')); ?>',title:'<?php echo addslashes(Text::_('COM_DECAROFORMS_TITLE')); ?>',description:'<?php echo addslashes(Text::_('COM_DECAROFORMS_DESCRIPTION')); ?>'};"
if old not in s: raise SystemExit('1.3.34: structureUi anchor missing')
s=s.replace(old,new,1)

# Row metadata survives row normalization/re-numbering.
oldnorm="function normalizeLayoutRows(){const rows=[...new Set(selected.map(f=>Number(f.config?.layout?.row||1)))].sort((a,b)=>a-b);const map=new Map(rows.map((r,i)=>[r,i+1]));selected.forEach(f=>{defaultFieldConfig(f);f.config.layout.row=map.get(Number(f.config.layout.row||1))||1;});for(const row of [...new Set(selected.map(f=>f.config.layout.row))])selected.filter(f=>f.config.layout.row===row).sort((a,b)=>(a.config.layout.col||1)-(b.config.layout.col||1)).forEach((f,i)=>f.config.layout.col=i+1);}"
newnorm="function normalizeLayoutRows(){builderConfig=builderConfig&&typeof builderConfig==='object'?builderConfig:{};builderConfig.layout=builderConfig.layout&&typeof builderConfig.layout==='object'?builderConfig.layout:{};const oldMeta=builderConfig.layout.row_meta&&typeof builderConfig.layout.row_meta==='object'?builderConfig.layout.row_meta:{};const rows=[...new Set(selected.map(f=>Number(f.config?.layout?.row||1)))].sort((a,b)=>a-b);const map=new Map(rows.map((r,i)=>[r,i+1])),nextMeta={};rows.forEach(r=>{const nr=map.get(r);if(oldMeta[r])nextMeta[nr]=oldMeta[r];});builderConfig.layout.row_meta=nextMeta;selected.forEach(f=>{defaultFieldConfig(f);f.config.layout.row=map.get(Number(f.config.layout.row||1))||1;});for(const row of [...new Set(selected.map(f=>f.config.layout.row))])selected.filter(f=>f.config.layout.row===row).sort((a,b)=>(a.config.layout.col||1)-(b.config.layout.col||1)).forEach((f,i)=>f.config.layout.col=i+1);}"
if oldnorm not in s: raise SystemExit('1.3.34: normalizeLayoutRows anchor missing')
s=s.replace(oldnorm,newnorm,1)

# Dedicated right-side editors for section and row.
render_anchor='function renderSelected(){'
if render_anchor not in s: raise SystemExit('1.3.34: renderSelected anchor missing')
extra=r'''
let activeStructureSelection=null;
function rowMeta(rowNo){builderConfig=builderConfig&&typeof builderConfig==='object'?builderConfig:{};builderConfig.layout=builderConfig.layout&&typeof builderConfig.layout==='object'?builderConfig.layout:{};builderConfig.layout.row_meta=builderConfig.layout.row_meta&&typeof builderConfig.layout.row_meta==='object'?builderConfig.layout.row_meta:{};const key=String(rowNo);builderConfig.layout.row_meta[key]=builderConfig.layout.row_meta[key]||{title:'',description:''};return builderConfig.layout.row_meta[key];}
function renderSectionSettings(x,i){defaultFieldConfig(x);sel.innerHTML='';const d=document.createElement('div');d.className='df-selected-item is-open df-structure-settings';d.innerHTML=`<div class="df-selected-top"><div class="df-field-toggle-main"><strong>${esc(structureUi.sectionSettings)}</strong><span class="df-field-summary"><span class="df-summary-chip">${esc(structureUi.section)}</span></span></div><div class="df-mini-actions"><button type="button" data-structure-remove class="df-icon-only" title="${esc(tr.remove)}" aria-label="${esc(tr.remove)}">${uiIcon('trash')}</button></div></div><div class="df-selected-config-wrap"><div class="df-selected-config-inner"><div class="df-selected-config"><details class="full df-main-settings" open><summary>${esc(structureUi.sectionSettings)}</summary><div class="df-main-settings-body"><div class="df-main-settings-grid"><div class="full"><label>${esc(structureUi.title)}</label><input data-section-title value="${esc(x.label||'')}"></div><div class="full"><label>${esc(structureUi.description)}</label><textarea class="df-options" data-section-description>${esc(x.config?.content||'')}</textarea></div></div></div></details></div></div></div>`;d.querySelector('[data-section-title]').oninput=e=>{x.label=e.target.value;sync();renderLayoutCanvas();};d.querySelector('[data-section-description]').oninput=e=>{x.config.content=e.target.value;sync();renderLayoutCanvas();};d.querySelector('[data-structure-remove]').onclick=()=>confirmDelete(`la sezione “${x.label||structureUi.section}”`,()=>removeCanvasField(i));sel.appendChild(d);sync();}
function renderRowSettings(rowNo){const meta=rowMeta(rowNo);sel.innerHTML='';const d=document.createElement('div');d.className='df-selected-item is-open df-structure-settings';d.innerHTML=`<div class="df-selected-top"><div class="df-field-toggle-main"><strong>${esc(structureUi.rowSettings)}</strong><span class="df-field-summary"><span class="df-summary-chip">${esc(structureUi.row)} ${rowNo}</span></span></div></div><div class="df-selected-config-wrap"><div class="df-selected-config-inner"><div class="df-selected-config"><details class="full df-main-settings" open><summary>${esc(structureUi.rowSettings)}</summary><div class="df-main-settings-body"><div class="df-main-settings-grid"><div class="full"><label>${esc(structureUi.title)}</label><input data-row-title value="${esc(meta.title||'')}" placeholder="${esc(structureUi.row)} ${rowNo}"></div><div class="full"><label>${esc(structureUi.description)}</label><textarea class="df-options" data-row-description>${esc(meta.description||'')}</textarea></div><div class="full df-note">Titolo e descrizione della riga servono per organizzare più velocemente il Builder e non vengono inviati come dati del modulo.</div></div></div></details></div></div></div>`;d.querySelector('[data-row-title]').oninput=e=>{meta.title=e.target.value;sync();renderLayoutCanvas();};d.querySelector('[data-row-description]').oninput=e=>{meta.description=e.target.value;sync();renderLayoutCanvas();};sel.appendChild(d);sync();}
function selectRowSettings(rowNo){activeStructureSelection={type:'row',row:Number(rowNo)};renderSelected();renderLayoutCanvas();}
'''
s=s.replace(render_anchor,extra+'\n'+render_anchor,1)

# renderSelected intercepts row and section selections.
oldstart="function renderSelected(){sel.innerHTML='';if(!selected.length){"
newstart="function renderSelected(){sel.innerHTML='';if(activeStructureSelection?.type==='row'){renderRowSettings(activeStructureSelection.row);return;}if(!selected.length){"
if oldstart not in s: raise SystemExit('1.3.34: renderSelected start missing')
s=s.replace(oldstart,newstart,1)
oldactive="if(!selected.some(x=>x.key===activeFieldKey))activeFieldKey=selected[0].key;openFieldKeys.clear();openFieldKeys.add(activeFieldKey);selected.map((x,i)=>[x,i]).filter(([x])=>x.key===activeFieldKey).forEach(([x,i])=>{defaultFieldConfig(x);"
newactive="if(!selected.some(x=>x.key===activeFieldKey))activeFieldKey=selected[0].key;const activeIndex=selected.findIndex(x=>x.key===activeFieldKey),activeItem=selected[activeIndex];if(activeItem&&isLayoutSectionField(activeItem)){renderSectionSettings(activeItem,activeIndex);return;}openFieldKeys.clear();openFieldKeys.add(activeFieldKey);selected.map((x,i)=>[x,i]).filter(([x])=>x.key===activeFieldKey).forEach(([x,i])=>{defaultFieldConfig(x);"
if oldactive not in s: raise SystemExit('1.3.34: renderSelected active anchor missing')
s=s.replace(oldactive,newactive,1)

# Selecting a normal field clears row-selection mode.
s=s.replace("function selectField(index){if(index==null||!selected[index])return;activeFieldKey=selected[index].key;",
            "function selectField(index){if(index==null||!selected[index])return;activeStructureSelection=null;activeFieldKey=selected[index].key;",1)

# Section titles/descriptions and row names appear immediately in accordion headers.
s=s.replace("const activeInGroup=(group.sectionField?.[0]?.key===activeFieldKey)||group.rows.some(r=>r.items.some(([f])=>f.key===activeFieldKey));",
            "const activeInGroup=(group.sectionField?.[0]?.key===activeFieldKey)||group.rows.some(r=>r.items.some(([f])=>f.key===activeFieldKey)||activeStructureSelection?.type==='row'&&Number(activeStructureSelection.row)===Number(r.rowNo));",1)
s=s.replace("head.innerHTML=`<span class=\"df-layout-section-chevron\">›</span><span class=\"df-layout-section-title\"><strong>${esc(group.title)}</strong><span class=\"df-layout-section-summary\">${count} ${esc(structureUi.fields)} · ${rowCount} ${esc(structureUi.rows)}</span></span>${sectionActions}`;",
            "const sectionDescription=group.sectionField?.[0]?.config?.content||'';head.innerHTML=`<span class=\"df-layout-section-chevron\">›</span><span class=\"df-layout-section-title\"><strong>${esc(group.title)}</strong>${sectionDescription?`<span class=\"df-layout-structure-description\">${esc(sectionDescription)}</span>`:''}<span class=\"df-layout-section-summary\">${count} ${esc(structureUi.fields)} · ${rowCount} ${esc(structureUi.rows)}</span></span>${sectionActions}`;",1)

oldsect="const toggleSection=()=>{layoutSectionState.set(group.id,!wrap.classList.contains('is-open'));renderLayoutCanvas();};head.addEventListener('click',e=>{if(e.target.closest('button'))return;toggleSection();});head.addEventListener('keydown',e=>{if((e.key==='Enter'||e.key===' ')&&!e.target.closest('button')){e.preventDefault();toggleSection();}});"
newsect="const toggleSection=()=>{layoutSectionState.set(group.id,!wrap.classList.contains('is-open'));renderLayoutCanvas();};head.addEventListener('click',e=>{if(e.target.closest('button'))return;if(e.target.closest('.df-layout-section-chevron')){toggleSection();return;}if(group.sectionField){const [,si]=group.sectionField;selectField(si);layoutSectionState.set(group.id,true);}else toggleSection();});head.addEventListener('keydown',e=>{if((e.key==='Enter'||e.key===' ')&&!e.target.closest('button')){e.preventDefault();if(group.sectionField){const [,si]=group.sectionField;selectField(si);layoutSectionState.set(group.id,true);}else toggleSection();}});"
if oldsect not in s: raise SystemExit('1.3.34: section click anchor missing')
s=s.replace(oldsect,newsect,1)

oldrow="const rowActive=model.items.some(([f])=>f.key===activeFieldKey),rowOpen=layoutRowState.has(model.rowNo)?layoutRowState.get(model.rowNo):(rowActive||(sectionOpen&&group.rows.length===1));"
newrow="const rowSelected=activeStructureSelection?.type==='row'&&Number(activeStructureSelection.row)===Number(model.rowNo),rowActive=rowSelected||model.items.some(([f])=>f.key===activeFieldKey),rowOpen=layoutRowState.has(model.rowNo)?layoutRowState.get(model.rowNo):(rowActive||(sectionOpen&&group.rows.length===1));"
if oldrow not in s: raise SystemExit('1.3.34: row active anchor missing')
s=s.replace(oldrow,newrow,1)
s=s.replace("rowGroup.className='df-layout-row-group'+(rowOpen?' is-open':'');", "rowGroup.className='df-layout-row-group'+(rowOpen?' is-open':'')+(rowSelected?' is-selected':'');",1)
oldrowhead="const rowBody=document.createElement('div');rowBody.className='df-layout-row-body';const row=document.createElement('div');"
# row header is before this; replace exact title markup and click handler separately.
s=s.replace("const widths=model.items.map(([f])=>Number(f.config.layout.width||100)+'%').join(' + ');rowHead.innerHTML=`<span class=\"df-layout-row-chevron\">›</span><span class=\"df-layout-row-label\">${esc(structureUi.row)} ${model.rowNo}</span><span class=\"df-layout-row-summary\">${model.items.length} ${esc(structureUi.fields)} · ${esc(widths)}</span>`;const toggleRow=()=>{layoutRowState.set(model.rowNo,!rowGroup.classList.contains('is-open'));renderLayoutCanvas();};rowHead.onclick=toggleRow;rowHead.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();toggleRow();}};",
            "const widths=model.items.map(([f])=>Number(f.config.layout.width||100)+'%').join(' + '),meta=rowMeta(model.rowNo),rowTitle=meta.title||`${structureUi.row} ${model.rowNo}`;rowHead.innerHTML=`<span class=\"df-layout-row-chevron\">›</span><span class=\"df-layout-row-label\">${esc(rowTitle)}</span>${meta.description?`<span class=\"df-layout-structure-description\">${esc(meta.description)}</span>`:''}<span class=\"df-layout-row-summary\">${model.items.length} ${esc(structureUi.fields)} · ${esc(widths)}</span>`;const toggleRow=()=>{layoutRowState.set(model.rowNo,!rowGroup.classList.contains('is-open'));renderLayoutCanvas();};rowHead.onclick=e=>{if(e.target.closest('.df-layout-row-chevron'))toggleRow();else selectRowSettings(model.rowNo);};rowHead.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();selectRowSettings(model.rowNo);}};",1)

# 5) Premium file pickers with drag/drop, UI trash, and page Analyze action below.
clear_anchor="document.getElementById('df-ai-html-clear')?.addEventListener('click',()=>{const input=document.getElementById('df-ai-html-file'),status=document.getElementById('df-ai-html-status');if(input)input.value='';if(status)status.textContent='HTML/ZIP massimo 25 MB';aiClearPreparedPreview();aiRefreshFileClearButtons();});"
if clear_anchor not in s: raise SystemExit('1.3.34: clear handlers anchor missing')
premium=r'''
function aiRefreshPremiumPicker(inputId){const input=document.getElementById(inputId);if(!input)return;const shell=input.closest('.df-ai-file-row')?.querySelector('.df-ai-upload-shell'),name=shell?.querySelector('[data-ai-upload-name]');if(!shell||!name)return;const file=input.files?.[0];shell.classList.toggle('has-file',!!file);name.textContent=file?.name||(inputId==='df-ai-file'?'Trascina qui il JSON o selezionalo':'Trascina qui HTML/ZIP o selezionalo');}
function aiEnhanceFilePicker(inputId,clearId,statusId){const input=document.getElementById(inputId),clear=document.getElementById(clearId),status=document.getElementById(statusId);if(!input||!clear||input.dataset.premiumPicker==='1')return;input.dataset.premiumPicker='1';input.classList.add('df-ai-native-file');clear.innerHTML=uiIcon('trash');clear.classList.add('df-ai-ui-delete');const row=input.closest('.df-ai-file-row');if(!row)return;row.classList.add('df-ai-premium-file-row');const shell=document.createElement('div');shell.className='df-ai-upload-shell';shell.tabIndex=0;shell.setAttribute('role','button');shell.setAttribute('aria-label','Seleziona file');shell.innerHTML=`<span class="df-ai-upload-copy"><strong>Seleziona file</strong><span data-ai-upload-name></span></span>`;row.insertBefore(shell,input);shell.appendChild(input);shell.appendChild(clear);const pick=()=>input.click();shell.addEventListener('click',e=>{if(e.target.closest('.df-ai-ui-delete'))return;pick();});shell.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();pick();}});['dragenter','dragover'].forEach(ev=>shell.addEventListener(ev,e=>{e.preventDefault();shell.classList.add('is-dragover');}));['dragleave','drop'].forEach(ev=>shell.addEventListener(ev,e=>{e.preventDefault();shell.classList.remove('is-dragover');}));shell.addEventListener('drop',e=>{const file=e.dataTransfer?.files?.[0];if(!file)return;try{const dt=new DataTransfer();dt.items.add(file);input.files=dt.files;input.dispatchEvent(new Event('change',{bubbles:true}));}catch{}});input.addEventListener('change',()=>queueMicrotask(()=>aiRefreshPremiumPicker(inputId)));aiRefreshPremiumPicker(inputId);if(status)row.appendChild(status);if(inputId==='df-ai-html-file'){const analyze=document.getElementById('df-ai-html-analyze');if(analyze){let actions=row.parentElement?.querySelector('.df-ai-page-actions');if(!actions){actions=document.createElement('div');actions.className='df-ai-actions df-ai-page-actions';row.after(actions);}analyze.classList.remove('df-small');analyze.classList.add('df-primary');actions.appendChild(analyze);}}}
function aiEnhanceUploadControls(){aiEnhanceFilePicker('df-ai-file','df-ai-file-clear','df-ai-file-status');aiEnhanceFilePicker('df-ai-html-file','df-ai-html-clear','df-ai-html-status');}
aiEnhanceUploadControls();document.getElementById('df-open-ai-import')?.addEventListener('click',()=>setTimeout(aiEnhanceUploadControls,0));
document.getElementById('df-ai-file-clear')?.addEventListener('click',()=>queueMicrotask(()=>aiRefreshPremiumPicker('df-ai-file')));document.getElementById('df-ai-html-clear')?.addEventListener('click',()=>queueMicrotask(()=>aiRefreshPremiumPicker('df-ai-html-file')));
'''
s=s.replace(clear_anchor,clear_anchor+'\n'+premium,1)

# 6) CSS finishing: premium uploads, UI delete, preview labels, entry buttons, structure selection.
css='''\n/* Forms 1.3.34: polished AI uploads + structure settings. */\n.df-field-entry-actions{display:grid!important;grid-template-columns:minmax(0,1fr) minmax(0,1fr)!important;gap:10px!important}.df-field-entry-actions>.df-add-field-main,.df-field-entry-actions>.df-ai-import-main{width:100%!important;min-height:46px!important;height:46px!important;margin:0!important;box-sizing:border-box}.df-ai-import-main>span,.df-add-field-main>span{font-size:18px;line-height:1}\n.df-ai-main-label{display:flex;flex-direction:column;gap:4px;min-width:0}.df-ai-main-label>span{font-size:11px;font-weight:800;color:var(--bs-secondary-color,#667085)}.df-ai-main-label>input{width:100%}\n.df-ai-premium-file-row{display:flex!important;flex-direction:column!important;align-items:stretch!important;gap:8px!important}.df-ai-native-file{position:absolute!important;width:1px!important;height:1px!important;opacity:0!important;pointer-events:none!important}.df-ai-upload-shell{display:flex;align-items:center;gap:12px;width:100%;min-height:66px;padding:10px 12px;border:1px dashed color-mix(in srgb,#7c3aed 42%,var(--df-border));border-radius:10px;background:color-mix(in srgb,#7c3aed 3%,var(--bs-body-bg,#fff));cursor:pointer;transition:border-color .16s ease,background .16s ease,box-shadow .16s ease}.df-ai-upload-shell:hover,.df-ai-upload-shell:focus-visible,.df-ai-upload-shell.is-dragover{outline:none;border-color:#7c3aed;background:color-mix(in srgb,#7c3aed 7%,var(--bs-body-bg,#fff));box-shadow:0 0 0 2px color-mix(in srgb,#7c3aed 10%,transparent)}.df-ai-upload-copy{display:flex;flex:1;min-width:0;flex-direction:column;gap:2px}.df-ai-upload-copy strong{font-size:13px}.df-ai-upload-copy [data-ai-upload-name]{font-size:12px;color:var(--bs-secondary-color,#667085);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.df-ai-upload-shell.has-file{border-style:solid}.df-ai-ui-delete{margin-left:auto!important;flex:0 0 34px!important;width:34px!important;height:34px!important;border:0!important;background:transparent!important;box-shadow:none!important;color:var(--bs-secondary-color,#667085)!important}.df-ai-ui-delete:hover,.df-ai-ui-delete:focus-visible{background:transparent!important;color:#dc3545!important;outline:none}.df-ai-ui-delete svg{width:18px!important;height:18px!important}.df-ai-page-actions{margin-top:2px}.df-ai-page-actions .df-primary{min-height:40px}\n.df-layout-row-group.is-selected>.df-layout-row-head{box-shadow:inset 3px 0 0 #7c3aed;background:color-mix(in srgb,#7c3aed 6%,var(--bs-body-bg,#fff))}.df-layout-structure-description{font-size:11px;color:var(--bs-secondary-color,#667085);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:260px}.df-structure-settings textarea{min-height:90px}.df-structure-settings .df-selected-top{min-height:54px}\n@media(max-width:720px){.df-field-entry-actions{grid-template-columns:1fr!important}.df-layout-structure-description{display:none}}\n'''
s=s.replace('</style>',css+'</style>',1)

# Version marker.
s=s.replace("window.dfBuilderRuntime={version:'1.3.33'","window.dfBuilderRuntime={version:'1.3.34'",1)

# Add/update translations.
translations={
'it-IT':{'COM_DECAROFORMS_SECTION_SETTINGS':'Impostazioni sezione','COM_DECAROFORMS_ROW_SETTINGS':'Impostazioni riga','COM_DECAROFORMS_TITLE':'Titolo','COM_DECAROFORMS_DESCRIPTION':'Descrizione'},
'en-GB':{'COM_DECAROFORMS_SECTION_SETTINGS':'Section settings','COM_DECAROFORMS_ROW_SETTINGS':'Row settings','COM_DECAROFORMS_TITLE':'Title','COM_DECAROFORMS_DESCRIPTION':'Description'},
'fr-FR':{'COM_DECAROFORMS_SECTION_SETTINGS':'Paramètres de section','COM_DECAROFORMS_ROW_SETTINGS':'Paramètres de ligne','COM_DECAROFORMS_TITLE':'Titre','COM_DECAROFORMS_DESCRIPTION':'Description'}}
for lang,vals in translations.items():
    lp=root/'administrator/components/com_decaroforms/language'/lang/'com_decaroforms.ini'
    if not lp.exists(): continue
    t=lp.read_text(encoding='utf-8')
    for k,v in vals.items():
        if re.search(r'^'+re.escape(k)+r'=',t,re.M): t=re.sub(r'^'+re.escape(k)+r'=.*$',f'{k}="{v}"',t,flags=re.M)
        else: t+=f'\n{k}="{v}"'
    lp.write_text(t+'\n' if not t.endswith('\n') else t,encoding='utf-8')

# Guardrails.
checks=["type==='upload'",'function aiHtmlUploadConfig','data-ai-main-label','function renderSectionSettings','function renderRowSettings','function aiEnhanceUploadControls',"uiIcon('trash')","version:'1.3.34'",'<span aria-hidden="true">＋</span> Importa con AI']
for c in checks:
    if c not in s: raise SystemExit('1.3.34 missing '+c)
p.write_text(s,encoding='utf-8')
PY

# Component version metadata.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)
php -l "$B" >/dev/null

# Check the injected JS fragments after stripping PHP echo expressions from the inspection slice.
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
assert "version:'1.3.34'" in s
assert 'function aiHtmlUploadConfig' in s
assert 'function renderRowSettings' in s
assert 'function aiEnhanceUploadControls' in s
# Syntax check substantial JS region; replace PHP echo calls with harmless quoted text.
a=s.index('const aiAllowedTypes=')
b=s.index('/* Forms 1.3.6: bind quick templates',a)
js=s[a:b]
js=re.sub(r"<\?php.*?\?>","X",js,flags=re.S)
Path('/tmp/forms-1334-check.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1334-check.js >/dev/null

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
<changelogs><changelog><element>pkg_decaroforms</element><type>package</type><version>$NEW</version><feature>Importazione HTML/ZIP: input file riconosciuti come Upload e configurazione accept, multiple e limite MB conservata quando leggibile.</feature><fix>Eliminati i campi Text disabilitati duplicati generati dai widget upload quando esiste il relativo Upload.</fix><improvement>Upload JSON e pagina salvata ridisegnati con selettore premium, drag and drop e icona UI elimina senza background.</improvement><improvement>Analizza pagina ora è un'azione principale colorata sotto al file selezionato.</improvement><improvement>L'anteprima AI mostra esplicitamente la voce Etichetta sopra il nome del campo.</improvement><improvement>Aggiungi campo e Importa con AI hanno dimensioni uniformi; Importa con AI usa il simbolo + ben visibile.</improvement><feature>Cliccando una sezione si apre Impostazioni sezione con Titolo e Descrizione.</feature><feature>Cliccando una riga si apre Impostazioni riga con Titolo e Descrizione interni al Builder; i metadati seguono la rinumerazione delle righe.</feature><language>it-IT</language></changelog></changelogs>
EOF
rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
