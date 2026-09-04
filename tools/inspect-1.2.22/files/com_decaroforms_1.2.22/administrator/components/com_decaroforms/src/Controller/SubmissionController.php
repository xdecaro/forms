<?php

namespace DeCaro\Component\Forms\Administrator\Controller;

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\ExportHelper;
use DeCaro\Component\Forms\Administrator\Helper\FormHelper;
use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\Controller\BaseController;
use Joomla\CMS\Router\Route;
use Joomla\CMS\Session\Session;
use Joomla\Database\DatabaseInterface;

final class SubmissionController extends BaseController
{
    public function save(): void
    {
        $app = Factory::getApplication();
        if (!Session::checkToken('post') || !$app->getIdentity()->authorise('core.edit', 'com_decaroforms')) {
            throw new \RuntimeException(Text::_('COM_DECAROFORMS_ERR_TOKEN_PERMISSIONS'), 403);
        }

        $id = $app->getInput()->post->getInt('id', 0);
        $status = $app->getInput()->post->getCmd('status', 'new');
        $note = trim($app->getInput()->post->getString('internal_note', ''));
        $formId = 0;

        if ($id > 0) {
            /** @var DatabaseInterface $db */
            $db = Factory::getContainer()->get(DatabaseInterface::class);
            $q = $db->createQuery()
                ->select(['s.form_id','f.*'])
                ->from($db->quoteName('#__decaroforms_submissions','s'))
                ->innerJoin($db->quoteName('#__decaroforms_forms','f') . ' ON f.id=s.form_id')
                ->where('s.id=:id')->bind(':id',$id);
            $db->setQuery($q);
            $form = $db->loadAssoc() ?: [];
            $formId = (int) ($form['form_id'] ?? 0);
            $statuses = FormHelper::statusesForForm($form);
            $allowed = array_column($statuses,'key');
            if (!in_array($status,$allowed,true)) {
                $status = (string)($allowed[0]??'new');
            }
            $row = (object)[
                'id'=>$id,
                'status'=>$status,
                'internal_note'=>$note,
                'updated_at'=>Factory::getDate()->toSql(),
            ];
            $db->updateObject('#__decaroforms_submissions', $row, 'id');
            $app->enqueueMessage(Text::_('COM_DECAROFORMS_MSG_SUBMISSION_UPDATED'), 'message');
        }

        if ($formId > 0) {
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=submissions&form_id=' . $formId, false));
            return;
        }
        $app->redirect(Route::_('index.php?option=com_decaroforms&view=recent', false));
    }

    public function export(): void
    {
        $app = Factory::getApplication();
        if (!$app->getIdentity()->authorise('core.manage', 'com_decaroforms')) {
            throw new \RuntimeException(Text::_('JERROR_ALERTNOAUTHOR'), 403);
        }
        if (!Session::checkToken('get')) {
            throw new \RuntimeException(Text::_('JINVALID_TOKEN'), 403);
        }

        $input = $app->getInput();
        $formId = $input->getInt('form_id', 0);
        $format = strtolower($input->getCmd('export_format', 'csv'));
        $idsRaw = trim($input->getString('ids', ''));
        $ids = array_values(array_unique(array_filter(
            array_map('intval', preg_split('/[\s,;]+/', $idsRaw) ?: []),
            static fn(int $id): bool => $id > 0
        )));
        $ids = array_slice($ids, 0, 1000);

        if ($formId <= 0 || !in_array($format, ['csv','xlsx','pdf'], true)) {
            throw new \RuntimeException(Text::_('COM_DECAROFORMS_EXPORT_INVALID'), 400);
        }
        if (!$ids) {
            throw new \RuntimeException(Text::_('COM_DECAROFORMS_EXPORT_SELECT_REQUIRED'), 400);
        }

        /** @var DatabaseInterface $db */
        $db = Factory::getContainer()->get(DatabaseInterface::class);
        $fq = $db->createQuery()
            ->select([$db->quoteName('title'), $db->quoteName('slug'), $db->quoteName('statuses_json')])
            ->from($db->quoteName('#__decaroforms_forms'))
            ->where($db->quoteName('id') . ' = :id')->bind(':id', $formId);
        $db->setQuery($fq);
        $form = $db->loadAssoc();
        if (!$form) {
            throw new \RuntimeException(Text::_('COM_DECAROFORMS_EXPORT_INVALID'), 404);
        }

        $rows = ExportHelper::loadRows($formId, '', 'all', $ids);
        $statuses = FormHelper::statusesForForm($form);
        $base = preg_replace('/[^a-z0-9_-]+/i', '-', (string) ($form['slug'] ?: $form['title'])) ?: 'forms';
        $date = Factory::getDate()->format('Ymd-His');

        if ($format === 'csv') {
            [$headers, $matrix] = ExportHelper::matrix($rows, $statuses);
            $content = ExportHelper::csv($headers, $matrix);
            $mime = 'text/csv; charset=UTF-8';
            $ext = 'csv';
        } elseif ($format === 'xlsx') {
            [$headers, $matrix] = ExportHelper::matrix($rows, $statuses);
            $content = ExportHelper::xlsx($headers, $matrix);
            $mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
            $ext = 'xlsx';
        } else {
            $content = ExportHelper::pdf((string) $form['title'], $rows, $statuses);
            $mime = 'application/pdf';
            $ext = 'pdf';
        }

        $app->setHeader('Content-Type', $mime, true);
        $app->setHeader('Content-Disposition', 'attachment; filename="' . $base . '-' . $date . '.' . $ext . '"', true);
        $app->setHeader('Content-Length', (string) strlen($content), true);
        $app->setHeader('Cache-Control', 'no-store, no-cache, must-revalidate', true);
        $app->sendHeaders();
        echo $content;
        $app->close();
    }
}
