#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 4:
    raise SystemExit('usage: patch.py COMPONENT_ROOT SYSTEM_PLUGIN_ROOT EDITOR_PLUGIN_ROOT')

comp=Path(sys.argv[1]); system=Path(sys.argv[2]); editor=Path(sys.argv[3])
builder=comp/'administrator/components/com_decaroforms/tmpl/builder/default.php'
helper=comp/'administrator/components/com_decaroforms/src/Helper/FormHelper.php'


def rep(text, old, new, label, count=1):
    if old not in text:
        raise RuntimeError(f'{label} not found')
    return text.replace(old,new,count)

# Version installed extensions.
h=helper.read_text(encoding='utf-8')
h=rep(h,"public const VERSION = '1.3.25';","public const VERSION = '1.3.26';",'helper version')
helper.write_text(h,encoding='utf-8')
for root in (comp,system,editor):
    for p in root.rglob('*.xml'):
        s=p.read_text(encoding='utf-8')
        if '<version>1.3.25</version>' in s:
            p.write_text(s.replace('<version>1.3.25</version>','<version>1.3.26</version>'),encoding='utf-8')

b=builder.read_text(encoding='utf-8')

# Chrome reports one blocked-script warning for every sandboxed email preview frame.
# Keep the frame isolated (no allow-same-origin, forms, popups or navigation), but permit
# scripts in the opaque sandbox so browser-injected scripts do not generate console noise.
b=rep(
    b,
    '<iframe class="df-email-thumb-frame" title="" tabindex="-1" sandbox></iframe>',
    '<iframe class="df-email-thumb-frame" title="" tabindex="-1" sandbox="allow-scripts"></iframe>',
    'email preview sandbox'
)

# Sanitize preview HTML before it reaches srcdoc. This prevents user HTML templates from
# gaining executable script/event-handler capability even though the isolated iframe now
# permits scripts for browser/runtime compatibility.
anchor='function renderEmailPickers(loadFrames=emailPickersRendered){'
sanitizer="""function sanitizeEmailPreviewHtml(html){
  const doc=new DOMParser().parseFromString(String(html||''),'text/html');
  doc.querySelectorAll('script,object,embed').forEach(el=>el.remove());
  doc.querySelectorAll('*').forEach(el=>{
    [...el.attributes].forEach(attr=>{
      const name=String(attr.name||'').toLowerCase(),value=String(attr.value||'').trim();
      if(name.startsWith('on')){el.removeAttribute(attr.name);return;}
      if(['href','src','xlink:href','formaction'].includes(name)&&/^javascript:/i.test(value))el.removeAttribute(attr.name);
    });
  });
  return '<!doctype html><html>'+doc.documentElement.innerHTML+'</html>';
}
function renderEmailPickers(loadFrames=emailPickersRendered){"""
b=rep(b,anchor,sanitizer,'email preview sanitizer')
b=rep(
    b,
    'frame.srcdoc=emailPreviewHtml(audience,key);',
    'frame.srcdoc=sanitizeEmailPreviewHtml(emailPreviewHtml(audience,key));',
    'sanitized email thumbnail srcdoc'
)

# Runtime marker for diagnostics.
b=rep(
    b,
    "window.dfBuilderRuntime={version:'1.3.25',draft:true,ensureRender:typeof window.dfBuilderEnsureRender==='function'};",
    "window.dfBuilderRuntime={version:'1.3.26',draft:true,ensureRender:typeof window.dfBuilderEnsureRender==='function',emailPreviewSandbox:true};",
    'runtime marker'
)

builder.write_text(b,encoding='utf-8')
