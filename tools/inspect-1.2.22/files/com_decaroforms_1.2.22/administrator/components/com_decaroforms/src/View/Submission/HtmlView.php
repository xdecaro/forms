<?php

namespace DeCaro\Component\Forms\Administrator\View\Submission;

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\View\HtmlView as BaseHtmlView;
use Joomla\Database\DatabaseInterface;
use DeCaro\Component\Forms\Administrator\Helper\FormHelper;

final class HtmlView extends BaseHtmlView
{
    public array $submission = [];
    public array $form = [];
    public array $payload = [];
    public array $files = [];
    public array $statuses = [];

    public function display($tpl = null): void
    {
        $id = Factory::getApplication()->getInput()->getInt('id',0);
        /** @var DatabaseInterface $db */
        $db = Factory::getContainer()->get(DatabaseInterface::class);
        if ($id > 0) {
            $q=$db->createQuery()->select('*')->from($db->quoteName('#__decaroforms_submissions'))->where($db->quoteName('id').'=:id')->bind(':id',$id); $db->setQuery($q); $this->submission=$db->loadAssoc()?:[];
            if ($this->submission) {
                $fid=(int)$this->submission['form_id'];
                $q=$db->createQuery()->select('*')->from($db->quoteName('#__decaroforms_forms'))->where($db->quoteName('id').'=:fid')->bind(':fid',$fid); $db->setQuery($q); $this->form=$db->loadAssoc()?:[];
                $this->statuses=FormHelper::statusesForForm($this->form);
                $this->payload=json_decode((string)$this->submission['payload_json'],true)?:[];
                $q=$db->createQuery()->select('*')->from($db->quoteName('#__decaroforms_files'))->where($db->quoteName('submission_id').'=:sid')->bind(':sid',$id)->order('id ASC'); $db->setQuery($q); $this->files=$db->loadAssocList()?:[];
            }
        }
        Factory::getApplication()->getDocument()->setTitle(Text::_('COM_DECAROFORMS_SUBMISSION'));
        parent::display($tpl);
    }
}
