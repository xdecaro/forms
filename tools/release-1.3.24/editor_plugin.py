#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 4:
    raise SystemExit('usage: editor_plugin.py COMPONENT_ROOT OUTER_ROOT EDITOR_PLUGIN_ROOT')

comp=Path(sys.argv[1]); outer=Path(sys.argv[2]); plug=Path(sys.argv[3])
version='1.3.24'

# Administrator modal used by the editor button.
modal=comp/'administrator/components/com_decaroforms/tmpl/forms/modal.php'
modal.parent.mkdir(parents=True,exist_ok=True)
modal.write_text(r'''<?php

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;

$app = Factory::getApplication();
$editor = $app->getInput()->getCmd('editor', '');
?>
<style>
.df-editor-picker{--df:#e60046;--df-dark:#b40038;--df-border:var(--bs-border-color,#dfe3e7);--df-bg:var(--bs-body-bg,#fff);padding:18px;color:var(--bs-body-color,#1f2937)}
.df-editor-picker *{box-sizing:border-box}.df-editor-picker h2{margin:0 0 5px;font-size:24px}.df-editor-picker .df-note{margin:0 0 16px;color:var(--bs-secondary-color,#667085)}
.df-editor-search{width:100%;min-height:44px;padding:0 13px;border:1px solid var(--df-border);border-radius:7px;background:var(--df-bg);color:inherit;margin-bottom:14px}
.df-editor-list{display:grid;gap:9px}.df-editor-row{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:14px;align-items:center;padding:13px 14px;border:1px solid var(--df-border);border-radius:8px;background:var(--df-bg)}.df-editor-row[hidden]{display:none}
.df-editor-title{font-weight:800;font-size:16px}.df-editor-desc{font-size:12px;color:var(--bs-secondary-color,#667085);margin-top:3px}.df-editor-meta{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-top:7px}.df-editor-code{font:700 12px/1.2 ui-monospace,SFMono-Regular,Menlo,monospace;color:var(--df)}
.df-editor-badge{display:inline-flex;align-items:center;min-height:24px;padding:0 8px;border-radius:999px;font-size:11px;font-weight:800}.df-editor-badge.is-on{background:#e8f7ee;color:#176b3a}.df-editor-badge.is-off{background:#fff0e5;color:#9f3b00}
.df-editor-insert{display:inline-flex;align-items:center;justify-content:center;gap:7px;min-height:40px;padding:0 14px;border:1px solid var(--df);border-radius:6px;background:var(--df);color:#fff;font-weight:800;cursor:pointer}.df-editor-insert:hover,.df-editor-insert:focus-visible{background:var(--df-dark);border-color:var(--df-dark)}.df-editor-insert svg{width:17px;height:17px}
.df-editor-empty{padding:28px 14px;text-align:center;border:1px dashed var(--df-border);border-radius:8px;color:var(--bs-secondary-color,#667085)}.df-editor-error{margin-bottom:12px;padding:10px 12px;border:1px solid #f2a7b8;border-radius:7px;background:#fff1f4;color:#7a1631}
@media(max-width:620px){.df-editor-picker{padding:12px}.df-editor-row{grid-template-columns:1fr}.df-editor-insert{width:100%}}
</style>
<div class="df-editor-picker">
  <h2><?php echo Text::_('COM_DECAROFORMS_EDITOR_PICKER_TITLE'); ?></h2>
  <p class="df-note"><?php echo Text::_('COM_DECAROFORMS_EDITOR_PICKER_DESC'); ?></p>
  <div class="df-editor-error" id="df-editor-error" hidden></div>
  <input class="df-editor-search" id="df-editor-search" type="search" autocomplete="off" placeholder="<?php echo htmlspecialchars(Text::_('COM_DECAROFORMS_EDITOR_PICKER_SEARCH'), ENT_QUOTES, 'UTF-8'); ?>">
  <div class="df-editor-list" id="df-editor-list">
  <?php if (!$this->forms): ?><div class="df-editor-empty"><?php echo Text::_('COM_DECAROFORMS_EDITOR_PICKER_EMPTY'); ?></div><?php endif; ?>
  <?php foreach ($this->forms as $form):
      $id=(int)$form['id'];
      $enabled=(int)$form['enabled']===1;
      $search=mb_strtolower((string)$form['title'].' '.(string)$form['description'].' '.$id.' {form id="'.$id.'"}', 'UTF-8');
  ?>
    <article class="df-editor-row" data-editor-form data-search="<?php echo htmlspecialchars($search, ENT_QUOTES, 'UTF-8'); ?>">
      <div>
        <div class="df-editor-title"><?php echo htmlspecialchars((string)$form['title'], ENT_QUOTES, 'UTF-8'); ?></div>
        <?php if(trim((string)$form['description'])!==''): ?><div class="df-editor-desc"><?php echo htmlspecialchars((string)$form['description'], ENT_QUOTES, 'UTF-8'); ?></div><?php endif; ?>
        <div class="df-editor-meta"><span class="df-editor-code">{form id="<?php echo $id; ?>"}</span><span class="df-editor-badge <?php echo $enabled?'is-on':'is-off'; ?>"><?php echo $enabled?Text::_('COM_DECAROFORMS_IN_PROGRESS'):Text::_('COM_DECAROFORMS_DISABLED'); ?></span></div>
      </div>
      <button class="df-editor-insert" type="button" data-insert-form="<?php echo $id; ?>"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M11 5h2v6h6v2h-6v6h-2v-6H5v-2h6V5Z" fill="currentColor"/></svg><span><?php echo Text::_('COM_DECAROFORMS_EDITOR_PICKER_INSERT'); ?></span></button>
    </article>
  <?php endforeach; ?>
  <?php if ($this->forms): ?><div class="df-editor-empty" id="df-editor-no-results" hidden><?php echo Text::_('COM_DECAROFORMS_EDITOR_PICKER_NO_RESULTS'); ?></div><?php endif; ?>
  </div>
</div>
<script>
(()=>{
 const editor=<?php echo json_encode($editor, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); ?>;
 const q=document.getElementById('df-editor-search'),rows=[...document.querySelectorAll('[data-editor-form]')],empty=document.getElementById('df-editor-no-results'),err=document.getElementById('df-editor-error');
 const showError=msg=>{if(!err)return;err.textContent=msg;err.hidden=false;};
 const closeModal=()=>{try{if(window.parent.Joomla?.Modal?.getCurrent())window.parent.Joomla.Modal.getCurrent().close();}catch(e){}};
 const insert=id=>{const shortcode=`{form id="${id}"}`;try{const instance=window.parent.Joomla?.editors?.instances?.[editor];if(!instance||typeof instance.replaceSelection!=='function')throw new Error('editor unavailable');instance.replaceSelection(shortcode);closeModal();}catch(e){showError(<?php echo json_encode(Text::_('COM_DECAROFORMS_EDITOR_PICKER_ERROR')); ?>);}};
 document.querySelectorAll('[data-insert-form]').forEach(btn=>btn.addEventListener('click',()=>insert(btn.dataset.insertForm)));
 q?.addEventListener('input',()=>{const term=(q.value||'').toLocaleLowerCase().trim();let shown=0;rows.forEach(row=>{const ok=!term||row.dataset.search.includes(term);row.hidden=!ok;if(ok)shown++;});if(empty)empty.hidden=shown!==0;});
 q?.focus();
})();
</script>
''',encoding='utf-8')

# Multilingual component strings for the modal.
strings={
'it-IT':[
'COM_DECAROFORMS_EDITOR_PICKER_TITLE="Inserisci modulo Forms"',
'COM_DECAROFORMS_EDITOR_PICKER_DESC="Scegli un modulo e inserisci automaticamente lo shortcode nel punto del cursore."',
'COM_DECAROFORMS_EDITOR_PICKER_SEARCH="Cerca modulo…"',
'COM_DECAROFORMS_EDITOR_PICKER_INSERT="Inserisci"',
'COM_DECAROFORMS_EDITOR_PICKER_EMPTY="Nessun modulo disponibile."',
'COM_DECAROFORMS_EDITOR_PICKER_NO_RESULTS="Nessun modulo corrisponde alla ricerca."',
'COM_DECAROFORMS_EDITOR_PICKER_ERROR="Impossibile inserire il modulo nell’editor."'],
'en-GB':[
'COM_DECAROFORMS_EDITOR_PICKER_TITLE="Insert Forms module"',
'COM_DECAROFORMS_EDITOR_PICKER_DESC="Choose a form and insert its shortcode at the current cursor position."',
'COM_DECAROFORMS_EDITOR_PICKER_SEARCH="Search forms…"',
'COM_DECAROFORMS_EDITOR_PICKER_INSERT="Insert"',
'COM_DECAROFORMS_EDITOR_PICKER_EMPTY="No forms are available."',
'COM_DECAROFORMS_EDITOR_PICKER_NO_RESULTS="No forms match your search."',
'COM_DECAROFORMS_EDITOR_PICKER_ERROR="The form could not be inserted into the editor."'],
'fr-FR':[
'COM_DECAROFORMS_EDITOR_PICKER_TITLE="Insérer un formulaire Forms"',
'COM_DECAROFORMS_EDITOR_PICKER_DESC="Choisissez un formulaire et insérez automatiquement son shortcode à la position du curseur."',
'COM_DECAROFORMS_EDITOR_PICKER_SEARCH="Rechercher un formulaire…"',
'COM_DECAROFORMS_EDITOR_PICKER_INSERT="Insérer"',
'COM_DECAROFORMS_EDITOR_PICKER_EMPTY="Aucun formulaire disponible."',
'COM_DECAROFORMS_EDITOR_PICKER_NO_RESULTS="Aucun formulaire ne correspond à la recherche."',
'COM_DECAROFORMS_EDITOR_PICKER_ERROR="Impossible d’insérer le formulaire dans l’éditeur."']}
for tag,lines in strings.items():
    p=comp/f'administrator/components/com_decaroforms/language/{tag}/com_decaroforms.ini'
    if p.exists():
        text=p.read_text(encoding='utf-8')
        if 'COM_DECAROFORMS_EDITOR_PICKER_TITLE=' not in text:
            p.write_text(text.rstrip()+'\n\n'+'\n'.join(lines)+'\n',encoding='utf-8')

# Enable the bundled editors-xtd plugin automatically during the component postflight.
installer=comp/'script.php'
s=installer.read_text(encoding='utf-8')
anchor="""        if (!isset($submissionColumns['payment_json'])) {
            $db->setQuery('ALTER TABLE ' . $db->quoteName($submissionTable) . ' ADD ' . $db->quoteName('payment_json') . ' LONGTEXT NULL AFTER ' . $db->quoteName('payload_json'));
            $db->execute();
        }

        return true;
"""
replacement="""        if (!isset($submissionColumns['payment_json'])) {
            $db->setQuery('ALTER TABLE ' . $db->quoteName($submissionTable) . ' ADD ' . $db->quoteName('payment_json') . ' LONGTEXT NULL AFTER ' . $db->quoteName('payload_json'));
            $db->execute();
        }

        // The package installs the editor button before the component; enable it automatically.
        try {
            $q = $db->createQuery()
                ->update($db->quoteName('#__extensions'))
                ->set($db->quoteName('enabled') . ' = 1')
                ->where($db->quoteName('type') . ' = ' . $db->quote('plugin'))
                ->where($db->quoteName('folder') . ' = ' . $db->quote('editors-xtd'))
                ->where($db->quoteName('element') . ' = ' . $db->quote('decaroforms'));
            $db->setQuery($q)->execute();
        } catch (\\Throwable $e) {
            Factory::getApplication()->enqueueMessage('Forms è stato aggiornato, ma il pulsante editor potrebbe richiedere l’attivazione manuale in Plugin.', 'warning');
        }

        return true;
"""
if anchor not in s: raise RuntimeError('component postflight anchor not found')
installer.write_text(s.replace(anchor,replacement,1),encoding='utf-8')

# Queue Joomla's native success message in the AJAX request and hide the temporary builder success banner before redirect.
controller=comp/'administrator/components/com_decaroforms/src/Controller/BuilderController.php'
c=controller.read_text(encoding='utf-8')
needle="""        if ($isAjax) {
            echo new JsonResponse(
"""
if needle not in c: raise RuntimeError('controller ajax success block not found')
c=c.replace(needle,"""        if ($isAjax) {
            $app->enqueueMessage(Text::_('COM_DECAROFORMS_MSG_FORM_SAVED'), 'message');
            echo new JsonResponse(
""",1)
controller.write_text(c,encoding='utf-8')

builder=comp/'administrator/components/com_decaroforms/tmpl/builder/default.php'
b=builder.read_text(encoding='utf-8')
b=b.replace("        notice(result.message||'Modulo salvato.','success');\n","        const saveNotice=document.getElementById('df-save-notice');if(saveNotice)saveNotice.hidden=true;\n",1)
b=b.replace("        setTimeout(()=>location.assign(redirect),180);","        location.assign(redirect);",1)
builder.write_text(b,encoding='utf-8')

# Editors-XTD plugin.
(plug/'services').mkdir(parents=True,exist_ok=True)
(plug/'src/Extension').mkdir(parents=True,exist_ok=True)
for tag in ('it-IT','en-GB','fr-FR'):(plug/f'language/{tag}').mkdir(parents=True,exist_ok=True)
(plug/'decaroforms.xml').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<extension type="plugin" group="editors-xtd" method="upgrade">
  <name>PLG_EDITORSXTD_DECAROFORMS</name>
  <author>Luca De Caro</author>
  <creationDate>2026-09-05</creationDate>
  <copyright>Copyright (C) 2026 Luca De Caro</copyright>
  <license>GNU General Public License version 2 or later</license>
  <version>{version}</version>
  <description>PLG_EDITORSXTD_DECAROFORMS_XML_DESCRIPTION</description>
  <namespace path="src">DeCaro\\Plugin\\EditorsXtd\\Forms</namespace>
  <files><folder plugin="decaroforms">services</folder><folder>src</folder></files>
  <languages>
    <language tag="it-IT">language/it-IT/plg_editors-xtd_decaroforms.ini</language><language tag="it-IT">language/it-IT/plg_editors-xtd_decaroforms.sys.ini</language>
    <language tag="en-GB">language/en-GB/plg_editors-xtd_decaroforms.ini</language><language tag="en-GB">language/en-GB/plg_editors-xtd_decaroforms.sys.ini</language>
    <language tag="fr-FR">language/fr-FR/plg_editors-xtd_decaroforms.ini</language><language tag="fr-FR">language/fr-FR/plg_editors-xtd_decaroforms.sys.ini</language>
  </languages>
</extension>
''',encoding='utf-8')
(plug/'services/provider.php').write_text(r'''<?php

defined('_JEXEC') or die;

use Joomla\CMS\Extension\PluginInterface;
use Joomla\CMS\Factory;
use Joomla\CMS\Plugin\PluginHelper;
use Joomla\DI\Container;
use Joomla\DI\ServiceProviderInterface;
use DeCaro\Plugin\EditorsXtd\Forms\Extension\Forms;

return new class () implements ServiceProviderInterface {
    public function register(Container $container): void
    {
        $container->set(PluginInterface::class, function (Container $container) {
            $plugin = new Forms((array) PluginHelper::getPlugin('editors-xtd', 'decaroforms'));
            $plugin->setApplication(Factory::getApplication());
            return $plugin;
        });
    }
};
''',encoding='utf-8')
(plug/'src/Extension/Forms.php').write_text(r'''<?php

namespace DeCaro\Plugin\EditorsXtd\Forms\Extension;

use Joomla\CMS\Editor\Button\Button;
use Joomla\CMS\Event\Editor\EditorButtonsSetupEvent;
use Joomla\CMS\Language\Text;
use Joomla\CMS\Plugin\CMSPlugin;
use Joomla\Event\SubscriberInterface;

defined('_JEXEC') or die;

final class Forms extends CMSPlugin implements SubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        return ['onEditorButtonsSetup' => 'onEditorButtonsSetup'];
    }

    public function onEditorButtonsSetup(EditorButtonsSetupEvent $event): void
    {
        if (in_array($this->_name, $event->getDisabledButtons(), true)) {
            return;
        }
        $user = $this->getApplication()->getIdentity();
        if (!$user || $user->guest || !$user->authorise('core.manage', 'com_decaroforms')) {
            return;
        }
        $this->loadLanguage();
        $editor = $event->getEditorId();
        $link = 'index.php?option=com_decaroforms&view=forms&layout=modal&tmpl=component&editor=' . rawurlencode($editor);
        $button = new Button($this->_name, [
            'action' => 'modal',
            'link' => $link,
            'text' => Text::_('PLG_EDITORSXTD_DECAROFORMS_BUTTON'),
            'icon' => 'list',
            'iconSVG' => '<svg viewBox="0 0 32 32" width="24" height="24"><path d="M5 4h22v24H5V4zm4 5h14v2H9V9zm0 6h14v2H9v-2zm0 6h9v2H9v-2z"></path></svg>',
            'name' => $this->_type . '_' . $this->_name,
        ]);
        $event->getButtonsRegistry()->add($button);
    }
}
''',encoding='utf-8')
langs={
'it-IT':('Forms','Aggiunge il pulsante Forms all’editor Joomla per inserire rapidamente lo shortcode di un modulo.'),
'en-GB':('Forms','Adds a Forms button to the Joomla editor for quickly inserting a form shortcode.'),
'fr-FR':('Forms','Ajoute un bouton Forms à l’éditeur Joomla pour insérer rapidement le shortcode d’un formulaire.')}
for tag,(label,desc) in langs.items():
    (plug/f'language/{tag}/plg_editors-xtd_decaroforms.ini').write_text(f'PLG_EDITORSXTD_DECAROFORMS_BUTTON="{label}"\n',encoding='utf-8')
    (plug/f'language/{tag}/plg_editors-xtd_decaroforms.sys.ini').write_text(f'PLG_EDITORSXTD_DECAROFORMS="Forms - Editor Button"\nPLG_EDITORSXTD_DECAROFORMS_XML_DESCRIPTION="{desc}"\n',encoding='utf-8')

# Outer manifest: include the new plugin before the component so component postflight can enable it.
pkg=outer/'pkg_decaroforms.xml'
p=pkg.read_text(encoding='utf-8').replace('1.3.23','1.3.24').replace('<creationDate>2026-09-04</creationDate>','<creationDate>2026-09-05</creationDate>')
component='        <file type="component" id="com_decaroforms">com_decaroforms_1.3.24.zip</file>'
editor_line='        <file type="plugin" id="decaroforms" group="editors-xtd">plg_editors-xtd_decaroforms_1.3.24.zip</file>'
if editor_line not in p:p=p.replace(component,editor_line+'\n'+component)
pkg.write_text(p,encoding='utf-8')

print('Bundled editors-xtd plugin and modal picker created for',version)
