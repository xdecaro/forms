#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit('usage: patch.py COMPONENT_ROOT PLUGIN_ROOT')

comp=Path(sys.argv[1]); plug=Path(sys.argv[2])
builder=comp/'administrator/components/com_decaroforms/tmpl/builder/default.php'
helper=comp/'administrator/components/com_decaroforms/src/Helper/FormHelper.php'
component_manifest=comp/'com_decaroforms.xml'
plugin_manifest=plug/'decaroforms.xml'

def rep(text, old, new, label):
    if old not in text:
        raise RuntimeError(f'{label} not found')
    return text.replace(old,new,1)

h=helper.read_text()
h=rep(h,"public const VERSION = '1.3.19';","public const VERSION = '1.3.20';",'helper version')
helper.write_text(h)
for m in (component_manifest,plugin_manifest):
    s=m.read_text()
    s=rep(s,'<version>1.3.19</version>','<version>1.3.20</version>',str(m))
    m.write_text(s)

t=builder.read_text()
t=rep(t,
'.df-security-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.df-custom-code-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}.df-warning{',
'.df-security-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.df-custom-code-grid{display:grid;grid-template-columns:1fr;gap:12px}.df-custom-code-grid .df-field{width:100%;min-width:0}.df-custom-code-grid .df-codearea{width:100%;max-width:none;box-sizing:border-box}.df-warning{',
'custom code full width')
t=rep(t,
'.df-admin-footer{margin:28px 0 10px;padding-top:16px;border-top:1px solid var(--df-border);text-align:center;color:var(--bs-secondary-color,#667085);font-size:12px}',
'.df-admin-footer{width:100%;box-sizing:border-box;clear:both;margin:28px 0 10px;padding-top:16px;border-top:1px solid var(--df-border);text-align:center;color:var(--bs-secondary-color,#667085);font-size:12px}',
'footer full width')
t=rep(t,
"  <?php echo FormHelper::footer(); ?>\n</div>\n\n<script>",
"</div>\n\n<?php echo FormHelper::footer(); ?>\n\n<script>",
'move footer outside builder')
builder.write_text(t)
