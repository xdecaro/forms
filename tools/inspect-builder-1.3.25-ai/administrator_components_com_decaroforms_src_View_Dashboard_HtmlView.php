<?php

namespace DeCaro\Component\Forms\Administrator\View\Dashboard;

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\View\HtmlView as BaseHtmlView;
use Joomla\CMS\Router\Route;
use Joomla\Database\DatabaseInterface;

final class HtmlView extends BaseHtmlView
{
    public array $stats=[];
    public array $forms=[];
    public array $recent=[];
    public string $formsUrl=''; public string $builderUrl=''; public string $recentUrl=''; public string $importUrl=''; public string $informationUrl='';
    public function display($tpl=null): void
    {
        /** @var DatabaseInterface $db */ $db=Factory::getContainer()->get(DatabaseInterface::class);
        $this->stats=['forms'=>(int)$db->setQuery('SELECT COUNT(*) FROM '.$db->quoteName('#__decaroforms_forms'))->loadResult(),'active'=>(int)$db->setQuery('SELECT COUNT(*) FROM '.$db->quoteName('#__decaroforms_forms').' WHERE '.$db->quoteName('enabled').'=1')->loadResult(),'submissions'=>(int)$db->setQuery('SELECT COUNT(*) FROM '.$db->quoteName('#__decaroforms_submissions'))->loadResult(),'today'=>(int)$db->setQuery('SELECT COUNT(*) FROM '.$db->quoteName('#__decaroforms_submissions').' WHERE '.$db->quoteName('created_at').' >= '.$db->quote(Factory::getDate('today')->toSql()))->loadResult()];
        $q=$db->createQuery()->select(['f.id','f.title','f.enabled','COUNT(s.id) submission_count','MAX(s.created_at) last_submission'])->from($db->quoteName('#__decaroforms_forms','f'))->leftJoin($db->quoteName('#__decaroforms_submissions','s').' ON s.form_id=f.id')->group(['f.id','f.title','f.enabled'])->order('submission_count DESC, f.id DESC');$db->setQuery($q,0,8);$this->forms=$db->loadAssocList()?:[];
        $q=$db->createQuery()->select(['s.id','s.reference','s.email','s.status','s.created_at','f.title form_title'])->from($db->quoteName('#__decaroforms_submissions','s'))->innerJoin($db->quoteName('#__decaroforms_forms','f').' ON f.id=s.form_id')->order('s.created_at DESC');$db->setQuery($q,0,8);$this->recent=$db->loadAssocList()?:[];
        $this->formsUrl=Route::_('index.php?option=com_decaroforms&view=forms',false);$this->builderUrl=Route::_('index.php?option=com_decaroforms&view=builder',false);$this->recentUrl=Route::_('index.php?option=com_decaroforms&view=recent',false);$this->importUrl=Route::_('index.php?option=com_decaroforms&view=import',false);$this->informationUrl=Route::_('index.php?option=com_decaroforms&view=information',false);
        Factory::getApplication()->getDocument()->setTitle(Text::_('COM_DECAROFORMS_DASHBOARD'));parent::display($tpl);
    }
}
