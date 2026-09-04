#!/usr/bin/env python3
from pathlib import Path
import re
import sys

if len(sys.argv) != 3:
    raise SystemExit('usage: patch.py COMPONENT_ROOT PLUGIN_ROOT')

comp = Path(sys.argv[1])
plug = Path(sys.argv[2])
builder = comp / 'administrator/components/com_decaroforms/tmpl/builder/default.php'
helper = comp / 'administrator/components/com_decaroforms/src/Helper/FormHelper.php'
controller = comp / 'administrator/components/com_decaroforms/src/Controller/BuilderController.php'
renderer = plug / 'src/Extension/FormsPlugin.php'

t = builder.read_text()
h = helper.read_text()
c = controller.read_text()
p = renderer.read_text()

def replace_once(text, old, new, label):
    if old not in text:
        raise RuntimeError(f'{label} not found')
    return text.replace(old, new, 1)

# Version metadata.
h = replace_once(h, "public const VERSION = '1.3.13';", "public const VERSION = '1.3.14';", 'helper version')
for manifest in (comp / 'com_decaroforms.xml', plug / 'decaroforms.xml'):
    value = manifest.read_text()
    value = replace_once(value, '<version>1.3.13</version>', '<version>1.3.14</version>', str(manifest))
    manifest.write_text(value)

# Province and dedicated Italian tax-code fields.
h = replace_once(h,
    "['key'=>'tax_code','type'=>'text','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_TAX_CODE'),'placeholder'=>'','required'=>false],",
    "['key'=>'tax_code','type'=>'tax_code','category'=>'personal','label'=>Text::_('COM_DECAROFORMS_FIELD_TAX_CODE'),'placeholder'=>'RSSMRA80A01H501U','required'=>true,'config'=>['uppercase'=>true,'max_length'=>16,'verify_links'=>true,'links'=>[]]],",
    'tax code library field')
h = replace_once(h,
    "['key'=>'city','type'=>'city','category'=>'address','label'=>Text::_('COM_DECAROFORMS_FIELD_CITY'),'placeholder'=>'','required'=>false,'options'=>[]],",
    "['key'=>'city','type'=>'city','category'=>'address','label'=>Text::_('COM_DECAROFORMS_FIELD_CITY'),'placeholder'=>'','required'=>false,'options'=>[]],\n            ['key'=>'province','type'=>'province','category'=>'address','label'=>'Provincia','placeholder'=>'Roma (RM)','required'=>false,'config'=>['display_format'=>'name_code']],",
    'province library field')
h = h.replace("'iban'=>'','holder'=>'','amount'=>'','cause'", "'iban'=>'','bic'=>'','bank_country'=>'IT','holder'=>'','amount'=>'','cause'", 1)
h = h.replace("'postcode'=>'COM_DECAROFORMS_FIELD_POSTCODE','city'=>'COM_DECAROFORMS_FIELD_CITY','region'", "'postcode'=>'COM_DECAROFORMS_FIELD_POSTCODE','city'=>'COM_DECAROFORMS_FIELD_CITY','province'=>'COM_DECAROFORMS_FIELD_PROVINCE','region'", 1)

allowed_old = "'nationality','country','region','city','postcode','member_number'"
allowed_new = "'nationality','country','region','city','province','postcode','member_number','tax_code'"
c = replace_once(c, allowed_old, allowed_new, 'builder allowed field types')

# Public rendering and server-side validation.
p = p.replace("'postcode'=>'COM_DECAROFORMS_FIELD_POSTCODE','city'=>'COM_DECAROFORMS_FIELD_CITY','region'", "'postcode'=>'COM_DECAROFORMS_FIELD_POSTCODE','city'=>'COM_DECAROFORMS_FIELD_CITY','province'=>'COM_DECAROFORMS_FIELD_PROVINCE','region'", 1)
p = replace_once(p,
    "        } elseif ($type === 'postcode') {\n            $html .= '<label for=\"' . $id . '\">' . $label . $star . '</label><input id=\"' . $id . '\" type=\"text\" inputmode=\"numeric\" pattern=\"[0-9]{5}\" maxlength=\"5\" name=\"' . $name . '\" value=\"' . $value . '\" placeholder=\"' . $placeholder . '\"' . $reqAttr . '>';",
    "        } elseif ($type === 'province') {\n            $format = (string) ($cfg['display_format'] ?? 'name_code');\n            $attrs = $format === 'code' ? ' maxlength=\"2\" pattern=\"[A-Za-z]{2}\" style=\"text-transform:uppercase\"' : '';\n            $html .= '<label for=\"' . $id . '\">' . $label . $star . '</label><input id=\"' . $id . '\" type=\"text\" name=\"' . $name . '\" value=\"' . $value . '\" placeholder=\"' . $placeholder . '\"' . $attrs . $reqAttr . '>';\n        } elseif ($type === 'tax_code') {\n            $html .= '<label for=\"' . $id . '\">' . $label . $star . '</label><input id=\"' . $id . '\" type=\"text\" name=\"' . $name . '\" value=\"' . $value . '\" placeholder=\"' . $placeholder . '\" maxlength=\"16\" minlength=\"16\" pattern=\"[A-Za-z0-9]{16}\" autocomplete=\"off\" style=\"text-transform:uppercase\"' . $reqAttr . '>';\n        } elseif ($type === 'postcode') {\n            $html .= '<label for=\"' . $id . '\">' . $label . $star . '</label><input id=\"' . $id . '\" type=\"text\" inputmode=\"numeric\" pattern=\"[0-9]{5}\" maxlength=\"5\" name=\"' . $name . '\" value=\"' . $value . '\" placeholder=\"' . $placeholder . '\"' . $reqAttr . '>';",
    'public province/tax renderer')
p = p.replace("$iban = htmlspecialchars((string) ($cfg['iban'] ?? ''), ENT_QUOTES, 'UTF-8'); $holder", "$iban = htmlspecialchars((string) ($cfg['iban'] ?? ''), ENT_QUOTES, 'UTF-8'); $bic = htmlspecialchars((string) ($cfg['bic'] ?? ''), ENT_QUOTES, 'UTF-8'); $bankCountry = htmlspecialchars((string) ($cfg['bank_country'] ?? ''), ENT_QUOTES, 'UTF-8'); $holder", 1)
p = p.replace("($iban !== '' ? '<div>IBAN: <code>' . $iban . '</code></div>' : '') . ($amount", "($iban !== '' ? '<div>IBAN: <code>' . $iban . '</code></div>' : '') . ($bic !== '' ? '<div>BIC/SWIFT: <code>' . $bic . '</code></div>' : '') . ($bankCountry !== '' ? '<div>Paese banca: ' . $bankCountry . '</div>' : '') . ($amount", 1)

postcode_validation = """            if ($type === 'postcode' && $value !== '' && (!is_string($value) || !preg_match('/^\\d{5}$/', $value))) {
                return ['success'=>false,'message'=>Text::_('PLG_SYSTEM_DECAROFORMS_INVALID_POSTCODE')];
            }
"""
tax_validation = postcode_validation + """            if ($type === 'tax_code' && $value !== '') {
                $code = strtoupper(preg_replace('/\\s+/', '', (string) $value));
                if (!preg_match('/^[A-Z]{6}[0-9]{2}[A-EHLMPRST][0-9]{2}[A-Z][0-9]{3}[A-Z]$/', $code)) {
                    return ['success'=>false,'message'=>Text::sprintf('PLG_SYSTEM_DECAROFORMS_INVALID_FIELD', $this->localizedFieldLabel($field))];
                }
                $odd = ['0'=>1,'1'=>0,'2'=>5,'3'=>7,'4'=>9,'5'=>13,'6'=>15,'7'=>17,'8'=>19,'9'=>21,'A'=>1,'B'=>0,'C'=>5,'D'=>7,'E'=>9,'F'=>13,'G'=>15,'H'=>17,'I'=>19,'J'=>21,'K'=>2,'L'=>4,'M'=>18,'N'=>20,'O'=>11,'P'=>3,'Q'=>6,'R'=>8,'S'=>12,'T'=>14,'U'=>16,'V'=>10,'W'=>22,'X'=>25,'Y'=>24,'Z'=>23];
                $even = array_combine(array_merge(range('0','9'), range('A','Z')), array_merge(range(0,9), range(0,25)));
                $sum = 0;
                for ($pos = 0; $pos < 15; $pos++) { $sum += ($pos % 2 === 0) ? $odd[$code[$pos]] : $even[$code[$pos]]; }
                if (chr(65 + ($sum % 26)) !== $code[15]) {
                    return ['success'=>false,'message'=>Text::sprintf('PLG_SYSTEM_DECAROFORMS_INVALID_FIELD', $this->localizedFieldLabel($field))];
                }
                $value = $code;
            }
"""
p = replace_once(p, postcode_validation, tax_validation, 'tax code validation')

# Remove conflicting manual layout controls; the canvas is the single source of truth.
t, count = re.subn(r'\n\s*<details class="df-layout-advanced-box">.*?</details>', '', t, count=1, flags=re.S)
if count != 1:
    raise RuntimeError('canvas advanced layout box not found')
t = replace_once(t, '<button class="df-add-field-main" type="button" id="df-open-library"><span aria-hidden="true">＋</span> Aggiungi campo</button>', '''<button class="df-add-field-main" type="button" id="df-open-library"><span aria-hidden="true">＋</span> Aggiungi campo</button>
            <div hidden aria-hidden="true"><select id="df-layout-columns"><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option></select><span id="df-layout-total"></span><div id="df-layout-widths"></div><button type="button" id="df-layout-apply">Applica</button></div>''', 'hidden legacy layout state')

# Clearer section terminology.
t = t.replace("<strong>5. <?php echo Text::_('COM_DECAROFORMS_SECTION_SUBMISSIONS'); ?></strong>", '<strong>5. Stati e visualizzazione</strong>', 1)
t = t.replace("<h4><?php echo Text::_('COM_DECAROFORMS_FORM_STATUSES'); ?></h4>", '<h4>Stati degli invii</h4>', 1)
t = t.replace("<h4><?php echo Text::_('COM_DECAROFORMS_TABLE_COLUMNS'); ?></h4>", '<h4>Colonne dell’elenco</h4>', 1)

# Global edit safety and history toolbar.
toolbar = '''
  <div class="df-editor-toolbar" role="toolbar" aria-label="Modifica modulo">
    <div class="df-history-actions"><button type="button" id="df-undo" title="Annulla ultima modifica" disabled>↶ Annulla</button><button type="button" id="df-redo" title="Ripristina modifica" disabled>↷ Ripristina</button></div>
    <div class="df-edit-mode" aria-label="Modalità modifica"><button type="button" class="df-lock-toggle" data-lock="1">🔒 Bloccato</button><button type="button" class="df-lock-toggle" data-lock="0">✏️ Modifica</button></div>
  </div>
'''
t = replace_once(t, '  <form method="post" action="<?php echo $this->saveUrl; ?>" id="df-builder-form">', toolbar + '\n  <form method="post" action="<?php echo $this->saveUrl; ?>" id="df-builder-form">', 'builder form toolbar')

css = r'''
/* Forms 1.3.14: balanced rows, safer editing and clearer controls. */
.df-editor-toolbar{position:sticky;top:0;z-index:40;display:flex;align-items:center;justify-content:space-between;gap:10px;margin:0 0 12px;padding:8px;border:1px solid var(--df-border);border-radius:8px;background:color-mix(in srgb,var(--bs-body-bg,#fff) 94%,transparent);backdrop-filter:blur(7px)}
.df-editor-toolbar button{min-height:34px;padding:6px 11px;border:1px solid var(--df-border);background:var(--bs-body-bg,#fff);color:inherit;font-weight:750;cursor:pointer}.df-editor-toolbar button:first-child{border-radius:6px 0 0 6px}.df-editor-toolbar button:last-child{border-radius:0 6px 6px 0}.df-editor-toolbar button:disabled{opacity:.42;cursor:not-allowed}.df-history-actions,.df-edit-mode{display:flex}.df-lock-toggle.is-active{background:#26364a;color:#fff;border-color:#26364a}
.df-builder.is-locked #df-builder-form input:not([type=hidden]),.df-builder.is-locked #df-builder-form select,.df-builder.is-locked #df-builder-form textarea{opacity:.72}.df-builder.is-locked .df-layout-handle{cursor:not-allowed}.df-builder.is-locked .df-layout-card{box-shadow:none}
.df-required-badge{display:inline-flex;align-items:center;padding:3px 7px;border-radius:999px;background:#fee4e8;color:#c5003c;font-size:10px;font-weight:850;white-space:nowrap}.df-summary-chip.df-required-badge{border-color:#f5a3ba;background:#fee4e8;color:#b90038}
.df-canvas-remove{color:#b42318!important}.df-main-settings,.df-condition-details,.df-tax-links{border:1px solid var(--df-border);border-radius:6px;background:color-mix(in srgb,var(--bs-tertiary-bg,#f7f8fa) 45%,transparent)}.df-main-settings>summary,.df-condition-details>summary,.df-tax-links>summary{cursor:pointer;padding:10px 11px;color:#2869b2;font-weight:800}.df-main-settings-body,.df-condition-body,.df-tax-links-body{padding:0 11px 11px}.df-main-settings-grid{display:grid;gap:8px}.df-condition-controls{display:grid;grid-template-columns:1fr;gap:8px;margin-top:8px}.df-condition-details .df-condition-row{grid-template-columns:1fr}.df-condition-details [data-add-condition]{margin-top:9px}
.df-status-row{grid-template-columns:minmax(0,1fr) 110px 34px}.df-status-row.is-conflict input[data-status-label]{border-color:#dc3545;box-shadow:0 0 0 2px rgba(220,53,69,.12)}.df-status-warning{margin:8px 0;padding:8px 10px;border:1px solid #dc3545;border-radius:6px;background:#fff1f3;color:#a40024;font-weight:700}
.df-email-templates{grid-template-columns:repeat(6,minmax(0,1fr))!important}.df-email-thumb{width:100%;height:105px;padding:0!important;background:#eef1f5!important;border:0!important}.df-email-thumb-frame{display:block;width:500%;height:525px;border:0;transform:scale(.2);transform-origin:top left;pointer-events:none;background:#fff}.df-email-choice-foot{justify-content:flex-start}.df-email-preview-btn{display:none!important}.df-email-preview-label{opacity:0!important}.df-email-thumb:hover .df-email-preview-label,.df-email-thumb:focus-visible .df-email-preview-label{opacity:1!important}
@media(max-width:900px){.df-email-templates{grid-template-columns:repeat(3,minmax(0,1fr))!important}.df-email-thumb{height:120px}.df-email-thumb-frame{transform:scale(.2)}}
@media(max-width:560px){.df-editor-toolbar{align-items:stretch;flex-direction:column}.df-editor-toolbar>div{display:grid;grid-template-columns:1fr 1fr}.df-email-templates{grid-template-columns:1fr!important}.df-email-thumb{height:150px}.df-email-thumb-frame{transform:scale(.25)}}
'''
t = replace_once(t, '</style>', css + '\n</style>', 'style end')

# Add new types and 12 email template choices.
t = t.replace("'city'=>Text::_('COM_DECAROFORMS_FIELD_CITY'),'postcode'", "'city'=>Text::_('COM_DECAROFORMS_FIELD_CITY'),'province'=>'Provincia','tax_code'=>'Codice fiscale','postcode'", 1)
t = t.replace("</label><input data-cfg=\"iban\" value=\"${esc(c.iban||'')}\"></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_ACCOUNT_HOLDER')); ?>", "</label><input data-cfg=\"iban\" value=\"${esc(c.iban||'')}\"></div><div><label>BIC / SWIFT</label><input data-cfg=\"bic\" value=\"${esc(c.bic||'')}\" placeholder=\"BCITITMM\"></div><div><label>Paese banca</label><input data-cfg=\"bank_country\" value=\"${esc(c.bank_country||'IT')}\" placeholder=\"IT\"></div><div><label><?php echo addslashes(Text::_('COM_DECAROFORMS_ACCOUNT_HOLDER')); ?>", 1)
t = re.sub(r"const templateDefs=\[.*?\];", "const templateDefs=[['standard','Standard'],['minimal','Minimal'],['institutional','Istituzionale'],['card','Scheda'],['compact','Compatto'],['modern','Moderno'],['elegant','Elegante'],['receipt','Ricevuta'],['professional','Professionale'],['custom','Personalizzato'],['html','HTML libero'],['chatgpt','AI']];", t, count=1)

# History is recorded from the shared sync point, including ordinary form inputs.
old_sync = re.search(r"function sync\(\)\{.*?\}\nfunction uniqueKey", t, re.S)
if not old_sync:
    raise RuntimeError('sync function not found')
new_sync = r'''let historyStates=[],historyIndex=-1,historyReady=false,historyApplying=false,historyTimer=null,initialHistorySignature='';
function simpleFormState(){return [...document.querySelectorAll('#df-builder-form [name]:not([type="hidden"])')].map(el=>({name:el.name,type:el.type,value:el.type==='checkbox'||el.type==='radio'?!!el.checked:el.value}));}
function captureHistoryState(){return {selected:clone(selected),statuses:clone(statuses),columns:clone(columns),builderConfig:clone(builderConfig),emailConfig:clone(emailConfig),additionalEmails:clone(additionalEmails),integrations:clone(integrations),activeFieldKey,form:simpleFormState()};}
function historySignature(state){return JSON.stringify(state);}
function updateHistoryButtons(){const locked=document.querySelector('.df-builder')?.classList.contains('is-locked');document.getElementById('df-undo').disabled=locked||historyIndex<=0;document.getElementById('df-redo').disabled=locked||historyIndex<0||historyIndex>=historyStates.length-1;}
function pushHistory(){if(!historyReady||historyApplying)return;const state=captureHistoryState(),sig=historySignature(state);if(historyIndex>=0&&historySignature(historyStates[historyIndex])===sig)return;historyStates=historyStates.slice(0,historyIndex+1);historyStates.push(state);if(historyStates.length>50)historyStates.shift();historyIndex=historyStates.length-1;updateHistoryButtons();}
function scheduleHistory(){if(!historyReady||historyApplying)return;clearTimeout(historyTimer);historyTimer=setTimeout(pushHistory,300);}
function restoreHistory(index){if(index<0||index>=historyStates.length)return;historyApplying=true;const s=clone(historyStates[index]);selected=s.selected;statuses=s.statuses;columns=s.columns;builderConfig=s.builderConfig;emailConfig=s.emailConfig;additionalEmails=s.additionalEmails;integrations=s.integrations;activeFieldKey=s.activeFieldKey;renderSelected();renderLayout();renderStatuses();renderColumns();renderTokens();renderUserEmailFields();renderEmailPickers();renderAdditional();const controls=[...document.querySelectorAll('#df-builder-form [name]:not([type="hidden"])')];(s.form||[]).forEach((v,i)=>{const el=controls[i];if(el&&el.name===v.name){if(el.type==='checkbox'||el.type==='radio')el.checked=!!v.value;else el.value=v.value;}});historyIndex=index;sync();historyApplying=false;applyLockState();updateHistoryButtons();}
function sync(){hidden.fields.value=JSON.stringify(selected);hidden.statuses.value=JSON.stringify(statuses.map(({_new,...st})=>st));hidden.columns.value=JSON.stringify(columns);hidden.builder.value=JSON.stringify(builderConfig);hidden.email.value=JSON.stringify(emailConfig);hidden.additional.value=JSON.stringify(additionalEmails);hidden.integrations.value=JSON.stringify(integrations);document.getElementById('df-legacy-admin-template').value=emailConfig.admin.template||'standard';document.getElementById('df-legacy-user-template').value=emailConfig.user.template||'standard';scheduleHistory();queueMicrotask(applyLockState);}
function uniqueKey'''
t = t[:old_sync.start()] + new_sync + t[old_sync.end():]
t = t.replace("function uniqueKey(base){base=String(base||'field').replace(/[^a-zA-Z0-9_]+/g,'_').replace(/^_+|_+$/g,'').toLowerCase()||'field';let k=base,n=2;while(selected.some(x=>x.key===k))k=base+'_'+n++;return k;}", "function uniqueKey(base,ignoreKey=''){base=String(base||'field').replace(/[^a-zA-Z0-9_]+/g,'_').replace(/^_+|_+$/g,'').toLowerCase()||'field';let k=base,n=2;while(selected.some(x=>x.key===k&&x.key!==ignoreKey))k=base+'_'+n++;return k;}", 1)

# Automatically repair old invalid rows (e.g. 50 + 100) and keep every row at 100.
t = replace_once(t, 'selected=selected.map(defaultFieldConfig);', '''selected=selected.map(defaultFieldConfig);
function fieldsInRow(row){return selected.map((f,i)=>[f,i]).filter(([f])=>Number(f.config?.layout?.row||1)===Number(row)).sort(([a],[b])=>(a.config.layout.col||1)-(b.config.layout.col||1));}
function distributeRow(row){const items=fieldsInRow(row),n=items.length;if(!n)return;const base=Math.floor(100/n),extra=100-base*n;items.forEach(([f],i)=>{f.config.layout.width=base+(i<extra?1:0);f.config.layout.col=i+1;});}
function repairInvalidRows(){[...new Set(selected.map(f=>Number(f.config.layout.row||1)))].forEach(row=>{const items=fieldsInRow(row),total=items.reduce((sum,[f])=>sum+Number(f.config.layout.width||0),0);if(total!==100)distributeRow(row);});}
repairInvalidRows();''', 'initial layout repair')

# Field-specific settings for province and tax-code mapping.
insert_before_member = "if(t==='member_number'){"
extra_config = r'''if(t==='province'){h+=`<div class="df-config-panel"><label>Formato provincia</label><select data-cfg="display_format"><option value="name_code" ${c.display_format==='name_code'||!c.display_format?'selected':''}>Nome e sigla — Roma (RM)</option><option value="name" ${c.display_format==='name'?'selected':''}>Solo nome — Roma</option><option value="code" ${c.display_format==='code'?'selected':''}>Solo sigla — RM</option></select></div>`;}
if(t==='tax_code'){const linkNames=[['first_name','Nome'],['last_name','Cognome'],['birth_date','Data di nascita'],['gender','Sesso'],['birth_city','Comune di nascita'],['birth_country','Stato estero'],['birth_province','Provincia di nascita']];c.links=c.links||{};const opts=(role,current)=>`<option value="">Campo non collegato — Aggiungi campo</option>`+selected.filter(f=>f.key!==x.key).map(f=>`<option value="${esc(f.key)}" ${current===f.key?'selected':''}>${esc(f.label)} (${esc(f.key)})</option>`).join('');h+=`<details class="df-tax-links"><summary>Verifica codice fiscale</summary><div class="df-tax-links-body"><p class="df-note">Collega i dati già presenti per verificare la coerenza. Il codice resta quello dichiarato dall’utente.</p>${linkNames.map(([role,label])=>`<div class="df-field"><label>${label}</label><select data-tax-link="${role}">${opts(role,c.links[role]||'')}</select></div>`).join('')}<div class="df-tax-conflict" hidden></div></div></details>`;}
'''
t = replace_once(t, insert_before_member, extra_config + insert_before_member, 'province/tax configuration')

# Conditions: vertical controls, rules, then add button.
cond_match = re.search(r"function renderConditions\(x,i\)\{.*?\}\nfunction renderSelected", t, re.S)
if not cond_match:
    raise RuntimeError('conditions renderer not found')
new_conditions = r'''function renderConditions(x,i){const c=x.config||{},rules=Array.isArray(c.conditions)?c.conditions:[];const rows=rules.map((r,ri)=>`<div class="df-condition-row"><select data-cond-field="${ri}"><option value="">— Campo —</option>${fieldSelectOptions(r.field||'')}</select><select data-cond-op="${ri}">${[['eq','='],['neq','≠'],['contains','contiene'],['not_contains','non contiene'],['empty','vuoto'],['not_empty','non vuoto'],['gt','>'],['lt','<'],['checked','selezionato'],['not_checked','non selezionato']].map(([v,l])=>`<option value="${v}" ${r.operator===v?'selected':''}>${l}</option>`).join('')}</select><input data-cond-value="${ri}" value="${esc(r.value||'')}" placeholder="Valore"><button type="button" data-cond-remove="${ri}">🗑 Elimina condizione</button></div>`).join('');return `<details class="df-condition-details"><summary>${esc(tr.conditions)} <span class="df-note">${rules.length?rules.length+' regola'+(rules.length===1?'':'e'):''}</span></summary><div class="df-condition-body"><p class="df-note">Mostra, nascondi o rendi obbligatorio questo campo in base ad altri valori.</p><div class="df-condition-controls"><div><label>Azione</label><select data-cfg="condition_action"><option value="show" ${c.condition_action==='show'?'selected':''}>Mostra</option><option value="hide" ${c.condition_action==='hide'?'selected':''}>Nascondi</option><option value="require" ${c.condition_action==='require'?'selected':''}>Rendi obbligatorio</option><option value="disable" ${c.condition_action==='disable'?'selected':''}>Disabilita</option></select></div><div><label>Applica le condizioni</label><select data-cfg="condition_logic"><option value="all" ${c.condition_logic!=='any'?'selected':''}>${esc(tr.all)}</option><option value="any" ${c.condition_logic==='any'?'selected':''}>${esc(tr.any)}</option></select></div></div><div class="df-condition-list">${rows||`<div class="df-note">Nessuna condizione configurata.</div>`}</div><button class="df-btn df-small" type="button" data-add-condition>+ ${esc(tr.addCondition)}</button></div></details>`;}
function renderSelected'''
t = t[:cond_match.start()] + new_conditions + t[cond_match.end():]

# Required badges, main-settings accordion and no manual-layout duplicate.
t = t.replace("const req=x.required?'<span class=\"df-summary-chip\">Obbligatorio</span>':'';", "const req=x.required?'<span class=\"df-summary-chip df-required-badge\">Obbligatorio</span>':'';", 1)
main_fields = '''<div><label>${esc(tr.label)}</label><input data-k="label" value="${esc(x.label)}"></div><div><label>${esc(tr.key)}</label><input data-k="key" value="${esc(x.key)}"></div><div><label>${esc(tr.type)}</label><select data-k="type">${types.map(t=>`<option value="${t}" ${x.type===t?'selected':''}>${esc(tr.types[t]||t)}</option>`).join('')}</select></div><div><label>${esc(tr.placeholder)}</label><input data-k="placeholder" value="${esc(x.placeholder||'')}"></div><div><label>${esc(tr.default)}</label><input data-k="default" value="${esc(x.default||'')}"></div><div><label>${esc(tr.help)}</label><input data-k="help" value="${esc(x.help||'')}"></div>'''
main_accordion = '''<details class="full df-main-settings" open><summary>Impostazioni principali</summary><div class="df-main-settings-body"><div class="df-main-settings-grid">''' + main_fields + '''</div></div></details>'''
t = replace_once(t, main_fields, main_accordion, 'main field settings')
t, count = re.subn(r'<details class="df-field-advanced"><summary>Layout manuale avanzato</summary>.*?</details>', '', t, count=1, flags=re.S)
if count != 1:
    raise RuntimeError('field manual layout accordion not found')
t = t.replace("${[100,75,66,50,33,25].map", "${[100,75,66,60,50,40,33,25].map", 1)
t = t.replace("x.config.layout.width=Number(btn.dataset.fieldWidth);sync();renderSelected();renderLayoutCanvas();", "setFieldWidth(i,Number(btn.dataset.fieldWidth));", 1)
t = t.replace("else{x[k]=el.value;if(k==='key'&&el.value!==x.key){openFieldKeys.delete(x.key);openFieldKeys.add(el.value);}}", "else{if(k==='key'){const old=x.key,next=uniqueKey(el.value,old);x.key=next;el.value=next;openFieldKeys.delete(old);openFieldKeys.add(next);activeFieldKey=next;}else x[k]=el.value;}", 1)

# Bind tax-code mappings and warn on duplicate field labels.
needle = "d.querySelectorAll('[data-cfg-check]').forEach(el=>el.addEventListener('change',()=>{setDeep(x.config,el.dataset.cfgCheck,el.checked);sync();}));"
addition = needle + " d.querySelectorAll('[data-tax-link]').forEach(el=>el.addEventListener('change',()=>{x.config.links=x.config.links||{};x.config.links[el.dataset.taxLink]=el.value;sync();}));const labelCounts=selected.reduce((m,f)=>{const k=String(f.label||'').trim().toLocaleLowerCase();if(k)m[k]=(m[k]||0)+1;return m;},{}),hasDuplicateLabels=Object.values(labelCounts).some(n=>n>1);const conflict=d.querySelector('.df-tax-conflict');if(conflict&&hasDuplicateLabels){conflict.hidden=false;conflict.className='df-status-warning';conflict.textContent='Attenzione: esistono campi con lo stesso nome. Usa la chiave mostrata tra parentesi per scegliere quello corretto.';}"
t = replace_once(t, needle, addition, 'tax mapping bindings')

# Balanced visual rows and clearer canvas actions.
t = re.sub(r"function widthChoices\(current\)\{.*?\}\nfunction selectField", "function widthChoices(current){const vals=[100,75,66,60,50,40,33,25];if(!vals.includes(Number(current)))vals.push(Number(current)||100);return vals.map(v=>`<option value=\"${v}\" ${Number(current)===v?'selected':''}>${v}%</option>`).join('');}\nfunction selectField", t, count=1, flags=re.S)
insert_set_width = r'''function setFieldWidth(index,width){if(index==null||!selected[index])return;const field=selected[index],row=Number(field.config.layout.row||1),items=fieldsInRow(row);width=Math.max(10,Math.min(100,Number(width)||100));if(items.length===1){field.config.layout.width=100;}else if(width===100){field.config.layout.width=100;let nextRow=Math.max(0,...selected.map(f=>Number(f.config.layout.row||1)))+1;items.filter(([,i])=>i!==index).forEach(([f])=>{f.config.layout.row=nextRow++;f.config.layout.col=1;f.config.layout.width=100;});normalizeLayoutRows();}else{field.config.layout.width=width;const others=items.filter(([,i])=>i!==index),remaining=100-width,base=Math.floor(remaining/others.length),extra=remaining-base*others.length;others.forEach(([f],i)=>f.config.layout.width=base+(i<extra?1:0));}sync();renderSelected();renderLayoutCanvas();}
'''
t = replace_once(t, 'function selectField(index)', insert_set_width + 'function selectField(index)', 'set width function')
t = t.replace("normalizeLayoutRows();renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();}", "normalizeLayoutRows();distributeRow(copy.config.layout.row);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();}", 1)
t = t.replace("d.querySelector('[data-act=\"remove\"]').onclick=()=>{openFieldKeys.delete(x.key);selected.splice(i,1);activeFieldKey=selected[Math.min(i,selected.length-1)]?.key||null;normalizeLayoutRows();", "d.querySelector('[data-act=\"remove\"]').onclick=()=>{const removedRow=Number(x.config.layout.row||1);openFieldKeys.delete(x.key);selected.splice(i,1);activeFieldKey=selected[Math.min(i,selected.length-1)]?.key||null;normalizeLayoutRows();distributeRow(removedRow);", 1)
t = t.replace("function removeCanvasField(index){if(index==null||!selected[index])return;const old=selected[index].key;selected.splice(index,1);", "function removeCanvasField(index){if(index==null||!selected[index])return;const old=selected[index].key,oldRow=Number(selected[index].config.layout.row||1);selected.splice(index,1);", 1)
t = t.replace("openFieldKeys.delete(old);activeFieldKey=selected[Math.min(index,selected.length-1)]?.key||null;normalizeLayoutRows();renderSelected();", "openFieldKeys.delete(old);activeFieldKey=selected[Math.min(index,selected.length-1)]?.key||null;normalizeLayoutRows();distributeRow(oldRow);renderSelected();", 1)
t = t.replace("function moveFieldToRow(index,row,targetIndex=null){if(index==null||!selected[index])return;const field=selected[index];selected.splice(index,1);", "function moveFieldToRow(index,row,targetIndex=null){if(index==null||!selected[index])return;const field=selected[index],oldRow=Number(selected[index].config.layout.row||1);selected.splice(index,1);", 1)
t = t.replace("normalizeLayoutRows();distributeRow(field.config.layout.row);activeFieldKey=field.key;", "normalizeLayoutRows();distributeRow(oldRow);distributeRow(field.config.layout.row);activeFieldKey=field.key;", 1)
t = t.replace("normalizeLayoutRows();activeFieldKey=field.key;sync();renderSelected();renderLayoutCanvas();}", "normalizeLayoutRows();distributeRow(field.config.layout.row);activeFieldKey=field.key;sync();renderSelected();renderLayoutCanvas();}", 1)
t = t.replace("normalizeLayoutRows();distributeRow(field.config.layout.row);activeFieldKey=field.key;", "normalizeLayoutRows();distributeRow(oldRow);distributeRow(field.config.layout.row);activeFieldKey=field.key;", 1)
t = t.replace("const rows=[...new Set(selected.map(f=>Number(f.config.layout.row||1)))].sort((a,b)=>a-b);rows.forEach(rowNo=>{const row=document.createElement('div');row.className='df-layout-row';row.dataset.row=String(rowNo);selected.map((f,i)=>[f,i]).filter(([f])=>Number(f.config.layout.row||1)===rowNo).sort", "const rows=[...new Set(selected.map(f=>Number(f.config.layout.row||1)))].sort((a,b)=>a-b);rows.forEach(rowNo=>{const row=document.createElement('div');row.className='df-layout-row';row.dataset.row=String(rowNo);const rowItems=fieldsInRow(rowNo);row.style.gridTemplateColumns=rowItems.map(([f])=>Math.max(10,Number(f.config.layout.width||100))+'fr').join(' ');selected.map((f,i)=>[f,i]).filter(([f])=>Number(f.config.layout.row||1)===rowNo).sort", 1)
t = t.replace("card.style.width=`${Math.max(10,Math.min(100,Number(f.config.layout.width||100)))}%`;const required=f.required?' *':'';card.innerHTML=`", "card.style.width='100%';const required=f.required?'<span class=\"df-required-badge\">Obbligatorio</span>':'';card.innerHTML=`", 1)
t = t.replace("<strong>${esc(f.label)}${required}</strong><span class=\"df-layout-meta\"><span class=\"df-layout-type\">", "<strong>${esc(f.label)}</strong><span class=\"df-layout-meta\"><span class=\"df-layout-type\">", 1)
t = t.replace("${esc(tr.types[f.type]||f.type)}</span><select", "${esc(tr.types[f.type]||f.type)}</span>${required}<select", 1)
t = t.replace('title="Modifica" aria-label="Modifica">✎', 'title="Modifica campo" aria-label="Modifica campo">✎', 1)
t = t.replace('title="Duplica" aria-label="Duplica">⧉', 'title="Duplica campo" aria-label="Duplica campo">⧉', 1)
t = t.replace('title="Elimina" aria-label="Elimina">×', 'title="Elimina campo" aria-label="Elimina campo">🗑', 1)
t = t.replace("card.querySelector('select').onchange=e=>{f.config.layout.width=Number(e.target.value);sync();renderLayoutCanvas();renderSelected();};", "card.querySelector('select').onchange=e=>setFieldWidth(i,Number(e.target.value));", 1)

# Status keys remain internal; duplicate visible names block saving.
status_match = re.search(r"function renderStatuses\(\)\{.*?\}\ndocument.getElementById\('df-add-status'\).*?\nfunction columnItems", t, re.S)
if not status_match:
    raise RuntimeError('status renderer not found')
new_status = r'''function normalizedStatusLabel(v){return String(v||'').trim().toLocaleLowerCase();}
function statusConflicts(){const seen=new Set(),dupes=new Set();statuses.forEach(st=>{const n=normalizedStatusLabel(st.label);if(!n)return;if(seen.has(n))dupes.add(n);seen.add(n);});return dupes;}
function renderStatuses(){statusEditor.innerHTML='';const dupes=statusConflicts();if(dupes.size){const warning=document.createElement('div');warning.className='df-status-warning';warning.textContent='Esistono stati con lo stesso nome. Rinominali prima di salvare.';statusEditor.appendChild(warning);}statuses.forEach((st,i)=>{st.color=/^#[0-9a-fA-F]{6}$/.test(st.color||'')?st.color:statusPalette[i%statusPalette.length];const r=document.createElement('div');r.className='df-status-row'+(dupes.has(normalizedStatusLabel(st.label))?' is-conflict':'');r.innerHTML=`<input data-status-label value="${esc(st.label||'')}" placeholder="Nome stato"><div class="df-status-color-wrap"><input class="df-status-color" data-status-color type="color" value="${esc(st.color)}"><span class="df-status-color-value">${esc(st.color)}</span></div><button type="button" class="df-status-remove" title="Elimina stato" aria-label="Elimina stato">🗑</button>`;const li=r.querySelector('[data-status-label]'),ci=r.querySelector('[data-status-color]');li.oninput=()=>{st.label=li.value;if(st._new)st.key=slugStatus(li.value);sync();};li.onblur=renderStatuses;ci.oninput=()=>{st.color=ci.value.toLowerCase();r.querySelector('.df-status-color-value').textContent=st.color;sync();};r.querySelector('button').onclick=()=>{if(statuses.length>1){statuses.splice(i,1);renderStatuses();}};statusEditor.appendChild(r);});sync();}
document.getElementById('df-add-status').onclick=()=>{statuses.push({key:'',label:'',color:statusPalette[statuses.length%statusPalette.length],_new:true});renderStatuses();statusEditor.querySelector('.df-status-row:last-child [data-status-label]')?.focus();};renderStatuses();
function columnItems'''
t = t[:status_match.start()] + new_status + t[status_match.end():]

# Real, scaled template thumbnails. One preview action only; whole thumbnail opens it.
email_match = re.search(r"function renderEmailPickers\(\)\{.*?\}\nfunction renderEmailSpecial", t, re.S)
if not email_match:
    raise RuntimeError('email picker renderer not found')
new_email = r'''function renderEmailPickers(){document.querySelectorAll('[data-email-picker]').forEach(box=>{const audience=box.dataset.emailPicker,config=emailConfig[audience];box.innerHTML='';templateDefs.forEach(([key,label])=>{const card=document.createElement('div'),special=['custom','html','chatgpt'].includes(key);card.className='df-email-choice'+((config.template||'standard')===key?' is-active':'');card.dataset.special=special?'1':'0';card.dataset.template=key;card.innerHTML=`<button type="button" class="df-email-thumb" title="Apri anteprima" aria-label="Apri anteprima: ${esc(label)}"><iframe class="df-email-thumb-frame" title="" tabindex="-1" sandbox></iframe><span class="df-email-preview-label" aria-hidden="true">◉ Apri anteprima</span></button><div class="df-email-choice-foot"><label class="df-email-radio"><input type="radio" name="df-email-template-${audience}" value="${key}" ${(config.template||'standard')===key?'checked':''}><span>${esc(label)}</span></label></div>`;card.querySelector('.df-email-thumb').onclick=e=>{e.preventDefault();showEmailPreview(audience,key);};card.querySelector('input').onchange=()=>{config.template=key;renderEmailPickers();renderEmailSpecial(audience);sync();};box.appendChild(card);requestAnimationFrame(()=>{const frame=card.querySelector('iframe');try{frame.srcdoc=emailPreviewHtml(audience,key);}catch{frame.srcdoc='<div style="font-family:Arial;padding:20px">Anteprima non disponibile</div>';}});});renderEmailSpecial(audience);});}
function renderEmailSpecial'''
t = t[:email_match.start()] + new_email + t[email_match.end():]
t = t.replace("if(template==='receipt')return", "if(template==='professional')return `<div style=\"font-family:Arial;background:#eef2f7;padding:24px\"><div style=\"background:#fff;border-top:7px solid #26364a;padding:24px;box-shadow:0 3px 12px rgba(15,23,42,.08)\"><div style=\"color:#26364a;font-size:12px;text-transform:uppercase;letter-spacing:.08em;margin-bottom:14px\">${esc(subject)}</div>${content}</div></div>`;if(template==='receipt')return", 1)

# Lock mode, undo/redo shortcuts and dirty-state warning.
end_marker = "renderSelected();renderLayout();renderTokens();renderUserEmailFields();renderEmailPickers();renderAdditional();sync();"
end_code = r'''const builderRoot=document.querySelector('.df-builder'),builderForm=document.getElementById('df-builder-form');let editorLocked=<?php echo $id ? 'true' : 'false'; ?>;
function applyLockState(){if(!builderRoot)return;builderRoot.classList.toggle('is-locked',editorLocked);document.querySelectorAll('.df-lock-toggle').forEach(b=>b.classList.toggle('is-active',(b.dataset.lock==='1')===editorLocked));builderForm.querySelectorAll('input:not([type="hidden"]),select,textarea,button:not(.df-section-toggle):not(.df-info)').forEach(el=>{if(!el.dataset.lockOriginal)el.dataset.lockOriginal=el.disabled?'1':'0';el.disabled=editorLocked||el.dataset.lockOriginal==='1';});updateHistoryButtons();}
function hasUnsavedChanges(){return historyReady&&historyIndex>=0&&historySignature(historyStates[historyIndex])!==initialHistorySignature;}
function setEditorLocked(locked,ask=true){if(locked===editorLocked)return;if(locked&&ask&&hasUnsavedChanges()&&!confirm('Ci sono modifiche non salvate. Vuoi bloccare comunque la modifica?'))return;editorLocked=locked;applyLockState();}
document.querySelectorAll('.df-lock-toggle').forEach(b=>b.onclick=()=>setEditorLocked(b.dataset.lock==='1'));
document.getElementById('df-undo').onclick=()=>restoreHistory(historyIndex-1);document.getElementById('df-redo').onclick=()=>restoreHistory(historyIndex+1);
document.addEventListener('keydown',e=>{if(editorLocked)return;const mod=e.ctrlKey||e.metaKey;if(!mod)return;if(e.key.toLowerCase()==='z'){e.preventDefault();restoreHistory(historyIndex+(e.shiftKey?1:-1));}else if(e.key.toLowerCase()==='y'){e.preventDefault();restoreHistory(historyIndex+1);}});
builderForm.addEventListener('input',scheduleHistory,true);builderForm.addEventListener('change',scheduleHistory,true);window.addEventListener('beforeunload',e=>{if(hasUnsavedChanges()){e.preventDefault();e.returnValue='';}});
renderSelected();renderLayout();renderTokens();renderUserEmailFields();renderEmailPickers();renderAdditional();sync();historyReady=true;historyStates=[captureHistoryState()];historyIndex=0;initialHistorySignature=historySignature(historyStates[0]);applyLockState();updateHistoryButtons();'''
t = replace_once(t, end_marker, end_code, 'initial render')

# Block duplicate statuses on submit, while keeping old keys untouched.
t, submit_count = re.subn(r"// Submit guard:.*?\nconst builderRoot", "// Submit guard: duplicate status names must be resolved before saving.\ndocument.getElementById('df-builder-form').addEventListener('submit',e=>{if(statusConflicts().size){e.preventDefault();openBuilderSection(4,true);renderStatuses();return;}sync();initialHistorySignature=historySignature(captureHistoryState());});\n\nconst builderRoot", t, count=1, flags=re.S)
if submit_count != 1:
    raise RuntimeError('submit guard not found')

builder.write_text(t)
helper.write_text(h)
controller.write_text(c)
renderer.write_text(p)
