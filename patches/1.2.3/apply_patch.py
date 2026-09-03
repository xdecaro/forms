#!/usr/bin/env python3
from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

VERSION = "1.2.3"

if len(sys.argv) != 4:
    raise SystemExit("usage: apply_patch.py COMPONENT_DIR PLUGIN_DIR OUTER_DIR")

component = Path(sys.argv[1]).resolve()
plugin = Path(sys.argv[2]).resolve()
outer = Path(sys.argv[3]).resolve()
patch_root = Path(__file__).resolve().parent / "component"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"missing patch target: {label}")
    return text.replace(old, new, 1)


def set_ini(path: Path, key: str, value: str) -> None:
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8-sig")
    line = f'{key}="{value}"'
    rx = re.compile(rf'^{re.escape(key)}=.*$', re.MULTILINE)
    if rx.search(text):
        text = rx.sub(line, text, count=1)
    else:
        if text and not text.endswith("\n"):
            text += "\n"
        text += line + "\n"
    path.write_text(text, encoding="utf-8")


for src in patch_root.rglob("*"):
    if src.is_file():
        dst = component / src.relative_to(patch_root)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

# ---------- FormHelper: version + status colors ----------
helper_path = component / "administrator/components/com_decaroforms/src/Helper/FormHelper.php"
text = helper_path.read_text(encoding="utf-8")
text = re.sub(r"public const VERSION = '[^']+';", f"public const VERSION = '{VERSION}';", text, count=1)
text = text.replace(
    ':root[data-color-scheme="dark"] .df-badge{background:#384451!important;color:#eef3f8!important}',
    ':root[data-color-scheme="dark"] .df-badge:not([style]){background:#384451!important;color:#eef3f8!important}',
)
old_default = """    public static function defaultStatuses(): array
    {
        return [
            ['key'=>'new','label'=>Text::_('COM_DECAROFORMS_STATUS_NEW')],
            ['key'=>'processing','label'=>Text::_('COM_DECAROFORMS_STATUS_PROCESSING')],
            ['key'=>'replied','label'=>Text::_('COM_DECAROFORMS_STATUS_REPLIED')],
            ['key'=>'closed','label'=>Text::_('COM_DECAROFORMS_STATUS_CLOSED')],
            ['key'=>'spam','label'=>Text::_('COM_DECAROFORMS_STATUS_SPAM')],
        ];
    }
"""
new_default = """    public static function defaultStatuses(): array
    {
        return [
            ['key'=>'new','label'=>Text::_('COM_DECAROFORMS_STATUS_NEW'),'color'=>'#0d6efd'],
            ['key'=>'processing','label'=>Text::_('COM_DECAROFORMS_STATUS_PROCESSING'),'color'=>'#f59e0b'],
            ['key'=>'replied','label'=>Text::_('COM_DECAROFORMS_STATUS_REPLIED'),'color'=>'#198754'],
            ['key'=>'closed','label'=>Text::_('COM_DECAROFORMS_STATUS_CLOSED'),'color'=>'#6c757d'],
            ['key'=>'spam','label'=>Text::_('COM_DECAROFORMS_STATUS_SPAM'),'color'=>'#dc3545'],
        ];
    }

    public static function defaultStatusColor(string $status, int $index = 0): string
    {
        $known = [
            'new'=>'#0d6efd',
            'processing'=>'#f59e0b',
            'replied'=>'#198754',
            'closed'=>'#6c757d',
            'spam'=>'#dc3545',
        ];
        if (isset($known[$status])) { return $known[$status]; }
        $palette = ['#7c3aed','#0891b2','#be123c','#2563eb','#15803d','#b45309','#4b5563'];
        return $palette[$index % count($palette)];
    }
"""
text = replace_once(text, old_default, new_default, "default status colors")
old_statuses = """    public static function statusesForForm(array $form): array
    {
        $raw = json_decode((string)($form['statuses_json'] ?? ''), true);
        if (!is_array($raw) || !$raw) { return self::defaultStatuses(); }
        $out=[];
        foreach ($raw as $row) {
            if (!is_array($row)) { continue; }
            $key = strtolower(trim((string)($row['key'] ?? '')));
            $key = preg_replace('/[^a-z0-9_-]+/', '_', $key) ?? '';
            $label = trim((string)($row['label'] ?? ''));
            if ($key !== '' && $label !== '' && !isset($out[$key])) { $out[$key]=['key'=>substr($key,0,30),'label'=>substr($label,0,100)]; }
        }
        return array_values($out) ?: self::defaultStatuses();
    }
"""
new_statuses = """    public static function statusesForForm(array $form): array
    {
        $raw = json_decode((string)($form['statuses_json'] ?? ''), true);
        if (!is_array($raw) || !$raw) { return self::defaultStatuses(); }
        $out=[];
        foreach (array_values($raw) as $index => $row) {
            if (!is_array($row)) { continue; }
            $key = strtolower(trim((string)($row['key'] ?? '')));
            $key = preg_replace('/[^a-z0-9_-]+/', '_', $key) ?? '';
            $label = trim((string)($row['label'] ?? ''));
            $color = strtolower(trim((string)($row['color'] ?? '')));
            if (!preg_match('/^#[0-9a-f]{6}$/', $color)) { $color = self::defaultStatusColor($key, $index); }
            if ($key !== '' && $label !== '' && !isset($out[$key])) {
                $out[$key]=['key'=>substr($key,0,30),'label'=>substr($label,0,100),'color'=>$color];
            }
        }
        return array_values($out) ?: self::defaultStatuses();
    }
"""
text = replace_once(text, old_statuses, new_statuses, "form status colors")
status_label_block = """    public static function statusLabel(string $status, array $statuses = []): string
    {
        foreach ($statuses ?: self::defaultStatuses() as $item) {
            if (($item['key'] ?? '') === $status) { return (string)($item['label'] ?? $status); }
        }
        return $status;
    }
"""
status_methods = status_label_block + """
    public static function statusColor(string $status, array $statuses = []): string
    {
        foreach ($statuses ?: self::defaultStatuses() as $index => $item) {
            if (($item['key'] ?? '') !== $status) { continue; }
            $color = strtolower((string)($item['color'] ?? ''));
            return preg_match('/^#[0-9a-f]{6}$/', $color) ? $color : self::defaultStatusColor($status, (int)$index);
        }
        return self::defaultStatusColor($status);
    }

    public static function statusTextColor(string $background): string
    {
        $hex = ltrim(strtolower($background), '#');
        if (!preg_match('/^[0-9a-f]{6}$/', $hex)) { return '#ffffff'; }
        $r = hexdec(substr($hex,0,2));
        $g = hexdec(substr($hex,2,2));
        $b = hexdec(substr($hex,4,2));
        $luminance = (0.299*$r + 0.587*$g + 0.114*$b);
        return $luminance > 165 ? '#17202a' : '#ffffff';
    }

    public static function statusBadgeStyle(string $status, array $statuses = []): string
    {
        $background = self::statusColor($status, $statuses);
        return 'background:' . $background . ';color:' . self::statusTextColor($background) . ';';
    }
"""
text = replace_once(text, status_label_block, status_methods, "status color helpers")
helper_path.write_text(text, encoding="utf-8")

# ---------- Builder controller: persist validated color in statuses_json ----------
controller_path = component / "administrator/components/com_decaroforms/src/Controller/BuilderController.php"
text = controller_path.read_text(encoding="utf-8")
old_normalise = """    private function normaliseStatuses(string $json): string
    {
        $rows=json_decode($json,true);
        $out=[];
        if (is_array($rows)) {
            foreach ($rows as $row) {
                if (!is_array($row)) { continue; }
                $key=strtolower(trim((string)($row['key']??'')));
                $key=preg_replace('/[^a-z0-9_-]+/','_',$key)??'';
                $label=trim((string)($row['label']??''));
                if ($key!=='' && $label!=='' && !isset($out[$key])) { $out[$key]=['key'=>substr($key,0,30),'label'=>substr($label,0,100)]; }
            }
        }
        if (!$out) { return ''; }
        $values=array_values($out);
        $default=[
            ['key'=>'new','label'=>Text::_('COM_DECAROFORMS_STATUS_NEW')],
            ['key'=>'processing','label'=>Text::_('COM_DECAROFORMS_STATUS_PROCESSING')],
            ['key'=>'replied','label'=>Text::_('COM_DECAROFORMS_STATUS_REPLIED')],
            ['key'=>'closed','label'=>Text::_('COM_DECAROFORMS_STATUS_CLOSED')],
            ['key'=>'spam','label'=>Text::_('COM_DECAROFORMS_STATUS_SPAM')],
        ];
        // Keep the built-in workflow untranslated in DB so it continues to follow Joomla language changes.
        if ($values === $default) { return ''; }
        return json_encode($values,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
    }
"""
new_normalise = """    private function normaliseStatuses(string $json): string
    {
        $rows=json_decode($json,true);
        $out=[];
        if (is_array($rows)) {
            foreach (array_values($rows) as $index => $row) {
                if (!is_array($row)) { continue; }
                $key=strtolower(trim((string)($row['key']??'')));
                $key=preg_replace('/[^a-z0-9_-]+/','_',$key)??'';
                $label=trim((string)($row['label']??''));
                $color=strtolower(trim((string)($row['color']??'')));
                if (!preg_match('/^#[0-9a-f]{6}$/',$color)) { $color=FormHelper::defaultStatusColor($key,(int)$index); }
                if ($key!=='' && $label!=='' && !isset($out[$key])) {
                    $out[$key]=['key'=>substr($key,0,30),'label'=>substr($label,0,100),'color'=>$color];
                }
            }
        }
        if (!$out) { return ''; }
        $values=array_values($out);
        $default=[
            ['key'=>'new','label'=>Text::_('COM_DECAROFORMS_STATUS_NEW'),'color'=>'#0d6efd'],
            ['key'=>'processing','label'=>Text::_('COM_DECAROFORMS_STATUS_PROCESSING'),'color'=>'#f59e0b'],
            ['key'=>'replied','label'=>Text::_('COM_DECAROFORMS_STATUS_REPLIED'),'color'=>'#198754'],
            ['key'=>'closed','label'=>Text::_('COM_DECAROFORMS_STATUS_CLOSED'),'color'=>'#6c757d'],
            ['key'=>'spam','label'=>Text::_('COM_DECAROFORMS_STATUS_SPAM'),'color'=>'#dc3545'],
        ];
        // Keep the built-in workflow untranslated in DB so it continues to follow Joomla language changes.
        if ($values === $default) { return ''; }
        return json_encode($values,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
    }
"""
text = replace_once(text, old_normalise, new_normalise, "status color normalisation")
controller_path.write_text(text, encoding="utf-8")

# ---------- Builder UI: third color column + one-row table columns ----------
builder_path = component / "administrator/components/com_decaroforms/tmpl/builder/default.php"
text = builder_path.read_text(encoding="utf-8")
text = replace_once(
    text,
    ".df-status-row{display:grid;grid-template-columns:minmax(0,1fr) minmax(140px,.65fr) 34px;gap:7px}",
    ".df-status-row{display:grid;grid-template-columns:minmax(0,1fr) minmax(140px,.65fr) 105px 34px;gap:7px;align-items:center}",
    "status row color column",
)
text = replace_once(
    text,
    ".df-column-list{display:grid;grid-template-columns:1fr 1fr;gap:7px 12px;margin-top:10px}.df-column-item{display:flex;align-items:center;gap:8px}.df-column-item input{width:17px;height:17px}",
    ".df-status-color-wrap{display:flex;align-items:center;gap:7px}.df-status-color{width:45px!important;min-width:45px;height:40px;padding:3px!important;cursor:pointer}.df-status-color-value{font:700 11px/1 ui-monospace,SFMono-Regular,Menlo,monospace;color:var(--bs-secondary-color,#667085)}.df-column-list{display:flex;flex-direction:column;gap:8px;margin-top:10px}.df-column-item{display:flex;align-items:center;gap:9px;padding:10px 12px;border:1px solid var(--bs-border-color,#dfe3e7);border-radius:6px;background:var(--bs-body-bg,#fff)}.df-column-item input{width:17px;height:17px}",
    "one-row column list",
)
old_render_statuses = """function renderStatuses(){statusEditor.innerHTML='';statuses.forEach((st,i)=>{const r=document.createElement('div');r.className='df-status-row';r.innerHTML=`<input data-status-label placeholder=\"<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_STATUS_LABEL'),ENT_QUOTES,'UTF-8'); ?>\" value=\"${esc(st.label||'')}\"><input data-status-key placeholder=\"key\" value=\"${esc(st.key||'')}\"><button type=\"button\" class=\"df-status-remove\" title=\"${esc(tr.remove)}\">×</button>`;const li=r.querySelector('[data-status-label]'),ki=r.querySelector('[data-status-key]');li.addEventListener('input',()=>{statuses[i].label=li.value;if(!statuses[i].key){statuses[i].key=slugStatus(li.value);ki.value=statuses[i].key;}sync();});ki.addEventListener('input',()=>{statuses[i].key=slugStatus(ki.value);sync();});r.querySelector('button').onclick=()=>{if(statuses.length>1){statuses.splice(i,1);renderStatuses();}};statusEditor.appendChild(r);});sync();}
"""
new_render_statuses = """const statusPalette=['#0d6efd','#f59e0b','#198754','#6c757d','#dc3545','#7c3aed','#0891b2'];
function defaultStatusColor(key,index){const known={new:'#0d6efd',processing:'#f59e0b',replied:'#198754',closed:'#6c757d',spam:'#dc3545'};return known[key]||statusPalette[index%statusPalette.length];}
function renderStatuses(){statusEditor.innerHTML='';statuses.forEach((st,i)=>{st.color=/^#[0-9a-fA-F]{6}$/.test(st.color||'')?st.color:defaultStatusColor(st.key||'',i);const r=document.createElement('div');r.className='df-status-row';r.innerHTML=`<input data-status-label placeholder=\"<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_STATUS_LABEL'),ENT_QUOTES,'UTF-8'); ?>\" value=\"${esc(st.label||'')}\"><input data-status-key placeholder=\"key\" value=\"${esc(st.key||'')}\"><div class=\"df-status-color-wrap\"><input class=\"df-status-color\" data-status-color type=\"color\" value=\"${esc(st.color)}\" title=\"<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_STATUS_COLOR'),ENT_QUOTES,'UTF-8'); ?>\" aria-label=\"<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_STATUS_COLOR'),ENT_QUOTES,'UTF-8'); ?>\"><span class=\"df-status-color-value\">${esc(st.color)}</span></div><button type=\"button\" class=\"df-status-remove\" title=\"${esc(tr.remove)}\">×</button>`;const li=r.querySelector('[data-status-label]'),ki=r.querySelector('[data-status-key]'),ci=r.querySelector('[data-status-color]'),cv=r.querySelector('.df-status-color-value');li.addEventListener('input',()=>{statuses[i].label=li.value;if(!statuses[i].key){statuses[i].key=slugStatus(li.value);ki.value=statuses[i].key;}sync();});ki.addEventListener('input',()=>{statuses[i].key=slugStatus(ki.value);sync();});ci.addEventListener('input',()=>{statuses[i].color=ci.value.toLowerCase();cv.textContent=statuses[i].color;sync();});r.querySelector('button').onclick=()=>{if(statuses.length>1){statuses.splice(i,1);renderStatuses();}};statusEditor.appendChild(r);});sync();}
"""
text = replace_once(text, old_render_statuses, new_render_statuses, "builder color picker")
text = replace_once(
    text,
    "document.getElementById('df-add-status').onclick=()=>{statuses.push({key:'',label:''});renderStatuses();};",
    "document.getElementById('df-add-status').onclick=()=>{statuses.push({key:'',label:'',color:statusPalette[statuses.length%statusPalette.length]});renderStatuses();};",
    "new status default color",
)
builder_path.write_text(text, encoding="utf-8")

# ---------- Single submission: show the current badge color below the status selector ----------
submission_path = component / "administrator/components/com_decaroforms/tmpl/submission/default.php"
text = submission_path.read_text(encoding="utf-8")
text = replace_once(
    text,
    ".df-field textarea{min-height:150px;resize:vertical}.df-note{font-size:12px;color:var(--bs-secondary-color,#667085)}.df-manage .df-btn-primary{width:100%}",
    ".df-field textarea{min-height:150px;resize:vertical}.df-note{font-size:12px;color:var(--bs-secondary-color,#667085)}.df-status-preview{display:inline-flex;align-items:center;align-self:flex-start;padding:4px 9px;border-radius:999px;font-size:12px;font-weight:800;margin-top:2px}.df-manage .df-btn-primary{width:100%}",
    "status preview style",
)
old_status_field = """        <div class=\"df-field\"><label for=\"df-status\"><?php echo Text::_('COM_DECAROFORMS_STATUS'); ?></label><select id=\"df-status\" name=\"status\"><?php foreach($this->statuses as $st): $k=(string)$st['key']; $n=(string)$st['label']; ?><option value=\"<?php echo htmlspecialchars($k,ENT_QUOTES,'UTF-8'); ?>\" <?php echo ($s['status']??'new')===$k?'selected':''; ?>><?php echo htmlspecialchars($n,ENT_QUOTES,'UTF-8'); ?></option><?php endforeach; ?></select></div>
"""
new_status_field = """        <div class=\"df-field\"><label for=\"df-status\"><?php echo Text::_('COM_DECAROFORMS_STATUS'); ?></label><select id=\"df-status\" name=\"status\"><?php foreach($this->statuses as $st): $k=(string)$st['key']; $n=(string)$st['label']; ?><option value=\"<?php echo htmlspecialchars($k,ENT_QUOTES,'UTF-8'); ?>\" <?php echo ($s['status']??'new')===$k?'selected':''; ?>><?php echo htmlspecialchars($n,ENT_QUOTES,'UTF-8'); ?></option><?php endforeach; ?></select><span class=\"df-status-preview\" id=\"df-status-preview\" style=\"<?php echo htmlspecialchars(FormHelper::statusBadgeStyle((string)($s['status']??'new'),$this->statuses),ENT_QUOTES,'UTF-8'); ?>\"><?php echo htmlspecialchars(FormHelper::statusLabel((string)($s['status']??'new'),$this->statuses),ENT_QUOTES,'UTF-8'); ?></span></div>
"""
text = replace_once(text, old_status_field, new_status_field, "detail status badge")
text += """
<script>
(()=>{const select=document.getElementById('df-status'),badge=document.getElementById('df-status-preview');if(!select||!badge)return;const statuses=<?php echo json_encode(array_map(static fn($st)=>['key'=>(string)($st['key']??''),'label'=>(string)($st['label']??''),'style'=>FormHelper::statusBadgeStyle((string)($st['key']??''),$this->statuses)],$this->statuses),JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;select.addEventListener('change',()=>{const st=statuses.find(item=>item.key===select.value);if(!st)return;badge.textContent=st.label;badge.setAttribute('style',st.style);});})();
</script>
"""
submission_path.write_text(text, encoding="utf-8")

# ---------- Languages ----------
translations = {
    'it-IT': {
        'COM_DECAROFORMS_BACK': 'Indietro',
        'COM_DECAROFORMS_COLUMNS': 'Colonne',
        'COM_DECAROFORMS_TABLE_COLUMNS': 'Colonne della tabella',
        'COM_DECAROFORMS_RESET_DEFAULTS': 'Ripristina predefinite',
        'COM_DECAROFORMS_STATUS_COLOR': 'Colore badge',
    },
    'en-GB': {
        'COM_DECAROFORMS_BACK': 'Back',
        'COM_DECAROFORMS_COLUMNS': 'Columns',
        'COM_DECAROFORMS_TABLE_COLUMNS': 'Table columns',
        'COM_DECAROFORMS_RESET_DEFAULTS': 'Restore defaults',
        'COM_DECAROFORMS_STATUS_COLOR': 'Badge color',
    },
    'fr-FR': {
        'COM_DECAROFORMS_BACK': 'Retour',
        'COM_DECAROFORMS_COLUMNS': 'Colonnes',
        'COM_DECAROFORMS_TABLE_COLUMNS': 'Colonnes du tableau',
        'COM_DECAROFORMS_RESET_DEFAULTS': 'Rétablir les valeurs par défaut',
        'COM_DECAROFORMS_STATUS_COLOR': 'Couleur du badge',
    },
}
for tag, entries in translations.items():
    lang_dir = component / f"administrator/components/com_decaroforms/language/{tag}"
    for filename in ('com_decaroforms.ini','com_decaroforms.sys.ini'):
        for key, value in entries.items():
            set_ini(lang_dir / filename, key, value)

# ---------- Versions ----------
component_manifest = component / "com_decaroforms.xml"
ct = component_manifest.read_text(encoding="utf-8")
ct = re.sub(r"<version>[^<]+</version>", f"<version>{VERSION}</version>", ct, count=1)
component_manifest.write_text(ct, encoding="utf-8")

plugin_manifest = plugin / "decaroforms.xml"
pt = plugin_manifest.read_text(encoding="utf-8")
pt = re.sub(r"<version>[^<]+</version>", f"<version>{VERSION}</version>", pt, count=1)
plugin_manifest.write_text(pt, encoding="utf-8")

package_manifest = outer / "pkg_decaroforms.xml"
ot = package_manifest.read_text(encoding="utf-8")
ot = re.sub(r"<version>[^<]+</version>", f"<version>{VERSION}</version>", ot, count=1)
ot = ot.replace("com_decaroforms_1.2.2.zip", f"com_decaroforms_{VERSION}.zip")
ot = ot.replace("plg_system_decaroforms_1.2.2.zip", f"plg_system_decaroforms_{VERSION}.zip")
package_manifest.write_text(ot, encoding="utf-8")

print(f"Forms patch {VERSION} applied")
