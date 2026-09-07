<?php

namespace DeCaro\Component\Forms\Administrator\View\Information;

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\View\HtmlView as BaseHtmlView;
use Joomla\CMS\Toolbar\ToolbarHelper;

final class HtmlView extends BaseHtmlView
{
    public array $info = [];
    public bool $canManageInstaller = false;

    public function display($tpl = null): void
    {
        $app = Factory::getApplication();
        $user = $app->getIdentity();

        if (!$user->authorise('core.manage', 'com_decaroforms')) {
            throw new \RuntimeException(Text::_('JERROR_ALERTNOAUTHOR'), 403);
        }

        $document = $app->getDocument();
        $wa = $document->getWebAssetManager();

        if (!$wa->assetExists('style', 'com_decaroforms.information')) {
            $wa->registerStyle(
                'com_decaroforms.information',
                'com_decaroforms/css/information.css',
                ['version' => '1.3.70']
            );
        }

        if (!$wa->assetExists('script', 'com_decaroforms.information')) {
            $wa->registerScript(
                'com_decaroforms.information',
                'com_decaroforms/js/information.js',
                ['version' => '1.3.70'],
                ['defer' => true]
            );
        }

        $wa->useStyle('com_decaroforms.information');
        $wa->useScript('com_decaroforms.information');

        $this->info = (array) $this->get('Info');
        $this->canManageInstaller = $user->authorise('core.manage', 'com_installer');

        if (count($errors = $this->get('Errors'))) {
            throw new \RuntimeException(implode("\n", $errors));
        }

        ToolbarHelper::title(Text::_('COM_DECAROFORMS_INFORMATION'), 'info-circle');
        $document->setTitle(Text::_('COM_DECAROFORMS_INFO_TITLE'));

        parent::display($tpl);
    }
}
