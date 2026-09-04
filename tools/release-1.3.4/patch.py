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

css = r'''
/* Forms 1.3.4 accordion visual style */
.df-section-toggle{
  background:var(--bs-dark,#1f2937)!important;
  color:#fff!important;
}
.df-section-toggle strong,
.df-section-toggle .df-section-chevron{
  color:#fff!important;
}
.df-section-toggle:hover,
.df-section-toggle:focus-visible{
  background:color-mix(in srgb,var(--bs-dark,#1f2937) 90%,#fff 10%)!important;
  color:#fff!important;
  box-shadow:none!important;
}
.df-section-toggle:focus-visible{
  outline:2px solid var(--bs-primary,#0d6efd)!important;
  outline-offset:2px;
}
'''

if '</style>' not in t:
    raise RuntimeError('builder style closing tag not found')
t = t.replace('</style>', css + '\n</style>', 1)

if "public const VERSION = '1.3.3'" not in h:
    raise RuntimeError('helper version 1.3.3 not found')
h = h.replace("public const VERSION = '1.3.3'", "public const VERSION = '1.3.4'", 1)

for p in (component_manifest, plugin_manifest):
    s = p.read_text()
    if '<version>1.3.3</version>' not in s:
        raise RuntimeError(f'1.3.3 version missing in {p.name}')
    p.write_text(s.replace('<version>1.3.3</version>', '<version>1.3.4</version>', 1))

builder.write_text(t)
helper.write_text(h)

final = builder.read_text()
for token in [
    'Forms 1.3.4 accordion visual style',
    'background:var(--bs-dark,#1f2937)!important',
    'color:#fff!important',
    'const accordionSections=',
    'split(/\\r?\\n/)',
]:
    if token not in final:
        raise RuntimeError('missing expected builder token: ' + token)

print('Forms 1.3.4 accordion style applied')
