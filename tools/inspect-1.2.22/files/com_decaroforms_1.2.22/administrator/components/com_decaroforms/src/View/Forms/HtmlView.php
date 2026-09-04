<?php

namespace DeCaro\Component\Forms\Administrator\View\Forms;

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\View\HtmlView as BaseHtmlView;
use Joomla\CMS\Router\Route;
use Joomla\Database\DatabaseInterface;

final class HtmlView extends BaseHtmlView
{
    public array $forms = [];
    public string $builderUrl = '';
    public string $recentUrl = '';
    public string $informationUrl = '';
    public string $importUrl = '';
    public string $dashboardUrl = '';

    public function display($tpl = null): void
    {
        /** @var DatabaseInterface $db */
        $db = Factory::getContainer()->get(DatabaseInterface::class);
        $q = $db->createQuery()
            ->select(['f.*','COUNT(s.id) AS submission_count'])
            ->from($db->quoteName('#__decaroforms_forms','f'))
            ->leftJoin($db->quoteName('#__decaroforms_submissions','s') . ' ON s.form_id = f.id')
            ->group('f.id')
            ->order('f.updated_at DESC, f.id DESC');
        $db->setQuery($q);
        $this->forms = $db->loadAssocList() ?: [];
        $this->builderUrl = Route::_('index.php?option=com_decaroforms&view=builder', false);
        $this->recentUrl = Route::_('index.php?option=com_decaroforms&view=recent', false);
        $this->informationUrl = Route::_('index.php?option=com_decaroforms&view=information', false);
        $this->importUrl = Route::_('index.php?option=com_decaroforms&view=import', false);
        $this->dashboardUrl = Route::_('index.php?option=com_decaroforms&view=dashboard', false);
        Factory::getApplication()->getDocument()->setTitle(Text::_('COM_DECAROFORMS_FORMS'));
        parent::display($tpl);
    }
}
