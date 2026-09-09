#!/usr/bin/env bash
set -Eeuo pipefail
trap 'status=$?; echo "Build failed at line ${LINENO}: ${BASH_COMMAND}" >&2; exit "$status"' ERR

BASE_VERSION="1.6.0"
NEW_VERSION="1.7.0"
RELEASE_DATE="2026-09-09"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_ZIP="$ROOT/releases/$BASE_VERSION/pkg_decaroforms_$BASE_VERSION.zip"
OUT="$ROOT/releases/$NEW_VERSION"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

[[ -f "$BASE_ZIP" ]] || { echo "Base package not found: $BASE_ZIP" >&2; exit 1; }
rm -rf "$OUT"
mkdir -p "$OUT" "$WORK/outer" "$WORK/component" "$WORK/system" "$WORK/editor"

unzip -q "$BASE_ZIP" -d "$WORK/outer"
unzip -q "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" -d "$WORK/component"
unzip -q "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" -d "$WORK/system"
unzip -q "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip" -d "$WORK/editor"

BUILDER="$WORK/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
CONTROLLER="$WORK/component/administrator/components/com_decaroforms/src/Controller/BuilderController.php"
MANIFEST="$WORK/component/com_decaroforms.xml"
for file in "$BUILDER" "$CONTROLLER" "$MANIFEST"; do
  [[ -f "$file" ]] || { echo "Required Forms source missing: $file" >&2; exit 1; }
done

python3 - "$BUILDER" <<'PY'
from pathlib import Path
import re, sys

path = Path(sys.argv[1])
s = path.read_text(encoding='utf-8')

# Joomla's modern editor registry is the only integration surface. Forms never
# imports Editor product classes or boots com_decaroeditor directly.
imports = "use Joomla\\CMS\\Editor\\EditorsRegistry;\nuse Joomla\\CMS\\Factory;\n"
marker = "use Joomla\\CMS\\HTML\\HTMLHelper;\n"
if imports not in s:
    if s.count(marker) != 1:
        raise SystemExit('Builder import marker not found exactly once')
    s = s.replace(marker, marker + imports, 1)

# Render two stable editor instances only when the public Joomla provider is
# enabled. They are moved between stable DOM hosts by JavaScript, never rebuilt.
provider_php = r'''
$emailEditorMarkup = ['admin' => '', 'user' => ''];
try {
    /** @var EditorsRegistry $editorsRegistry */
    $editorsRegistry = Factory::getContainer()->get(EditorsRegistry::class);
    if ($editorsRegistry->has('decaroeditor')) {
        $emailEditorProvider = $editorsRegistry->get('decaroeditor');
        foreach (['admin', 'user'] as $audience) {
            $emailEditorMarkup[$audience] = $emailEditorProvider->display(
                'df_editor_' . $audience . '_html',
                (string) ($emailConfig[$audience]['html'] ?? ''),
                [
                    'id' => 'df-editor-' . $audience . '-html',
                    'width' => '100%',
                    'height' => '420px',
                    'col' => 60,
                    'row' => 20,
                ],
                ['buttons' => true]
            );
        }
    }
} catch (\Throwable $exception) {
    // Editor is optional. Any unavailable/incompatible provider keeps the
    // existing Forms textarea path without affecting Builder availability.
    $emailEditorMarkup = ['admin' => '', 'user' => ''];
}
'''.strip()

if '$emailEditorMarkup =' not in s:
    m = re.search(r"(\$emailConfig\['user'\]\s*\+=\s*\[.*?\n\];)(\n\?>)", s, re.S)
    if not m:
        raise SystemExit('User email config block not found')
    s = s[:m.end(1)] + "\n\n" + provider_php + s[m.end(1):]

pool_markup = r'''
        <?php if ($emailEditorMarkup['admin'] !== '' || $emailEditorMarkup['user'] !== ''): ?>
        <div data-email-editor-pool hidden>
          <?php foreach (['admin', 'user'] as $emailEditorAudience): ?>
            <?php if ($emailEditorMarkup[$emailEditorAudience] !== ''): ?>
              <div data-email-editor-host="<?php echo $emailEditorAudience; ?>" hidden><?php echo $emailEditorMarkup[$emailEditorAudience]; ?></div>
            <?php endif; ?>
          <?php endforeach; ?>
        </div>
        <?php endif; ?>
'''.strip('\n')

if 'data-email-editor-pool' not in s:
    lines = s.splitlines()
    out = []
    inserted = False
    for line in lines:
        out.append(line)
        if 'id="df-token-insert"' in line:
            out.extend(pool_markup.splitlines())
            inserted = True
    if not inserted:
        raise SystemExit('Email token toolbar marker not found')
    s = '\n'.join(out) + ('\n' if s.endswith('\n') else '')

# Keep technical editor textareas out of Forms' positional Undo/Redo and draft
# snapshots. Moving an editor host must never change normal form control indexes.
old = "function simpleFormState(){return [...document.querySelectorAll('#df-builder-form [name]:not([type=\"hidden\"])')].map(el=>({name:el.name,type:el.type,value:el.type==='checkbox'||el.type==='radio'?!!el.checked:el.value}));}"
new = "function simpleFormControls(){return [...document.querySelectorAll('#df-builder-form [name]:not([type=\"hidden\"])')].filter(el=>!el.closest('[data-email-editor-host]'));}function simpleFormState(){return simpleFormControls().map(el=>({name:el.name,type:el.type,value:el.type==='checkbox'||el.type==='radio'?!!el.checked:el.value}));}"
if old in s:
    s = s.replace(old, new, 1)
elif 'function simpleFormControls()' not in s:
    raise SystemExit('simpleFormState marker not found')

controls_expr = "const controls=[...document.querySelectorAll('#df-builder-form [name]:not([type=\"hidden\"])')];"
if controls_expr in s:
    s = s.replace(controls_expr, "const controls=simpleFormControls();")
if controls_expr in s:
    raise SystemExit('Unconverted positional form control snapshot remains')

# Before Forms creates FormData, force the Joomla editor instance to copy the
# visual canvas into its canonical hidden textarea, then serialize emailConfig.
submit_marker = "        if(typeof window.dfBuilderSync==='function')window.dfBuilderSync();"
submit_replacement = "        if(typeof window.dfFormsFlushEmailEditors==='function')window.dfFormsFlushEmailEditors();\n" + submit_marker
if 'window.dfFormsFlushEmailEditors();' not in s:
    if s.count(submit_marker) != 1:
        raise SystemExit('Robust submit sync marker not found exactly once')
    s = s.replace(submit_marker, submit_replacement, 1)

# Token insertion remains compatible with textareas, but when the xdecaro
# editor owns focus it uses Joomla.editors.instances.replaceSelection().
old = "let lastTokenTarget=null;document.querySelectorAll('[data-email]').forEach(el=>{const path=el.dataset.email;el.addEventListener('focus',()=>lastTokenTarget=el);const ev=el.tagName==='SELECT'?'change':'input';el.addEventListener(ev,()=>{setDeep(emailConfig,path,el.value);sync();});});"
new = "let lastTokenTarget=null,lastTokenEditorId=null;document.querySelectorAll('[data-email]').forEach(el=>{const path=el.dataset.email;el.addEventListener('focus',()=>{lastTokenTarget=el;lastTokenEditorId=null;});const ev=el.tagName==='SELECT'?'change':'input';el.addEventListener(ev,()=>{setDeep(emailConfig,path,el.value);sync();});});"
if old in s:
    s = s.replace(old, new, 1)
elif 'lastTokenEditorId=null' not in s:
    raise SystemExit('Email token target marker not found')

old_token = "document.getElementById('df-token-insert').onclick=()=>{if(!lastTokenTarget)return;const token=document.getElementById('df-token-picker').value;const s=lastTokenTarget.selectionStart??lastTokenTarget.value.length,e=lastTokenTarget.selectionEnd??s;lastTokenTarget.value=lastTokenTarget.value.slice(0,s)+token+lastTokenTarget.value.slice(e);lastTokenTarget.dispatchEvent(new Event('input',{bubbles:true}));lastTokenTarget.focus();};"
new_token = "document.getElementById('df-token-insert').onclick=()=>{const token=document.getElementById('df-token-picker').value;if(lastTokenEditorId){const instance=window.Joomla?.editors?.instances?.[lastTokenEditorId];if(instance&&typeof instance.replaceSelection==='function'){instance.replaceSelection(token);document.getElementById(lastTokenEditorId)?.dispatchEvent(new Event('change',{bubbles:true}));return;}}if(!lastTokenTarget)return;const start=lastTokenTarget.selectionStart??lastTokenTarget.value.length,end=lastTokenTarget.selectionEnd??start;lastTokenTarget.value=lastTokenTarget.value.slice(0,start)+token+lastTokenTarget.value.slice(end);lastTokenTarget.dispatchEvent(new Event('input',{bubbles:true}));lastTokenTarget.focus();};"
if old_token in s:
    s = s.replace(old_token, new_token, 1)
elif 'instance.replaceSelection(token)' not in s:
    raise SystemExit('Token insertion marker not found')

helpers = r'''
function emailEditorPool(){return document.querySelector('[data-email-editor-pool]');}
function detachEmailEditorHost(audience){const pool=emailEditorPool(),host=document.querySelector(`[data-email-editor-host="${audience}"]`);if(!host)return null;const source=host.querySelector('textarea[id]');if(lastTokenEditorId&&source?.id===lastTokenEditorId){lastTokenEditorId=null;lastTokenTarget=null;}if(pool&&host.parentElement!==pool)pool.appendChild(host);host.hidden=true;return host;}
function bindEmailEditorHost(audience,host){if(!host)return null;window.Joomla?.XdecaroEditor?.scan?.(host);const source=host.querySelector('textarea[id]');if(!source)return null;if(source.dataset.dfFormsEmailEditorBound!=='1'){source.dataset.dfFormsEmailEditorBound='1';source.addEventListener('change',()=>{if(emailConfig[audience])emailConfig[audience].html=source.value;sync();});host.addEventListener('focusin',()=>{lastTokenTarget=source;lastTokenEditorId=source.id;});}return source;}
function showEmailEditorHost(audience,box,cfg){const host=detachEmailEditorHost(audience);if(!host)return false;box.innerHTML=`<label class="df-label">HTML libero</label><div class="df-note"><?php echo addslashes(Text::_('COM_DECAROFORMS_HTML_VARIABLE_NOTE')); ?></div>`;box.appendChild(host);host.hidden=false;const source=bindEmailEditorHost(audience,host);if(!source){detachEmailEditorHost(audience);return false;}const value=String(cfg.html||'');const instance=window.Joomla?.editors?.instances?.[source.id];if(instance&&typeof instance.setValue==='function')instance.setValue(value);else source.value=value;return true;}
window.dfFormsFlushEmailEditors=()=>{document.querySelectorAll('[data-email-editor-host] textarea[id]').forEach(source=>{const instance=window.Joomla?.editors?.instances?.[source.id];if(instance&&typeof instance.onSave==='function')instance.onSave();const host=source.closest('[data-email-editor-host]'),audience=host?.dataset.emailEditorHost;if(audience&&emailConfig[audience])emailConfig[audience].html=source.value;});if(typeof window.dfBuilderSync==='function')window.dfBuilderSync();};
'''.strip()

render_marker = 'function renderEmailSpecial(audience){'
if 'function emailEditorPool()' not in s:
    if s.count(render_marker) != 1:
        raise SystemExit('renderEmailSpecial marker not found exactly once')
    s = s.replace(render_marker, helpers + "\n" + render_marker, 1)

old_render_start = "function renderEmailSpecial(audience){const box=document.querySelector(`[data-email-special=\"${audience}\"]`),cfg=emailConfig[audience],t=cfg.template||'standard';box.hidden=!['custom','html','chatgpt'].includes(t);"
new_render_start = "function renderEmailSpecial(audience){const box=document.querySelector(`[data-email-special=\"${audience}\"]`),cfg=emailConfig[audience],t=cfg.template||'standard';detachEmailEditorHost(audience);box.hidden=!['custom','html','chatgpt'].includes(t);"
if old_render_start in s:
    s = s.replace(old_render_start, new_render_start, 1)
elif 'detachEmailEditorHost(audience);box.hidden=' not in s:
    raise SystemExit('renderEmailSpecial start marker not found')

old_html = "if(t==='html'){box.innerHTML=`<label class=\"df-label\">HTML libero</label><textarea class=\"df-codearea\" data-email-html placeholder=\"<div>...</div>\">${esc(cfg.html||'')}</textarea><div class=\"df-note\"><?php echo addslashes(Text::_('COM_DECAROFORMS_HTML_VARIABLE_NOTE')); ?></div>`;box.querySelector('[data-email-html]').oninput=e=>{cfg.html=e.target.value;lastTokenTarget=e.target;sync();};box.querySelector('[data-email-html]').onfocus=e=>lastTokenTarget=e.target;}"
new_html = "if(t==='html'){if(!showEmailEditorHost(audience,box,cfg)){box.innerHTML=`<label class=\"df-label\">HTML libero</label><textarea class=\"df-codearea\" data-email-html placeholder=\"<div>...</div>\">${esc(cfg.html||'')}</textarea><div class=\"df-note\"><?php echo addslashes(Text::_('COM_DECAROFORMS_HTML_VARIABLE_NOTE')); ?></div>`;box.querySelector('[data-email-html]').oninput=e=>{cfg.html=e.target.value;lastTokenTarget=e.target;lastTokenEditorId=null;sync();};box.querySelector('[data-email-html]').onfocus=e=>{lastTokenTarget=e.target;lastTokenEditorId=null;};}}"
if old_html in s:
    s = s.replace(old_html, new_html, 1)
elif 'showEmailEditorHost(audience,box,cfg)' not in s:
    raise SystemExit('HTML email textarea marker not found')

# AI HTML remains a raw-code workflow. Ensure focusing it disables visual token target.
old_ai = "box.querySelector('[data-chatgpt-html]').oninput=e=>{cfg.html=e.target.value;sync();};"
new_ai = "box.querySelector('[data-chatgpt-html]').oninput=e=>{cfg.html=e.target.value;lastTokenTarget=e.target;lastTokenEditorId=null;sync();};box.querySelector('[data-chatgpt-html]').onfocus=e=>{lastTokenTarget=e.target;lastTokenEditorId=null;};"
if old_ai in s:
    s = s.replace(old_ai, new_ai, 1)

path.write_text(s, encoding='utf-8')
PY

# Version all three existing package children without changing product IDs,
# namespaces, database schema or plugin identities.
python3 - "$WORK/component" "$WORK/system" "$WORK/editor" "$WORK/outer" "$BASE_VERSION" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import re, sys
roots = [Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])]
outer = Path(sys.argv[4]); old, new, release_date = sys.argv[5:8]
text_suffixes = {'.php','.xml','.ini','.json','.md','.css','.js','.txt'}
for root in roots:
    for p in root.rglob('*'):
        if not p.is_file() or p.suffix.lower() not in text_suffixes:
            continue
        try: s = p.read_text(encoding='utf-8')
        except UnicodeDecodeError: continue
        if old in s: s = s.replace(old, new)
        if p.name in {'com_decaroforms.xml','decaroforms.xml'}:
            s = re.sub(r'<creationDate>[^<]+</creationDate>', f'<creationDate>{release_date}</creationDate>', s, count=1)
        p.write_text(s, encoding='utf-8')
for p in outer.iterdir():
    if not p.is_file() or p.suffix.lower()=='.zip': continue
    try: s=p.read_text(encoding='utf-8')
    except UnicodeDecodeError: continue
    s=s.replace(old,new)
    if p.name=='pkg_decaroforms.xml':
        s=re.sub(r'<creationDate>[^<]+</creationDate>',f'<creationDate>{release_date}</creationDate>',s,count=1)
    p.write_text(s,encoding='utf-8')
PY

# Security/regression gates.
php -l "$BUILDER" >/dev/null
while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$WORK/component" "$WORK/system" "$WORK/editor" -type f -name '*.php' -print0)
python3 - "$WORK/component" "$WORK/system" "$WORK/editor" "$WORK/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys, xml.etree.ElementTree as ET
for root in map(Path, sys.argv[1:4]):
    for p in root.rglob('*.xml'): ET.parse(p)
ET.parse(sys.argv[4])
PY

grep -Fq 'use Joomla\CMS\Editor\EditorsRegistry;' "$BUILDER"
grep -Fq "has('decaroeditor')" "$BUILDER"
grep -Fq "get('decaroeditor')" "$BUILDER"
grep -Fq 'data-email-editor-pool' "$BUILDER"
grep -Fq 'simpleFormControls()' "$BUILDER"
grep -Fq 'window.dfFormsFlushEmailEditors' "$BUILDER"
grep -Fq 'Joomla?.editors?.instances' "$BUILDER"
grep -Fq 'instance.replaceSelection(token)' "$BUILDER"
grep -Fq 'showEmailEditorHost(audience,box,cfg)' "$BUILDER"
grep -Fq 'data-chatgpt-html' "$BUILDER"
grep -Fq 'data-a="html"' "$BUILDER"
grep -Fq "Session::checkToken('post')" "$CONTROLLER"
grep -Fq "authorise('core.manage', 'com_decaroforms')" "$CONTROLLER"

if grep -RInE 'Xdecaro\\+Core' "$WORK/component" --include='*.php'; then
  echo 'Legacy Core namespace remains in Forms runtime PHP' >&2; exit 1
fi
if grep -RInE 'Xdecaro\\Component\\Decaroeditor|Xdecaro\\Plugin\\Editors\\Decaroeditor|bootComponent\([^)]*decaroeditor' "$WORK/component" --include='*.php' --include='*.js'; then
  echo 'Forms must not consume Editor implementation classes or boot its component' >&2; exit 1
fi
if grep -RInE '<file[^>]+decaroeditor|<dependency[^>]+decaroeditor' "$WORK/outer/pkg_decaroforms.xml"; then
  echo 'Editor integration must remain optional at package level' >&2; exit 1
fi

# The save controller and database ownership are intentionally untouched except
# for version text replacement performed package-wide.
python3 - "$BASE_ZIP" "$CONTROLLER" "$BASE_VERSION" "$NEW_VERSION" <<'PY'
from pathlib import Path
import sys, zipfile, tempfile
base_zip, new_controller, old, new = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], sys.argv[4]
with tempfile.TemporaryDirectory() as d:
    d=Path(d)
    with zipfile.ZipFile(base_zip) as z: z.extractall(d/'outer')
    with zipfile.ZipFile(d/'outer'/f'com_decaroforms_{old}.zip') as z:
        old_bytes=z.read('administrator/components/com_decaroforms/src/Controller/BuilderController.php')
old_text=old_bytes.decode().replace(old,new)
if old_text.encode()!=new_controller.read_bytes():
    raise SystemExit('BuilderController changed beyond version normalization')
PY

# Deterministic ZIP helper: fixed timestamps and sorted entries.
zip_tree() {
  local src="$1" dest="$2"
  python3 - "$src" "$dest" <<'PY'
from pathlib import Path
import stat, sys, zipfile
src, dest = Path(sys.argv[1]), Path(sys.argv[2])
fixed=(2026,9,9,0,0,0)
with zipfile.ZipFile(dest,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for p in sorted(x for x in src.rglob('*') if x.is_file()):
        rel=p.relative_to(src).as_posix()
        info=zipfile.ZipInfo(rel,fixed)
        info.compress_type=zipfile.ZIP_DEFLATED
        info.external_attr=(stat.S_IFREG | 0o644) << 16
        z.writestr(info,p.read_bytes(),compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
PY
}

rm -f "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip"
zip_tree "$WORK/component" "$WORK/outer/com_decaroforms_${NEW_VERSION}.zip"
zip_tree "$WORK/system" "$WORK/outer/plg_system_decaroforms_${NEW_VERSION}.zip"
zip_tree "$WORK/editor" "$WORK/outer/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip"
zip_tree "$WORK/outer" "$OUT/pkg_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/com_decaroforms_${NEW_VERSION}.zip" "$OUT/com_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/plg_system_decaroforms_${NEW_VERSION}.zip" "$OUT/plg_system_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip" "$OUT/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/pkg_decaroforms.xml" "$OUT/pkg_decaroforms.xml"

for file in "$OUT"/*.zip; do unzip -t "$file" >/dev/null; done
SHA256="$(sha256sum "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | awk '{print $1}')"
printf '%s  %s\n' "$SHA256" "pkg_decaroforms_${NEW_VERSION}.zip" > "$OUT/SHA256SUMS.txt"
cat > "$OUT/README.md" <<EOF
# Forms $NEW_VERSION

Optional Joomla editor integration for HTML email templates.

- Forms detects the public Joomla editor provider \`decaroeditor\` through \`EditorsRegistry\`;
- when Editor by xdecaro 0.1.0-alpha6+ is enabled, administrator and user “HTML libero” email templates use the visual editor;
- when Editor is absent, disabled or incompatible, the existing raw textarea remains available automatically;
- AI HTML and additional-email HTML remain raw-code fields in this release;
- email content continues to be stored only in \`email_config_json\`;
- no new database table/column, package dependency, Core API or product-specific Core logic is introduced;
- ACL, CSRF, Builder save transaction, Forms identifiers and data remain unchanged.

SHA-256 package: \`$SHA256\`
EOF

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update><name>Forms by xdecaro</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description><element>pkg_decaroforms</element><type>package</type><client>site</client><version>$NEW_VERSION</version><downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/$NEW_VERSION/pkg_decaroforms_$NEW_VERSION.zip</downloadurl></downloads><changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags><maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl><targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA256</sha256></update></updates>
EOF

python3 - "$ROOT/updates/changelog.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
entry='''\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>1.7.0</version>\n\t\t<note>Builder email: integrazione opzionale con il provider editor Joomla decaroeditor per i template HTML libero di amministrazione e utente. Editor assente/disabilitato mantiene automaticamente il textarea precedente. AI HTML ed email aggiuntive restano raw HTML. Nessuna nuova tabella, dipendenza obbligatoria, modifica a Core, ACL, CSRF o dati Forms.</note>\n\t</changelog>\n'''
if '<version>1.7.0</version>' not in s:
    s=s.replace('<changelogs>\n','<changelogs>\n'+entry,1)
p.write_text(s,encoding='utf-8')
PY

python3 - "$ROOT/README.md" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
s=s.replace('**1.6.0**','**1.7.0**',1)
needle='Email template cards are clickable and can be previewed through a modal facsimile preview before being used.\n'
addition='''\nWhen the optional **Editor by xdecaro 0.1.0-alpha6+** Joomla editor plugin is enabled, the administrator and user “HTML libero” email templates use the visual editor through Joomla’s public `EditorsRegistry` contract. Forms does not depend on Editor: if it is absent or disabled, the original HTML textarea is used automatically.\n'''
if 'Editor by xdecaro 0.1.0-alpha6+' not in s:
    if needle not in s: raise SystemExit('README email marker not found')
    s=s.replace(needle,needle+addition,1)
p.write_text(s,encoding='utf-8')
PY

python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" "$OUT/pkg_decaroforms.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for p in sys.argv[1:]: ET.parse(p)
PY

echo "Forms $NEW_VERSION package SHA-256: $SHA256"
