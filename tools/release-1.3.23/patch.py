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

def rep(text, old, new, label, count=1):
    if old not in text:
        raise RuntimeError(f'{label} not found')
    return text.replace(old,new,count)

# Versions.
h=helper.read_text(); h=rep(h,"public const VERSION = '1.3.22';","public const VERSION = '1.3.23';",'helper version'); helper.write_text(h)
for m in (component_manifest,plugin_manifest):
    s=m.read_text(); s=rep(s,'<version>1.3.22</version>','<version>1.3.23</version>',str(m)); m.write_text(s)

t=builder.read_text()

# Remove colour ownership from the original generic button declaration. One consolidated layer below now owns all button colours.
old='''.df-btn{display:inline-flex;align-items:center;justify-content:center;min-height:39px;padding:0 14px;border:1px solid var(--df-border);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit!important;text-decoration:none;font-weight:750;cursor:pointer}.df-btn:hover{border-color:var(--df)}.df-primary{background:var(--df);border-color:var(--df);color:#fff!important}.df-danger{border-color:#cf3343;color:#a51828!important}.df-small{min-height:34px;padding:0 10px;font-size:12px}'''
new='''.df-btn{display:inline-flex;align-items:center;justify-content:center;min-height:39px;padding:0 14px;border:1px solid;border-radius:6px;text-decoration:none;font-weight:750;cursor:pointer}.df-small{min-height:34px;padding:0 10px;font-size:12px}'''
t=rep(t,old,new,'base button colour cleanup')

# Stop the old theme-surface rule from recolouring every secondary button.
old='''.df-builder .df-btn:not(.df-primary),
.df-builder .df-status-remove{
  background:var(--df-theme-input)!important;
  color:var(--df-theme-text)!important;
  border-color:var(--df-theme-border)!important;
}'''
new='''.df-builder .df-status-remove{
  background:var(--df-theme-input)!important;
  color:var(--df-theme-text)!important;
  border-color:var(--df-theme-border)!important;
}'''
t=rep(t,old,new,'remove legacy broad button theme rule')

# Remove the later one-off Save structure colour override; it becomes a normal primary button.
old='''.df-save-structure{background:var(--df)!important;border-color:var(--df)!important;color:#fff!important;font-weight:800!important}
.df-save-structure:hover,.df-save-structure:focus-visible{background:var(--df-dark)!important;border-color:var(--df-dark)!important;color:#fff!important}'''
new='''.df-save-structure{font-weight:800!important}'''
t=rep(t,old,new,'remove save structure duplicate colours')

# Replace the 1.3.19 compatibility overrides with a single semantic button system.
old='''/* Forms 1.3.19: unified buttons, action modals, fast properties and 2D layout. */
.df-builder .df-btn{background:var(--bs-body-bg,#fff)!important;color:var(--bs-body-color,#1f2937)!important;border-color:var(--bs-border-color,#d9dee5)!important}
.df-builder .df-btn:hover,.df-builder .df-btn:focus-visible{background:var(--bs-tertiary-bg,#f6f7f9)!important;border-color:#b9c2ce!important;color:var(--bs-body-color,#1f2937)!important}
.df-builder .df-btn.df-primary,.df-builder .df-save-structure,.df-builder .df-add{background:var(--df)!important;border-color:var(--df)!important;color:#fff!important}
.df-builder .df-btn.df-primary:hover,.df-builder .df-btn.df-primary:focus-visible,.df-builder .df-save-structure:hover,.df-builder .df-save-structure:focus-visible,.df-builder .df-add:hover{background:var(--df-dark)!important;border-color:var(--df-dark)!important;color:#fff!important}
.df-builder .df-btn.df-danger{background:#fff1f3!important;border-color:#e69aa7!important;color:#a4132d!important}.df-builder .df-btn.df-danger:hover{background:#dc3545!important;border-color:#dc3545!important;color:#fff!important}'''
new='''/* Forms 1.3.23: single button system. Do not derive light buttons from Bootstrap/OS colour variables. */
.df-builder,.df-action-modal,.df-live-preview-modal,.df-preview-modal{
  --df-btn-bg:#fff;
  --df-btn-text:#1f2937;
  --df-btn-border:#d9dee5;
  --df-btn-hover-bg:#f6f7f9;
  --df-btn-hover-border:#cfd6df;
}
html[data-bs-theme="dark"] .df-builder,body[data-bs-theme="dark"] .df-builder,html[data-color-scheme="dark"] .df-builder,
html[data-bs-theme="dark"] .df-action-modal,body[data-bs-theme="dark"] .df-action-modal,html[data-color-scheme="dark"] .df-action-modal,
html[data-bs-theme="dark"] .df-live-preview-modal,body[data-bs-theme="dark"] .df-live-preview-modal,html[data-color-scheme="dark"] .df-live-preview-modal,
html[data-bs-theme="dark"] .df-preview-modal,body[data-bs-theme="dark"] .df-preview-modal,html[data-color-scheme="dark"] .df-preview-modal{
  --df-btn-bg:#111827;
  --df-btn-text:#f8fafc;
  --df-btn-border:#475569;
  --df-btn-hover-bg:#273548;
  --df-btn-hover-border:#64748b;
}
.df-builder .df-btn,.df-action-modal .df-btn,.df-live-preview-modal .df-btn,.df-preview-modal .df-btn{
  background:var(--df-btn-bg)!important;
  color:var(--df-btn-text)!important;
  border-color:var(--df-btn-border)!important;
  box-shadow:none!important;
}
.df-builder .df-btn:hover,.df-builder .df-btn:focus-visible,
.df-action-modal .df-btn:hover,.df-action-modal .df-btn:focus-visible,
.df-live-preview-modal .df-btn:hover,.df-live-preview-modal .df-btn:focus-visible,
.df-preview-modal .df-btn:hover,.df-preview-modal .df-btn:focus-visible{
  background:var(--df-btn-hover-bg)!important;
  color:var(--df-btn-text)!important;
  border-color:var(--df-btn-hover-border)!important;
}
.df-builder .df-btn.df-primary,.df-builder .df-btn.df-btn-primary,.df-builder .df-save-structure,.df-builder .df-add,
.df-action-modal .df-btn.df-primary,.df-action-modal .df-btn.df-btn-primary{
  background:var(--df)!important;
  border-color:var(--df)!important;
  color:#fff!important;
}
.df-builder .df-btn.df-primary:hover,.df-builder .df-btn.df-primary:focus-visible,
.df-builder .df-btn.df-btn-primary:hover,.df-builder .df-btn.df-btn-primary:focus-visible,
.df-builder .df-save-structure:hover,.df-builder .df-save-structure:focus-visible,.df-builder .df-add:hover,
.df-action-modal .df-btn.df-primary:hover,.df-action-modal .df-btn.df-primary:focus-visible,
.df-action-modal .df-btn.df-btn-primary:hover,.df-action-modal .df-btn.df-btn-primary:focus-visible{
  background:var(--df-dark)!important;
  border-color:var(--df-dark)!important;
  color:#fff!important;
}
.df-builder .df-btn.df-danger,.df-builder .df-btn.df-btn-danger{
  background:#fff1f3!important;
  border-color:#e69aa7!important;
  color:#a4132d!important;
}
.df-builder .df-btn.df-danger:hover,.df-builder .df-btn.df-btn-danger:hover,
.df-builder .df-btn.df-danger:focus-visible,.df-builder .df-btn.df-btn-danger:focus-visible{
  background:#dc3545!important;
  border-color:#dc3545!important;
  color:#fff!important;
}
html[data-bs-theme="dark"] .df-builder .df-btn.df-danger,body[data-bs-theme="dark"] .df-builder .df-btn.df-danger,html[data-color-scheme="dark"] .df-builder .df-btn.df-danger,
html[data-bs-theme="dark"] .df-builder .df-btn.df-btn-danger,body[data-bs-theme="dark"] .df-builder .df-btn.df-btn-danger,html[data-color-scheme="dark"] .df-builder .df-btn.df-btn-danger{
  background:#4a1e2b!important;
  border-color:#a94e68!important;
  color:#ffc0d0!important;
}'''
t=rep(t,old,new,'replace button system')

# Explicit semantic primary class for Save structure; legacy df-primary remains supported elsewhere.
t=rep(t,'class="df-btn df-small df-save-structure" type="button" id="df-save-structure"','class="df-btn df-small df-btn-primary df-save-structure" type="button" id="df-save-structure"','save structure primary class')

builder.write_text(t)
