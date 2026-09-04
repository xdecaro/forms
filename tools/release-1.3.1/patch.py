#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit('usage: patch.py COMPONENT_ROOT PLUGIN_ROOT')
comp = Path(sys.argv[1])
plug = Path(sys.argv[2])

builder = comp / 'administrator/components/com_decaroforms/tmpl/builder/default.php'
t = builder.read_text()

def replace_once(old: str, new: str, label: str) -> None:
    global t
    if old not in t:
        raise RuntimeError(f'{label} pattern not found')
    t = t.replace(old, new, 1)

# Approved visual language: red accordion headers, white content, clear selected quick template.
replace_once(
    ".df-section-toggle{width:100%;display:flex;align-items:center;justify-content:space-between;gap:12px;padding:15px 17px;border:0;background:var(--bs-tertiary-bg,#f7f8fa);color:inherit;text-align:left;font:inherit;font-weight:850;cursor:pointer}.df-section-toggle strong{font-size:18px}",
    ".df-section-toggle{width:100%;display:flex;align-items:center;justify-content:space-between;gap:12px;padding:15px 17px;border:0;background:var(--df);color:#fff;text-align:left;font:inherit;font-weight:850;cursor:pointer;transition:background .18s ease}.df-section-toggle:hover,.df-section-toggle:focus-visible{background:var(--df-dark);color:#fff}.df-section-toggle strong{font-size:18px;color:#fff}.df-section-chevron{color:#fff}",
    'accordion CSS'
)
replace_once(
    ".df-template-row button:hover{border-color:var(--df);color:var(--df)}",
    ".df-template-row button:hover{border-color:var(--df);color:var(--df)}.df-template-row button.is-active{background:var(--df);border-color:var(--df);color:#fff}.df-template-row button.is-active:hover{background:var(--df-dark);border-color:var(--df-dark);color:#fff}.df-layout-feedback{font-size:12px;font-weight:800;color:#18794e}",
    'template button CSS'
)

# Always source the library directly from the helper. This avoids an empty UI if the view property is stale/cached.
replace_once(
    "const library=<?php echo json_encode($this->library, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;",
    "const library=<?php echo json_encode(FormHelper::fieldLibrary(), JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;",
    'library data source'
)

# Render the library immediately after its listeners are attached, instead of waiting for the entire advanced script to finish.
replace_once(
    "filter.addEventListener('change',()=>{filter.dataset.value=filter.value;renderLibrary();});search.addEventListener('input',renderLibrary);",
    "filter.addEventListener('change',()=>{filter.dataset.value=filter.value;renderLibrary();});search.addEventListener('input',renderLibrary);renderLibrary();",
    'library initial render'
)

# Make Apply to fields visibly confirm the operation and open Selected fields so the result is immediately inspectable.
old_layout = "document.getElementById('df-layout-apply').addEventListener('click',()=>{const widths=builderConfig.layout.widths.slice(0,builderConfig.layout.columns);selected.forEach((f,i)=>{defaultFieldConfig(f);const col=(i%builderConfig.layout.columns)+1,row=Math.floor(i/builderConfig.layout.columns)+1;f.config.layout={row,col,width:widths[col-1]||100};});renderSelected();});"
new_layout = "document.getElementById('df-layout-apply').addEventListener('click',e=>{const widths=builderConfig.layout.widths.slice(0,builderConfig.layout.columns);selected.forEach((f,i)=>{defaultFieldConfig(f);const col=(i%builderConfig.layout.columns)+1,row=Math.floor(i/builderConfig.layout.columns)+1;f.config.layout={row,col,width:widths[col-1]||100};});renderSelected();sync();const btn=e.currentTarget,oldText=btn.textContent;btn.textContent=selected.length?`✓ Applicato a ${selected.length} camp${selected.length===1?'o':'i'}`:'Nessun campo selezionato';setTimeout(()=>btn.textContent=oldText,1800);if(selected.length)openBuilderSection(2,true);});"
replace_once(old_layout, new_layout, 'layout apply handler')

# Render statuses and columns immediately, so a later optional integration error cannot blank these core sections.
replace_once(
    "document.getElementById('df-add-status').onclick=()=>{statuses.push({key:'status_'+(statuses.length+1),label:'Nuovo stato',color:statusPalette[statuses.length%statusPalette.length]});renderStatuses();};",
    "document.getElementById('df-add-status').onclick=()=>{statuses.push({key:'',label:'',color:statusPalette[statuses.length%statusPalette.length]});renderStatuses();};renderStatuses();",
    'status add/render'
)
replace_once(
    "document.getElementById('df-columns-all').onclick=()=>{columns=columnItems().map(i=>i[0]);renderColumns();};document.getElementById('df-columns-reset').onclick=()=>{columns=['_reference','_email','_status','_created_at'];renderColumns();};",
    "document.getElementById('df-columns-all').onclick=()=>{columns=columnItems().map(i=>i[0]);renderColumns();};document.getElementById('df-columns-reset').onclick=()=>{columns=['_reference','_email','_status','_created_at'];renderColumns();};renderColumns();",
    'columns initial render'
)

# Quick templates: populate fields, mark the selected preset, close preset section and open Selected fields automatically.
old_quick = "// Quick templates.\nconst libByKey=()=>Object.fromEntries(library.map(x=>[x.key,x]));const formTemplates={contact:['first_name','last_name','email','phone','subject','message','privacy_consent'],registration:['first_name','last_name','birth_date','email','phone','address','postcode','city','privacy_consent'],event:['first_name','last_name','email','event_date','participants','notes','privacy_consent'],membership:['first_name','last_name','birth_date','email','phone','address','postcode','city','member_number','privacy_consent'],reservation:['first_name','last_name','email','phone','event_date','participants','notes'],blank:[]};document.querySelectorAll('[data-form-template]').forEach(b=>b.onclick=()=>{const name=b.dataset.formTemplate;if(name==='blank'){selected=[];}else{const map=libByKey();selected=(formTemplates[name]||[]).map(k=>defaultFieldConfig(clone(map[k]))).filter(Boolean);selected.forEach((f,i)=>{f.key=uniqueKey(f.key);f.config.layout={row:i+1,col:1,width:100};});}renderSelected();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();});"
new_quick = "// Quick templates.\nconst libByKey=()=>Object.fromEntries(library.map(x=>[x.key,x]));\nconst formTemplates={contact:['first_name','last_name','email','phone','subject','message','privacy_consent'],registration:['first_name','last_name','birth_date','email','phone','address','postcode','city','privacy_consent'],event:['first_name','last_name','email','event_date','participants','notes','privacy_consent'],membership:['first_name','last_name','birth_date','email','phone','address','postcode','city','member_number','privacy_consent'],reservation:['first_name','last_name','email','phone','event_date','participants','notes'],blank:[]};\nfunction openBuilderSection(index,scroll=false){const sections=[...document.querySelectorAll('[data-accordion]')],section=sections[index];if(!section)return;if(window.matchMedia('(max-width:800px)').matches){sections.forEach((x,i)=>{if(i!==index){x.classList.remove('is-open');x.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','false');}});}section.classList.add('is-open');section.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','true');if(scroll)setTimeout(()=>section.scrollIntoView({behavior:'smooth',block:'start'}),80);}\ndocument.querySelectorAll('[data-form-template]').forEach(b=>b.addEventListener('click',()=>{const name=b.dataset.formTemplate,map=libByKey();if(name==='blank'){selected=[];}else{selected=(formTemplates[name]||[]).map(k=>map[k]?defaultFieldConfig(clone(map[k])):null).filter(Boolean);selected.forEach((f,i)=>{f.key=String(f.key||('field_'+(i+1)));f.config.layout={row:i+1,col:1,width:100};});}document.querySelectorAll('[data-form-template]').forEach(x=>x.classList.toggle('is-active',x===b));renderSelected();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();sync();const quickSection=[...document.querySelectorAll('[data-accordion]')][1];quickSection?.classList.remove('is-open');quickSection?.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','false');openBuilderSection(2,true);}));"
replace_once(old_quick, new_quick, 'quick template handler')

# Remove duplicate final core renders that are now done earlier; keep advanced renders and sync.
replace_once(
    "renderLibrary();renderSelected();renderLayout();renderStatuses();renderColumns();renderTokens();renderUserEmailFields();renderEmailPickers();renderAdditional();sync();",
    "renderSelected();renderLayout();renderTokens();renderUserEmailFields();renderEmailPickers();renderAdditional();sync();",
    'final render sequence'
)

builder.write_text(t)

# Bump component, plugin and helper version references.
for p in [
    comp / 'com_decaroforms.xml',
    plug / 'decaroforms.xml',
    comp / 'administrator/components/com_decaroforms/src/Helper/FormHelper.php',
]:
    s = p.read_text()
    if '1.3.0' not in s:
        raise RuntimeError(f'1.3.0 not found in {p}')
    p.write_text(s.replace('1.3.0','1.3.1'))

print('Forms 1.3.1 builder fixes applied')
