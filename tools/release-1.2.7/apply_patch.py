#!/usr/bin/env python3
from pathlib import Path
import re
import sys

if len(sys.argv) != 4:
    raise SystemExit('usage: apply_patch.py COMPONENT_DIR PLUGIN_DIR OUTER_DIR')

component = Path(sys.argv[1])
plugin = Path(sys.argv[2])
outer = Path(sys.argv[3])
VERSION = '1.2.7'


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding='utf-8')
    if old not in text:
        raise RuntimeError(f'missing patch target: {label} in {path}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


def set_ini(path: Path, key: str, value: str) -> None:
    text = path.read_text(encoding='utf-8-sig')
    line = f'{key}="{value}"'
    rx = re.compile(rf'^{re.escape(key)}=.*$', re.M)
    if rx.search(text):
        text = rx.sub(line, text, count=1)
    else:
        if text and not text.endswith('\n'):
            text += '\n'
        text += line + '\n'
    path.write_text(text, encoding='utf-8')

# Builder controller: clipboard in Joomla session, paste creates a new independent form.
controller = component / 'administrator/components/com_decaroforms/src/Controller/BuilderController.php'
text = controller.read_text(encoding='utf-8')
text = text.replace(
    'final class BuilderController extends BaseController\n{',
    "final class BuilderController extends BaseController\n{\n    private const COPY_SESSION_KEY = 'com_decaroforms.copied_form_id';",
    1,
)
insert_before = '    public function delete(): void\n'
if insert_before not in text:
    raise RuntimeError('delete method marker missing')
methods = r'''    public function copy(): void
    {
        $app = Factory::getApplication();
        if (!Session::checkToken('post') || !$app->getIdentity()->authorise('core.create', 'com_decaroforms')) {
            throw new \RuntimeException(Text::_('COM_DECAROFORMS_ERR_TOKEN_PERMISSIONS'), 403);
        }

        $id = $app->getInput()->post->getInt('id', 0);
        /** @var DatabaseInterface $db */
        $db = Factory::getContainer()->get(DatabaseInterface::class);
        $q = $db->createQuery()
            ->select(['id','title'])
            ->from($db->quoteName('#__decaroforms_forms'))
            ->where($db->quoteName('id') . ' = :id')
            ->bind(':id', $id);
        $db->setQuery($q);
        $form = $db->loadAssoc();
        if (!$form) {
            $app->enqueueMessage(Text::_('COM_DECAROFORMS_ERR_COPY_FORM_NOT_FOUND'), 'error');
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=forms', false));
            return;
        }

        $app->getSession()->set(self::COPY_SESSION_KEY, $id);
        $app->enqueueMessage(Text::sprintf('COM_DECAROFORMS_MSG_FORM_COPIED', (string) $form['title']), 'message');

        $returnView = $app->getInput()->post->getCmd('return_view', 'forms');
        if ($returnView === 'submissions') {
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=submissions&form_id=' . $id, false));
            return;
        }
        $app->redirect(Route::_('index.php?option=com_decaroforms&view=forms', false));
    }

    public function paste(): void
    {
        $app = Factory::getApplication();
        if (!Session::checkToken('post') || !$app->getIdentity()->authorise('core.create', 'com_decaroforms')) {
            throw new \RuntimeException(Text::_('COM_DECAROFORMS_ERR_TOKEN_PERMISSIONS'), 403);
        }

        $sourceId = (int) $app->getSession()->get(self::COPY_SESSION_KEY, 0);
        if ($sourceId <= 0) {
            $app->enqueueMessage(Text::_('COM_DECAROFORMS_ERR_NO_COPIED_FORM'), 'warning');
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=forms', false));
            return;
        }

        /** @var DatabaseInterface $db */
        $db = Factory::getContainer()->get(DatabaseInterface::class);
        $q = $db->createQuery()
            ->select('*')
            ->from($db->quoteName('#__decaroforms_forms'))
            ->where($db->quoteName('id') . ' = :id')
            ->bind(':id', $sourceId);
        $db->setQuery($q);
        $source = $db->loadAssoc();
        if (!$source) {
            $app->getSession()->set(self::COPY_SESSION_KEY, 0);
            $app->enqueueMessage(Text::_('COM_DECAROFORMS_ERR_COPY_FORM_NOT_FOUND'), 'error');
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=forms', false));
            return;
        }

        $baseTitle = Text::sprintf('COM_DECAROFORMS_COPY_TITLE', (string) $source['title']);
        $title = $baseTitle;
        $titleIndex = 2;
        while ($this->formTitleExists($db, $title)) {
            $title = $baseTitle . ' ' . $titleIndex++;
        }

        $baseSlug = FormHelper::slugify((string) ($source['slug'] ?: $source['title'])) . '-copy';
        $slug = $baseSlug;
        $slugIndex = 2;
        while ($this->formSlugExists($db, $slug)) {
            $slug = $baseSlug . '-' . $slugIndex++;
        }

        $clone = new \stdClass();
        foreach ($source as $key => $value) {
            if ($key === 'id') {
                continue;
            }
            $clone->{$key} = $value;
        }
        $now = Factory::getDate()->toSql();
        $clone->title = $title;
        $clone->slug = $slug;
        $clone->created_at = $now;
        $clone->updated_at = $now;
        $db->insertObject('#__decaroforms_forms', $clone, 'id');
        $newId = (int) $clone->id;

        $q = $db->createQuery()
            ->select('*')
            ->from($db->quoteName('#__decaroforms_fields'))
            ->where($db->quoteName('form_id') . ' = :fid')
            ->bind(':fid', $sourceId)
            ->order([$db->quoteName('sort_order') . ' ASC', $db->quoteName('id') . ' ASC']);
        $db->setQuery($q);
        foreach ($db->loadAssocList() ?: [] as $field) {
            $record = new \stdClass();
            foreach ($field as $key => $value) {
                if ($key === 'id') {
                    continue;
                }
                $record->{$key} = $value;
            }
            $record->form_id = $newId;
            $db->insertObject('#__decaroforms_fields', $record);
        }

        $app->enqueueMessage(Text::_('COM_DECAROFORMS_MSG_FORM_PASTED'), 'message');
        $app->redirect(Route::_('index.php?option=com_decaroforms&view=builder&id=' . $newId, false));
    }

    private function formTitleExists(DatabaseInterface $db, string $title): bool
    {
        $q = $db->createQuery()->select('COUNT(*)')->from($db->quoteName('#__decaroforms_forms'))->where($db->quoteName('title') . ' = :title')->bind(':title', $title);
        $db->setQuery($q);
        return (int) $db->loadResult() > 0;
    }

    private function formSlugExists(DatabaseInterface $db, string $slug): bool
    {
        $q = $db->createQuery()->select('COUNT(*)')->from($db->quoteName('#__decaroforms_forms'))->where($db->quoteName('slug') . ' = :slug')->bind(':slug', $slug);
        $db->setQuery($q);
        return (int) $db->loadResult() > 0;
    }

'''
text = text.replace(insert_before, methods + insert_before, 1)
controller.write_text(text, encoding='utf-8')

# Forms list UI.
forms = component / 'administrator/components/com_decaroforms/tmpl/forms/default.php'
text = forms.read_text(encoding='utf-8')
text = text.replace("use Joomla\\CMS\\Router\\Route;\nuse Joomla\\CMS\\Language\\Text;", "use Joomla\\CMS\\Router\\Route;\nuse Joomla\\CMS\\Language\\Text;\nuse Joomla\\CMS\\HTML\\HTMLHelper;", 1)
text = text.replace('.df-actions{display:flex;gap:9px;flex-wrap:wrap}', '.df-actions{display:flex;gap:9px;flex-wrap:wrap}.df-actions form,.df-card-actions form{margin:0}', 1)
old_head = '<div class="df-actions"><a class="df-btn" href="<?php echo $this->dashboardUrl; ?>"><?php echo Text::_(\'COM_DECAROFORMS_DASHBOARD\'); ?></a><a class="df-btn" href="<?php echo $this->recentUrl; ?>"><?php echo Text::_(\'COM_DECAROFORMS_RECENT\'); ?></a><a class="df-btn" href="<?php echo $this->importUrl; ?>"><?php echo Text::_(\'COM_DECAROFORMS_MENU_IMPORT\'); ?></a><a class="df-btn" href="<?php echo $this->informationUrl; ?>"><?php echo Text::_(\'COM_DECAROFORMS_INFORMATION\'); ?></a><a class="df-btn df-btn-primary" href="<?php echo $this->builderUrl; ?>"><?php echo Text::_(\'COM_DECAROFORMS_CREATE_FORM\'); ?></a></div>'
new_head = '<div class="df-actions"><a class="df-btn" href="<?php echo $this->dashboardUrl; ?>"><?php echo Text::_(\'COM_DECAROFORMS_DASHBOARD\'); ?></a><a class="df-btn" href="<?php echo $this->recentUrl; ?>"><?php echo Text::_(\'COM_DECAROFORMS_RECENT\'); ?></a><a class="df-btn" href="<?php echo $this->importUrl; ?>"><?php echo Text::_(\'COM_DECAROFORMS_MENU_IMPORT\'); ?></a><a class="df-btn" href="<?php echo $this->informationUrl; ?>"><?php echo Text::_(\'COM_DECAROFORMS_INFORMATION\'); ?></a><form method="post" action="index.php?option=com_decaroforms&task=builder.paste"><button class="df-btn" type="submit"><?php echo Text::_(\'COM_DECAROFORMS_PASTE_FORM\'); ?></button><?php echo HTMLHelper::_(\'form.token\'); ?></form><a class="df-btn df-btn-primary" href="<?php echo $this->builderUrl; ?>"><?php echo Text::_(\'COM_DECAROFORMS_CREATE_FORM\'); ?></a></div>'
if old_head not in text:
    raise RuntimeError('forms head actions target missing')
text = text.replace(old_head, new_head, 1)
old_card = '<div class="df-card-actions"><a class="df-btn" href="<?php echo Route::_(\'index.php?option=com_decaroforms&view=builder&id=\'.(int)$form[\'id\'],false); ?>"><?php echo Text::_(\'COM_DECAROFORMS_EDIT\'); ?></a><a class="df-btn df-btn-primary" href="<?php echo Route::_(\'index.php?option=com_decaroforms&view=submissions&form_id=\'.(int)$form[\'id\'],false); ?>"><?php echo Text::_(\'COM_DECAROFORMS_OPEN_SUBMISSIONS\'); ?></a></div>'
new_card = '<div class="df-card-actions"><a class="df-btn" href="<?php echo Route::_(\'index.php?option=com_decaroforms&view=builder&id=\'.(int)$form[\'id\'],false); ?>"><?php echo Text::_(\'COM_DECAROFORMS_EDIT\'); ?></a><form method="post" action="index.php?option=com_decaroforms&task=builder.copy"><input type="hidden" name="id" value="<?php echo (int)$form[\'id\']; ?>"><input type="hidden" name="return_view" value="forms"><button class="df-btn" type="submit"><?php echo Text::_(\'COM_DECAROFORMS_COPY_FORM\'); ?></button><?php echo HTMLHelper::_(\'form.token\'); ?></form><a class="df-btn df-btn-primary" href="<?php echo Route::_(\'index.php?option=com_decaroforms&view=submissions&form_id=\'.(int)$form[\'id\'],false); ?>"><?php echo Text::_(\'COM_DECAROFORMS_OPEN_SUBMISSIONS\'); ?></a></div>'
if old_card not in text:
    raise RuntimeError('forms card actions target missing')
text = text.replace(old_card, new_card, 1)
forms.write_text(text, encoding='utf-8')

# Submissions page: add Copy module in the header actions.
subs = component / 'administrator/components/com_decaroforms/tmpl/submissions/default.php'
text = subs.read_text(encoding='utf-8')
text = text.replace("use Joomla\\CMS\\Router\\Route;", "use Joomla\\CMS\\Router\\Route;\nuse Joomla\\CMS\\HTML\\HTMLHelper;", 1)
text = text.replace('.df-actions{display:flex;gap:8px;flex-wrap:wrap;align-items:center}', '.df-actions{display:flex;gap:8px;flex-wrap:wrap;align-items:center}.df-actions form{margin:0}', 1)
old_back = '      <a class="df-btn" href="index.php?option=com_decaroforms&view=forms">← <?php echo Text::_(\'COM_DECAROFORMS_FORMS_LIST\'); ?></a>'
new_back = '      <form method="post" action="index.php?option=com_decaroforms&task=builder.copy"><input type="hidden" name="id" value="<?php echo (int) ($this->form[\'id\'] ?? 0); ?>"><input type="hidden" name="return_view" value="submissions"><button class="df-btn" type="submit"><?php echo Text::_(\'COM_DECAROFORMS_COPY_FORM\'); ?></button><?php echo HTMLHelper::_(\'form.token\'); ?></form>\n      <a class="df-btn" href="index.php?option=com_decaroforms&view=forms">← <?php echo Text::_(\'COM_DECAROFORMS_FORMS_LIST\'); ?></a>'
if old_back not in text:
    raise RuntimeError('submissions back button target missing')
text = text.replace(old_back, new_back, 1)
subs.write_text(text, encoding='utf-8')

# Languages.
translations = {
    'it-IT': {
        'COM_DECAROFORMS_COPY_FORM': 'Copia modulo',
        'COM_DECAROFORMS_PASTE_FORM': 'Incolla modulo',
        'COM_DECAROFORMS_MSG_FORM_COPIED': 'Modulo "%s" copiato. Ora puoi usare Incolla modulo.',
        'COM_DECAROFORMS_MSG_FORM_PASTED': 'Copia creata. Il nuovo modulo è indipendente e non contiene gli invii del modulo originale.',
        'COM_DECAROFORMS_ERR_COPY_FORM_NOT_FOUND': 'Il modulo da copiare non esiste più.',
        'COM_DECAROFORMS_ERR_NO_COPIED_FORM': 'Nessun modulo copiato. Premi prima Copia modulo.',
        'COM_DECAROFORMS_COPY_TITLE': '%s – copia',
    },
    'en-GB': {
        'COM_DECAROFORMS_COPY_FORM': 'Copy form',
        'COM_DECAROFORMS_PASTE_FORM': 'Paste form',
        'COM_DECAROFORMS_MSG_FORM_COPIED': 'Form "%s" copied. You can now use Paste form.',
        'COM_DECAROFORMS_MSG_FORM_PASTED': 'Copy created. The new form is independent and does not contain submissions from the original form.',
        'COM_DECAROFORMS_ERR_COPY_FORM_NOT_FOUND': 'The form to copy no longer exists.',
        'COM_DECAROFORMS_ERR_NO_COPIED_FORM': 'No form has been copied. Use Copy form first.',
        'COM_DECAROFORMS_COPY_TITLE': '%s - copy',
    },
    'fr-FR': {
        'COM_DECAROFORMS_COPY_FORM': 'Copier le formulaire',
        'COM_DECAROFORMS_PASTE_FORM': 'Coller le formulaire',
        'COM_DECAROFORMS_MSG_FORM_COPIED': 'Formulaire "%s" copié. Vous pouvez maintenant utiliser Coller le formulaire.',
        'COM_DECAROFORMS_MSG_FORM_PASTED': 'Copie créée. Le nouveau formulaire est indépendant et ne contient pas les envois du formulaire original.',
        'COM_DECAROFORMS_ERR_COPY_FORM_NOT_FOUND': 'Le formulaire à copier n’existe plus.',
        'COM_DECAROFORMS_ERR_NO_COPIED_FORM': 'Aucun formulaire copié. Utilisez d’abord Copier le formulaire.',
        'COM_DECAROFORMS_COPY_TITLE': '%s – copie',
    },
}
for tag, entries in translations.items():
    path = component / f'administrator/components/com_decaroforms/language/{tag}/com_decaroforms.ini'
    for key, value in entries.items():
        set_ini(path, key, value)

# Version in helper/manifests/package names.
helper = component / 'administrator/components/com_decaroforms/src/Helper/FormHelper.php'
text = helper.read_text(encoding='utf-8')
text, count = re.subn(r"public const VERSION = '[^']+';", f"public const VERSION = '{VERSION}';", text, count=1)
if count != 1:
    raise RuntimeError('FormHelper version constant not found')
helper.write_text(text, encoding='utf-8')

for path in [component / 'com_decaroforms.xml', plugin / 'decaroforms.xml', outer / 'pkg_decaroforms.xml']:
    text = path.read_text(encoding='utf-8')
    text, count = re.subn(r'<version>[^<]+</version>', f'<version>{VERSION}</version>', text, count=1)
    if count != 1:
        raise RuntimeError(f'version tag not found in {path}')
    path.write_text(text, encoding='utf-8')

pkg = outer / 'pkg_decaroforms.xml'
text = pkg.read_text(encoding='utf-8')
text = text.replace('com_decaroforms_1.2.6.zip', 'com_decaroforms_1.2.7.zip')
text = text.replace('plg_system_decaroforms_1.2.6.zip', 'plg_system_decaroforms_1.2.7.zip')
pkg.write_text(text, encoding='utf-8')

print('Forms 1.2.7 copy-paste module patch applied')
