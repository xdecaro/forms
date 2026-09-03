#!/usr/bin/env python3
from pathlib import Path
import re
import sys

if len(sys.argv) != 4:
    raise SystemExit('usage: apply_patch.py COMPONENT_DIR PLUGIN_DIR OUTER_DIR')

component = Path(sys.argv[1])
plugin = Path(sys.argv[2])
outer = Path(sys.argv[3])
VERSION = '1.2.6'


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding='utf-8')
    if old not in text:
        raise RuntimeError(f'missing patch target: {label} in {path}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


# Invii recenti: live search while typing + immediate select filters.
recent = component / 'administrator/components/com_decaroforms/tmpl/recent/default.php'
old_recent = "document.getElementById('df-r-filter').addEventListener('click',apply);document.getElementById('df-r-clear').addEventListener('click',()=>{search.value='';form.value='all';status.value='all';limit.value='50';apply();});search.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();apply();}});limit.addEventListener('change',apply);statButtons.forEach(button=>button.addEventListener('click',()=>{status.value=button.dataset.recentStatusFilter||'all';apply();}));"
new_recent = "let liveTimer=null;function scheduleApply(){clearTimeout(liveTimer);liveTimer=setTimeout(apply,180);}document.getElementById('df-r-filter').addEventListener('click',()=>{clearTimeout(liveTimer);apply();});document.getElementById('df-r-clear').addEventListener('click',()=>{clearTimeout(liveTimer);search.value='';form.value='all';status.value='all';limit.value='50';apply();});search.addEventListener('input',scheduleApply);search.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();clearTimeout(liveTimer);apply();}});form.addEventListener('change',apply);status.addEventListener('change',apply);limit.addEventListener('change',apply);statButtons.forEach(button=>button.addEventListener('click',()=>{status.value=button.dataset.recentStatusFilter||'all';apply();}));"
replace_once(recent, old_recent, new_recent, 'recent live filters')

# Invii del singolo modulo: same live behaviour.
submissions = component / 'administrator/components/com_decaroforms/tmpl/submissions/default.php'
old_sub = "document.getElementById('df-filter-btn').addEventListener('click',apply);\ndocument.getElementById('df-clear-btn').addEventListener('click',()=>{search.value='';filter.value='all';limit.value='50';apply();});\nstatButtons.forEach(button=>button.addEventListener('click',()=>{filter.value=button.dataset.statusFilter||'all';apply();}));\nsearch.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();apply();}});limit.addEventListener('change',apply);"
new_sub = "let liveTimer=null;function scheduleApply(){clearTimeout(liveTimer);liveTimer=setTimeout(apply,180);}\ndocument.getElementById('df-filter-btn').addEventListener('click',()=>{clearTimeout(liveTimer);apply();});\ndocument.getElementById('df-clear-btn').addEventListener('click',()=>{clearTimeout(liveTimer);search.value='';filter.value='all';limit.value='50';apply();});\nstatButtons.forEach(button=>button.addEventListener('click',()=>{filter.value=button.dataset.statusFilter||'all';apply();}));\nsearch.addEventListener('input',scheduleApply);search.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();clearTimeout(liveTimer);apply();}});filter.addEventListener('change',apply);limit.addEventListener('change',apply);"
replace_once(submissions, old_sub, new_sub, 'form submissions live filters')

# Elenco moduli already live; standardise typing with same lightweight debounce.
forms = component / 'administrator/components/com_decaroforms/tmpl/forms/default.php'
old_forms = "(()=>{const q=document.getElementById('df-search'),f=document.getElementById('df-filter'),cards=[...document.querySelectorAll('.df-card')];function apply(){const s=(q.value||'').toLowerCase().trim(),st=f.value;cards.forEach(c=>{const okText=!s||c.dataset.title.includes(s),okSt=st==='all'||c.dataset.status===st;c.style.display=okText&&okSt?'':'none';});}q?.addEventListener('input',apply);f?.addEventListener('change',apply);})();"
new_forms = "(()=>{const q=document.getElementById('df-search'),f=document.getElementById('df-filter'),cards=[...document.querySelectorAll('.df-card')];let liveTimer=null;function apply(){const s=(q.value||'').toLowerCase().trim(),st=f.value;cards.forEach(c=>{const okText=!s||c.dataset.title.includes(s),okSt=st==='all'||c.dataset.status===st;c.style.display=okText&&okSt?'':'none';});}function scheduleApply(){clearTimeout(liveTimer);liveTimer=setTimeout(apply,180);}q?.addEventListener('input',scheduleApply);f?.addEventListener('change',apply);})();"
replace_once(forms, old_forms, new_forms, 'forms list live debounce')

# Component footer version.
helper = component / 'administrator/components/com_decaroforms/src/Helper/FormHelper.php'
text = helper.read_text(encoding='utf-8')
text, count = re.subn(r"public const VERSION = '[^']+';", f"public const VERSION = '{VERSION}';", text, count=1)
if count != 1:
    raise RuntimeError('FormHelper version constant not found')
helper.write_text(text, encoding='utf-8')

# Component/plugin/package manifests.
for path in [component / 'com_decaroforms.xml', plugin / 'decaroforms.xml', outer / 'pkg_decaroforms.xml']:
    text = path.read_text(encoding='utf-8')
    text, count = re.subn(r'<version>[^<]+</version>', f'<version>{VERSION}</version>', text, count=1)
    if count != 1:
        raise RuntimeError(f'version tag not found in {path}')
    path.write_text(text, encoding='utf-8')

pkg = outer / 'pkg_decaroforms.xml'
text = pkg.read_text(encoding='utf-8')
text = text.replace('com_decaroforms_1.2.5.zip', 'com_decaroforms_1.2.6.zip')
text = text.replace('plg_system_decaroforms_1.2.5.zip', 'plg_system_decaroforms_1.2.6.zip')
pkg.write_text(text, encoding='utf-8')

print('Forms 1.2.6 live filtering patch applied')
