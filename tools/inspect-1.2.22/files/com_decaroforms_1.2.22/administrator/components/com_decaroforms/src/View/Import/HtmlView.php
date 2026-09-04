<?php

namespace DeCaro\Component\Forms\Administrator\View\Import;

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\ImportHelper;
use DeCaro\Component\Forms\Administrator\Helper\MigrationHelper;
use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\View\HtmlView as BaseHtmlView;
use Joomla\CMS\Router\Route;
use Joomla\Database\DatabaseInterface;

final class HtmlView extends BaseHtmlView
{
    public string $stage='source'; public array $state=[]; public array $forms=[]; public array $targetFields=[]; public array $tables=[]; public array $lsfs=[];
    public string $prepareUrl=''; public string $runUrl=''; public string $resetUrl=''; public string $lsfsUrl=''; public string $formsUrl=''; public string $informationUrl='';
    public array $auto=[];
    public function display($tpl=null): void
    {
        $app=Factory::getApplication();/** @var DatabaseInterface $db */$db=Factory::getContainer()->get(DatabaseInterface::class);
        $this->stage=$app->input->getCmd('stage','source');$this->state=(array)$app->getSession()->get(ImportHelper::SESSION_KEY,[]);if($this->stage==='map'&&!$this->state)$this->stage='source';
        $this->forms=ImportHelper::listForms($db);$this->tables=ImportHelper::listJoomlaTables($db);$this->lsfs=MigrationHelper::inspect($db);
        if($this->stage==='map'&&(int)($this->state['target_form_id']??0)>0)$this->targetFields=ImportHelper::formFields($db,(int)$this->state['target_form_id']);
        $cols=(array)($this->state['columns']??[]);$this->auto=['email'=>ImportHelper::autoColumn($cols,['email','mail']),'status'=>ImportHelper::autoColumn($cols,['status','stato','statut']),'date'=>ImportHelper::autoColumn($cols,['created_at','created','timestamp','date','data']),'reference'=>ImportHelper::autoColumn($cols,['reference','riferimento','ref','id']),'note'=>ImportHelper::autoColumn($cols,['internal_note','note','notes','comment'])];
        $this->prepareUrl=Route::_('index.php?option=com_decaroforms&task=dataimport.prepare',false);$this->runUrl=Route::_('index.php?option=com_decaroforms&task=dataimport.run',false);$this->resetUrl=Route::_('index.php?option=com_decaroforms&task=dataimport.reset',false);$this->lsfsUrl=Route::_('index.php?option=com_decaroforms&view=migration',false);$this->formsUrl=Route::_('index.php?option=com_decaroforms&view=forms',false);$this->informationUrl=Route::_('index.php?option=com_decaroforms&view=information',false);
        $app->getDocument()->setTitle(Text::_('COM_DECAROFORMS_IMPORT_TITLE'));parent::display($tpl);
    }
}
