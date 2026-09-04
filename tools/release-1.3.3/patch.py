#!/usr/bin/env python3
from pathlib import Path
import re, sys

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

# 1.3.2 accidentally emitted a JavaScript RegExp split over two physical lines.
# Replace the complete option-splitting expression with a valid /\r?\n/ expression.
pattern = r"x\.options=el\.value\.split\(.*?\)\.map\(v=>v\.trim\(\)\)\.filter\(Boolean\)"
replacement = r"x.options=el.value.split(/\r?\n/).map(v=>v.trim()).filter(Boolean)"
t2, n = re.subn(pattern, lambda m: replacement, t, count=1, flags=re.S)
if n != 1:
    raise RuntimeError(f'option split hotfix replacements={n}')
t = t2

# Make the main Builder accordions deterministic and independent.
old_accordion = "document.querySelectorAll('[data-accordion]').forEach(section=>{const btn=section.querySelector('.df-section-toggle');btn?.addEventListener('click',()=>{const open=!section.classList.contains('is-open');if(window.matchMedia('(max-width:800px)').matches&&open){document.querySelectorAll('[data-accordion].is-open').forEach(x=>{if(x!==section){x.classList.remove('is-open');x.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','false');}});}section.classList.toggle('is-open',open);btn.setAttribute('aria-expanded',open?'true':'false');});});"
new_accordion = "const accordionSections=[...document.querySelectorAll('[data-accordion]')];accordionSections.forEach((section,index)=>{const btn=section.querySelector('.df-section-toggle');const setOpen=open=>{section.classList.toggle('is-open',open);btn?.setAttribute('aria-expanded',open?'true':'false');};setOpen(index===0);btn?.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();const open=!section.classList.contains('is-open');if(window.matchMedia('(max-width:800px)').matches&&open){accordionSections.forEach(x=>{if(x!==section){x.classList.remove('is-open');x.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','false');}});}setOpen(open);});});"
if old_accordion not in t:
    raise RuntimeError('main accordion handler not found')
t = t.replace(old_accordion, new_accordion, 1)

# Remove the custom pink/red hover from accordion headers and soften only the closure panel.
hotfix_css = r'''
/* Forms 1.3.3 interaction hotfix */
.df-section-toggle:hover,
.df-section-toggle:focus-visible{
  background:var(--bs-tertiary-bg,#f7f8fa)!important;
  color:inherit!important;
  box-shadow:none!important;
}
.df-closed-box{
  background:color-mix(in srgb,var(--df) 7%,var(--bs-body-bg,#fff))!important;
  border:1px solid color-mix(in srgb,var(--df) 34%,var(--df-border,#dfe3e7))!important;
}
.df-closed-box label{
  color:var(--bs-body-color,#1f2937)!important;
}
.df-closed-box .df-note{
  color:var(--bs-secondary-color,#667085)!important;
  opacity:1!important;
}
.df-closed-box input,
.df-closed-box select{
  background:var(--bs-body-bg,#fff)!important;
  color:var(--bs-body-color,#1f2937)!important;
}
'''
if '</style>' not in t:
    raise RuntimeError('builder style closing tag not found')
t = t.replace('</style>', hotfix_css + '\n</style>', 1)

# Version bump.
if "public const VERSION = '1.3.2'" not in h:
    raise RuntimeError('helper version 1.3.2 not found')
h = h.replace("public const VERSION = '1.3.2'", "public const VERSION = '1.3.3'", 1)
for p in (component_manifest, plugin_manifest):
    s = p.read_text()
    if '<version>1.3.2</version>' not in s:
        raise RuntimeError(f'1.3.2 version missing in {p.name}')
    p.write_text(s.replace('<version>1.3.2</version>', '<version>1.3.3</version>', 1))

builder.write_text(t)
helper.write_text(h)

# Hard checks for the exact regression.
final = builder.read_text()
if 'split(/\\r?\\n/)' not in final:
    raise RuntimeError('valid option split regex missing after hotfix')
if re.search(r"split\(/\\r\?\\\s*\n/\)", final):
    raise RuntimeError('broken multiline split regex still present')
if 'const accordionSections=' not in final:
    raise RuntimeError('stable accordion handler missing')
print('Forms 1.3.3 hotfix applied')
