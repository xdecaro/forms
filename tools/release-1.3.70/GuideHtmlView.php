<?php

namespace DeCaro\Component\Forms\Administrator\View\Guide;

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\View\HtmlView as BaseHtmlView;
use Joomla\CMS\Router\Route;
use Joomla\CMS\Toolbar\ToolbarHelper;

final class HtmlView extends BaseHtmlView
{
    public string $formsUrl = '';
    public string $builderUrl = '';
    public string $recentUrl = '';
    public string $importUrl = '';

    public function display($tpl = null): void
    {
        $app = Factory::getApplication();
        $user = $app->getIdentity();

        if (!$user->authorise('core.manage', 'com_decaroforms')) {
            throw new \RuntimeException(Text::_('JERROR_ALERTNOAUTHOR'), 403);
        }

        $this->formsUrl = Route::_('index.php?option=com_decaroforms&view=forms', false);
        $this->builderUrl = Route::_('index.php?option=com_decaroforms&view=builder', false);
        $this->recentUrl = Route::_('index.php?option=com_decaroforms&view=recent', false);
        $this->importUrl = Route::_('index.php?option=com_decaroforms&view=import', false);

        ToolbarHelper::title(Text::_('COM_DECAROFORMS_GUIDE'), 'question-circle');
        $app->getDocument()->setTitle(Text::_('COM_DECAROFORMS_GUIDE_TITLE'));

        parent::display($tpl);
    }
}
