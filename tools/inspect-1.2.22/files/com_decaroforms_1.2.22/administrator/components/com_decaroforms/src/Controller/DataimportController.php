<?php

namespace DeCaro\Component\Forms\Administrator\Controller;

defined('_JEXEC') or die;

use DeCaro\Component\Forms\Administrator\Helper\ImportHelper;
use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\Controller\BaseController;
use Joomla\CMS\Router\Route;
use Joomla\CMS\Session\Session;
use Joomla\Database\DatabaseInterface;
use Throwable;

final class DataimportController extends BaseController
{
    private function check(): void
    {
        $app=Factory::getApplication();
        if(!Session::checkToken('post')||!$app->getIdentity()->authorise('core.create','com_decaroforms'))throw new \RuntimeException(Text::_('COM_DECAROFORMS_ERR_TOKEN_PERMISSIONS'),403);
    }

    public function prepare(): void
    {
        $app=Factory::getApplication();
        try{
            $this->check();
            /** @var DatabaseInterface $db */ $db=Factory::getContainer()->get(DatabaseInterface::class);
            $input=$app->input;$type=$input->post->getCmd('source_type');$target=$input->post->getInt('target_form_id',0);
            $old=(array)$app->getSession()->get(ImportHelper::SESSION_KEY,[]);ImportHelper::cleanupStateFile($old);
            $state=match($type){
                'joomla_db'=>ImportHelper::prepareJoomla($db,$input->post->getString('joomla_table'),$target),
                'csv'=>ImportHelper::prepareCsv((array)$input->files->get('csv_file',null,'array'),$target),
                'google_sheets','google_forms'=>ImportHelper::prepareGoogle($type,$input->post->getString('google_url'),$target),
                'external_db'=>ImportHelper::prepareExternal(['host'=>$input->post->getString('ext_host'),'port'=>$input->post->getInt('ext_port',3306),'database'=>$input->post->getString('ext_database'),'username'=>$input->post->getString('ext_username'),'password'=>$input->post->getRaw('ext_password'),'table'=>$input->post->getString('ext_table')],$target),
                default=>throw new \RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_SOURCE')),
            };
            $app->getSession()->set(ImportHelper::SESSION_KEY,$state);
            $app->enqueueMessage(Text::sprintf('COM_DECAROFORMS_IMPORT_SOURCE_READY',(int)$state['count']),'message');
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=import&stage=map',false));
        }catch(Throwable $e){$app->enqueueMessage($e->getMessage(),'error');$app->redirect(Route::_('index.php?option=com_decaroforms&view=import',false));}
    }

    public function run(): void
    {
        $app=Factory::getApplication();
        try{
            $this->check();
            $state=(array)$app->getSession()->get(ImportHelper::SESSION_KEY,[]);if(!$state)throw new \RuntimeException(Text::_('COM_DECAROFORMS_IMPORT_ERR_SESSION'));
            /** @var DatabaseInterface $db */ $db=Factory::getContainer()->get(DatabaseInterface::class);
            $post=$app->input->post;
            $result=ImportHelper::run($db,$state,['map'=>(array)$post->get('map',[],'array'),'include'=>(array)$post->get('include',[],'array'),'new_form_title'=>$post->getString('new_form_title'),'email_column'=>$post->getString('email_column'),'status_column'=>$post->getString('status_column'),'date_column'=>$post->getString('date_column'),'reference_column'=>$post->getString('reference_column'),'note_column'=>$post->getString('note_column'),'limit'=>$post->getInt('limit',ImportHelper::MAX_ROWS)]);
            $app->getSession()->set(ImportHelper::SESSION_KEY,[]);
            $app->enqueueMessage(Text::sprintf('COM_DECAROFORMS_IMPORT_DONE',$result['imported'],$result['skipped'],$result['processed']),'message');
            $app->redirect(Route::_('index.php?option=com_decaroforms&view=submissions&form_id='.(int)$result['form_id'],false));
        }catch(Throwable $e){$app->enqueueMessage(Text::sprintf('COM_DECAROFORMS_IMPORT_STOPPED',$e->getMessage()),'error');$app->redirect(Route::_('index.php?option=com_decaroforms&view=import&stage=map',false));}
    }

    public function reset(): void
    {
        $app=Factory::getApplication();
        try{$this->check();$state=(array)$app->getSession()->get(ImportHelper::SESSION_KEY,[]);ImportHelper::cleanupStateFile($state);$app->getSession()->set(ImportHelper::SESSION_KEY,[]);}catch(Throwable $e){$app->enqueueMessage($e->getMessage(),'error');}
        $app->redirect(Route::_('index.php?option=com_decaroforms&view=import',false));
    }
}
