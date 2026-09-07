<?php

namespace DeCaro\Component\Forms\Administrator\Model;

defined('_JEXEC') or die;

use Joomla\CMS\MVC\Model\BaseDatabaseModel;
use Joomla\CMS\Version;
use Joomla\Database\ParameterType;

final class InformationModel extends BaseDatabaseModel
{
    public const UPDATE_SITE_URL = 'https://raw.githubusercontent.com/xdecaro/forms/main/updates/pkg_decaroforms.xml';
    public const MINIMUM_JOOMLA = '6.0.0';
    public const MINIMUM_PHP = '8.3.0';

    private const EXPECTED_TABLES = [
        '#__decaroforms_forms' => [
            'id', 'title', 'slug', 'enabled', 'statuses_json', 'list_columns_json',
            'builder_config_json', 'email_config_json', 'additional_emails_json',
            'integrations_json', 'custom_css', 'custom_js', 'created_at', 'updated_at',
        ],
        '#__decaroforms_fields' => [
            'id', 'form_id', 'field_key', 'field_type', 'label', 'options_json',
            'config_json', 'required', 'sort_order',
        ],
        '#__decaroforms_submissions' => [
            'id', 'form_id', 'reference', 'email', 'status', 'payload_json',
            'payment_json', 'internal_note', 'created_at', 'updated_at',
        ],
        '#__decaroforms_files' => [
            'id', 'submission_id', 'field_key', 'file_name', 'mime_type',
            'file_size', 'sha256', 'data_blob', 'created_at',
        ],
        '#__decaroforms_migrations' => [
            'id', 'source_component', 'source_table', 'source_id', 'target_type',
            'target_id', 'source_reference', 'migrated_at',
        ],
        '#__decaroforms_import_log' => [
            'id', 'source_type', 'source_name', 'source_key', 'target_id', 'imported_at',
        ],
    ];

    public function getInfo(): array
    {
        $db = $this->getDatabase();

        $component = $this->getExtension('component', 'com_decaroforms');
        $package = $this->getExtension('package', 'pkg_decaroforms');
        $systemPlugin = $this->getExtension('plugin', 'decaroforms', 'system');
        $editorPlugin = $this->getExtension('plugin', 'decaroforms', 'editors-xtd');

        $versions = [
            'component' => $this->getManifestVersion($component),
            'package' => $this->getManifestVersion($package),
            'system_plugin' => $this->getManifestVersion($systemPlugin),
            'editor_plugin' => $this->getManifestVersion($editorPlugin),
        ];

        $installedVersion = $versions['package'] ?: $versions['component'] ?: '0.0.0';
        $installationConsistent = $installedVersion !== '0.0.0';

        foreach ($versions as $version) {
            if ($version === '' || $version !== $installedVersion) {
                $installationConsistent = false;
                break;
            }
        }

        $tableHealth = $this->getTableHealth();
        $schemaAligned = $tableHealth['all_present'] && $tableHealth['columns_aligned'];

        $update = null;
        $updateSite = null;

        if ($package !== null) {
            $extensionId = (int) $package->extension_id;
            $location = self::UPDATE_SITE_URL;

            $query = $db->getQuery(true)
                ->select([$db->quoteName('version'), $db->quoteName('detailsurl')])
                ->from($db->quoteName('#__updates'))
                ->where($db->quoteName('extension_id') . ' = :extensionId')
                ->bind(':extensionId', $extensionId, ParameterType::INTEGER)
                ->order($db->quoteName('update_id') . ' DESC');
            $update = $db->setQuery($query, 0, 1)->loadObject();

            $query = $db->getQuery(true)
                ->select([
                    $db->quoteName('s.update_site_id'),
                    $db->quoteName('s.name'),
                    $db->quoteName('s.location'),
                    $db->quoteName('s.enabled'),
                    $db->quoteName('s.last_check_timestamp'),
                ])
                ->from($db->quoteName('#__update_sites', 's'))
                ->innerJoin(
                    $db->quoteName('#__update_sites_extensions', 'm')
                    . ' ON ' . $db->quoteName('m.update_site_id')
                    . ' = ' . $db->quoteName('s.update_site_id')
                )
                ->where($db->quoteName('m.extension_id') . ' = :extensionId')
                ->where($db->quoteName('s.location') . ' = :location')
                ->bind(':extensionId', $extensionId, ParameterType::INTEGER)
                ->bind(':location', $location);
            $updateSite = $db->setQuery($query, 0, 1)->loadObject();
        }

        $latestVersion = $update !== null ? trim((string) $update->version) : '';
        $updateAvailable = $latestVersion !== '' && version_compare($latestVersion, $installedVersion, 'gt');
        $lastCheckTimestamp = $updateSite !== null ? (int) $updateSite->last_check_timestamp : 0;
        $updateSiteEnabled = $updateSite !== null && (int) $updateSite->enabled === 1;
        $updateState = 'unchecked';

        if ($updateAvailable) {
            $updateState = 'available';
        } elseif ($updateSiteEnabled && $lastCheckTimestamp > 0) {
            $updateState = 'current';
        } elseif (!$updateSiteEnabled) {
            $updateState = 'inactive';
        }

        $joomlaVersion = (new Version())->getShortVersion();
        $phpVersion = PHP_VERSION;
        $environmentCompatible = version_compare($joomlaVersion, self::MINIMUM_JOOMLA, '>=')
            && version_compare($phpVersion, self::MINIMUM_PHP, '>=');

        $integrations = [
            $this->getRelatedComponent(
                'Courses by xdecaro',
                'com_decarocourses',
                'xdecaro/courses',
                false
            ),
        ];

        $systemPluginEnabled = $systemPlugin !== null && (int) ($systemPlugin->enabled ?? 0) === 1;
        $editorPluginEnabled = $editorPlugin !== null && (int) ($editorPlugin->enabled ?? 0) === 1;

        $criticalIssues = [];
        $warnings = [];

        if (!$installationConsistent) {
            $criticalIssues[] = 'versions';
        }
        if (!$schemaAligned) {
            $criticalIssues[] = 'database';
        }
        if (!$systemPluginEnabled) {
            $criticalIssues[] = 'system_plugin';
        }
        if (!$environmentCompatible) {
            $criticalIssues[] = 'environment';
        }
        if (!$updateSiteEnabled) {
            $warnings[] = 'update_site';
        }
        if (!$editorPluginEnabled) {
            $warnings[] = 'editor_plugin';
        }
        if ($updateAvailable) {
            $warnings[] = 'update_available';
        }

        return [
            'installed_version' => $installedVersion,
            'extension_versions' => $versions,
            'installation_consistent' => $installationConsistent,
            'system_plugin_installed' => $systemPlugin !== null,
            'system_plugin_enabled' => $systemPluginEnabled,
            'editor_plugin_installed' => $editorPlugin !== null,
            'editor_plugin_enabled' => $editorPluginEnabled,
            'latest_version' => $latestVersion,
            'update_available' => $updateAvailable,
            'update_state' => $updateState,
            'update_site_enabled' => $updateSiteEnabled,
            'update_site_url' => self::UPDATE_SITE_URL,
            'last_check_timestamp' => $lastCheckTimestamp,
            'joomla_version' => $joomlaVersion,
            'minimum_joomla' => self::MINIMUM_JOOMLA,
            'php_version' => $phpVersion,
            'minimum_php' => self::MINIMUM_PHP,
            'database_type' => method_exists($db, 'getServerType') ? (string) $db->getServerType() : (string) $db->getName(),
            'database_version' => (string) $db->getVersion(),
            'table_health' => $tableHealth,
            'schema_aligned' => $schemaAligned,
            'environment_compatible' => $environmentCompatible,
            'integrations' => $integrations,
            'critical_issues' => $criticalIssues,
            'warnings' => $warnings,
            'component_id' => 'com_decaroforms',
            'package_id' => 'pkg_decaroforms',
            'repository' => 'xdecaro/forms',
        ];
    }

    private function getExtension(string $type, string $element, ?string $folder = null): ?object
    {
        $db = $this->getDatabase();
        $typeValue = $type;
        $elementValue = $element;

        $query = $db->getQuery(true)
            ->select([
                $db->quoteName('extension_id'),
                $db->quoteName('manifest_cache'),
                $db->quoteName('enabled'),
                $db->quoteName('client_id'),
            ])
            ->from($db->quoteName('#__extensions'))
            ->where($db->quoteName('type') . ' = :type')
            ->where($db->quoteName('element') . ' = :element')
            ->bind(':type', $typeValue)
            ->bind(':element', $elementValue);

        if ($folder !== null) {
            $folderValue = $folder;
            $query->where($db->quoteName('folder') . ' = :folder')
                ->bind(':folder', $folderValue);
        }

        $row = $db->setQuery($query, 0, 1)->loadObject();

        return $row ?: null;
    }

    private function getManifestVersion(?object $extension): string
    {
        if ($extension === null || empty($extension->manifest_cache)) {
            return '';
        }

        $manifest = json_decode((string) $extension->manifest_cache, true);

        return is_array($manifest) ? trim((string) ($manifest['version'] ?? '')) : '';
    }

    private function getTableHealth(): array
    {
        $db = $this->getDatabase();
        $availableTables = array_flip($db->getTableList());
        $tables = [];
        $allPresent = true;
        $columnsAligned = true;

        foreach (self::EXPECTED_TABLES as $table => $requiredColumns) {
            $realTable = $db->replacePrefix($table);
            $present = isset($availableTables[$realTable]);
            $missingColumns = [];

            if ($present) {
                try {
                    $columns = array_change_key_case($db->getTableColumns($realTable, false), CASE_LOWER);
                    foreach ($requiredColumns as $requiredColumn) {
                        if (!array_key_exists(strtolower($requiredColumn), $columns)) {
                            $missingColumns[] = $requiredColumn;
                        }
                    }
                } catch (\Throwable) {
                    $missingColumns = $requiredColumns;
                }
            } else {
                $allPresent = false;
            }

            if ($missingColumns !== []) {
                $columnsAligned = false;
            }

            $tables[$table] = [
                'present' => $present,
                'missing_columns' => $missingColumns,
            ];
        }

        return [
            'tables' => $tables,
            'all_present' => $allPresent,
            'columns_aligned' => $columnsAligned,
            'present_count' => count(array_filter($tables, static fn (array $row): bool => $row['present'])),
            'expected_count' => count(self::EXPECTED_TABLES),
        ];
    }

    private function getRelatedComponent(
        string $name,
        string $element,
        string $repository,
        bool $required
    ): array {
        $extension = $this->getExtension('component', $element);

        return [
            'name' => $name,
            'element' => $element,
            'repository' => $repository,
            'required' => $required,
            'installed' => $extension !== null,
            'version' => $this->getManifestVersion($extension),
            'enabled' => $extension !== null && (int) ($extension->enabled ?? 0) === 1,
        ];
    }
}
