<?php

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Installer\InstallerAdapter;
use Joomla\CMS\Installer\InstallerScriptInterface;
use Joomla\Database\DatabaseInterface;

return new class () implements InstallerScriptInterface {
    private string $minimumJoomla = '6.0.0';
    private string $minimumPhp = '8.3.0';

    public function install(InstallerAdapter $adapter): bool { return true; }
    public function update(InstallerAdapter $adapter): bool { return true; }
    public function uninstall(InstallerAdapter $adapter): bool { return true; }

    public function preflight(string $type, InstallerAdapter $adapter): bool
    {
        if (version_compare(PHP_VERSION, $this->minimumPhp, '<')) {
            Factory::getApplication()->enqueueMessage('Forms requires PHP ' . $this->minimumPhp . ' or later.', 'error');
            return false;
        }
        if (version_compare(JVERSION, $this->minimumJoomla, '<')) {
            Factory::getApplication()->enqueueMessage('Forms requires Joomla ' . $this->minimumJoomla . ' or later.', 'error');
            return false;
        }
        return true;
    }

    public function postflight(string $type, InstallerAdapter $adapter): bool
    {
        /** @var DatabaseInterface $db */
        $db = Factory::getContainer()->get(DatabaseInterface::class);

        $queries = [
<<<SQL
CREATE TABLE IF NOT EXISTS `#__decaroforms_forms` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `title` varchar(190) NOT NULL,
  `slug` varchar(120) NOT NULL,
  `description` text NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  `show_heading` tinyint(1) NOT NULL DEFAULT 1,
  `success_message` text NULL,
  `closed_reason` varchar(40) NOT NULL DEFAULT 'closed',
  `closed_message` text NULL,
  `admin_email` varchar(190) NOT NULL DEFAULT '',
  `user_confirmation` tinyint(1) NOT NULL DEFAULT 0,
  `email_template_user` varchar(30) NOT NULL DEFAULT 'standard',
  `email_template_admin` varchar(30) NOT NULL DEFAULT 'standard',
  `email_subject_user` varchar(190) NOT NULL DEFAULT '',
  `email_subject_admin` varchar(190) NOT NULL DEFAULT '',
  `statuses_json` longtext NULL,
  `list_columns_json` longtext NULL,
  `builder_config_json` longtext NULL,
  `email_config_json` longtext NULL,
  `additional_emails_json` longtext NULL,
  `integrations_json` longtext NULL,
  `custom_css` longtext NULL,
  `custom_js` longtext NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_decaroforms_slug` (`slug`),
  KEY `idx_decaroforms_enabled` (`enabled`),
  KEY `idx_decaroforms_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
SQL,
<<<SQL
CREATE TABLE IF NOT EXISTS `#__decaroforms_fields` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `form_id` int unsigned NOT NULL,
  `field_key` varchar(120) NOT NULL,
  `field_type` varchar(40) NOT NULL,
  `category` varchar(40) NOT NULL DEFAULT 'other',
  `label` varchar(190) NOT NULL,
  `placeholder` varchar(190) NOT NULL DEFAULT '',
  `help_text` text NULL,
  `default_value` text NULL,
  `options_json` text NULL,
  `config_json` longtext NULL,
  `required` tinyint(1) NOT NULL DEFAULT 0,
  `sort_order` int NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_decaroforms_field_key` (`form_id`,`field_key`),
  KEY `idx_decaroforms_field_form` (`form_id`),
  KEY `idx_decaroforms_field_order` (`form_id`,`sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
SQL,
<<<SQL
CREATE TABLE IF NOT EXISTS `#__decaroforms_submissions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `form_id` int unsigned NOT NULL,
  `reference` varchar(48) NOT NULL,
  `email` varchar(190) NOT NULL DEFAULT '',
  `status` varchar(30) NOT NULL DEFAULT 'new',
  `payload_json` longtext NOT NULL,
  `payment_json` longtext NULL,
  `internal_note` text NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_decaroforms_reference` (`reference`),
  KEY `idx_decaroforms_submission_form` (`form_id`),
  KEY `idx_decaroforms_submission_email` (`email`),
  KEY `idx_decaroforms_submission_status` (`status`),
  KEY `idx_decaroforms_submission_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
SQL,
<<<SQL
CREATE TABLE IF NOT EXISTS `#__decaroforms_files` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `submission_id` int unsigned NOT NULL,
  `field_key` varchar(120) NOT NULL,
  `file_name` varchar(190) NOT NULL,
  `mime_type` varchar(100) NOT NULL,
  `file_size` int unsigned NOT NULL,
  `sha256` char(64) NOT NULL,
  `data_blob` longblob NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_decaroforms_file_submission` (`submission_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
SQL,
<<<SQL
CREATE TABLE IF NOT EXISTS `#__decaroforms_migrations` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `source_component` varchar(120) NOT NULL,
  `source_table` varchar(160) NOT NULL,
  `source_id` int unsigned NOT NULL DEFAULT 0,
  `target_type` varchar(30) NOT NULL,
  `target_id` int unsigned NOT NULL,
  `source_reference` varchar(80) NOT NULL DEFAULT '',
  `migrated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_decaroforms_migration_source` (`source_component`,`source_table`,`source_id`,`target_type`),
  KEY `idx_decaroforms_migration_target` (`target_type`,`target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
SQL,

<<<SQL
CREATE TABLE IF NOT EXISTS `#__decaroforms_import_log` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `source_type` varchar(40) NOT NULL,
  `source_name` varchar(255) NOT NULL,
  `source_key` char(64) NOT NULL,
  `target_id` int unsigned NOT NULL,
  `imported_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_decaroforms_import_source` (`source_type`,`source_name`,`source_key`),
  KEY `idx_decaroforms_import_target` (`target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
SQL,
        ];

        foreach ($queries as $sql) {
            $db->setQuery($db->replacePrefix($sql));
            $db->execute();
        }

        // Upgrade existing installations without losing forms/submissions.
        $formTable = $db->replacePrefix('#__decaroforms_forms');
        $columns = $db->getTableColumns($formTable, false);
        if (!isset($columns['statuses_json'])) {
            $db->setQuery('ALTER TABLE ' . $db->quoteName($formTable) . ' ADD ' . $db->quoteName('statuses_json') . ' LONGTEXT NULL AFTER ' . $db->quoteName('email_subject_admin'));
            $db->execute();
        }
        $columns = $db->getTableColumns($formTable, false);
        if (!isset($columns['list_columns_json'])) {
            $db->setQuery('ALTER TABLE ' . $db->quoteName($formTable) . ' ADD ' . $db->quoteName('list_columns_json') . ' LONGTEXT NULL AFTER ' . $db->quoteName('statuses_json'));
            $db->execute();
        }

        $columns = $db->getTableColumns($formTable, false);
        foreach ([
            'builder_config_json' => 'list_columns_json',
            'email_config_json' => 'builder_config_json',
            'additional_emails_json' => 'email_config_json',
            'integrations_json' => 'additional_emails_json',
            'custom_css' => 'integrations_json',
            'custom_js' => 'custom_css',
        ] as $column => $after) {
            if (!isset($columns[$column])) {
                $db->setQuery('ALTER TABLE ' . $db->quoteName($formTable) . ' ADD ' . $db->quoteName($column) . ' LONGTEXT NULL AFTER ' . $db->quoteName($after));
                $db->execute();
                $columns[$column] = true;
            }
        }

        $fieldTable = $db->replacePrefix('#__decaroforms_fields');
        $fieldColumns = $db->getTableColumns($fieldTable, false);
        if (!isset($fieldColumns['config_json'])) {
            $db->setQuery('ALTER TABLE ' . $db->quoteName($fieldTable) . ' ADD ' . $db->quoteName('config_json') . ' LONGTEXT NULL AFTER ' . $db->quoteName('options_json'));
            $db->execute();
        }

        $submissionTable = $db->replacePrefix('#__decaroforms_submissions');
        $submissionColumns = $db->getTableColumns($submissionTable, false);
        if (!isset($submissionColumns['payment_json'])) {
            $db->setQuery('ALTER TABLE ' . $db->quoteName($submissionTable) . ' ADD ' . $db->quoteName('payment_json') . ' LONGTEXT NULL AFTER ' . $db->quoteName('payload_json'));
            $db->execute();
        }

        // The package installs the editor button before the component; enable it automatically.
        try {
            $q = $db->createQuery()
                ->update($db->quoteName('#__extensions'))
                ->set($db->quoteName('enabled') . ' = 1')
                ->where($db->quoteName('type') . ' = ' . $db->quote('plugin'))
                ->where($db->quoteName('folder') . ' = ' . $db->quote('editors-xtd'))
                ->where($db->quoteName('element') . ' = ' . $db->quote('decaroforms'));
            $db->setQuery($q)->execute();
        } catch (\Throwable $e) {
            Factory::getApplication()->enqueueMessage('Forms è stato aggiornato, ma il pulsante editor potrebbe richiedere l’attivazione manuale in Plugin.', 'warning');
        }

        foreach ([
            JPATH_ADMINISTRATOR . '/components/com_decaroforms/tmpl/builder/default.php',
            JPATH_ADMINISTRATOR . '/components/com_decaroforms/src/Controller/BuilderController.php',
            JPATH_ADMINISTRATOR . '/components/com_decaroforms/src/Helper/FormHelper.php',
        ] as $phpFile) {
            if (is_file($phpFile)) {
                clearstatcache(true, $phpFile);
                if (function_exists('opcache_invalidate')) { @opcache_invalidate($phpFile, true); }
            }
        }

        return true;
    }
};
