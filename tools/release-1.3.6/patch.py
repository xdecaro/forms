#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit('usage: patch.py COMPONENT_ROOT PLUGIN_ROOT')

comp = Path(sys.argv[1])
plug = Path(sys.argv[2])
builder = comp / 'administrator/components/com_decaroforms/tmpl/builder/default.php'
helper = comp / 'administrator/components/com_decaroforms/src/Helper/FormHelper.php'
component_manifest = comp / 'com_decaroforms.xml'
plugin_manifest = plug / 'decaroforms.xml'

t = builder.read_text()
h = helper.read_text()

old_add = "function add(item){const x=defaultFieldConfig(clone(item));x.key=uniqueKey(x.key);x.options=Array.isArray(x.options)?x.options:[];selected.push(x);openFieldKeys.add(x.key);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();}"
new_add = "function add(item){const x=defaultFieldConfig(clone(item));x.key=uniqueKey(x.key);x.options=Array.isArray(x.options)?x.options:[];selected.push(x);openFieldKeys.add(x.key);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();openBuilderSection(2,false);setTimeout(()=>{const cards=sel.querySelectorAll('.df-selected-item');const card=cards[cards.length-1];card?.scrollIntoView({behavior:'smooth',block:'center'});},100);}"
if old_add not in t:
    raise RuntimeError('add() function not found')
t = t.replace(old_add, new_add, 1)

old_defs = "const formTemplates={contact:['first_name','last_name','email','phone','subject','message','privacy_consent'],registration:['first_name','last_name','birth_date','email','phone','address','postcode','city','privacy_consent'],event:['first_name','last_name','email','event_date','participants','notes','privacy_consent'],membership:['first_name','last_name','birth_date','email','phone','address','postcode','city','member_number','privacy_consent'],reservation:['first_name','last_name','email','phone','event_date','participants','notes'],blank:[]};"
if old_defs not in t:
    raise RuntimeError('old quick-template definitions not found')
t = t.replace(old_defs, '', 1)

old_handler = "document.querySelectorAll('[data-form-template]').forEach(b=>b.addEventListener('click',()=>{const name=b.dataset.formTemplate,map=libByKey();try{if(name==='blank'){selected=[];openFieldKeys.clear();}else{const wanted=formTemplates[name]||[];const next=[];wanted.forEach(k=>{if(!map[k])return;const f=defaultFieldConfig(clone(map[k]));f.key=String(f.key||k);f.options=Array.isArray(f.options)?f.options:[];next.push(f);});selected=next;selected.forEach((f,i)=>{f.config.layout={row:i+1,col:1,width:100};});openFieldKeys.clear();if(selected[0])openFieldKeys.add(selected[0].key);}sync();renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();document.querySelectorAll('[data-form-template]').forEach(x=>x.classList.toggle('is-active',x===b));const quick=[...document.querySelectorAll('[data-accordion]')][1];quick?.classList.remove('is-open');quick?.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','false');openBuilderSection(2,true);}catch(err){console.error('Forms quick template error',err);alert('Impossibile caricare il modello rapido. Ricarica la pagina e riprova.');}}));"
if old_handler not in t:
    raise RuntimeError('old quick-template click handler not found')
t = t.replace(old_handler, '', 1)

quick_block = r'''
/* Forms 1.3.6: bind quick templates early so unrelated later initializers cannot disable them. */
const quickFormTemplates={contact:['first_name','last_name','email','phone','subject','message','privacy_consent'],registration:['first_name','last_name','birth_date','email','phone','address','postcode','city','privacy_consent'],event:['first_name','last_name','email','event_date','participants','notes','privacy_consent'],membership:['first_name','last_name','birth_date','email','phone','address','postcode','city','member_number','privacy_consent'],reservation:['first_name','last_name','email','phone','event_date','participants','notes'],blank:[]};
function applyQuickTemplate(button){
 const name=button.dataset.formTemplate;
 const map=Object.fromEntries(library.map(x=>[x.key,x]));
 try{
  const wanted=quickFormTemplates[name]||[];
  const next=[];
  if(name!=='blank')wanted.forEach(k=>{if(!map[k])return;const f=defaultFieldConfig(clone(map[k]));f.key=String(f.key||k);f.options=Array.isArray(f.options)?f.options:[];next.push(f);});
  if(name!=='blank'&&!next.length)throw new Error('Quick template contains no available fields: '+name);
  selected.splice(0,selected.length,...next);
  selected.forEach((f,i)=>{defaultFieldConfig(f);f.config.layout={row:i+1,col:1,width:100};});
  openFieldKeys.clear();
  if(selected[0])openFieldKeys.add(selected[0].key);
  sync();renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();
  document.querySelectorAll('[data-form-template]').forEach(x=>x.classList.toggle('is-active',x===button));
  const quick=[...document.querySelectorAll('[data-accordion]')][1];
  quick?.classList.remove('is-open');quick?.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','false');
  openBuilderSection(2,true);
 }catch(err){console.error('Forms quick template error',err);alert('Impossibile caricare il modello rapido. Ricarica la pagina e riprova.');}
}
document.addEventListener('click',e=>{const button=e.target.closest('[data-form-template]');if(!button)return;e.preventDefault();e.stopPropagation();applyQuickTemplate(button);});
'''
if new_add not in t:
    raise RuntimeError('new add anchor missing')
t = t.replace(new_add, new_add + '\n' + quick_block, 1)

css = r'''
/* Forms 1.3.6 mobile library + status UX */
.df-builder .df-status-remove{
  border-color:#dc3545!important;
  color:#b42332!important;
  background:color-mix(in srgb,#dc3545 6%,var(--df-theme-input,var(--bs-body-bg,#fff)))!important;
  font-weight:850;
}
.df-builder .df-status-remove:hover,
.df-builder .df-status-remove:focus-visible{
  border-color:#dc3545!important;
  color:#fff!important;
  background:#b42332!important;
}
[data-bs-theme="dark"] .df-builder .df-library-tab,
html[data-bs-theme="dark"] .df-builder .df-library-tab,
body[data-bs-theme="dark"] .df-builder .df-library-tab{
  background:#1f2937!important;
  color:#f4f7fb!important;
  border-color:#4a596b!important;
  box-shadow:none!important;
}
[data-bs-theme="dark"] .df-builder .df-library-tab:hover,
html[data-bs-theme="dark"] .df-builder .df-library-tab:hover,
body[data-bs-theme="dark"] .df-builder .df-library-tab:hover{
  background:#2a3747!important;
  color:#fff!important;
  border-color:#64748b!important;
}
[data-bs-theme="dark"] .df-builder .df-library-tab.is-active,
html[data-bs-theme="dark"] .df-builder .df-library-tab.is-active,
body[data-bs-theme="dark"] .df-builder .df-library-tab.is-active{
  background:rgba(230,0,70,.14)!important;
  color:#ff9bb4!important;
  border-color:#e60046!important;
  box-shadow:0 0 0 2px rgba(230,0,70,.12)!important;
}
[data-bs-theme="dark"] .df-builder .df-library-tab-count,
html[data-bs-theme="dark"] .df-builder .df-library-tab-count,
body[data-bs-theme="dark"] .df-builder .df-library-tab-count{
  background:#334155!important;
  color:#e5edf7!important;
}
[data-bs-theme="dark"] .df-builder .df-library-tab.is-active .df-library-tab-count,
html[data-bs-theme="dark"] .df-builder .df-library-tab.is-active .df-library-tab-count,
body[data-bs-theme="dark"] .df-builder .df-library-tab.is-active .df-library-tab-count{
  background:rgba(230,0,70,.22)!important;
  color:#ffd3de!important;
}
@media (prefers-color-scheme:dark){
 .df-builder .df-library-tab{background:#1f2937!important;color:#f4f7fb!important;border-color:#4a596b!important;box-shadow:none!important}
 .df-builder .df-library-tab:hover{background:#2a3747!important;color:#fff!important;border-color:#64748b!important}
 .df-builder .df-library-tab.is-active{background:rgba(230,0,70,.14)!important;color:#ff9bb4!important;border-color:#e60046!important;box-shadow:0 0 0 2px rgba(230,0,70,.12)!important}
 .df-builder .df-library-tab-count{background:#334155!important;color:#e5edf7!important}
 .df-builder .df-library-tab.is-active .df-library-tab-count{background:rgba(230,0,70,.22)!important;color:#ffd3de!important}
 .df-builder .df-status-remove{color:#ff9aa8!important;background:rgba(220,53,69,.10)!important;border-color:#b94b59!important}
 .df-builder .df-status-remove:hover,.df-builder .df-status-remove:focus-visible{color:#fff!important;background:#9f2f3d!important;border-color:#d95d6c!important}
}
@media(max-width:560px){
 .df-builder .df-status-editor{gap:14px}
 .df-builder .df-status-row{
   grid-template-columns:minmax(0,1fr) minmax(0,1fr)!important;
   gap:10px!important;
   padding:11px!important;
   border:1px solid var(--df-theme-border,var(--df-border))!important;
   border-radius:8px!important;
   background:var(--df-theme-surface-soft,var(--bs-tertiary-bg,#f7f8fa))!important;
 }
 .df-builder .df-status-row>input{min-width:0}
 .df-builder .df-status-color-wrap{grid-column:1!important;min-width:0}
 .df-builder .df-status-remove{grid-column:2!important;width:100%!important;height:44px!important;min-width:0}
}
'''
if '</style>' not in t:
    raise RuntimeError('builder style closing tag not found')
t = t.replace('</style>', css + '\n</style>', 1)

if "public const VERSION = '1.3.5'" not in h:
    raise RuntimeError('helper version 1.3.5 not found')
h = h.replace("public const VERSION = '1.3.5'", "public const VERSION = '1.3.6'", 1)
for p in (component_manifest, plugin_manifest):
    s = p.read_text()
    if '<version>1.3.5</version>' not in s:
        raise RuntimeError(f'1.3.5 version missing in {p.name}')
    p.write_text(s.replace('<version>1.3.5</version>', '<version>1.3.6</version>', 1))

builder.write_text(t)
helper.write_text(h)

final = builder.read_text()
checks = [
 'Forms 1.3.6: bind quick templates early',
 'selected.splice(0,selected.length,...next)',
 "openBuilderSection(2,false)",
 "card?.scrollIntoView({behavior:'smooth',block:'center'})",
 'Forms 1.3.6 mobile library + status UX',
 'background:rgba(230,0,70,.14)!important',
 'grid-template-columns:minmax(0,1fr) minmax(0,1fr)!important',
]
for token in checks:
    if token not in final:
        raise RuntimeError('missing expected builder token: '+token)
if old_handler in final or old_defs in final:
    raise RuntimeError('legacy quick-template handler still present')
print('Forms 1.3.6 patch applied')
