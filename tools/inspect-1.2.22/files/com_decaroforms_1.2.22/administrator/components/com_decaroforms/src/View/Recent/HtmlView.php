<?php

namespace DeCaro\Component\Forms\Administrator\View\Recent;

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\FormHelper;
use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\View\HtmlView as BaseHtmlView;
use Joomla\Database\DatabaseInterface;

final class HtmlView extends BaseHtmlView
{
    public array $submissions = [];
    public array $forms = [];
    public array $statusOptions = [];
    public array $stats = [];

    public function display($tpl = null): void
    {
        /** @var DatabaseInterface $db */
        $db = Factory::getContainer()->get(DatabaseInterface::class);

        $q = $db->createQuery()
            ->select(['id','title','statuses_json'])
            ->from($db->quoteName('#__decaroforms_forms'))
            ->order($db->quoteName('title') . ' ASC');
        $db->setQuery($q);
        $this->forms = $db->loadAssocList() ?: [];

        $statusLabels = [];
        foreach ($this->forms as $form) {
            foreach (FormHelper::statusesForForm($form) as $status) {
                $key = (string) ($status['key'] ?? '');
                $label = (string) ($status['label'] ?? $key);
                if ($key !== '' && !isset($statusLabels[$key])) {
                    $statusLabels[$key] = $label;
                }
            }
        }
        foreach (FormHelper::defaultStatuses() as $status) {
            $key = (string) ($status['key'] ?? '');
            if ($key !== '' && !isset($statusLabels[$key])) {
                $statusLabels[$key] = (string) ($status['label'] ?? $key);
            }
        }
        foreach ($statusLabels as $key => $label) {
            $this->statusOptions[] = ['key' => $key, 'label' => $label];
        }

        $total = (int) $db->setQuery(
            'SELECT COUNT(*) FROM ' . $db->quoteName('#__decaroforms_submissions')
        )->loadResult();

        $counts = [];
        $q = $db->createQuery()
            ->select([$db->quoteName('status'), 'COUNT(*) AS total'])
            ->from($db->quoteName('#__decaroforms_submissions'))
            ->group($db->quoteName('status'));
        $db->setQuery($q);
        foreach ($db->loadAssocList() ?: [] as $row) {
            $counts[(string) $row['status']] = (int) $row['total'];
        }
        $this->stats = [
            'total' => $total,
            'new' => $counts['new'] ?? 0,
            'processing' => $counts['processing'] ?? 0,
            'replied' => $counts['replied'] ?? 0,
            'closed' => $counts['closed'] ?? 0,
            'spam' => $counts['spam'] ?? 0,
        ];

        $q = $db->createQuery()
            ->select(['s.*','f.title AS form_title','f.statuses_json AS form_statuses_json'])
            ->from($db->quoteName('#__decaroforms_submissions','s'))
            ->leftJoin($db->quoteName('#__decaroforms_forms','f') . ' ON f.id=s.form_id')
            ->order('s.created_at DESC');
        $db->setQuery($q, 0, 500);
        $this->submissions = $db->loadAssocList() ?: [];

        foreach ($this->submissions as &$submission) {
            $payload = json_decode((string) ($submission['payload_json'] ?? '{}'), true) ?: [];
            $parts = [
                (string) ($submission['form_title'] ?? ''),
                (string) ($submission['reference'] ?? ''),
                (string) ($submission['email'] ?? ''),
            ];
            foreach ($payload as $label => $value) {
                $parts[] = (string) $label;
                $parts[] = is_array($value) ? implode(' ', array_map('strval', $value)) : (string) $value;
            }
            $submission['_search_text'] = mb_strtolower(implode(' ', $parts), 'UTF-8');
            $statuses = FormHelper::statusesForForm(['statuses_json' => $submission['form_statuses_json'] ?? '']);
            $statusKey = (string) ($submission['status'] ?? '');
            $submission['_status_label'] = FormHelper::statusLabel($statusKey, $statuses);
            $submission['_status_badge_style'] = FormHelper::statusBadgeStyle($statusKey, $statuses);
        }
        unset($submission);

        Factory::getApplication()->getDocument()->setTitle(Text::_('COM_DECAROFORMS_RECENT'));
        parent::display($tpl);
    }
}
