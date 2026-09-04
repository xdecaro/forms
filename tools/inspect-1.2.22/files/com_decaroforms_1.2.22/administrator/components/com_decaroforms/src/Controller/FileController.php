<?php

namespace DeCaro\Component\Forms\Administrator\Controller;

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\Controller\BaseController;
use Joomla\CMS\Session\Session;
use Joomla\Database\DatabaseInterface;

final class FileController extends BaseController
{
    public function download(): void
    {
        $app = Factory::getApplication();
        if (!Session::checkToken('get') || !$app->getIdentity()->authorise('core.manage', 'com_decaroforms')) {
            throw new \RuntimeException(Text::_('COM_DECAROFORMS_ERR_TOKEN_PERMISSIONS'), 403);
        }
        $id = $app->getInput()->getInt('id', 0);
        /** @var DatabaseInterface $db */
        $db = Factory::getContainer()->get(DatabaseInterface::class);
        $q = $db->createQuery()->select('*')->from($db->quoteName('#__decaroforms_files'))->where($db->quoteName('id') . ' = :id')->bind(':id', $id);
        $db->setQuery($q);
        $file = $db->loadAssoc();
        if (!$file) {
            throw new \RuntimeException(Text::_('COM_DECAROFORMS_ERR_FILE_NOT_FOUND'), 404);
        }
        $name = preg_replace('/[^A-Za-z0-9._ -]/', '_', (string) $file['file_name']) ?: 'attachment';
        header('Content-Type: ' . (string) $file['mime_type']);
        header('Content-Length: ' . (int) $file['file_size']);
        header('Content-Disposition: attachment; filename="' . addslashes($name) . '"');
        echo $file['data_blob'];
        $app->close();
    }
}
