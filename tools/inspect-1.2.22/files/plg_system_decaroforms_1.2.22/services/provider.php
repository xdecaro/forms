<?php

defined('_JEXEC') or die;

use DeCaro\Plugin\System\Forms\Extension\FormsPlugin;
use Joomla\CMS\Extension\PluginInterface;
use Joomla\CMS\Factory;
use Joomla\CMS\Plugin\PluginHelper;
use Joomla\DI\Container;
use Joomla\DI\ServiceProviderInterface;
use Joomla\Event\DispatcherInterface;

return new class implements ServiceProviderInterface {
    public function register(Container $container): void
    {
        $container->set(PluginInterface::class, static function (Container $container) {
            $plugin = new FormsPlugin($container->get(DispatcherInterface::class), (array) PluginHelper::getPlugin('system', 'decaroforms'));
            $plugin->setApplication(Factory::getApplication());
            $plugin->setDatabase(Factory::getContainer()->get(\Joomla\Database\DatabaseInterface::class));
            return $plugin;
        });
    }
};
