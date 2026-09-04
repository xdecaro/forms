<?php

namespace DeCaro\Component\Forms\Administrator\Controller;

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\FormHelper;
use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\Controller\BaseController;
use Joomla\CMS\Router\Route;
use Joomla\CMS\Session\Session;
use Joomla\Database\DatabaseInterface;
use Throwable;

final class BuilderController extends BaseController
{
    private const COPY_SESSION_KEY = 'com_decaroforms.copied_form_id';
    public function save(): void
    {
        $app = Factory::getApplication();
        if (!Session::checkToken('post') || !$app->getIdentity()->authorise('core.create', 'com_decaroforms')) {
            throw new \RuntimeException(Text::_('COM_DECAROFORMS_ERR_TOKEN_PERMISSIONS'), 403);
        }

        $input = $app->getInput();
        $id = $input->post->getInt('id', 0);
        $title = trim($input->post->getString('title', ''));
        if ($title === '') {
            $app->enqueueMessage(Text::_('COM_DECAROFORMS_ERR_TITLE_REQUIRED'), 'error');
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=builder&id=' . $id, false));
            return;
        }

        $slug = FormHelper::slugify($input->post->getString('slug', $title));
        $now = Factory::getDate()->toSql();
        /** @var DatabaseInterface $db */
        $db = Factory::getContainer()->get(DatabaseInterface::class);

        $existing = 0;
        $q = $db->createQuery()->select('id')->from($db->quoteName('#__decaroforms_forms'))->where($db->quoteName('slug') . ' = :slug')->bind(':slug', $slug);
        if ($id > 0) {
            $q->where($db->quoteName('id') . ' != :id')->bind(':id', $id);
        }
        $db->setQuery($q);
        $existing = (int) $db->loadResult();
        if ($existing > 0) {
            $slug .= '-' . substr(hash('crc32b', $title . microtime(true)), 0, 5);
        }

        $row = (object) [
            'id' => $id ?: null,
            'title' => $title,
            'slug' => $slug,
            'description' => trim($input->post->getString('description', '')),
            'enabled' => $input->post->getInt('enabled', 0) ? 1 : 0,
            'show_heading' => $input->post->getInt('show_heading', 0) ? 1 : 0,
            'success_message' => trim($input->post->getString('success_message', Text::_('COM_DECAROFORMS_SUCCESS_DEFAULT'))),
            'closed_reason' => trim($input->post->getCmd('closed_reason', 'closed')),
            'closed_message' => trim($input->post->getString('closed_message', '')),
            'admin_email' => trim($input->post->getString('admin_email', '')),
            'user_confirmation' => $input->post->getInt('user_confirmation', 0) ? 1 : 0,
            'email_template_user' => trim($input->post->getCmd('email_template_user', 'standard')),
            'email_template_admin' => trim($input->post->getCmd('email_template_admin', 'standard')),
            'email_subject_user' => trim($input->post->getString('email_subject_user', '')),
            'email_subject_admin' => trim($input->post->getString('email_subject_admin', '')),
            'statuses_json' => $this->normaliseStatuses($input->post->getString('statuses_json', '[]')),
            'list_columns_json' => $this->normaliseColumns($input->post->getString('list_columns_json', '[]')),
            'updated_at' => $now,
        ];

        if ($id > 0) {
            $db->updateObject('#__decaroforms_forms', $row, 'id');
        } else {
            $row->created_at = $now;
            $db->insertObject('#__decaroforms_forms', $row, 'id');
            $id = (int) $row->id;
        }

        $fieldsJson = $input->post->getString('fields_json', '[]');
        $fields = json_decode($fieldsJson, true);
        if (!is_array($fields)) {
            $fields = [];
        }

        $del = $db->createQuery()->delete($db->quoteName('#__decaroforms_fields'))->where($db->quoteName('form_id') . ' = :fid')->bind(':fid', $id);
        $db->setQuery($del)->execute();

        $used = [];
        foreach (array_values($fields) as $index => $field) {
            if (!is_array($field)) { continue; }
            $key = FormHelper::slugify((string) ($field['key'] ?? 'field-' . ($index + 1)));
            $key = str_replace('-', '_', $key);
            $base = $key;
            $n = 2;
            while (isset($used[$key])) { $key = $base . '_' . $n++; }
            $used[$key] = true;
            $type = (string) ($field['type'] ?? 'text');
            if (!in_array($type, ['text','email','tel','number','date','time','textarea','select','radio','checkboxes','consent','file'], true)) { $type = 'text'; }
            $options = $field['options'] ?? [];
            if (is_string($options)) {
                $options = array_values(array_filter(array_map('trim', preg_split('/\r\n|\r|\n|,/', $options) ?: []), static fn($v) => $v !== ''));
            }
            $record = (object) [
                'form_id' => $id,
                'field_key' => $key,
                'field_type' => $type,
                'category' => substr((string) ($field['category'] ?? 'custom'), 0, 40),
                'label' => substr(trim((string) ($field['label'] ?? $key)), 0, 190),
                'placeholder' => substr(trim((string) ($field['placeholder'] ?? '')), 0, 190),
                'help_text' => trim((string) ($field['help'] ?? '')),
                'default_value' => trim((string) ($field['default'] ?? '')),
                'options_json' => json_encode(array_values($options), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
                'required' => !empty($field['required']) ? 1 : 0,
                'sort_order' => $index,
            ];
            $db->insertObject('#__decaroforms_fields', $record);
        }

        $app->enqueueMessage(Text::_('COM_DECAROFORMS_MSG_FORM_SAVED'), 'message');
        $app->redirect(Route::_('index.php?option=com_decaroforms&view=builder&id=' . $id, false));
    }

    private function normaliseStatuses(string $json): string
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

    private function normaliseColumns(string $json): string
    {
        $rows=json_decode($json,true);
        $out=[];
        if (is_array($rows)) {
            foreach ($rows as $key) {
                $key=(string)$key;
                if (preg_match('/^(?:_[a-z_]+|[a-zA-Z0-9_\-]+)$/',$key) && !in_array($key,$out,true)) { $out[]=substr($key,0,120); }
            }
        }
        return json_encode($out?:['_reference','_email','_status','_created_at'],JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
    }

    public function duplicate(): void
    {
        $app = Factory::getApplication();
        if (!Session::checkToken('post') || !$app->getIdentity()->authorise('core.create', 'com_decaroforms')) {
            throw new \RuntimeException(Text::_('COM_DECAROFORMS_ERR_TOKEN_PERMISSIONS'), 403);
        }

        $sourceId = $app->getInput()->post->getInt('id', 0);
        /** @var DatabaseInterface $db */
        $db = Factory::getContainer()->get(DatabaseInterface::class);
        $q = $db->createQuery()->select('*')->from($db->quoteName('#__decaroforms_forms'))->where($db->quoteName('id') . ' = :id')->bind(':id', $sourceId);
        $db->setQuery($q);
        $source = $db->loadAssoc();
        if (!$source) {
            $app->enqueueMessage(Text::_('COM_DECAROFORMS_ERR_COPY_FORM_NOT_FOUND'), 'error');
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=forms', false));
            return;
        }

        $baseTitle = Text::sprintf('COM_DECAROFORMS_DUPLICATE_TITLE', (string) $source['title']);
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

        try {
            $db->transactionStart();
            $clone = new \stdClass();
            foreach ($source as $key => $value) {
                if ($key !== 'id') {
                    $clone->{$key} = $value;
                }
            }
            $now = Factory::getDate()->toSql();
            $clone->title = $title;
            $clone->slug = $slug;
            $clone->created_at = $now;
            $clone->updated_at = $now;
            $db->insertObject('#__decaroforms_forms', $clone, 'id');
            $newId = (int) $clone->id;

            $q = $db->createQuery()->select('*')->from($db->quoteName('#__decaroforms_fields'))->where($db->quoteName('form_id') . ' = :fid')->bind(':fid', $sourceId)->order([$db->quoteName('sort_order') . ' ASC', $db->quoteName('id') . ' ASC']);
            $db->setQuery($q);
            foreach ($db->loadAssocList() ?: [] as $field) {
                $record = new \stdClass();
                foreach ($field as $key => $value) {
                    if ($key !== 'id') {
                        $record->{$key} = $value;
                    }
                }
                $record->form_id = $newId;
                $db->insertObject('#__decaroforms_fields', $record);
            }
            $db->transactionCommit();
        } catch (Throwable $e) {
            $db->transactionRollback();
            $app->enqueueMessage(Text::sprintf('COM_DECAROFORMS_ERR_DUPLICATE_FAILED', $e->getMessage()), 'error');
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=forms', false));
            return;
        }

        $app->enqueueMessage(Text::_('COM_DECAROFORMS_MSG_FORM_DUPLICATED'), 'message');
        $app->redirect(Route::_('index.php?option=com_decaroforms&view=builder&id=' . $newId, false));
    }

    public function copy(): void
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

    public function delete(): void
    {
        $app = Factory::getApplication();
        if (!Session::checkToken('get') || !$app->getIdentity()->authorise('core.delete', 'com_decaroforms')) {
            throw new \RuntimeException(Text::_('COM_DECAROFORMS_ERR_TOKEN_PERMISSIONS'), 403);
        }
        $id = $app->getInput()->getInt('id', 0);
        if ($id > 0) {
            /** @var DatabaseInterface $db */
            $db = Factory::getContainer()->get(DatabaseInterface::class);
            foreach (['#__decaroforms_fields','#__decaroforms_submissions'] as $table) {
                $q = $db->createQuery()->delete($db->quoteName($table))->where($db->quoteName('form_id') . ' = :id')->bind(':id', $id);
                $db->setQuery($q)->execute();
            }
            $q = $db->createQuery()->delete($db->quoteName('#__decaroforms_forms'))->where($db->quoteName('id') . ' = :id')->bind(':id', $id);
            $db->setQuery($q)->execute();
            $app->enqueueMessage(Text::_('COM_DECAROFORMS_MSG_FORM_DELETED'), 'message');
        }
        $app->redirect(Route::_('index.php?option=com_decaroforms&view=forms', false));
    }
}
