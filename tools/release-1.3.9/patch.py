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
/* Forms 1.3.9: accordion contrast fix in Joomla light mode. */
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle,
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle *,
html[data-bs-theme="light"] .df-builder .df-section-toggle,
html[data-bs-theme="light"] .df-builder .df-section-toggle *{
  color:#1f2937!important;
}
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle,
html[data-bs-theme="light"] .df-builder .df-section-toggle{
  background:#f6f7f9!important;
  border-color:#d9dee5!important;
  box-shadow:none!important;
}
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle:hover,
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle:focus-visible,
html[data-bs-theme="light"] .df-builder .df-section-toggle:hover,
html[data-bs-theme="light"] .df-builder .df-section-toggle:focus-visible{
  background:#eef1f4!important;
  color:#1f2937!important;
}
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section.is-open>.df-section-toggle,
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section.is-open>.df-section-toggle *,
html[data-bs-theme="light"] .df-builder .df-section.is-open>.df-section-toggle,
html[data-bs-theme="light"] .df-builder .df-section.is-open>.df-section-toggle *{
  background:#f1f4f8!important;
  color:#1f2937!important;
}
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle svg,
html[data-bs-theme="light"] .df-builder .df-section-toggle svg{
  color:#1f2937!important;
  fill:currentColor!important;
  stroke:currentColor!important;
}
html:not([data-bs-theme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-section-toggle .df-section-chevron,
html[data-bs-theme="light"] .df-builder .df-section-toggle .df-section-chevron{
  color:#1f2937!important;
}
'''

if '</style>' not in t:
    raise RuntimeError('builder style closing tag not found')
t = t.replace('</style>', css + '\n</style>', 1)

if "public const VERSION = '1.3.8'" not in h:
    raise RuntimeError('helper version 1.3.8 not found')
h = h.replace("public const VERSION = '1.3.8'", "public const VERSION = '1.3.9'", 1)

for p in (component_manifest, plugin_manifest):
    s = p.read_text()
    if '<version>1.3.8</version>' not in s:
        raise RuntimeError(f'1.3.8 version missing in {p.name}')
    p.write_text(s.replace('<version>1.3.8</version>', '<version>1.3.9</version>', 1))

builder.write_text(t)
helper.write_text(h)

final = builder.read_text()
for token in [
    'Forms 1.3.9: accordion contrast fix in Joomla light mode.',
    '.df-section-toggle *',
    'background:#f6f7f9!important',
    'color:#1f2937!important',
    'fill:currentColor!important',
]:
    if token not in final:
        raise RuntimeError('missing expected token: ' + token)

print('Forms 1.3.9 patch applied')
