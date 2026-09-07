<?php

namespace DeCaro\Component\Forms\Administrator\View\Information;

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\View\HtmlView as BaseHtmlView;
use Joomla\CMS\Router\Route;

final class HtmlView extends BaseHtmlView
{
    public string $formsUrl = '';
    public string $builderUrl = '';
    public string $recentUrl = '';
    public string $importUrl = '';

    public function display($tpl = null): void
    {
        $this->formsUrl = Route::_('index.php?option=com_decaroforms&view=forms', false);
        $this->builderUrl = Route::_('index.php?option=com_decaroforms&view=builder', false);
        $this->recentUrl = Route::_('index.php?option=com_decaroforms&view=recent', false);
        $this->importUrl = Route::_('index.php?option=com_decaroforms&view=import', false);
        Factory::getApplication()->getDocument()->setTitle(Text::_('COM_DECAROFORMS_INFO_TITLE'));
        parent::display($tpl);
    }
}
