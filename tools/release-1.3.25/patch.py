#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 4:
    raise SystemExit('usage: patch.py COMPONENT_ROOT SYSTEM_PLUGIN_ROOT EDITOR_PLUGIN_ROOT')

comp=Path(sys.argv[1]); system=Path(sys.argv[2]); editor=Path(sys.argv[3])
builder=comp/'administrator/components/com_decaroforms/tmpl/builder/default.php'
helper=comp/'administrator/components/com_decaroforms/src/Helper/FormHelper.php'
installer=comp/'script.php'


def rep(text, old, new, label, count=1):
    if old not in text:
        raise RuntimeError(f'{label} not found')
    return text.replace(old,new,count)

# Version all installed extension manifests/helper.
h=helper.read_text(encoding='utf-8')
h=rep(h,"public const VERSION = '1.3.24';","public const VERSION = '1.3.25';",'helper version')
helper.write_text(h,encoding='utf-8')
for root in (comp,system,editor):
    for p in root.rglob('*.xml'):
        s=p.read_text(encoding='utf-8')
        if '<version>1.3.24</version>' in s:
            p.write_text(s.replace('<version>1.3.24</version>','<version>1.3.25</version>'),encoding='utf-8')

b=builder.read_text(encoding='utf-8')

# Make the custom-code section explicit, full width, and easy to diagnose.
b=rep(b,'<textarea class="df-codearea" name="custom_css"','<textarea class="df-codearea" id="df-custom-css" name="custom_css"','custom css id')
b=rep(b,'<textarea class="df-codearea" name="custom_js"','<textarea class="df-codearea" id="df-custom-js" name="custom_js"','custom js id')
css='''\n/* Forms 1.3.25: stable full-width custom-code editor and runtime diagnostics. */\n.df-custom-code-grid{display:grid!important;grid-template-columns:minmax(0,1fr)!important;gap:14px!important;width:100%!important;max-width:none!important}\n.df-custom-code-grid>.df-field{width:100%!important;max-width:none!important;min-width:0!important}\n.df-custom-code-grid .df-codearea{display:block;width:100%!important;max-width:none!important}\n'''
b=rep(b,'</style>',css+'</style>','custom code css')

# Clean duplicate class attributes introduced by previous icon conversion.
b=b.replace('class="df-saved-quick-delete" data-saved-quick-delete="${esc(tpl.id)}" title="Elimina modello salvato" aria-label="Elimina modello salvato" class="df-icon-only"','class="df-saved-quick-delete df-icon-only" data-saved-quick-delete="${esc(tpl.id)}" title="Elimina modello salvato" aria-label="Elimina modello salvato"')
b=b.replace('class="df-lib-delete" type="button" title="${esc(tr.remove)}" aria-label="${esc(tr.remove)}" class="df-icon-only"','class="df-lib-delete df-icon-only" type="button" title="${esc(tr.remove)}" aria-label="${esc(tr.remove)}"')

# Render the already-loaded field workspace immediately, before later optional initializers can fail.
anchor="""  });sync();
}
layoutNewRow?.addEventListener('dragover',e=>{e.preventDefault();layoutNewRow.classList.add('is-over');});"""
replacement="""  });sync();
}
function ensureInitialFieldWorkspace(){
  if(!selected.length)return;
  renderSelected();
  renderLayoutCanvas();
  const verify=()=>{
    if(selected.length&&layoutCanvas&&!layoutCanvas.querySelector('.df-layout-card')){
      renderSelected();
      renderLayoutCanvas();
    }
  };
  requestAnimationFrame(()=>{verify();setTimeout(verify,60);});
}
window.dfBuilderEnsureRender=ensureInitialFieldWorkspace;
ensureInitialFieldWorkspace();
layoutNewRow?.addEventListener('dragover',e=>{e.preventDefault();layoutNewRow.classList.add('is-over');});"""
b=rep(b,anchor,replacement,'early field workspace render')

# Optional integration controls must never abort the whole Builder when a stale/hybrid cached template omits section 9.
old="""const sheetsEnabled=document.getElementById('df-sheets-enabled'),sheetsWebhook=document.getElementById('df-sheets-webhook'),sheetsSecret=document.getElementById('df-sheets-secret'),sheetsFiles=document.getElementById('df-sheets-files');sheetsEnabled.checked=!!integrations.google_sheets.enabled;sheetsWebhook.value=integrations.google_sheets.webhook_url||'';sheetsSecret.value=integrations.google_sheets.secret||'';sheetsFiles.checked=!!integrations.google_sheets.include_files;sheetsEnabled.onchange=e=>{integrations.google_sheets.enabled=e.target.checked;sync();};sheetsWebhook.oninput=e=>{integrations.google_sheets.webhook_url=e.target.value;sync();};sheetsSecret.oninput=e=>{integrations.google_sheets.secret=e.target.value;sync();};sheetsFiles.onchange=e=>{integrations.google_sheets.include_files=e.target.checked;sync();};
document.getElementById('df-add-calculation').onclick=()=>add({key:'calculation',type:'calculated',category:'values',label:'<?php echo addslashes(Text::_('COM_DECAROFORMS_FIELD_CALCULATION')); ?>',placeholder:'',help:'',default:'',options:[],required:false,config:{formula:'',decimals:2,prefix:'',suffix:'',visible:true}});"""
new="""const sheetsEnabled=document.getElementById('df-sheets-enabled'),sheetsWebhook=document.getElementById('df-sheets-webhook'),sheetsSecret=document.getElementById('df-sheets-secret'),sheetsFiles=document.getElementById('df-sheets-files');
if(sheetsEnabled&&sheetsWebhook&&sheetsSecret&&sheetsFiles){
  sheetsEnabled.checked=!!integrations.google_sheets.enabled;sheetsWebhook.value=integrations.google_sheets.webhook_url||'';sheetsSecret.value=integrations.google_sheets.secret||'';sheetsFiles.checked=!!integrations.google_sheets.include_files;
  sheetsEnabled.onchange=e=>{integrations.google_sheets.enabled=e.target.checked;sync();};sheetsWebhook.oninput=e=>{integrations.google_sheets.webhook_url=e.target.value;sync();};sheetsSecret.oninput=e=>{integrations.google_sheets.secret=e.target.value;sync();};sheetsFiles.onchange=e=>{integrations.google_sheets.include_files=e.target.checked;sync();};
}
document.getElementById('df-add-calculation')?.addEventListener('click',()=>add({key:'calculation',type:'calculated',category:'values',label:'<?php echo addslashes(Text::_('COM_DECAROFORMS_FIELD_CALCULATION')); ?>',placeholder:'',help:'',default:'',options:[],required:false,config:{formula:'',decimals:2,prefix:'',suffix:'',visible:true}}));"""
b=rep(b,old,new,'optional integration guards')

# Export an explicit runtime marker and keep draft APIs visible to the robust save handler.
anchor="""window.dfSetSaveNotice=setSaveNotice;
window.dfBuilderSaveDraft=saveDraftNow;
window.dfBuilderClearDraft=clearDraft;
window.dfBuilderSync=sync;
"""
new="""window.dfSetSaveNotice=setSaveNotice;
window.dfBuilderSaveDraft=saveDraftNow;
window.dfBuilderClearDraft=clearDraft;
window.dfBuilderSync=sync;
window.dfBuilderRuntime={version:'1.3.25',draft:true,ensureRender:typeof window.dfBuilderEnsureRender==='function'};
"""
b=rep(b,anchor,new,'runtime marker')

# Use the protected early renderer again in the normal final initialization.
b=rep(b,'renderSelected();renderLayout();renderTokens();renderUserEmailFields();renderAdditional();renderEmailPickers(false);sync();','ensureInitialFieldWorkspace();renderLayout();renderTokens();renderUserEmailFields();renderAdditional();renderEmailPickers(false);sync();','final initial render')

builder.write_text(b,encoding='utf-8')

# Invalidate stale PHP opcode entries after package update so the administrator does not mix old/new Builder files.
s=installer.read_text(encoding='utf-8')
needle='''        return true;\n    }\n};\n'''
insert='''        foreach ([\n            JPATH_ADMINISTRATOR . '/components/com_decaroforms/tmpl/builder/default.php',\n            JPATH_ADMINISTRATOR . '/components/com_decaroforms/src/Controller/BuilderController.php',\n            JPATH_ADMINISTRATOR . '/components/com_decaroforms/src/Helper/FormHelper.php',\n        ] as $phpFile) {\n            if (is_file($phpFile)) {\n                clearstatcache(true, $phpFile);\n                if (function_exists('opcache_invalidate')) { @opcache_invalidate($phpFile, true); }\n            }\n        }\n\n        return true;\n    }\n};\n'''
idx=s.rfind(needle)
if idx < 0:
    raise RuntimeError('installer final postflight return not found')
s=s[:idx]+insert+s[idx+len(needle):]
installer.write_text(s,encoding='utf-8')
