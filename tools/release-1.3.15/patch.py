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

def replace_once(text, old, new, label):
    if old not in text:
        raise RuntimeError(f'{label} not found')
    return text.replace(old, new, 1)

# Version metadata.
h = replace_once(h, "public const VERSION = '1.3.14';", "public const VERSION = '1.3.15';", 'helper version')
for manifest in (component_manifest, plugin_manifest):
    value = manifest.read_text()
    value = replace_once(value, '<version>1.3.14</version>', '<version>1.3.15</version>', str(manifest))
    manifest.write_text(value)

# Put required + width controls in their own accordion in the field properties panel.
old_layout = '''<div class="full df-required"><input type="checkbox" data-k-check="required" ${x.required?'checked':''}><label>${esc(tr.required)}</label></div><div class="full"><label>Larghezza</label><div class="df-field-width-pills">${[100,75,66,60,50,40,33,25].map(w=>`<button type="button" data-field-width="${w}" class="${Number(x.config.layout.width||100)===w?'is-active':''}">${w}%</button>`).join('')}</div></div>${configHtml(x)}${renderConditions(x,i)}'''
new_layout = '''<details class="full df-layout-settings"><summary>Layout e larghezza</summary><div class="df-layout-settings-body"><div class="df-required"><input type="checkbox" data-k-check="required" ${x.required?'checked':''}><label>${esc(tr.required)}</label></div><div class="df-field-width-block"><label>Larghezza</label><div class="df-field-width-pills">${[100,75,66,60,50,40,33,25].map(w=>`<button type="button" data-field-width="${w}" class="${Number(x.config.layout.width||100)===w?'is-active':''}">${w}%</button>`).join('')}</div></div></div></details>${configHtml(x)}${renderConditions(x,i)}'''
t = replace_once(t, old_layout, new_layout, 'field layout accordion')

css = r'''
/* Forms 1.3.15: explicit light-mode surfaces and compact field layout accordion. */
.df-layout-settings{grid-column:1/-1;border:1px solid var(--df-border);border-radius:6px;background:color-mix(in srgb,var(--bs-tertiary-bg,#f7f8fa) 45%,transparent);overflow:hidden}
.df-layout-settings>summary{cursor:pointer;list-style:none;display:flex;align-items:center;justify-content:space-between;padding:10px 11px;color:#2869b2;font-weight:800}
.df-layout-settings>summary::-webkit-details-marker{display:none}
.df-layout-settings>summary:after{content:'⌄';font-size:12px;transition:transform .2s ease}
.df-layout-settings[open]>summary:after{transform:rotate(180deg)}
.df-layout-settings-body{display:grid;gap:12px;padding:0 11px 11px}
.df-field-width-block>label{display:block;margin-bottom:7px;font-weight:750}

/* Joomla can be light while the operating system prefers dark. These final rules make the Builder follow Joomla, not the OS. */
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-layout-row{
  background:#f6f7f9!important;border-color:#d9dee5!important;color:#1f2937!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-layout-card{
  background:#fff!important;color:#1f2937!important;border-color:#d9dee5!important;box-shadow:0 1px 2px rgba(15,23,42,.05)!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-layout-card strong{color:#1f2937!important}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-layout-handle{color:#7b8796!important}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-layout-card select{
  background:#fff!important;color:#1f2937!important;border-color:#cfd6df!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-layout-newrow{
  background:#fff!important;color:#667085!important;border-color:#cfd6df!important;
}

html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-subbox,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-email-block,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-email-block-body,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-email-choice,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-email-special,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-additional-card{
  background:#fff!important;color:#1f2937!important;border-color:#d9dee5!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-email-block>summary{
  background:#f6f7f9!important;color:#1f2937!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-subbox h4,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-email-block summary,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-email-block label,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-subbox label,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-check,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-label-info,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-email-choice-foot,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-status-color-value{
  color:#1f2937!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-note{color:#667085!important}

html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-status-row input:not([type=color]),
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-status-remove,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-column-item,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-field input:not([type=checkbox]):not([type=radio]):not([type=color]),
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-field textarea,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-field select,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-codearea,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-tokenbar select{
  background:#fff!important;color:#1f2937!important;border-color:#cfd6df!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-codearea::placeholder,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder input::placeholder,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder textarea::placeholder{color:#8a94a3!important;opacity:1}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-column-item{color:#1f2937!important}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-status-remove{color:#b42318!important;background:#fff!important;border-color:#e3a3aa!important}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-status-remove:hover,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-status-remove:focus-visible{background:#fff1f3!important;color:#a10f25!important;border-color:#dc3545!important}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-warning{background:#fff8e8!important;color:#5f4600!important}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-layout-settings,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-main-settings,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-condition-details,
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-tax-links{
  background:#f8f9fb!important;color:#1f2937!important;border-color:#d9dee5!important;
}
'''
if '</style>' not in t:
    raise RuntimeError('builder style closing tag not found')
t = t.replace('</style>', css + '\n</style>', 1)

builder.write_text(t)
helper.write_text(h)

final = builder.read_text()
for token in ['df-layout-settings','Layout e larghezza','Forms 1.3.15','background:#fff!important;color:#1f2937!important']:
    if token not in final:
        raise RuntimeError('missing expected token: ' + token)
print('Forms 1.3.15 patch applied')
