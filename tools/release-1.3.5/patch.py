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

# Accordion sections must be independent on desktop, tablet and smartphone.
mobile_close = "if(window.matchMedia('(max-width:800px)').matches&&open){accordionSections.forEach(x=>{if(x!==section){x.classList.remove('is-open');x.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','false');}});}"
if mobile_close not in t:
    raise RuntimeError('mobile accordion auto-close handler not found')
t = t.replace(mobile_close, '', 1)

quick_mobile_close = "if(window.matchMedia('(max-width:800px)').matches){sections.forEach((x,i)=>{if(i!==index){x.classList.remove('is-open');x.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','false');}});}"
if quick_mobile_close not in t:
    raise RuntimeError('quick-template mobile accordion auto-close handler not found')
t = t.replace(quick_mobile_close, '', 1)

css = r'''
/* Forms 1.3.5 dark-mode surfaces + independent accordion polish */
.df-builder{
  --df-theme-surface:var(--bs-body-bg,#fff);
  --df-theme-surface-soft:var(--bs-tertiary-bg,#f7f8fa);
  --df-theme-input:var(--bs-body-bg,#fff);
  --df-theme-text:var(--bs-body-color,#1f2937);
  --df-theme-muted:var(--bs-secondary-color,#667085);
  --df-theme-border:var(--bs-border-color,#dfe3e7);
  --df-close-bg:color-mix(in srgb,var(--df) 7%,var(--bs-body-bg,#fff));
  --df-close-border:color-mix(in srgb,var(--df) 34%,var(--df-border,#dfe3e7));
  --df-close-label:var(--bs-body-color,#1f2937);
}
[data-bs-theme="dark"] .df-builder,
html[data-bs-theme="dark"] .df-builder,
body[data-bs-theme="dark"] .df-builder{
  --df-theme-surface:#1f2937;
  --df-theme-surface-soft:#263241;
  --df-theme-input:#111922;
  --df-theme-text:#f4f7fb;
  --df-theme-muted:#b6c0ce;
  --df-theme-border:#4a596b;
  --df-close-bg:rgba(230,0,70,.14);
  --df-close-border:#a94762;
  --df-close-label:#ffb1c3;
}
@media (prefers-color-scheme:dark){
  .df-builder{
    --df-theme-surface:#1f2937;
    --df-theme-surface-soft:#263241;
    --df-theme-input:#111922;
    --df-theme-text:#f4f7fb;
    --df-theme-muted:#b6c0ce;
    --df-theme-border:#4a596b;
    --df-close-bg:rgba(230,0,70,.14);
    --df-close-border:#a94762;
    --df-close-label:#ffb1c3;
  }
}

/* Internal cards: remove white islands in dark mode. */
.df-builder .df-subbox,
.df-builder .df-email-block,
.df-builder .df-email-block-body,
.df-builder .df-additional-card,
.df-builder .df-column-item,
.df-builder .df-email-choice,
.df-builder .df-email-special,
.df-builder .df-info-bubble{
  background:var(--df-theme-surface)!important;
  color:var(--df-theme-text)!important;
  border-color:var(--df-theme-border)!important;
}
.df-builder .df-email-block>summary{
  background:var(--df-theme-surface-soft)!important;
  color:var(--df-theme-text)!important;
  border-color:var(--df-theme-border)!important;
}
.df-builder .df-subbox h4,
.df-builder .df-email-block summary,
.df-builder .df-column-item span,
.df-builder .df-email-choice-foot,
.df-builder .df-additional-card,
.df-builder .df-security-grid,
.df-builder .df-status-color-value{
  color:var(--df-theme-text)!important;
}
.df-builder .df-note{
  color:var(--df-theme-muted)!important;
}

/* Form controls inside Builder use a real dark surface instead of white. */
.df-builder .df-field input:not([type=checkbox]):not([type=radio]):not([type=color]),
.df-builder .df-field textarea,
.df-builder .df-field select,
.df-builder .df-input,
.df-builder .df-status-row input:not([type=color]),
.df-builder .df-status-remove,
.df-builder .df-tokenbar select,
.df-builder .df-codearea{
  background:var(--df-theme-input)!important;
  color:var(--df-theme-text)!important;
  border-color:var(--df-theme-border)!important;
}
.df-builder .df-field input::placeholder,
.df-builder .df-field textarea::placeholder,
.df-builder .df-codearea::placeholder{
  color:var(--df-theme-muted)!important;
  opacity:.82;
}
.df-builder .df-btn:not(.df-primary),
.df-builder .df-status-remove{
  background:var(--df-theme-input)!important;
  color:var(--df-theme-text)!important;
  border-color:var(--df-theme-border)!important;
}

/* Closed-form warning: light red in light mode, dark red translucent in dark mode. */
.df-builder .df-closed-box{
  background:var(--df-close-bg)!important;
  border-color:var(--df-close-border)!important;
}
.df-builder .df-closed-box label{
  color:var(--df-close-label)!important;
}
.df-builder .df-closed-box input,
.df-builder .df-closed-box select{
  background:var(--df-theme-input)!important;
  color:var(--df-theme-text)!important;
  border-color:var(--df-theme-border)!important;
}

/* Custom CSS/JS helper line: align it with the editor content. */
.df-builder .df-custom-code-grid .df-note{
  display:block;
  padding-left:5px;
  margin-top:2px;
}
'''

if '</style>' not in t:
    raise RuntimeError('builder style closing tag not found')
t = t.replace('</style>', css + '\n</style>', 1)

if "public const VERSION = '1.3.4'" not in h:
    raise RuntimeError('helper version 1.3.4 not found')
h = h.replace("public const VERSION = '1.3.4'", "public const VERSION = '1.3.5'", 1)

for p in (component_manifest, plugin_manifest):
    s = p.read_text()
    if '<version>1.3.4</version>' not in s:
        raise RuntimeError(f'1.3.4 version missing in {p.name}')
    p.write_text(s.replace('<version>1.3.4</version>', '<version>1.3.5</version>', 1))

builder.write_text(t)
helper.write_text(h)

final = builder.read_text()
checks = [
    'Forms 1.3.5 dark-mode surfaces + independent accordion polish',
    '--df-theme-surface:#1f2937',
    '--df-close-bg:rgba(230,0,70,.14)',
    '.df-builder .df-custom-code-grid .df-note',
    'const accordionSections=',
    'split(/\\r?\\n/)',
]
for token in checks:
    if token not in final:
        raise RuntimeError('missing expected builder token: ' + token)
if mobile_close in final or quick_mobile_close in final:
    raise RuntimeError('accordion auto-close logic still present')

print('Forms 1.3.5 patch applied')
