<?php

namespace DeCaro\Component\Forms\Administrator\View\Submissions;

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\FormHelper;
use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\View\HtmlView as BaseHtmlView;
use Joomla\Database\DatabaseInterface;

final class HtmlView extends BaseHtmlView
{
    public array $form = [];
    public array $submissions = [];
    public array $fields = [];
    public array $statuses = [];
    public array $columns = [];
    public array $stats = [];

    public function display($tpl = null): void
    {
        $fid = Factory::getApplication()->getInput()->getInt('form_id', 0);
        /** @var DatabaseInterface $db */
        $db = Factory::getContainer()->get(DatabaseInterface::class);

        if ($fid > 0) {
            $q = $db->createQuery()
                ->select('*')
                ->from($db->quoteName('#__decaroforms_forms'))
                ->where($db->quoteName('id') . ' = :id')
                ->bind(':id', $fid);
            $db->setQuery($q);
            $this->form = $db->loadAssoc() ?: [];

            $q = $db->createQuery()
                ->select('*')
                ->from($db->quoteName('#__decaroforms_fields'))
                ->where($db->quoteName('form_id') . ' = :id')
                ->bind(':id', $fid)
                ->order('sort_order ASC,id ASC');
            $db->setQuery($q);
            $this->fields = $db->loadAssocList() ?: [];

            $this->statuses = FormHelper::statusesForForm($this->form);
            $this->columns = FormHelper::listColumnsForForm($this->form);

            $q = $db->createQuery()
                ->select('*')
                ->from($db->quoteName('#__decaroforms_submissions'))
                ->where($db->quoteName('form_id') . ' = :id')
                ->bind(':id', $fid)
                ->order('created_at DESC');
            $db->setQuery($q);
            $this->submissions = $db->loadAssocList() ?: [];

            $counts = [];
            foreach ($this->submissions as &$submission) {
                $submission['payload'] = json_decode((string) ($submission['payload_json'] ?? '{}'), true) ?: [];
                $status = (string) ($submission['status'] ?? '');
                $counts[$status] = ($counts[$status] ?? 0) + 1;
            }
            unset($submission);

            $this->stats = ['total' => count($this->submissions), 'statuses' => []];
            foreach ($this->statuses as $status) {
                $key = (string) ($status['key'] ?? '');
                $this->stats['statuses'][] = [
                    'key' => $key,
                    'label' => (string) ($status['label'] ?? $key),
                    'color' => FormHelper::statusColor($key, $this->statuses),
                    'count' => $counts[$key] ?? 0,
                ];
            }
        }

        Factory::getApplication()->getDocument()->setTitle(Text::_('COM_DECAROFORMS_SUBMISSIONS'));
        parent::display($tpl);
    }
}
