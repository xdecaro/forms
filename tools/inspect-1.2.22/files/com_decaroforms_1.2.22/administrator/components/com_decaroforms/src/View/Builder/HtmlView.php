<?php

namespace DeCaro\Component\Forms\Administrator\View\Builder;

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\FormHelper;
use Joomla\CMS\Component\ComponentHelper;
use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\View\HtmlView as BaseHtmlView;
use Joomla\CMS\Router\Route;
use Joomla\Database\DatabaseInterface;

final class HtmlView extends BaseHtmlView
{
    public array $form = [];
    public array $fields = [];
    public array $library = [];
    public string $saveUrl = '';
    public string $formsUrl = '';
    public string $deleteUrl = '';
    public string $defaultAdminEmail = '';

    public function display($tpl = null): void
    {
        $app = Factory::getApplication();
        $id = $app->getInput()->getInt('id', 0);
        /** @var DatabaseInterface $db */
        $db = Factory::getContainer()->get(DatabaseInterface::class);
        if ($id > 0) {
            $q = $db->createQuery()->select('*')->from($db->quoteName('#__decaroforms_forms'))->where($db->quoteName('id') . ' = :id')->bind(':id', $id);
            $db->setQuery($q);
            $this->form = $db->loadAssoc() ?: [];
            $q = $db->createQuery()->select('*')->from($db->quoteName('#__decaroforms_fields'))->where($db->quoteName('form_id') . ' = :id')->bind(':id', $id)->order('sort_order ASC, id ASC');
            $db->setQuery($q);
            $rows = $db->loadAssocList() ?: [];
            foreach ($rows as &$row) {
                $row['options'] = json_decode((string)($row['options_json'] ?? '[]'), true) ?: [];
            }
            unset($row);
            $this->fields = $rows;
        }
        $this->library = FormHelper::fieldLibrary();
        $params = ComponentHelper::getParams('com_decaroforms');
        $this->defaultAdminEmail = (string) $params->get('default_admin_email', '');
        $this->saveUrl = Route::_('index.php?option=com_decaroforms&task=builder.save', false);
        $this->formsUrl = Route::_('index.php?option=com_decaroforms&view=forms', false);
        $this->deleteUrl = $id > 0 ? Route::_('index.php?option=com_decaroforms&task=builder.delete&id=' . $id . '&' . Factory::getSession()->getFormToken() . '=1', false) : '';
        $app->getDocument()->setTitle($id > 0 ? Text::_('COM_DECAROFORMS_BUILDER_EDIT_TITLE') : Text::_('COM_DECAROFORMS_BUILDER_CREATE_TITLE'));
        parent::display($tpl);
    }
}
