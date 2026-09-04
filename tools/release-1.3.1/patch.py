#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit('usage: patch.py COMPONENT_ROOT PLUGIN_ROOT')
comp = Path(sys.argv[1])
plug = Path(sys.argv[2])

builder = comp / 'administrator/components/com_decaroforms/tmpl/builder/default.php'
t = builder.read_text()

old_css = ".df-section-toggle{width:100%;display:flex;align-items:center;justify-content:space-between;gap:12px;padding:15px 17px;border:0;background:var(--bs-tertiary-bg,#f7f8fa);color:inherit;text-align:left;font:inherit;font-weight:850;cursor:pointer}.df-section-toggle strong{font-size:18px}"
new_css = ".df-section-toggle{width:100%;display:flex;align-items:center;justify-content:space-between;gap:12px;padding:15px 17px;border:0;background:var(--df);color:#fff;text-align:left;font:inherit;font-weight:850;cursor:pointer;transition:background .18s ease}.df-section-toggle:hover,.df-section-toggle:focus-visible{background:var(--df-dark);color:#fff}.df-section-toggle strong{font-size:18px;color:#fff}.df-section-chevron{color:#fff}"
if old_css not in t:
    raise RuntimeError('accordion CSS pattern not found')
t = t.replace(old_css, new_css, 1)

old_tpl_css = ".df-template-row button:hover{border-color:var(--df);color:var(--df)}"
new_tpl_css = ".df-template-row button:hover{border-color:var(--df);color:var(--df)}.df-template-row button.is-active{background:var(--df);border-color:var(--df);color:#fff}.df-template-row button.is-active:hover{background:var(--df-dark);border-color:var(--df-dark);color:#fff}"
if old_tpl_css not in t:
    raise RuntimeError('template button CSS pattern not found')
t = t.replace(old_tpl_css, new_tpl_css, 1)

old = "// Quick templates.\nconst libByKey=()=>Object.fromEntries(library.map(x=>[x.key,x]));const formTemplates={contact:['first_name','last_name','email','phone','subject','message','privacy_consent'],registration:['first_name','last_name','birth_date','email','phone','address','postcode','city','privacy_consent'],event:['first_name','last_name','email','event_date','participants','notes','privacy_consent'],membership:['first_name','last_name','birth_date','email','phone','address','postcode','city','member_number','privacy_consent'],reservation:['first_name','last_name','email','phone','event_date','participants','notes'],blank:[]};document.querySelectorAll('[data-form-template]').forEach(b=>b.onclick=()=>{const name=b.dataset.formTemplate;if(name==='blank'){selected=[];}else{const map=libByKey();selected=(formTemplates[name]||[]).map(k=>defaultFieldConfig(clone(map[k]))).filter(Boolean);selected.forEach((f,i)=>{f.key=uniqueKey(f.key);f.config.layout={row:i+1,col:1,width:100};});}renderSelected();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();});"
new = "// Quick templates.\nconst libByKey=()=>Object.fromEntries(library.map(x=>[x.key,x]));\nconst formTemplates={contact:['first_name','last_name','email','phone','subject','message','privacy_consent'],registration:['first_name','last_name','birth_date','email','phone','address','postcode','city','privacy_consent'],event:['first_name','last_name','email','event_date','participants','notes','privacy_consent'],membership:['first_name','last_name','birth_date','email','phone','address','postcode','city','member_number','privacy_consent'],reservation:['first_name','last_name','email','phone','event_date','participants','notes'],blank:[]};\nfunction openBuilderSection(index,scroll=false){const sections=[...document.querySelectorAll('[data-accordion]')],section=sections[index];if(!section)return;if(window.matchMedia('(max-width:800px)').matches){sections.forEach((x,i)=>{if(i!==index){x.classList.remove('is-open');x.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','false');}});}section.classList.add('is-open');section.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','true');if(scroll)setTimeout(()=>section.scrollIntoView({behavior:'smooth',block:'start'}),80);}\ndocument.querySelectorAll('[data-form-template]').forEach(b=>b.addEventListener('click',()=>{\n const name=b.dataset.formTemplate,map=libByKey();\n if(name==='blank'){selected=[];}else{selected=(formTemplates[name]||[]).map(k=>map[k]?defaultFieldConfig(clone(map[k])):null).filter(Boolean);selected.forEach((f,i)=>{f.key=String(f.key||('field_'+(i+1)));f.config.layout={row:i+1,col:1,width:100};});}\n document.querySelectorAll('[data-form-template]').forEach(x=>x.classList.toggle('is-active',x===b));\n renderSelected();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();sync();\n const quickSection=[...document.querySelectorAll('[data-accordion]')][1];quickSection?.classList.remove('is-open');quickSection?.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','false');\n openBuilderSection(2,true);\n}));"
if old not in t:
    raise RuntimeError('quick template handler pattern not found')
t = t.replace(old, new, 1)

# A newly added status starts empty: avoid showing a confusing duplicate "Nuovo stato" next to the built-in "Nuovo" status.
old_status = "document.getElementById('df-add-status').onclick=()=>{statuses.push({key:'status_'+(statuses.length+1),label:'Nuovo stato',color:statusPalette[statuses.length%statusPalette.length]});renderStatuses();};"
new_status = "document.getElementById('df-add-status').onclick=()=>{statuses.push({key:'',label:'',color:statusPalette[statuses.length%statusPalette.length]});renderStatuses();};"
if old_status not in t:
    raise RuntimeError('add status pattern not found')
t = t.replace(old_status, new_status, 1)

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

print('Forms 1.3.1 builder fix applied')
