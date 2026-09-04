<?php

defined('_JEXEC') or die;

use Joomla\CMS\Dispatcher\ComponentDispatcherFactoryInterface;
use Joomla\CMS\Extension\Component;
use Joomla\CMS\Extension\ComponentInterface;
use Joomla\CMS\Extension\Service\Provider\ComponentDispatcherFactory as ComponentDispatcherFactoryServiceProvider;
use Joomla\CMS\Extension\Service\Provider\MVCFactory as MVCFactoryServiceProvider;
use Joomla\DI\Container;
use Joomla\DI\ServiceProviderInterface;

return new class implements ServiceProviderInterface {
    public function register(Container $container): void
    {
        $container->registerServiceProvider(new MVCFactoryServiceProvider('\\DeCaro\\Component\\Forms'));
        $container->registerServiceProvider(new ComponentDispatcherFactoryServiceProvider('\\DeCaro\\Component\\Forms'));
        $container->set(ComponentInterface::class, static fn (Container $container) => new Component($container->get(ComponentDispatcherFactoryInterface::class)));
    }
};
