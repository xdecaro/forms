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

def replace_once(text, old, new, label):
    if old not in text:
        raise RuntimeError(f'{label} not found')
    return text.replace(old, new, 1)

# Versions.
h = helper.read_text()
h = replace_once(h, "public const VERSION = '1.3.15';", "public const VERSION = '1.3.16';", 'helper version')
helper.write_text(h)
for manifest in (component_manifest, plugin_manifest):
    value = manifest.read_text()
    value = replace_once(value, '<version>1.3.15</version>', '<version>1.3.16</version>', str(manifest))
    manifest.write_text(value)

t = builder.read_text()

# Neutral back button, visually matching the Menu control rather than a dark primary action.
old_head = '''<div class="df-bactions"><a class="df-btn" href="<?php echo $this->formsUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_BACK_FORMS'); ?></a><?php if ($id): ?><a class="df-btn df-danger" href="<?php echo $this->deleteUrl; ?>" onclick="return confirm(<?php echo htmlspecialchars(json_encode(Text::_('COM_DECAROFORMS_DELETE_CONFIRM')), ENT_QUOTES, 'UTF-8'); ?>)"><?php echo Text::_('COM_DECAROFORMS_DELETE'); ?></a><?php endif; ?></div>'''
new_head = '''<div class="df-bactions"><a class="df-btn df-back-btn" href="<?php echo $this->formsUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_BACK_FORMS'); ?></a><?php if ($id): ?><a class="df-btn df-danger" href="<?php echo $this->deleteUrl; ?>" onclick="return confirm(<?php echo htmlspecialchars(json_encode(Text::_('COM_DECAROFORMS_DELETE_CONFIRM')), ENT_QUOTES, 'UTF-8'); ?>)"><?php echo Text::_('COM_DECAROFORMS_DELETE'); ?></a><?php endif; ?></div>'''
t = replace_once(t, old_head, new_head, 'back button')

# Restore a clearly visible save action in the top editing toolbar.
old_modes = '''<div class="df-edit-mode" aria-label="Modalità modifica"><button type="button" class="df-lock-toggle" data-lock="1">🔒 Bloccato</button><button type="button" class="df-lock-toggle" data-lock="0">✏️ Modifica</button></div>'''
new_modes = '''<div class="df-edit-mode" aria-label="Modalità modifica"><button type="button" class="df-lock-toggle" data-lock="1">🔒 Bloccato</button><button type="button" class="df-lock-toggle" data-lock="0">✏️ Modifica</button><button class="df-save-top" type="submit" form="df-builder-form"><?php echo Text::_('COM_DECAROFORMS_SAVE_FORM'); ?></button></div>'''
t = replace_once(t, old_modes, new_modes, 'top save button')

# The save action must respect the edit lock even though it sits above/outside the form element.
old_lock = '''document.querySelectorAll('.df-lock-toggle').forEach(b=>b.classList.toggle('is-active',(b.dataset.lock==='1')===editorLocked));builderForm.querySelectorAll('input:not([type="hidden"]),select,textarea,button:not(.df-section-toggle):not(.df-info)').forEach(el=>{'''
new_lock = '''document.querySelectorAll('.df-lock-toggle').forEach(b=>b.classList.toggle('is-active',(b.dataset.lock==='1')===editorLocked));document.querySelectorAll('.df-save-top').forEach(b=>b.disabled=editorLocked);builderForm.querySelectorAll('input:not([type="hidden"]),select,textarea,button:not(.df-section-toggle):not(.df-info)').forEach(el=>{'''
t = replace_once(t, old_lock, new_lock, 'lock save state')

css = r'''
/* Forms 1.3.16: toolbar contrast, neutral navigation and readable closed-state labels. */
.df-editor-toolbar{
  display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;
  margin:0 0 12px;padding:8px 10px;border:1px solid var(--df-border);border-radius:8px;
  background:var(--bs-body-bg,#fff);
}
.df-editor-toolbar .df-history-actions,.df-editor-toolbar .df-edit-mode{display:flex;align-items:center;flex-wrap:wrap}
.df-editor-toolbar button{transition:background .16s ease,border-color .16s ease,color .16s ease,opacity .16s ease}
.df-editor-toolbar .df-save-top{
  min-height:34px;margin-left:8px;padding:6px 13px;border:1px solid var(--df)!important;border-radius:6px!important;
  background:var(--df)!important;color:#fff!important;font-weight:800;cursor:pointer;
}
.df-editor-toolbar .df-save-top:hover,.df-editor-toolbar .df-save-top:focus-visible{background:var(--df-dark)!important;border-color:var(--df-dark)!important;color:#fff!important}
.df-editor-toolbar .df-save-top:disabled{opacity:.46!important;cursor:not-allowed!important}

/* Light mode: toolbar and navigation stay neutral, like Joomla's Menu button. */
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-editor-toolbar,
html[data-bs-theme="light"] .df-builder .df-editor-toolbar{
  background:#fff!important;border-color:#d9dee5!important;color:#1f2937!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-editor-toolbar button:not(.df-save-top),
html[data-bs-theme="light"] .df-builder .df-editor-toolbar button:not(.df-save-top){
  background:#fff!important;color:#1f2937!important;border-color:#d9dee5!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-editor-toolbar button:not(.df-save-top):hover,
html[data-bs-theme="light"] .df-builder .df-editor-toolbar button:not(.df-save-top):hover{
  background:#f6f7f9!important;color:#1f2937!important;border-color:#cfd6df!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-lock-toggle.is-active,
html[data-bs-theme="light"] .df-builder .df-lock-toggle.is-active{
  background:#eef1f4!important;color:#1f2937!important;border-color:#c7d0da!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-back-btn,
html[data-bs-theme="light"] .df-builder .df-back-btn{
  background:#fff!important;color:#1f2937!important;border-color:#d9dee5!important;box-shadow:none!important;
}
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-back-btn:hover,
html[data-bs-theme="light"] .df-builder .df-back-btn:hover{
  background:#f6f7f9!important;color:#1f2937!important;border-color:#cfd6df!important;
}

/* The two closed-form labels must remain readable on the pale pink semantic panel. */
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-closed-box label,
html[data-bs-theme="light"] .df-builder .df-closed-box label{
  color:#7a1631!important;opacity:1!important;font-weight:750!important;
}

/* Dark mode: no white action strip and no washed-out controls. */
html[data-bs-theme="dark"] .df-builder .df-editor-toolbar,
body[data-bs-theme="dark"] .df-builder .df-editor-toolbar,
html[data-color-scheme="dark"] .df-builder .df-editor-toolbar{
  background:#1f2937!important;border-color:#475569!important;color:#f8fafc!important;
}
html[data-bs-theme="dark"] .df-builder .df-editor-toolbar button:not(.df-save-top),
body[data-bs-theme="dark"] .df-builder .df-editor-toolbar button:not(.df-save-top),
html[data-color-scheme="dark"] .df-builder .df-editor-toolbar button:not(.df-save-top){
  background:#111827!important;color:#f8fafc!important;border-color:#475569!important;
}
html[data-bs-theme="dark"] .df-builder .df-editor-toolbar button:not(.df-save-top):hover,
body[data-bs-theme="dark"] .df-builder .df-editor-toolbar button:not(.df-save-top):hover,
html[data-color-scheme="dark"] .df-builder .df-editor-toolbar button:not(.df-save-top):hover{
  background:#273548!important;color:#fff!important;border-color:#64748b!important;
}
html[data-bs-theme="dark"] .df-builder .df-lock-toggle.is-active,
body[data-bs-theme="dark"] .df-builder .df-lock-toggle.is-active,
html[data-color-scheme="dark"] .df-builder .df-lock-toggle.is-active{
  background:#334155!important;color:#fff!important;border-color:#64748b!important;
}
html[data-bs-theme="dark"] .df-builder .df-back-btn,
body[data-bs-theme="dark"] .df-builder .df-back-btn,
html[data-color-scheme="dark"] .df-builder .df-back-btn{
  background:#1f2937!important;color:#f8fafc!important;border-color:#475569!important;box-shadow:none!important;
}
html[data-bs-theme="dark"] .df-builder .df-back-btn:hover,
body[data-bs-theme="dark"] .df-builder .df-back-btn:hover,
html[data-color-scheme="dark"] .df-builder .df-back-btn:hover{
  background:#273548!important;color:#fff!important;border-color:#64748b!important;
}
@media(max-width:800px){
  .df-editor-toolbar{align-items:stretch}
  .df-editor-toolbar .df-edit-mode{margin-left:auto}
  .df-editor-toolbar .df-save-top{margin-left:6px}
}
'''
if '</style>' not in t:
    raise RuntimeError('builder style closing tag not found')
t = t.replace('</style>', css + '\n</style>', 1)

builder.write_text(t)

final = builder.read_text()
for token in ['df-save-top','df-back-btn','color:#7a1631!important','Forms 1.3.16']:
    if token not in final:
        raise RuntimeError('missing expected token: ' + token)
print('Forms 1.3.16 patch applied')
