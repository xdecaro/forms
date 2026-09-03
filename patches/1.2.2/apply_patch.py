#!/usr/bin/env python3
from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

VERSION = "1.2.2"

if len(sys.argv) != 4:
    raise SystemExit("usage: apply_patch.py COMPONENT_DIR PLUGIN_DIR OUTER_DIR")

component = Path(sys.argv[1]).resolve()
plugin = Path(sys.argv[2]).resolve()
outer = Path(sys.argv[3]).resolve()
repo = Path(__file__).resolve().parents[2]
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


# Copy complete replacement files prepared for this release.
for src in patch_root.rglob("*"):
    if src.is_file():
        dst = component / src.relative_to(patch_root)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

# Export helper: support a whitelist of selected submission IDs.
export_path = component / "administrator/components/com_decaroforms/src/Helper/ExportHelper.php"
text = export_path.read_text(encoding="utf-8")
text = replace_once(
    text,
    "public static function loadRows(int $formId, string $query = '', string $status = 'all'): array",
    "public static function loadRows(int $formId, string $query = '', string $status = 'all', array $onlyIds = []): array",
    "ExportHelper::loadRows signature",
)
needle = """        if ($status !== '' && $status !== 'all' && preg_match('/^[a-z0-9_-]{1,30}$/', $status)) {
            $q->where($db->quoteName('status') . ' = :status')->bind(':status', $status);
        }
        $db->setQuery($q);"""
replacement = """        if ($status !== '' && $status !== 'all' && preg_match('/^[a-z0-9_-]{1,30}$/', $status)) {
            $q->where($db->quoteName('status') . ' = :status')->bind(':status', $status);
        }
        if ($onlyIds) {
            $onlyIds = array_values(array_unique(array_filter(array_map('intval', $onlyIds), static fn(int $id): bool => $id > 0)));
            if ($onlyIds) {
                $q->whereIn($db->quoteName('id'), $onlyIds);
            }
        }
        $db->setQuery($q);"""
text = replace_once(text, needle, replacement, "selected export ID filter")
export_path.write_text(text, encoding="utf-8")

# Version footer + global admin full-width/dark-mode selectors.
helper_path = component / "administrator/components/com_decaroforms/src/Helper/FormHelper.php"
text = helper_path.read_text(encoding="utf-8")
text = re.sub(r"public const VERSION = '[^']+';", f"public const VERSION = '{VERSION}';", text, count=1)
text = text.replace(
    ".df-wrap,.df-builder,.df-info,.df-imp,.df-mig,.df-dashboard{",
    ".df-wrap,.df-builder,.df-info,.df-imp,.df-mig,.df-dashboard,.df-recent,.df-submissions,.df-detail{",
)
text = text.replace(
    ':root[data-color-scheme="dark"] .df-wrap,:root[data-color-scheme="dark"] .df-builder,:root[data-color-scheme="dark"] .df-info,:root[data-color-scheme="dark"] .df-imp,:root[data-color-scheme="dark"] .df-mig,:root[data-color-scheme="dark"] .df-dashboard{',
    ':root[data-color-scheme="dark"] .df-wrap,:root[data-color-scheme="dark"] .df-builder,:root[data-color-scheme="dark"] .df-info,:root[data-color-scheme="dark"] .df-imp,:root[data-color-scheme="dark"] .df-mig,:root[data-color-scheme="dark"] .df-dashboard,:root[data-color-scheme="dark"] .df-recent,:root[data-color-scheme="dark"] .df-submissions,:root[data-color-scheme="dark"] .df-detail{',
)
helper_path.write_text(text, encoding="utf-8")

# Builder: clickable email template cards + realistic facsimile modal based on current form fields.
builder_path = component / "administrator/components/com_decaroforms/tmpl/builder/default.php"
text = builder_path.read_text(encoding="utf-8")
modal_css = r'''
.df-email-card{appearance:none;width:100%;cursor:pointer;background:var(--bs-body-bg,#fff);color:inherit;font:inherit;position:relative;transition:border-color .15s ease,box-shadow .15s ease,transform .15s ease}.df-email-card:hover,.df-email-card:focus-visible{border-color:var(--df);box-shadow:0 0 0 2px color-mix(in srgb,var(--df) 20%,transparent);outline:0;transform:translateY(-1px)}.df-email-card.is-active{border-color:var(--df);box-shadow:0 0 0 2px color-mix(in srgb,var(--df) 24%,transparent)}
.df-email-modal[hidden]{display:none!important}.df-email-modal{position:fixed;inset:0;z-index:12000;display:grid;place-items:center;padding:24px}.df-email-modal-backdrop{position:absolute;inset:0;background:rgba(0,0,0,.58)}.df-email-dialog{position:relative;z-index:1;width:min(820px,100%);max-height:min(88vh,920px);overflow:auto;border:1px solid var(--bs-border-color,#d5dbe3);border-radius:10px;background:var(--bs-body-bg,#fff);color:inherit;box-shadow:0 24px 80px rgba(0,0,0,.28)}.df-email-modal-head{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:15px 17px;border-bottom:1px solid var(--bs-border-color,#dfe3e7)}.df-email-modal-head h3{margin:0;font-size:19px}.df-email-x{width:36px;height:36px;border:1px solid var(--bs-border-color,#d5dbe3);border-radius:6px;background:transparent;color:inherit;font-size:22px;cursor:pointer}.df-email-modal-body{padding:17px}.df-email-tabs{display:flex;gap:7px;margin-bottom:13px}.df-email-tab{min-height:37px;padding:0 12px;border:1px solid var(--bs-border-color,#d5dbe3);border-radius:6px;background:var(--bs-body-bg,#fff);color:inherit;font-weight:800;cursor:pointer}.df-email-tab.is-active{background:var(--df);border-color:var(--df);color:#fff}.df-email-subject{margin-bottom:12px;padding:10px 12px;border:1px solid var(--bs-border-color,#dfe3e7);border-radius:6px;background:var(--bs-tertiary-bg,#f7f8fa)}.df-email-subject small{display:block;margin-bottom:3px;color:var(--bs-secondary-color,#667085);font-weight:700}.df-email-canvas{padding:22px;background:#e9edf2;border:1px solid #d6dce4;border-radius:7px;overflow:auto}.df-email-canvas>div{margin:0 auto}.df-email-modal-actions{display:flex;justify-content:flex-end;gap:8px;padding:14px 17px;border-top:1px solid var(--bs-border-color,#dfe3e7)}.df-email-template-name{font-weight:800;color:var(--df)}
@media(max-width:680px){.df-email-modal{padding:10px}.df-email-modal-actions{flex-direction:column-reverse}.df-email-modal-actions .df-btn{width:100%}.df-email-tabs{display:grid;grid-template-columns:1fr 1fr}.df-email-canvas{padding:10px}}
'''
text = replace_once(text, "</style>", modal_css + "\n</style>", "builder modal styles")

cards_pattern = re.compile(
    r'<div class="df-field df-field-full"><label><\?php echo Text::_\(\'COM_DECAROFORMS_EMAIL_TEMPLATE\'\); \?></label><div class="df-email-templates">.*?</div></div>\s*<div class="df-field"><label><\?php echo Text::_\(\'COM_DECAROFORMS_ADMIN_TEMPLATE\'\); \?></label>',
    re.S,
)
cards_html = '''<div class="df-field df-field-full"><label><?php echo Text::_('COM_DECAROFORMS_EMAIL_TEMPLATE'); ?></label><div class="df-email-templates">
        <button type="button" class="df-email-card" data-email-template="standard"><div class="df-email-preview"></div><b><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_STANDARD'); ?></b></button>
        <button type="button" class="df-email-card" data-email-template="minimal"><div class="df-email-preview"></div><b><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_MINIMAL'); ?></b></button>
        <button type="button" class="df-email-card" data-email-template="institutional"><div class="df-email-preview"></div><b><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_INSTITUTIONAL'); ?></b></button>
        <button type="button" class="df-email-card" data-email-template="card"><div class="df-email-preview"></div><b><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_CARD'); ?></b></button>
        <button type="button" class="df-email-card" data-email-template="compact"><div class="df-email-preview"></div><b><?php echo Text::_('COM_DECAROFORMS_TEMPLATE_COMPACT'); ?></b></button>
      </div><span class="df-note"><?php echo Text::_('COM_DECAROFORMS_EMAIL_PREVIEW_NOTE'); ?></span></div>
      <div class="df-field"><label><?php echo Text::_('COM_DECAROFORMS_ADMIN_TEMPLATE'); ?></label>'''
text, n = cards_pattern.subn(cards_html, text, count=1)
if n != 1:
    raise RuntimeError("missing patch target: email template cards")

modal_html = '''
    <div class="df-email-modal" id="df-email-modal" hidden>
      <div class="df-email-modal-backdrop" data-email-close></div>
      <div class="df-email-dialog" role="dialog" aria-modal="true" aria-labelledby="df-email-modal-title">
        <div class="df-email-modal-head"><div><h3 id="df-email-modal-title"><?php echo Text::_('COM_DECAROFORMS_EMAIL_PREVIEW'); ?></h3><span class="df-email-template-name" id="df-email-template-name"></span></div><button class="df-email-x" type="button" data-email-close aria-label="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_CLOSE'),ENT_QUOTES,'UTF-8'); ?>">×</button></div>
        <div class="df-email-modal-body">
          <div class="df-email-tabs"><button type="button" class="df-email-tab is-active" data-email-audience="admin"><?php echo Text::_('COM_DECAROFORMS_PREVIEW_ADMIN'); ?></button><button type="button" class="df-email-tab" data-email-audience="user"><?php echo Text::_('COM_DECAROFORMS_PREVIEW_USER'); ?></button></div>
          <div class="df-email-subject"><small><?php echo Text::_('COM_DECAROFORMS_EMAIL_PREVIEW_SUBJECT'); ?></small><strong id="df-email-preview-subject"></strong></div>
          <div class="df-email-canvas" id="df-email-preview-canvas"></div>
        </div>
        <div class="df-email-modal-actions"><button class="df-btn" type="button" data-email-close><?php echo Text::_('COM_DECAROFORMS_CLOSE'); ?></button><button class="df-btn df-primary" type="button" id="df-email-use-template"><?php echo Text::_('COM_DECAROFORMS_USE_TEMPLATE'); ?></button></div>
      </div>
    </div>
'''
text = replace_once(
    text,
    '    <div class="df-bactions" style="justify-content:flex-end">',
    modal_html + '\n    <div class="df-bactions" style="justify-content:flex-end">',
    "email preview modal markup",
)

preview_js = r'''
const emailModal=document.getElementById('df-email-modal'),emailCanvas=document.getElementById('df-email-preview-canvas'),emailSubject=document.getElementById('df-email-preview-subject'),emailTemplateName=document.getElementById('df-email-template-name'),emailUse=document.getElementById('df-email-use-template'),emailAdminSelect=document.querySelector('[name="email_template_admin"]'),emailUserSelect=document.querySelector('[name="email_template_user"]');
const emailTemplateNames=<?php echo json_encode(['standard'=>Text::_('COM_DECAROFORMS_TEMPLATE_STANDARD'),'minimal'=>Text::_('COM_DECAROFORMS_TEMPLATE_MINIMAL'),'institutional'=>Text::_('COM_DECAROFORMS_TEMPLATE_INSTITUTIONAL'),'card'=>Text::_('COM_DECAROFORMS_TEMPLATE_CARD'),'compact'=>Text::_('COM_DECAROFORMS_TEMPLATE_COMPACT')],JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;
const emailLabels=<?php echo json_encode(['yes'=>Text::_('JYES'),'selected'=>Text::_('COM_DECAROFORMS_TEMPLATE_SELECTED'),'use'=>Text::_('COM_DECAROFORMS_USE_TEMPLATE')],JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;
let emailTemplate='standard',emailAudience='admin';
function emailValue(field){const key=String(field.key||'').toLowerCase(),type=String(field.type||'text');const map={first_name:'Mario',last_name:'Rossi',full_name:'Mario Rossi',birth_date:'15/05/1990',email:'mario.rossi@example.com',phone:'+39 333 123 4567',address:'Via Roma',street_number:'10',postcode:'00100',city:'Roma',country:'Italia',organisation:'Organizzazione esempio',club:'Associazione esempio',role:'Referente',member_number:'12345',sport:'Pallavolo',team_name:'Squadra esempio',event_date:'15/09/2026',arrival_date:'15/09/2026',departure_date:'16/09/2026',participants:'2',subject:'Richiesta informazioni',message:'Questo è un testo di esempio inviato tramite il modulo.',notes:'Nota di esempio',motivation:'Testo di esempio.',attachment:'documento.pdf',identity_document:'documento-identita.pdf',photo:'foto.jpg',payment_proof:'ricevuta.pdf'};if(map[key])return map[key];if(Array.isArray(field.options)&&field.options.length)return String(field.options[0]);if(type==='consent')return emailLabels.yes;if(type==='file')return 'documento.pdf';if(type==='date')return '03/09/2026';if(type==='time')return '10:30';if(type==='number')return '1';if(type==='email')return 'mario.rossi@example.com';if(type==='tel')return '+39 333 123 4567';return 'Esempio';}
function emailRowsHtml(){return selected.map(field=>`<tr><td style="padding:8px 10px;border-bottom:1px solid #e6e9ed;color:#68717d;width:40%;font-size:13px">${esc(field.label||field.key)}</td><td style="padding:8px 10px;border-bottom:1px solid #e6e9ed;color:#17202a;font-weight:600;font-size:13px">${esc(emailValue(field))}</td></tr>`).join('')||'<tr><td style="padding:12px;color:#68717d">—</td></tr>';}
function emailCurrentSelect(){return emailAudience==='user'?emailUserSelect:emailAdminSelect;}
function emailMarkCards(){const active=emailCurrentSelect()?.value||'';document.querySelectorAll('[data-email-template]').forEach(card=>card.classList.toggle('is-active',card.dataset.emailTemplate===active));}
function emailRender(){const title=(document.querySelector('[name="title"]')?.value||'Modulo').trim()||'Modulo';const rawSubject=(emailAudience==='user'?document.querySelector('[name="email_subject_user"]')?.value:document.querySelector('[name="email_subject_admin"]')?.value)||'';const fallback=emailAudience==='user'?'Abbiamo ricevuto il tuo invio – {form_title}':'Nuovo invio – {form_title}';const subject=(rawSubject.trim()||fallback).replaceAll('{form_title}',title);const intro=emailAudience==='user'?`Abbiamo ricevuto correttamente il tuo invio per <strong>${esc(title)}</strong>.`:`È stato ricevuto un nuovo invio dal modulo <strong>${esc(title)}</strong>.`;const rows=emailRowsHtml(),ref='FRM-20260903-DEMO',accent='#e60046',dark='#182433';emailSubject.textContent=subject;emailTemplateName.textContent=emailTemplateNames[emailTemplate]||emailTemplate;let html='';if(emailTemplate==='minimal'){html=`<div style="max-width:680px;background:#fff;padding:24px;font-family:Arial,sans-serif;color:#17202a"><h2 style="margin:0 0 9px;font-size:22px">${esc(subject)}</h2><p style="margin:0 0 14px;line-height:1.55">${intro}</p><div style="margin-bottom:12px;font-size:12px;color:#68717d">Riferimento: <strong style="color:#17202a">${ref}</strong></div><table style="width:100%;border-collapse:collapse">${rows}</table></div>`;}else if(emailTemplate==='institutional'){html=`<div style="max-width:680px;background:#fff;font-family:Arial,sans-serif;color:#17202a"><div style="background:${dark};padding:22px 24px"><h2 style="margin:0;color:#fff;font-size:23px">${esc(subject)}</h2></div><div style="padding:20px 24px"><p style="margin:0 0 14px;line-height:1.55">${intro}</p><div style="padding:9px 11px;background:#f2f4f6;margin-bottom:12px;font-size:12px">Riferimento: <strong>${ref}</strong></div><table style="width:100%;border-collapse:collapse">${rows}</table></div></div>`;}else if(emailTemplate==='card'){html=`<div style="max-width:680px;background:#eef1f4;padding:22px;font-family:Arial,sans-serif;color:#17202a"><div style="background:#fff;border:1px solid #dfe3e8;border-radius:8px;padding:22px"><h2 style="margin:0 0 10px;color:${accent};font-size:23px">${esc(subject)}</h2><p style="margin:0 0 14px;line-height:1.55">${intro}</p><div style="padding:9px 11px;border:1px solid #e1e5e9;border-radius:5px;margin-bottom:12px;font-size:12px">Riferimento: <strong>${ref}</strong></div><table style="width:100%;border-collapse:collapse">${rows}</table></div></div>`;}else if(emailTemplate==='compact'){html=`<div style="max-width:620px;background:#fff;border-left:6px solid ${accent};padding:18px 20px;font-family:Arial,sans-serif;color:#17202a"><h2 style="margin:0 0 8px;font-size:20px">${esc(subject)}</h2><p style="margin:0 0 10px;line-height:1.45;font-size:13px">${intro}</p><div style="margin-bottom:9px;font-size:11px;color:#68717d">Riferimento: <strong>${ref}</strong></div><table style="width:100%;border-collapse:collapse">${rows}</table></div>`;}else{html=`<div style="max-width:680px;background:#fff;border-radius:6px;overflow:hidden;font-family:Arial,sans-serif;color:#17202a"><div style="height:8px;background:${accent}"></div><div style="padding:22px 24px"><h2 style="margin:0 0 10px;font-size:24px">${esc(subject)}</h2><p style="margin:0 0 14px;line-height:1.55">${intro}</p><div style="padding:9px 11px;background:#f2f4f6;border-radius:4px;margin-bottom:12px;font-size:12px">Riferimento: <strong>${ref}</strong></div><table style="width:100%;border-collapse:collapse">${rows}</table></div></div>`;}emailCanvas.innerHTML=html;emailMarkCards();emailUse.textContent=(emailCurrentSelect()?.value===emailTemplate)?emailLabels.selected:emailLabels.use;}
function emailOpen(template){emailTemplate=template||'standard';emailAudience='admin';document.querySelectorAll('[data-email-audience]').forEach(x=>x.classList.toggle('is-active',x.dataset.emailAudience===emailAudience));emailModal.hidden=false;document.body.style.overflow='hidden';emailRender();}
function emailClose(){emailModal.hidden=true;document.body.style.overflow='';}
document.querySelectorAll('[data-email-template]').forEach(card=>card.addEventListener('click',()=>emailOpen(card.dataset.emailTemplate)));
document.querySelectorAll('[data-email-close]').forEach(btn=>btn.addEventListener('click',emailClose));
document.querySelectorAll('[data-email-audience]').forEach(btn=>btn.addEventListener('click',()=>{emailAudience=btn.dataset.emailAudience||'admin';document.querySelectorAll('[data-email-audience]').forEach(x=>x.classList.toggle('is-active',x===btn));emailRender();}));
emailUse.addEventListener('click',()=>{const select=emailCurrentSelect();if(select){select.value=emailTemplate;select.dispatchEvent(new Event('change',{bubbles:true}));}emailRender();});
[emailAdminSelect,emailUserSelect,document.querySelector('[name="email_subject_admin"]'),document.querySelector('[name="email_subject_user"]'),document.querySelector('[name="title"]')].filter(Boolean).forEach(el=>el.addEventListener('input',()=>{if(!emailModal.hidden)emailRender();}));
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!emailModal.hidden)emailClose();});
'''
marker = "document.getElementById('df-add-status').onclick=()=>{statuses.push({key:'',label:''});renderStatuses();};"
text = replace_once(text, marker, preview_js + "\n" + marker, "email preview javascript")
builder_path.write_text(text, encoding="utf-8")

# Language labels: simple Italian terminology + complete translations for new UI.
translations = {
    "it-IT": {
        "COM_DECAROFORMS_MENU_DASHBOARD": "Riepilogo",
        "COM_DECAROFORMS_DASHBOARD": "Riepilogo",
        "COM_DECAROFORMS_MENU_IMPORT": "Importa dati",
        "COM_DECAROFORMS_IMPORT_TITLE": "Importa dati",
        "COM_DECAROFORMS_MENU_INFORMATION": "Guida",
        "COM_DECAROFORMS_INFORMATION": "Guida",
        "COM_DECAROFORMS_MENU_CREATE": "Nuovo modulo",
        "COM_DECAROFORMS_CREATE_FORM": "+ Nuovo modulo",
        "COM_DECAROFORMS_BACK_FORMS": "← Elenco moduli",
        "COM_DECAROFORMS_EDIT": "Modifica modulo",
        "COM_DECAROFORMS_OPEN_SUBMISSIONS": "Vedi invii",
        "COM_DECAROFORMS_LIST_COLUMNS": "Colonne della tabella",
        "COM_DECAROFORMS_LIST_COLUMNS_HELP": "Scegli le colonne da mostrare nella tabella degli invii.",
        "COM_DECAROFORMS_RECENT_DESC": "Ultimi invii e aggiornamenti dei moduli",
        "COM_DECAROFORMS_FORMS_LIST": "Elenco moduli",
        "COM_DECAROFORMS_TOTAL_SHORT": "Totale",
        "COM_DECAROFORMS_SEARCH": "Cerca",
        "COM_DECAROFORMS_FORM": "Modulo",
        "COM_DECAROFORMS_ALL_FORMS": "Tutti i moduli",
        "COM_DECAROFORMS_SHOW": "Mostra",
        "COM_DECAROFORMS_FILTER": "Filtra",
        "COM_DECAROFORMS_CLEAR": "Pulisci",
        "COM_DECAROFORMS_SEARCH_ALL": "Cerca riferimento, nome, email o dettagli",
        "COM_DECAROFORMS_SELECT_ALL": "Seleziona tutti",
        "COM_DECAROFORMS_DESELECT_ALL": "Deseleziona tutti",
        "COM_DECAROFORMS_SELECTED": "selezionati",
        "COM_DECAROFORMS_SELECT_SUBMISSION": "Seleziona invio",
        "COM_DECAROFORMS_EXPORT_SELECT_REQUIRED": "Seleziona almeno un invio da esportare.",
        "COM_DECAROFORMS_BACK_SUBMISSIONS": "Torna agli invii",
        "COM_DECAROFORMS_DOWNLOAD": "Scarica",
        "COM_DECAROFORMS_SUBMISSION_INFO": "Informazioni invio",
        "COM_DECAROFORMS_RECEIVED_AT": "Ricevuto il",
        "COM_DECAROFORMS_LAST_UPDATE": "Ultimo aggiornamento",
        "COM_DECAROFORMS_MANAGE_SUBMISSION": "Gestisci invio",
        "COM_DECAROFORMS_INTERNAL_NOTE_PLACEHOLDER": "Scrivi una nota interna...",
        "COM_DECAROFORMS_INTERNAL_NOTE_PRIVATE": "Questa nota non è mai visibile nel sito pubblico.",
        "COM_DECAROFORMS_SAVE_CLOSE": "Salva e chiudi",
        "COM_DECAROFORMS_EMAIL_PREVIEW": "Anteprima template",
        "COM_DECAROFORMS_PREVIEW_ADMIN": "Email amministratore",
        "COM_DECAROFORMS_PREVIEW_USER": "Email utente",
        "COM_DECAROFORMS_USE_TEMPLATE": "Usa questo template",
        "COM_DECAROFORMS_TEMPLATE_SELECTED": "Template selezionato",
        "COM_DECAROFORMS_CLOSE": "Chiudi",
        "COM_DECAROFORMS_EMAIL_PREVIEW_NOTE": "Clicca un template per vedere l'anteprima con i dati di esempio di questo modulo.",
        "COM_DECAROFORMS_EMAIL_PREVIEW_SUBJECT": "Oggetto",
    },
    "en-GB": {
        "COM_DECAROFORMS_RECENT_DESC": "Latest submissions and form updates",
        "COM_DECAROFORMS_FORMS_LIST": "Forms list",
        "COM_DECAROFORMS_TOTAL_SHORT": "Total",
        "COM_DECAROFORMS_SEARCH": "Search",
        "COM_DECAROFORMS_FORM": "Form",
        "COM_DECAROFORMS_ALL_FORMS": "All forms",
        "COM_DECAROFORMS_SHOW": "Show",
        "COM_DECAROFORMS_FILTER": "Filter",
        "COM_DECAROFORMS_CLEAR": "Clear",
        "COM_DECAROFORMS_SEARCH_ALL": "Search reference, name, email or details",
        "COM_DECAROFORMS_SELECT_ALL": "Select all",
        "COM_DECAROFORMS_DESELECT_ALL": "Deselect all",
        "COM_DECAROFORMS_SELECTED": "selected",
        "COM_DECAROFORMS_SELECT_SUBMISSION": "Select submission",
        "COM_DECAROFORMS_EXPORT_SELECT_REQUIRED": "Select at least one submission to export.",
        "COM_DECAROFORMS_BACK_SUBMISSIONS": "Back to submissions",
        "COM_DECAROFORMS_DOWNLOAD": "Download",
        "COM_DECAROFORMS_SUBMISSION_INFO": "Submission information",
        "COM_DECAROFORMS_RECEIVED_AT": "Received at",
        "COM_DECAROFORMS_LAST_UPDATE": "Last update",
        "COM_DECAROFORMS_MANAGE_SUBMISSION": "Manage submission",
        "COM_DECAROFORMS_INTERNAL_NOTE_PLACEHOLDER": "Write an internal note...",
        "COM_DECAROFORMS_INTERNAL_NOTE_PRIVATE": "This note is never visible on the public website.",
        "COM_DECAROFORMS_SAVE_CLOSE": "Save and close",
        "COM_DECAROFORMS_EMAIL_PREVIEW": "Template preview",
        "COM_DECAROFORMS_PREVIEW_ADMIN": "Administrator email",
        "COM_DECAROFORMS_PREVIEW_USER": "User email",
        "COM_DECAROFORMS_USE_TEMPLATE": "Use this template",
        "COM_DECAROFORMS_TEMPLATE_SELECTED": "Template selected",
        "COM_DECAROFORMS_CLOSE": "Close",
        "COM_DECAROFORMS_EMAIL_PREVIEW_NOTE": "Click a template to preview it with sample data from this form.",
        "COM_DECAROFORMS_EMAIL_PREVIEW_SUBJECT": "Subject",
    },
    "fr-FR": {
        "COM_DECAROFORMS_RECENT_DESC": "Derniers envois et mises à jour des formulaires",
        "COM_DECAROFORMS_FORMS_LIST": "Liste des formulaires",
        "COM_DECAROFORMS_TOTAL_SHORT": "Total",
        "COM_DECAROFORMS_SEARCH": "Rechercher",
        "COM_DECAROFORMS_FORM": "Formulaire",
        "COM_DECAROFORMS_ALL_FORMS": "Tous les formulaires",
        "COM_DECAROFORMS_SHOW": "Afficher",
        "COM_DECAROFORMS_FILTER": "Filtrer",
        "COM_DECAROFORMS_CLEAR": "Effacer",
        "COM_DECAROFORMS_SEARCH_ALL": "Rechercher une référence, un nom, un e-mail ou des détails",
        "COM_DECAROFORMS_SELECT_ALL": "Tout sélectionner",
        "COM_DECAROFORMS_DESELECT_ALL": "Tout désélectionner",
        "COM_DECAROFORMS_SELECTED": "sélectionnés",
        "COM_DECAROFORMS_SELECT_SUBMISSION": "Sélectionner l'envoi",
        "COM_DECAROFORMS_EXPORT_SELECT_REQUIRED": "Sélectionnez au moins un envoi à exporter.",
        "COM_DECAROFORMS_BACK_SUBMISSIONS": "Retour aux envois",
        "COM_DECAROFORMS_DOWNLOAD": "Télécharger",
        "COM_DECAROFORMS_SUBMISSION_INFO": "Informations sur l'envoi",
        "COM_DECAROFORMS_RECEIVED_AT": "Reçu le",
        "COM_DECAROFORMS_LAST_UPDATE": "Dernière mise à jour",
        "COM_DECAROFORMS_MANAGE_SUBMISSION": "Gérer l'envoi",
        "COM_DECAROFORMS_INTERNAL_NOTE_PLACEHOLDER": "Écrire une note interne...",
        "COM_DECAROFORMS_INTERNAL_NOTE_PRIVATE": "Cette note n'est jamais visible sur le site public.",
        "COM_DECAROFORMS_SAVE_CLOSE": "Enregistrer et fermer",
        "COM_DECAROFORMS_EMAIL_PREVIEW": "Aperçu du modèle",
        "COM_DECAROFORMS_PREVIEW_ADMIN": "E-mail administrateur",
        "COM_DECAROFORMS_PREVIEW_USER": "E-mail utilisateur",
        "COM_DECAROFORMS_USE_TEMPLATE": "Utiliser ce modèle",
        "COM_DECAROFORMS_TEMPLATE_SELECTED": "Modèle sélectionné",
        "COM_DECAROFORMS_CLOSE": "Fermer",
        "COM_DECAROFORMS_EMAIL_PREVIEW_NOTE": "Cliquez sur un modèle pour l'afficher avec des données d'exemple de ce formulaire.",
        "COM_DECAROFORMS_EMAIL_PREVIEW_SUBJECT": "Objet",
    },
}
for tag, entries in translations.items():
    lang_dir = component / f"administrator/components/com_decaroforms/language/{tag}"
    for filename in ("com_decaroforms.ini", "com_decaroforms.sys.ini"):
        path = lang_dir / filename
        for key, value in entries.items():
            set_ini(path, key, value)

# Ensure relevant English/French main navigation still has simple explicit wording.
for tag, replacements in {
    "en-GB": {
        "COM_DECAROFORMS_MENU_DASHBOARD": "Overview", "COM_DECAROFORMS_DASHBOARD": "Overview",
        "COM_DECAROFORMS_MENU_IMPORT": "Import data", "COM_DECAROFORMS_IMPORT_TITLE": "Import data",
        "COM_DECAROFORMS_MENU_INFORMATION": "Help", "COM_DECAROFORMS_INFORMATION": "Help",
        "COM_DECAROFORMS_MENU_CREATE": "New form", "COM_DECAROFORMS_CREATE_FORM": "+ New form",
        "COM_DECAROFORMS_BACK_FORMS": "← Forms list", "COM_DECAROFORMS_EDIT": "Edit form", "COM_DECAROFORMS_OPEN_SUBMISSIONS": "View submissions",
        "COM_DECAROFORMS_LIST_COLUMNS": "Table columns", "COM_DECAROFORMS_LIST_COLUMNS_HELP": "Choose the columns shown in the submissions table.",
    },
    "fr-FR": {
        "COM_DECAROFORMS_MENU_DASHBOARD": "Vue d'ensemble", "COM_DECAROFORMS_DASHBOARD": "Vue d'ensemble",
        "COM_DECAROFORMS_MENU_IMPORT": "Importer des données", "COM_DECAROFORMS_IMPORT_TITLE": "Importer des données",
        "COM_DECAROFORMS_MENU_INFORMATION": "Aide", "COM_DECAROFORMS_INFORMATION": "Aide",
        "COM_DECAROFORMS_MENU_CREATE": "Nouveau formulaire", "COM_DECAROFORMS_CREATE_FORM": "+ Nouveau formulaire",
        "COM_DECAROFORMS_BACK_FORMS": "← Liste des formulaires", "COM_DECAROFORMS_EDIT": "Modifier le formulaire", "COM_DECAROFORMS_OPEN_SUBMISSIONS": "Voir les envois",
        "COM_DECAROFORMS_LIST_COLUMNS": "Colonnes du tableau", "COM_DECAROFORMS_LIST_COLUMNS_HELP": "Choisissez les colonnes affichées dans le tableau des envois.",
    },
}.items():
    lang_dir = component / f"administrator/components/com_decaroforms/language/{tag}"
    for filename in ("com_decaroforms.ini", "com_decaroforms.sys.ini"):
        for key, value in replacements.items():
            set_ini(lang_dir / filename, key, value)

# Component, plugin and package versions.
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
ot = ot.replace("com_decaroforms_1.2.1.zip", f"com_decaroforms_{VERSION}.zip")
ot = ot.replace("plg_system_decaroforms_1.2.1.zip", f"plg_system_decaroforms_{VERSION}.zip")
package_manifest.write_text(ot, encoding="utf-8")

print(f"Forms patch {VERSION} applied")
