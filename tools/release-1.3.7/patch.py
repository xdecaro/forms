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

old_add = "function add(item){const x=defaultFieldConfig(clone(item));x.key=uniqueKey(x.key);x.options=Array.isArray(x.options)?x.options:[];selected.push(x);openFieldKeys.add(x.key);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();openBuilderSection(2,false);setTimeout(()=>{const cards=sel.querySelectorAll('.df-selected-item');const card=cards[cards.length-1];card?.scrollIntoView({behavior:'smooth',block:'center'});},100);}"
new_add = "function add(item){const x=defaultFieldConfig(clone(item));x.key=uniqueKey(x.key);x.options=Array.isArray(x.options)?x.options:[];selected.push(x);openFieldKeys.add(x.key);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();const selectedSection=[...document.querySelectorAll('[data-accordion]')][2];if(selectedSection){selectedSection.classList.add('is-open');selectedSection.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','true');}setTimeout(()=>{if(selectedSection){selectedSection.classList.add('is-open');selectedSection.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','true');}const cards=sel.querySelectorAll('.df-selected-item');const card=cards[cards.length-1];if(card){card.classList.add('is-open');card.scrollIntoView({behavior:'smooth',block:'center'});}},140);}"
if old_add not in t:
    raise RuntimeError('Forms 1.3.6 add() function not found')
t = t.replace(old_add, new_add, 1)

css = r'''
/* Forms 1.3.7 layout dark-mode and spacing fixes */
.df-builder .df-layout-newrow{
  margin-top:16px;
  margin-bottom:18px;
  padding:12px 14px;
  line-height:1.45;
}
.df-builder .df-layout-advanced-box{
  margin-top:18px;
}
[data-bs-theme="dark"] .df-builder .df-layout-row,
html[data-bs-theme="dark"] .df-builder .df-layout-row,
body[data-bs-theme="dark"] .df-builder .df-layout-row{
  background:rgba(255,255,255,.035)!important;
  border-color:#657386!important;
}
[data-bs-theme="dark"] .df-builder .df-layout-card,
html[data-bs-theme="dark"] .df-builder .df-layout-card,
body[data-bs-theme="dark"] .df-builder .df-layout-card{
  background:#151c24!important;
  color:#f4f7fb!important;
  border-color:#5b697a!important;
  box-shadow:0 1px 2px rgba(0,0,0,.28)!important;
}
[data-bs-theme="dark"] .df-builder .df-layout-card strong,
html[data-bs-theme="dark"] .df-builder .df-layout-card strong,
body[data-bs-theme="dark"] .df-builder .df-layout-card strong{
  color:#f4f7fb!important;
}
[data-bs-theme="dark"] .df-builder .df-layout-handle,
html[data-bs-theme="dark"] .df-builder .df-layout-handle,
body[data-bs-theme="dark"] .df-builder .df-layout-handle{
  color:#a9b6c6!important;
}
[data-bs-theme="dark"] .df-builder .df-layout-card select,
html[data-bs-theme="dark"] .df-builder .df-layout-card select,
body[data-bs-theme="dark"] .df-builder .df-layout-card select{
  background:#111820!important;
  color:#f8fafc!important;
  border-color:#5b697a!important;
}
[data-bs-theme="dark"] .df-builder .df-layout-newrow,
html[data-bs-theme="dark"] .df-builder .df-layout-newrow,
body[data-bs-theme="dark"] .df-builder .df-layout-newrow{
  background:rgba(255,255,255,.025)!important;
  color:#aeb9c7!important;
  border-color:#758294!important;
}
@media (prefers-color-scheme:dark){
 .df-builder .df-layout-row{background:rgba(255,255,255,.035)!important;border-color:#657386!important}
 .df-builder .df-layout-card{background:#151c24!important;color:#f4f7fb!important;border-color:#5b697a!important;box-shadow:0 1px 2px rgba(0,0,0,.28)!important}
 .df-builder .df-layout-card strong{color:#f4f7fb!important}
 .df-builder .df-layout-handle{color:#a9b6c6!important}
 .df-builder .df-layout-card select{background:#111820!important;color:#f8fafc!important;border-color:#5b697a!important}
 .df-builder .df-layout-newrow{background:rgba(255,255,255,.025)!important;color:#aeb9c7!important;border-color:#758294!important}
}
'''
if '</style>' not in t:
    raise RuntimeError('builder style closing tag not found')
t = t.replace('</style>', css + '\n</style>', 1)

if "public const VERSION = '1.3.6'" not in h:
    raise RuntimeError('helper version 1.3.6 not found')
h = h.replace("public const VERSION = '1.3.6'", "public const VERSION = '1.3.7'", 1)
for p in (component_manifest, plugin_manifest):
    s = p.read_text()
    if '<version>1.3.6</version>' not in s:
        raise RuntimeError(f'1.3.6 version missing in {p.name}')
    p.write_text(s.replace('<version>1.3.6</version>', '<version>1.3.7</version>', 1))

builder.write_text(t)
helper.write_text(h)

final = builder.read_text()
checks = [
    "const selectedSection=[...document.querySelectorAll('[data-accordion]')][2]",
    "selectedSection.classList.add('is-open')",
    "card.classList.add('is-open')",
    'Forms 1.3.7 layout dark-mode and spacing fixes',
    'margin-top:16px',
    'background:#151c24!important',
]
for token in checks:
    if token not in final:
        raise RuntimeError('missing expected token: ' + token)
print('Forms 1.3.7 patch applied')
