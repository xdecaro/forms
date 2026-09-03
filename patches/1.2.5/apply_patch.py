#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

VERSION = "1.2.5"

if len(sys.argv) != 4:
    raise SystemExit("usage: apply_patch.py COMPONENT_DIR PLUGIN_DIR OUTER_DIR")

component = Path(sys.argv[1]).resolve()
plugin = Path(sys.argv[2]).resolve()
outer = Path(sys.argv[3]).resolve()


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


# ---------------------------------------------------------------------------
# Forms list: title must match the Joomla submenu label.
# ---------------------------------------------------------------------------
for tag, value in {
    "it-IT": "Elenco moduli",
    "en-GB": "Forms list",
    "fr-FR": "Liste des formulaires",
}.items():
    lang_dir = component / f"administrator/components/com_decaroforms/language/{tag}"
    for filename in ("com_decaroforms.ini", "com_decaroforms.sys.ini"):
        set_ini(lang_dir / filename, "COM_DECAROFORMS_FORMS", value)

# ---------------------------------------------------------------------------
# Per-form submissions page.
# - remove isolated Back button
# - use one ← Forms list action in the header
# - export icons
# - clickable summary cards as instant status filters
# ---------------------------------------------------------------------------
path = component / "administrator/components/com_decaroforms/tmpl/submissions/default.php"
text = path.read_text(encoding="utf-8")
text = replace_once(
    text,
    ".df-submissions{--df:#e60046;--df-blue:#087fb7;width:100%;max-width:none}.df-sub-back{margin:4px 0 12px}.df-sub-head",
    ".df-submissions{--df:#e60046;--df-blue:#087fb7;width:100%;max-width:none}.df-sub-head",
    "remove standalone back css",
)
text = replace_once(
    text,
    ".df-sub-stat{min-height:104px;padding:18px 19px;border:1px solid var(--bs-border-color,#d9e0e8);border-top:4px solid var(--stat-color,var(--bs-border-color,#d9e0e8));border-radius:8px;background:var(--bs-body-bg,#fff)}.df-sub-stat strong",
    ".df-sub-stat{appearance:none;width:100%;min-height:104px;padding:18px 19px;border:1px solid var(--bs-border-color,#d9e0e8);border-top:4px solid var(--stat-color,var(--bs-border-color,#d9e0e8));border-radius:8px;background:var(--bs-body-bg,#fff);color:inherit;text-align:left;font:inherit;cursor:pointer;transition:box-shadow .15s ease,transform .15s ease,border-color .15s ease}.df-sub-stat:hover{transform:translateY(-1px);box-shadow:0 5px 16px rgba(0,0,0,.08)}.df-sub-stat.is-active{box-shadow:0 0 0 3px color-mix(in srgb,var(--stat-color,#087fb7) 26%,transparent);border-color:var(--stat-color,#087fb7)}.df-sub-stat strong",
    "clickable submission stat styles",
)
text = replace_once(
    text,
    ".df-export-menu button{display:block;width:100%;padding:10px 11px;border:0;border-radius:5px;background:transparent;color:inherit;text-align:left;font-weight:750;cursor:pointer}.df-export-menu button:hover",
    ".df-export-menu button{display:flex;width:100%;align-items:center;gap:10px;padding:10px 11px;border:0;border-radius:5px;background:transparent;color:inherit;text-align:left;font-weight:750;cursor:pointer}.df-export-menu button:hover",
    "export menu icon alignment",
)
text = replace_once(
    text,
    ".df-export-menu button:hover{background:var(--bs-tertiary-bg,#f2f5f8)}",
    ".df-export-menu button:hover{background:var(--bs-tertiary-bg,#f2f5f8)}.df-export-icon{width:17px;height:17px;display:inline-flex;align-items:center;justify-content:center;flex:0 0 17px}.df-export-icon svg{display:block;width:17px;height:17px;fill:none;stroke:currentColor;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}.df-export-format{display:inline-flex;align-items:center;gap:8px}",
    "export icon css",
)
text = replace_once(
    text,
    "  <div class=\"df-sub-back\"><a class=\"df-btn\" href=\"index.php?option=com_decaroforms&view=forms\">← <?php echo Text::_('COM_DECAROFORMS_BACK'); ?></a></div>\n\n",
    "",
    "remove standalone back button",
)
text = replace_once(
    text,
    "        <button class=\"df-btn df-btn-export\" type=\"button\" id=\"df-export-toggle\" disabled><?php echo Text::_('COM_DECAROFORMS_EXPORT'); ?> ▾</button>\n        <div class=\"df-export-menu\" id=\"df-export-menu\" hidden>\n          <button type=\"button\" data-format=\"csv\">CSV</button>\n          <button type=\"button\" data-format=\"xlsx\">Excel</button>\n          <button type=\"button\" data-format=\"pdf\">PDF</button>\n        </div>",
    "        <button class=\"df-btn df-btn-export\" type=\"button\" id=\"df-export-toggle\" disabled><span class=\"df-export-icon\" aria-hidden=\"true\"><svg viewBox=\"0 0 24 24\"><path d=\"M12 3v12\"></path><path d=\"m7 10 5 5 5-5\"></path><path d=\"M5 21h14\"></path></svg></span><?php echo Text::_('COM_DECAROFORMS_EXPORT'); ?> ▾</button>\n        <div class=\"df-export-menu\" id=\"df-export-menu\" hidden>\n          <button type=\"button\" data-format=\"csv\"><span class=\"df-export-icon\" aria-hidden=\"true\"><svg viewBox=\"0 0 24 24\"><path d=\"M6 3h9l3 3v15H6z\"></path><path d=\"M15 3v4h4\"></path><path d=\"M9 12h6\"></path><path d=\"M9 16h6\"></path></svg></span><span>CSV</span></button>\n          <button type=\"button\" data-format=\"xlsx\"><span class=\"df-export-icon\" aria-hidden=\"true\"><svg viewBox=\"0 0 24 24\"><rect x=\"4\" y=\"4\" width=\"16\" height=\"16\" rx=\"1\"></rect><path d=\"M4 10h16M10 4v16M15 4v16\"></path></svg></span><span>Excel</span></button>\n          <button type=\"button\" data-format=\"pdf\"><span class=\"df-export-icon\" aria-hidden=\"true\"><svg viewBox=\"0 0 24 24\"><path d=\"M6 3h9l3 3v15H6z\"></path><path d=\"M15 3v4h4\"></path><path d=\"M9 13h6M9 17h4\"></path></svg></span><span>PDF</span></button>\n        </div>",
    "submission export icons",
)
text = replace_once(
    text,
    "      <a class=\"df-btn\" href=\"index.php?option=com_decaroforms&view=forms\"><?php echo Text::_('COM_DECAROFORMS_FORMS_LIST'); ?></a>",
    "      <a class=\"df-btn\" href=\"index.php?option=com_decaroforms&view=forms\">← <?php echo Text::_('COM_DECAROFORMS_FORMS_LIST'); ?></a>",
    "header forms-list back action",
)
text = replace_once(
    text,
    "    <div class=\"df-sub-stat\"><strong><?php echo (int) ($this->stats['total'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_TOTAL_SHORT'); ?></span></div>\n    <?php foreach (($this->stats['statuses'] ?? []) as $stat): ?>\n      <div class=\"df-sub-stat\" style=\"--stat-color:<?php echo htmlspecialchars((string) $stat['color'], ENT_QUOTES, 'UTF-8'); ?>\"><strong><?php echo (int) $stat['count']; ?></strong><span><?php echo htmlspecialchars((string) $stat['label'], ENT_QUOTES, 'UTF-8'); ?></span></div>\n    <?php endforeach; ?>",
    "    <button type=\"button\" class=\"df-sub-stat is-active\" data-status-filter=\"all\" style=\"--stat-color:#087fb7\"><strong><?php echo (int) ($this->stats['total'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_TOTAL_SHORT'); ?></span></button>\n    <?php foreach (($this->stats['statuses'] ?? []) as $stat): ?>\n      <button type=\"button\" class=\"df-sub-stat\" data-status-filter=\"<?php echo htmlspecialchars((string) ($stat['key'] ?? ''), ENT_QUOTES, 'UTF-8'); ?>\" style=\"--stat-color:<?php echo htmlspecialchars((string) $stat['color'], ENT_QUOTES, 'UTF-8'); ?>\"><strong><?php echo (int) $stat['count']; ?></strong><span><?php echo htmlspecialchars((string) $stat['label'], ENT_QUOTES, 'UTF-8'); ?></span></button>\n    <?php endforeach; ?>",
    "clickable submission summary markup",
)
text = replace_once(
    text,
    " const search=document.getElementById('df-s'),filter=document.getElementById('df-f'),limit=document.getElementById('df-limit'),rows=[...document.querySelectorAll('.df-table tbody tr')],head=document.getElementById('df-select-head'),allBtn=document.getElementById('df-select-visible'),exportBtn=document.getElementById('df-export-toggle'),menu=document.getElementById('df-export-menu'),counter=document.getElementById('df-selection-count'),empty=document.getElementById('df-sub-empty');",
    " const search=document.getElementById('df-s'),filter=document.getElementById('df-f'),limit=document.getElementById('df-limit'),rows=[...document.querySelectorAll('.df-table tbody tr')],head=document.getElementById('df-select-head'),allBtn=document.getElementById('df-select-visible'),exportBtn=document.getElementById('df-export-toggle'),menu=document.getElementById('df-export-menu'),counter=document.getElementById('df-selection-count'),empty=document.getElementById('df-sub-empty'),statButtons=[...document.querySelectorAll('[data-status-filter]')];",
    "submission stat js references",
)
text = replace_once(
    text,
    " function apply(){const query=(search.value||'').trim().toLowerCase(),status=filter.value,max=parseInt(limit.value||'50',10);let shown=0;rows.forEach(row=>{const match=(!query||row.dataset.text.includes(query))&&(status==='all'||row.dataset.status===status);const visible=match&&shown<max;row.hidden=!visible;if(visible)shown++;});empty.hidden=shown!==0;updateSelection();}",
    " function updateActiveStat(){statButtons.forEach(button=>button.classList.toggle('is-active',button.dataset.statusFilter===filter.value));}\n function apply(){const query=(search.value||'').trim().toLowerCase(),status=filter.value,max=parseInt(limit.value||'50',10);let shown=0;rows.forEach(row=>{const match=(!query||row.dataset.text.includes(query))&&(status==='all'||row.dataset.status===status);const visible=match&&shown<max;row.hidden=!visible;if(visible)shown++;});empty.hidden=shown!==0;updateActiveStat();updateSelection();}",
    "submission active summary js",
)
text = replace_once(
    text,
    " document.getElementById('df-clear-btn').addEventListener('click',()=>{search.value='';filter.value='all';limit.value='50';apply();});",
    " document.getElementById('df-clear-btn').addEventListener('click',()=>{search.value='';filter.value='all';limit.value='50';apply();});\n statButtons.forEach(button=>button.addEventListener('click',()=>{filter.value=button.dataset.statusFilter||'all';apply();}));",
    "submission stat click handlers",
)
path.write_text(text, encoding="utf-8")

# ---------------------------------------------------------------------------
# Recent submissions: make the summary cards clickable too for consistency.
# ---------------------------------------------------------------------------
path = component / "administrator/components/com_decaroforms/tmpl/recent/default.php"
text = path.read_text(encoding="utf-8")
text = replace_once(
    text,
    ".df-recent-stat{min-height:112px;padding:20px 22px;border:1px solid var(--bs-border-color,#d9e0e8);border-radius:9px;background:var(--bs-body-bg,#fff)}.df-recent-stat strong",
    ".df-recent-stat{appearance:none;width:100%;min-height:112px;padding:20px 22px;border:1px solid var(--bs-border-color,#d9e0e8);border-top:4px solid var(--stat-color,var(--bs-border-color,#d9e0e8));border-radius:9px;background:var(--bs-body-bg,#fff);color:inherit;text-align:left;font:inherit;cursor:pointer;transition:box-shadow .15s ease,transform .15s ease,border-color .15s ease}.df-recent-stat:hover{transform:translateY(-1px);box-shadow:0 5px 16px rgba(0,0,0,.08)}.df-recent-stat.is-active{box-shadow:0 0 0 3px color-mix(in srgb,var(--stat-color,#0789c8) 26%,transparent);border-color:var(--stat-color,#0789c8)}.df-recent-stat strong",
    "recent clickable stat styles",
)
old_stats = """    <div class=\"df-recent-stat\"><strong><?php echo (int) ($this->stats['total'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_TOTAL_SHORT'); ?></span></div>
    <div class=\"df-recent-stat\"><strong><?php echo (int) ($this->stats['new'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_NEW'); ?></span></div>
    <div class=\"df-recent-stat\"><strong><?php echo (int) ($this->stats['processing'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_PROCESSING'); ?></span></div>
    <div class=\"df-recent-stat\"><strong><?php echo (int) ($this->stats['replied'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_REPLIED'); ?></span></div>
    <div class=\"df-recent-stat\"><strong><?php echo (int) ($this->stats['closed'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_CLOSED'); ?></span></div>
    <div class=\"df-recent-stat\"><strong><?php echo (int) ($this->stats['spam'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_SPAM'); ?></span></div>"""
new_stats = """    <button type=\"button\" class=\"df-recent-stat is-active\" data-recent-status-filter=\"all\" style=\"--stat-color:#0789c8\"><strong><?php echo (int) ($this->stats['total'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_TOTAL_SHORT'); ?></span></button>
    <button type=\"button\" class=\"df-recent-stat\" data-recent-status-filter=\"new\" style=\"--stat-color:#0d6efd\"><strong><?php echo (int) ($this->stats['new'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_NEW'); ?></span></button>
    <button type=\"button\" class=\"df-recent-stat\" data-recent-status-filter=\"processing\" style=\"--stat-color:#f59e0b\"><strong><?php echo (int) ($this->stats['processing'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_PROCESSING'); ?></span></button>
    <button type=\"button\" class=\"df-recent-stat\" data-recent-status-filter=\"replied\" style=\"--stat-color:#198754\"><strong><?php echo (int) ($this->stats['replied'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_REPLIED'); ?></span></button>
    <button type=\"button\" class=\"df-recent-stat\" data-recent-status-filter=\"closed\" style=\"--stat-color:#6c757d\"><strong><?php echo (int) ($this->stats['closed'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_CLOSED'); ?></span></button>
    <button type=\"button\" class=\"df-recent-stat\" data-recent-status-filter=\"spam\" style=\"--stat-color:#dc3545\"><strong><?php echo (int) ($this->stats['spam'] ?? 0); ?></strong><span><?php echo Text::_('COM_DECAROFORMS_STATUS_SPAM'); ?></span></button>"""
text = replace_once(text, old_stats, new_stats, "recent clickable stats markup")
text = replace_once(
    text,
    " const search=document.getElementById('df-r-search'),form=document.getElementById('df-r-form'),status=document.getElementById('df-r-status'),limit=document.getElementById('df-r-limit'),rows=[...document.querySelectorAll('#df-r-body tr')],empty=document.getElementById('df-r-empty');",
    " const search=document.getElementById('df-r-search'),form=document.getElementById('df-r-form'),status=document.getElementById('df-r-status'),limit=document.getElementById('df-r-limit'),rows=[...document.querySelectorAll('#df-r-body tr')],empty=document.getElementById('df-r-empty'),statButtons=[...document.querySelectorAll('[data-recent-status-filter]')];",
    "recent stat js references",
)
text = replace_once(
    text,
    " function apply(){const query=(search.value||'').trim().toLowerCase(),formId=form.value,statusKey=status.value,max=parseInt(limit.value||'50',10);let shown=0;rows.forEach(row=>{const match=(!query||row.dataset.text.includes(query))&&(formId==='all'||row.dataset.form===formId)&&(statusKey==='all'||row.dataset.status===statusKey);const visible=match&&shown<max;row.hidden=!visible;if(visible)shown++;});empty.hidden=shown!==0;}",
    " function updateActiveStat(){statButtons.forEach(button=>button.classList.toggle('is-active',button.dataset.recentStatusFilter===status.value));}\n function apply(){const query=(search.value||'').trim().toLowerCase(),formId=form.value,statusKey=status.value,max=parseInt(limit.value||'50',10);let shown=0;rows.forEach(row=>{const match=(!query||row.dataset.text.includes(query))&&(formId==='all'||row.dataset.form===formId)&&(statusKey==='all'||row.dataset.status===statusKey);const visible=match&&shown<max;row.hidden=!visible;if(visible)shown++;});empty.hidden=shown!==0;updateActiveStat();}",
    "recent active stat js",
)
text = replace_once(
    text,
    " document.getElementById('df-r-filter').addEventListener('click',apply);document.getElementById('df-r-clear').addEventListener('click',()=>{search.value='';form.value='all';status.value='all';limit.value='50';apply();});search.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();apply();}});limit.addEventListener('change',apply);",
    " document.getElementById('df-r-filter').addEventListener('click',apply);document.getElementById('df-r-clear').addEventListener('click',()=>{search.value='';form.value='all';status.value='all';limit.value='50';apply();});search.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();apply();}});limit.addEventListener('change',apply);statButtons.forEach(button=>button.addEventListener('click',()=>{status.value=button.dataset.recentStatusFilter||'all';apply();}));",
    "recent stat click handlers",
)
path.write_text(text, encoding="utf-8")

# ---------------------------------------------------------------------------
# Submission detail: move a larger live status badge into the Manage header.
# ---------------------------------------------------------------------------
path = component / "administrator/components/com_decaroforms/tmpl/submission/default.php"
text = path.read_text(encoding="utf-8")
text = replace_once(
    text,
    ".df-manage{position:sticky;top:12px;padding:16px}.df-manage h3{margin:0 0 16px;font-size:19px}.df-field",
    ".df-manage{position:sticky;top:12px;padding:16px}.df-manage-head{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:16px}.df-manage h3{margin:0;font-size:19px}.df-field",
    "manage header layout",
)
text = replace_once(
    text,
    ".df-status-preview{display:inline-flex;align-items:center;align-self:flex-start;padding:4px 9px;border-radius:999px;font-size:12px;font-weight:800;margin-top:2px}",
    ".df-status-preview{display:inline-flex;align-items:center;justify-content:center;min-height:34px;padding:7px 13px;border-radius:999px;font-size:14px;line-height:1;font-weight:850;white-space:nowrap;box-shadow:0 2px 7px rgba(0,0,0,.12)}",
    "larger status badge",
)
text = replace_once(
    text,
    "    <aside class=\"df-manage\">\n      <h3><?php echo Text::_('COM_DECAROFORMS_MANAGE_SUBMISSION'); ?></h3>\n      <form",
    "    <aside class=\"df-manage\">\n      <div class=\"df-manage-head\"><h3><?php echo Text::_('COM_DECAROFORMS_MANAGE_SUBMISSION'); ?></h3><span class=\"df-status-preview\" id=\"df-status-preview\" style=\"<?php echo htmlspecialchars(FormHelper::statusBadgeStyle((string)($s['status']??'new'),$this->statuses),ENT_QUOTES,'UTF-8'); ?>\"><?php echo htmlspecialchars(FormHelper::statusLabel((string)($s['status']??'new'),$this->statuses),ENT_QUOTES,'UTF-8'); ?></span></div>\n      <form",
    "move status badge into manage header",
)
old_field = """        <div class=\"df-field\"><label for=\"df-status\"><?php echo Text::_('COM_DECAROFORMS_STATUS'); ?></label><select id=\"df-status\" name=\"status\"><?php foreach($this->statuses as $st): $k=(string)$st['key']; $n=(string)$st['label']; ?><option value=\"<?php echo htmlspecialchars($k,ENT_QUOTES,'UTF-8'); ?>\" <?php echo ($s['status']??'new')===$k?'selected':''; ?>><?php echo htmlspecialchars($n,ENT_QUOTES,'UTF-8'); ?></option><?php endforeach; ?></select><span class=\"df-status-preview\" id=\"df-status-preview\" style=\"<?php echo htmlspecialchars(FormHelper::statusBadgeStyle((string)($s['status']??'new'),$this->statuses),ENT_QUOTES,'UTF-8'); ?>\"><?php echo htmlspecialchars(FormHelper::statusLabel((string)($s['status']??'new'),$this->statuses),ENT_QUOTES,'UTF-8'); ?></span></div>"""
new_field = """        <div class=\"df-field\"><label for=\"df-status\"><?php echo Text::_('COM_DECAROFORMS_STATUS'); ?></label><select id=\"df-status\" name=\"status\"><?php foreach($this->statuses as $st): $k=(string)$st['key']; $n=(string)$st['label']; ?><option value=\"<?php echo htmlspecialchars($k,ENT_QUOTES,'UTF-8'); ?>\" <?php echo ($s['status']??'new')===$k?'selected':''; ?>><?php echo htmlspecialchars($n,ENT_QUOTES,'UTF-8'); ?></option><?php endforeach; ?></select></div>"""
text = replace_once(text, old_field, new_field, "remove badge below status select")
text = replace_once(
    text,
    "@media(max-width:640px){.df-data-grid,.df-tracking{grid-template-columns:1fr}.df-detail-main,.df-manage{padding:13px}.df-file{align-items:flex-start;flex-direction:column}.df-file .df-btn{width:100%}}",
    "@media(max-width:640px){.df-data-grid,.df-tracking{grid-template-columns:1fr}.df-detail-main,.df-manage{padding:13px}.df-file{align-items:flex-start;flex-direction:column}.df-file .df-btn{width:100%}.df-manage-head{align-items:flex-start;flex-direction:column}.df-status-preview{font-size:13px}}",
    "detail mobile badge layout",
)
path.write_text(text, encoding="utf-8")

# ---------------------------------------------------------------------------
# Version bump in helper and manifests.
# ---------------------------------------------------------------------------
helper = component / "administrator/components/com_decaroforms/src/Helper/FormHelper.php"
h = helper.read_text(encoding="utf-8")
h = re.sub(r"public const VERSION = '[^']+';", f"public const VERSION = '{VERSION}';", h, count=1)
helper.write_text(h, encoding="utf-8")

manifest = component / "com_decaroforms.xml"
m = manifest.read_text(encoding="utf-8")
m = re.sub(r"<version>[^<]+</version>", f"<version>{VERSION}</version>", m, count=1)
manifest.write_text(m, encoding="utf-8")

plugin_manifest = plugin / "decaroforms.xml"
pm = plugin_manifest.read_text(encoding="utf-8")
pm = re.sub(r"<version>[^<]+</version>", f"<version>{VERSION}</version>", pm, count=1)
plugin_manifest.write_text(pm, encoding="utf-8")

package_manifest = outer / "pkg_decaroforms.xml"
pkg = package_manifest.read_text(encoding="utf-8")
pkg = re.sub(r"<version>[^<]+</version>", f"<version>{VERSION}</version>", pkg, count=1)
pkg = pkg.replace("com_decaroforms_1.2.4.zip", f"com_decaroforms_{VERSION}.zip")
pkg = pkg.replace("plg_system_decaroforms_1.2.4.zip", f"plg_system_decaroforms_{VERSION}.zip")
package_manifest.write_text(pkg, encoding="utf-8")

print(f"Forms patch {VERSION} applied")
