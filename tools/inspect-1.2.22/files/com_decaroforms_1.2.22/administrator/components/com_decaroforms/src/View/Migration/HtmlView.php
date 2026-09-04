<?php

namespace DeCaro\Component\Forms\Administrator\View\Migration;

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\MigrationHelper;
use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\View\HtmlView as BaseHtmlView;
use Joomla\CMS\Router\Route;
use Joomla\Database\DatabaseInterface;

final class HtmlView extends BaseHtmlView
{
    public array $state=[];
    public string $runUrl='';
    public string $formsUrl='';
    public string $informationUrl='';
    public function display($tpl=null): void
    {
        /** @var DatabaseInterface $db */
        $db=Factory::getContainer()->get(DatabaseInterface::class);
        $this->state=MigrationHelper::inspect($db);
        $this->runUrl=Route::_('index.php?option=com_decaroforms&task=migration.run',false);
        $this->formsUrl=Route::_('index.php?option=com_decaroforms&view=forms',false);
        $this->informationUrl=Route::_('index.php?option=com_decaroforms&view=information',false);
        Factory::getApplication()->getDocument()->setTitle(Text::_('COM_DECAROFORMS_MIG_TITLE'));
        parent::display($tpl);
    }
}
