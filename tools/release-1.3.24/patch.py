#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit('usage: patch.py COMPONENT_ROOT PLUGIN_ROOT')

comp=Path(sys.argv[1]); plug=Path(sys.argv[2])
builder=comp/'administrator/components/com_decaroforms/tmpl/builder/default.php'
controller=comp/'administrator/components/com_decaroforms/src/Controller/BuilderController.php'
helper=comp/'administrator/components/com_decaroforms/src/Helper/FormHelper.php'
component_manifest=comp/'com_decaroforms.xml'
plugin_manifest=plug/'decaroforms.xml'

def rep(text, old, new, label, count=1):
    if old not in text:
        raise RuntimeError(f'{label} not found')
    return text.replace(old,new,count)

# Versions.
h=helper.read_text(); h=rep(h,"public const VERSION = '1.3.23';","public const VERSION = '1.3.24';",'helper version'); helper.write_text(h)
for m in (component_manifest,plugin_manifest):
    s=m.read_text(); s=rep(s,'<version>1.3.23</version>','<version>1.3.24</version>',str(m)); m.write_text(s)

t=builder.read_text()

# Shared inline SVG UI icon styling.
anchor='.df-small{min-height:34px;padding:0 10px;font-size:12px}'
addition='''.df-small{min-height:34px;padding:0 10px;font-size:12px}.df-ui-icon{width:16px;height:16px;display:inline-block;flex:0 0 auto;vertical-align:-2px}.df-ui-icon path,.df-ui-icon line,.df-ui-icon polyline,.df-ui-icon rect,.df-ui-icon circle{vector-effect:non-scaling-stroke}.df-btn .df-ui-icon,.df-lock-toggle .df-ui-icon{margin-right:6px}.df-icon-only .df-ui-icon,.df-layout-actions button .df-ui-icon,.df-mini-actions button .df-ui-icon,.df-status-remove .df-ui-icon,.df-lib-delete .df-ui-icon,.df-saved-quick-delete .df-ui-icon{margin:0}.df-icon-only{display:inline-flex;align-items:center;justify-content:center}'''
t=rep(t,anchor,addition,'icon css')

save_svg='<svg class="df-ui-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M5 3h11l3 3v15H5V3zM7 3v6h9V4M8 21v-7h8v7" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>'
lock_svg='<svg class="df-ui-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><rect x="5" y="10" width="14" height="10" rx="2" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M8 10V7a4 4 0 0 1 8 0v3" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>'
edit_svg='<svg class="df-ui-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M4 20l4.2-1 10.5-10.5a2.1 2.1 0 0 0-3-3L5.2 16 4 20z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M14.5 6.7l2.8 2.8" fill="none" stroke="currentColor" stroke-width="1.8"/></svg>'

# Static toolbar and Save structure emojis -> UI SVG.
t=rep(t,'<button type="button" class="df-lock-toggle" data-lock="1">🔒 Bloccato</button>',f'<button type="button" class="df-lock-toggle" data-lock="1">{lock_svg}<span>Bloccato</span></button>','lock icon')
t=rep(t,'<button type="button" class="df-lock-toggle" data-lock="0">✏️ Modifica</button>',f'<button type="button" class="df-lock-toggle" data-lock="0">{edit_svg}<span>Modifica</span></button>','edit toolbar icon')
t=rep(t,'>💾 Salva struttura</button>',f'>{save_svg}<span>Salva struttura</span></button>','save structure icon')

# Add a JS UI icon factory after clone().
anchor="const clone=o=>JSON.parse(JSON.stringify(o??{}));"
icons_js=r'''const clone=o=>JSON.parse(JSON.stringify(o??{}));
const uiIcon=name=>{const icons={
 save:'<svg class="df-ui-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 3h11l3 3v15H5V3zM7 3v6h9V4M8 21v-7h8v7" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>',
 edit:'<svg class="df-ui-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20l4.2-1 10.5-10.5a2.1 2.1 0 0 0-3-3L5.2 16 4 20z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M14.5 6.7l2.8 2.8" fill="none" stroke="currentColor" stroke-width="1.8"/></svg>',
 copy:'<svg class="df-ui-icon" viewBox="0 0 24 24" aria-hidden="true"><rect x="8" y="8" width="11" height="11" rx="2" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2" fill="none" stroke="currentColor" stroke-width="1.8"/></svg>',
 trash:'<svg class="df-ui-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M9 7V4h6v3M7 7l1 13h8l1-13M10 10v7M14 10v7" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>'
};return icons[name]||'';};'''
t=rep(t,anchor,icons_js,'js icon factory')

# Replace delete/canvas glyphs with SVG UI icons.
t=rep(t,'aria-label="Elimina modello salvato">×</button>','aria-label="Elimina modello salvato" class="df-icon-only">${uiIcon(\'trash\')}</button>','saved quick trash')
t=rep(t,'aria-label="${esc(tr.remove)}">×</button>','aria-label="${esc(tr.remove)}" class="df-icon-only">${uiIcon(\'trash\')}</button>','library trash')
t=rep(t,'<button type="button" data-cond-remove="${ri}">🗑 Elimina condizione</button>','<button type="button" data-cond-remove="${ri}">${uiIcon(\'trash\')}<span>Elimina condizione</span></button>','condition trash')
t=rep(t,'<button type="button" data-act="remove" title="${esc(tr.remove)}">×</button>','<button type="button" data-act="remove" class="df-icon-only" title="${esc(tr.remove)}" aria-label="${esc(tr.remove)}">${uiIcon(\'trash\')}</button>','selected field trash')
t=rep(t,'<button type="button" data-canvas-edit title="Modifica campo" aria-label="Modifica campo">✎</button><button type="button" data-canvas-duplicate title="Duplica campo" aria-label="Duplica campo">⧉</button><button type="button" data-canvas-remove class="df-canvas-remove" title="Elimina campo" aria-label="Elimina campo">🗑</button>','<button type="button" data-canvas-edit class="df-icon-only" title="Modifica campo" aria-label="Modifica campo">${uiIcon(\'edit\')}</button><button type="button" data-canvas-duplicate class="df-icon-only" title="Duplica campo" aria-label="Duplica campo">${uiIcon(\'copy\')}</button><button type="button" data-canvas-remove class="df-canvas-remove df-icon-only" title="Elimina campo" aria-label="Elimina campo">${uiIcon(\'trash\')}</button>','canvas ui icons')
t=rep(t,'<button type="button" class="df-status-remove" title="Elimina stato" aria-label="Elimina stato">🗑</button>','<button type="button" class="df-status-remove df-icon-only" title="Elimina stato" aria-label="Elimina stato">${uiIcon(\'trash\')}</button>','status trash icon')

# Field payload integrity: add count and explicit marker.
t=rep(t,'<input type="hidden" name="fields_json" id="df-fields-json">','<input type="hidden" name="fields_json" id="df-fields-json"><input type="hidden" name="fields_count" id="df-fields-count" value="0"><input type="hidden" name="fields_payload" value="1">','fields integrity hidden inputs')
t=rep(t,"const hidden={fields:document.getElementById('df-fields-json'),statuses:","const hidden={fields:document.getElementById('df-fields-json'),fieldCount:document.getElementById('df-fields-count'),statuses:",'hidden field count ref')
t=rep(t,'function sync(){hidden.fields.value=JSON.stringify(selected);hidden.statuses.value=',"function sync(){hidden.fields.value=JSON.stringify(selected);if(hidden.fieldCount)hidden.fieldCount.value=String(selected.length);hidden.statuses.value=",'sync field count')

# Export the live field state so the early robust save handler can force a final synchronization.
t=rep(t,'selected=selected.map(defaultFieldConfig);','selected=selected.map(defaultFieldConfig);window.dfBuilderSync=sync;window.dfBuilderFieldCount=()=>selected.length;window.dfBuilderFieldsSnapshot=()=>clone(selected);','export builder sync')

# Robust submit: verify live selected state exactly matches the hidden payload before token request / FormData.
old="""        if(typeof window.dfBuilderSync==='function')window.dfBuilderSync();
        if(typeof window.dfBuilderSaveDraft==='function')window.dfBuilderSaveDraft();
        const buttons=[...document.querySelectorAll('.df-save-top'),...form.querySelectorAll('button[type=\"submit\"]')];buttons.forEach(b=>b.disabled=true);"""
new="""        if(typeof window.dfBuilderSync==='function')window.dfBuilderSync();
        const fieldsInput=form.querySelector('#df-fields-json'),fieldsCountInput=form.querySelector('#df-fields-count');
        const liveCount=typeof window.dfBuilderFieldCount==='function'?Number(window.dfBuilderFieldCount()):Number(fieldsCountInput?.value||0);
        let payloadFields=null;try{payloadFields=JSON.parse(fieldsInput?.value||'');}catch{}
        if(!Array.isArray(payloadFields)||payloadFields.length!==liveCount){
          notice('I campi del modulo non sono sincronizzati. Il salvataggio è stato bloccato per evitare la perdita dei campi.','error',false);
          if(typeof window.dfBuilderSaveDraft==='function')window.dfBuilderSaveDraft();
          return false;
        }
        if(fieldsCountInput)fieldsCountInput.value=String(liveCount);
        if(typeof window.dfBuilderSaveDraft==='function')window.dfBuilderSaveDraft();
        const buttons=[...document.querySelectorAll('.df-save-top'),...form.querySelectorAll('button[type=\"submit\"]')];buttons.forEach(b=>b.disabled=true);"""
t=rep(t,old,new,'client field save guard')

# On successful response, verify server persisted the same field count before draft deletion / redirect.
old="""        if(typeof window.dfBuilderClearDraft==='function')window.dfBuilderClearDraft();
        notice(result.message||'Modulo salvato.','success');"""
new="""        const expectedFields=typeof window.dfBuilderFieldCount==='function'?Number(window.dfBuilderFieldCount()):Number(form.querySelector('#df-fields-count')?.value||0);
        if(Number(result.data?.fields_saved)!==expectedFields){notice('Il modulo è stato ricevuto, ma il controllo dei campi non coincide. La bozza è stata conservata.','error',false);return false;}
        if(typeof window.dfBuilderClearDraft==='function')window.dfBuilderClearDraft();
        notice(result.message||'Modulo salvato.','success');"""
t=rep(t,old,new,'server field count verification')

builder.write_text(t)

# Server-side validation: parse and validate fields before any form/field DB mutation.
c=controller.read_text()
anchor="""        $slug = FormHelper::slugify($input->post->getString('slug', $title));
        $now = Factory::getDate()->toSql();"""
insert="""        $fieldsPayload = $input->post->getInt('fields_payload', 0);
        $fieldsJson = (string) $input->post->get('fields_json', '', 'raw');
        $postedFieldCount = max(0, $input->post->getInt('fields_count', -1));
        $fields = json_decode($fieldsJson, true);
        if ($fieldsPayload !== 1 || !is_array($fields) || count($fields) !== $postedFieldCount) {
            $message = 'I campi del modulo non sono stati ricevuti correttamente. Il salvataggio è stato annullato per evitare la perdita dei campi.';
            if ($isAjax) {
                echo new JsonResponse(['code' => 'invalid_fields_payload'], $message, true);
                $app->close();
                return;
            }
            $app->enqueueMessage($message, 'error');
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=builder&id=' . $id, false));
            return;
        }

        $slug = FormHelper::slugify($input->post->getString('slug', $title));
        $now = Factory::getDate()->toSql();"""
c=rep(c,anchor,insert,'server payload validation')

# Remove the old permissive decode block that silently converted invalid payloads to [].
old="""        $fieldsJson = (string) $input->post->get('fields_json', '[]', 'raw');
        $fields = json_decode($fieldsJson, true);
        if (!is_array($fields)) {
            $fields = [];
        }

"""
c=rep(c,old,'','remove permissive fields decode')

# Return persisted field count to the client.
c=rep(c,"['id' => $id, 'redirect' => Route::_('index.php?option=com_decaroforms&view=forms', false)],","['id' => $id, 'fields_saved' => count($fields), 'redirect' => Route::_('index.php?option=com_decaroforms&view=forms', false)],",'response field count')
controller.write_text(c)
