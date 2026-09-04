<?php

namespace DeCaro\Component\Forms\Administrator\Controller;

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\MigrationHelper;
use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\Controller\BaseController;
use Joomla\CMS\Router\Route;
use Joomla\CMS\Session\Session;
use Joomla\Database\DatabaseInterface;
use Throwable;

final class MigrationController extends BaseController
{
    public function run(): void
    {
        $app = Factory::getApplication();
        if (!Session::checkToken('post') || !$app->getIdentity()->authorise('core.create', 'com_decaroforms')) {
            throw new \RuntimeException(Text::_('COM_DECAROFORMS_ERR_TOKEN_PERMISSIONS'), 403);
        }
        try {
            /** @var DatabaseInterface $db */
            $db = Factory::getContainer()->get(DatabaseInterface::class);
            $r = MigrationHelper::migrate($db);
            $app->enqueueMessage(Text::sprintf('COM_DECAROFORMS_MSG_MIGRATION_DONE', $r['forms_created'], $r['submissions_imported'], $r['files_imported'], $r['skipped']), 'message');
        } catch (Throwable $e) {
            $app->enqueueMessage(Text::sprintf('COM_DECAROFORMS_MSG_MIGRATION_STOPPED', $e->getMessage()), 'error');
        }
        $app->redirect(Route::_('index.php?option=com_decaroforms&view=migration', false));
    }
}
