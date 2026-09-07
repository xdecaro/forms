<?php

defined('_JEXEC') or die;

use Joomla\CMS\Language\Text;
use Joomla\CMS\Router\Route;

$info = $this->info;
$installedVersion = (string) ($info['installed_version'] ?? '0.0.0');
$versions = (array) ($info['extension_versions'] ?? []);
$installationConsistent = !empty($info['installation_consistent']);
$schemaAligned = !empty($info['schema_aligned']);
$environmentCompatible = !empty($info['environment_compatible']);
$systemPluginInstalled = !empty($info['system_plugin_installed']);
$systemPluginEnabled = !empty($info['system_plugin_enabled']);
$editorPluginInstalled = !empty($info['editor_plugin_installed']);
$editorPluginEnabled = !empty($info['editor_plugin_enabled']);
$updateSiteEnabled = !empty($info['update_site_enabled']);
$updateAvailable = !empty($info['update_available']);
$updateState = (string) ($info['update_state'] ?? 'unchecked');
$latestVersion = (string) ($info['latest_version'] ?? '');
$lastCheck = (int) ($info['last_check_timestamp'] ?? 0);
$tableHealth = (array) ($info['table_health'] ?? []);
$integrations = (array) ($info['integrations'] ?? []);
$criticalIssues = (array) ($info['critical_issues'] ?? []);
$warnings = (array) ($info['warnings'] ?? []);
$systemOk = count($criticalIssues) === 0;

$versionBadge = static function (string $version) use ($installedVersion): string {
    if ($version === '') {
        return '<span class="dfi-badge is-danger">' . Text::_('COM_DECAROFORMS_INFO_NOT_INSTALLED') . '</span>';
    }

    $class = $version === $installedVersion ? 'is-success' : 'is-warning';

    return '<span class="dfi-badge ' . $class . '">' . htmlspecialchars($version, ENT_QUOTES, 'UTF-8') . '</span>';
};

$updateLabelKey = match ($updateState) {
    'current' => 'COM_DECAROFORMS_INFO_UP_TO_DATE',
    'available' => 'COM_DECAROFORMS_INFO_UPDATE_AVAILABLE',
    'inactive' => 'COM_DECAROFORMS_INFO_INACTIVE',
    default => 'COM_DECAROFORMS_INFO_NEVER_CHECKED',
};
$updateBadgeClass = match ($updateState) {
    'current' => 'is-success',
    'available' => 'is-warning',
    'inactive' => 'is-danger',
    default => 'is-muted',
};

$diagnosticLines = [
    'Forms ' . $installedVersion,
    'Joomla: ' . (string) ($info['joomla_version'] ?? '—'),
    'PHP: ' . (string) ($info['php_version'] ?? '—'),
    'Database: ' . trim((string) ($info['database_type'] ?? '') . ' ' . (string) ($info['database_version'] ?? '')),
    'Componente: ' . ((string) ($versions['component'] ?? '') ?: '—'),
    'Pacchetto: ' . ((string) ($versions['package'] ?? '') ?: '—'),
    'Plugin sistema: ' . ((string) ($versions['system_plugin'] ?? '') ?: '—') . ($systemPluginEnabled ? ' (attivo)' : ' (non attivo)'),
    'Pulsante editor: ' . ((string) ($versions['editor_plugin'] ?? '') ?: '—') . ($editorPluginEnabled ? ' (attivo)' : ' (non attivo)'),
    'Database Forms: ' . ($schemaAligned ? 'allineato' : 'da verificare'),
    'Update server: ' . ($updateSiteEnabled ? 'attivo' : 'non attivo'),
    'Stato aggiornamento: ' . Text::_($updateLabelKey),
    'Problemi critici: ' . count($criticalIssues),
    'Avvisi: ' . count($warnings),
];
$diagnosticText = implode("\n", $diagnosticLines);
?>

<div class="dfi-page">
    <header class="dfi-page-header">
        <span class="dfi-eyebrow"><?= Text::_('COM_DECAROFORMS_INFO_SECTION'); ?></span>
        <h1><?= Text::_('COM_DECAROFORMS_INFORMATION'); ?></h1>
        <p><?= Text::_('COM_DECAROFORMS_INFO_DESC'); ?></p>
    </header>

    <?php if (!$systemOk) : ?>
        <div class="alert alert-danger dfi-alert" role="alert">
            <strong><?= Text::_('COM_DECAROFORMS_INFO_ATTENTION_REQUIRED'); ?></strong>
            <?= Text::_('COM_DECAROFORMS_INFO_CRITICAL_DESC'); ?>
        </div>
    <?php elseif (!$updateSiteEnabled) : ?>
        <div class="alert alert-warning dfi-alert" role="alert"><?= Text::_('COM_DECAROFORMS_INFO_UPDATE_SITE_WARNING'); ?></div>
    <?php elseif ($updateAvailable) : ?>
        <div class="alert alert-info dfi-alert" role="status"><?= Text::sprintf('COM_DECAROFORMS_INFO_UPDATE_AVAILABLE_DESC', $this->escape($latestVersion)); ?></div>
    <?php endif; ?>

    <div class="dfi-summary" aria-label="<?= $this->escape(Text::_('COM_DECAROFORMS_INFO_QUICK_STATUS')); ?>">
        <strong>Forms <?= $this->escape($installedVersion); ?></strong>
        <span class="dfi-badge <?= $updateBadgeClass; ?>"><?= Text::_($updateLabelKey); ?></span>
        <span class="dfi-badge <?= $systemOk ? 'is-success' : 'is-danger'; ?>">
            <?= Text::_($systemOk ? 'COM_DECAROFORMS_INFO_SYSTEM_OK' : 'COM_DECAROFORMS_INFO_SYSTEM_CHECK'); ?>
        </span>
    </div>

    <div class="dfi-grid">
        <section class="dfi-card">
            <div class="dfi-card-head">
                <div>
                    <span class="dfi-eyebrow"><?= Text::_('COM_DECAROFORMS_INFO_PRODUCT_SECTION'); ?></span>
                    <h2><?= Text::_('COM_DECAROFORMS_INFO_VERSIONS_TITLE'); ?></h2>
                </div>
                <span class="dfi-badge <?= $installationConsistent ? 'is-success' : 'is-warning'; ?>">
                    <?= Text::_($installationConsistent ? 'COM_DECAROFORMS_INFO_COHERENT' : 'COM_DECAROFORMS_INFO_NOT_COHERENT'); ?>
                </span>
            </div>

            <dl class="dfi-list">
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_COMPONENT_VERSION'); ?></dt><dd><?= $versionBadge((string) ($versions['component'] ?? '')); ?></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_PACKAGE_VERSION'); ?></dt><dd><?= $versionBadge((string) ($versions['package'] ?? '')); ?></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_DATABASE_SCHEMA'); ?></dt><dd><span class="dfi-badge <?= $schemaAligned ? 'is-success' : 'is-danger'; ?>"><?= Text::_($schemaAligned ? 'COM_DECAROFORMS_INFO_ALIGNED' : 'COM_DECAROFORMS_INFO_CHECK_REQUIRED'); ?></span></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_COMPONENT_ID'); ?></dt><dd><code>com_decaroforms</code></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_PACKAGE_ID'); ?></dt><dd><code>pkg_decaroforms</code></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_DEVELOPER'); ?></dt><dd>Luca De Caro</dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_REPOSITORY'); ?></dt><dd><a href="https://github.com/xdecaro/forms" target="_blank" rel="noopener noreferrer">xdecaro/forms <span aria-hidden="true">↗</span></a></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_LICENSE'); ?></dt><dd>GNU GPL v2 or later</dd></div>
            </dl>
        </section>

        <section class="dfi-card">
            <div class="dfi-card-head">
                <div>
                    <span class="dfi-eyebrow"><?= Text::_('COM_DECAROFORMS_INFO_ENVIRONMENT_SECTION'); ?></span>
                    <h2><?= Text::_('COM_DECAROFORMS_INFO_SYSTEM_TITLE'); ?></h2>
                </div>
                <span class="dfi-badge <?= $environmentCompatible ? 'is-success' : 'is-danger'; ?>">
                    <?= Text::_($environmentCompatible ? 'COM_DECAROFORMS_INFO_COMPATIBLE' : 'COM_DECAROFORMS_INFO_INCOMPATIBLE'); ?>
                </span>
            </div>

            <dl class="dfi-list">
                <div class="dfi-row"><dt>Joomla</dt><dd><?= $this->escape((string) ($info['joomla_version'] ?? '—')); ?></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_JOOMLA_MINIMUM'); ?></dt><dd><?= $this->escape((string) ($info['minimum_joomla'] ?? '—')); ?></dd></div>
                <div class="dfi-row"><dt>PHP</dt><dd><?= $this->escape((string) ($info['php_version'] ?? '—')); ?></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_PHP_MINIMUM'); ?></dt><dd><?= $this->escape((string) ($info['minimum_php'] ?? '—')); ?></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_DATABASE'); ?></dt><dd><?= $this->escape(trim((string) ($info['database_type'] ?? '') . ' ' . (string) ($info['database_version'] ?? ''))); ?></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_TABLES'); ?></dt><dd><span class="dfi-badge <?= !empty($tableHealth['all_present']) ? 'is-success' : 'is-danger'; ?>"><?= (int) ($tableHealth['present_count'] ?? 0); ?>/<?= (int) ($tableHealth['expected_count'] ?? 0); ?> <?= Text::_('COM_DECAROFORMS_INFO_PRESENT'); ?></span></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_DATABASE_SCHEMA'); ?></dt><dd><span class="dfi-badge <?= $schemaAligned ? 'is-success' : 'is-danger'; ?>"><?= Text::_($schemaAligned ? 'COM_DECAROFORMS_INFO_ALIGNED' : 'COM_DECAROFORMS_INFO_CHECK_REQUIRED'); ?></span></dd></div>
            </dl>
        </section>

        <section class="dfi-card">
            <div class="dfi-card-head">
                <div>
                    <span class="dfi-eyebrow"><?= Text::_('COM_DECAROFORMS_INFO_EXTENSIONS_SECTION'); ?></span>
                    <h2><?= Text::_('COM_DECAROFORMS_INFO_INCLUDED_EXTENSIONS'); ?></h2>
                </div>
            </div>

            <dl class="dfi-list">
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_SYSTEM_PLUGIN'); ?></dt><dd><span class="dfi-badge <?= $systemPluginInstalled ? 'is-success' : 'is-danger'; ?>"><?= Text::_($systemPluginInstalled ? 'COM_DECAROFORMS_INFO_INSTALLED' : 'COM_DECAROFORMS_INFO_NOT_INSTALLED'); ?></span></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_VERSION'); ?></dt><dd><?= $versionBadge((string) ($versions['system_plugin'] ?? '')); ?></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_STATUS'); ?></dt><dd><span class="dfi-badge <?= $systemPluginEnabled ? 'is-success' : 'is-danger'; ?>"><?= Text::_($systemPluginEnabled ? 'COM_DECAROFORMS_INFO_ACTIVE' : 'COM_DECAROFORMS_INFO_INACTIVE'); ?></span></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_EDITOR_BUTTON'); ?></dt><dd><span class="dfi-badge <?= $editorPluginInstalled ? 'is-success' : 'is-warning'; ?>"><?= Text::_($editorPluginInstalled ? 'COM_DECAROFORMS_INFO_INSTALLED' : 'COM_DECAROFORMS_INFO_NOT_INSTALLED'); ?></span></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_VERSION'); ?></dt><dd><?= $versionBadge((string) ($versions['editor_plugin'] ?? '')); ?></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_STATUS'); ?></dt><dd><span class="dfi-badge <?= $editorPluginEnabled ? 'is-success' : 'is-warning'; ?>"><?= Text::_($editorPluginEnabled ? 'COM_DECAROFORMS_INFO_ACTIVE' : 'COM_DECAROFORMS_INFO_INACTIVE'); ?></span></dd></div>
            </dl>
        </section>

        <section class="dfi-card">
            <div class="dfi-card-head">
                <div>
                    <span class="dfi-eyebrow"><?= Text::_('COM_DECAROFORMS_INFO_UPDATES_SECTION'); ?></span>
                    <h2><?= Text::_('COM_DECAROFORMS_INFO_UPDATE_CHANNEL_TITLE'); ?></h2>
                </div>
                <span class="dfi-badge <?= $updateSiteEnabled ? 'is-success' : 'is-danger'; ?>"><?= Text::_($updateSiteEnabled ? 'COM_DECAROFORMS_INFO_ACTIVE' : 'COM_DECAROFORMS_INFO_INACTIVE'); ?></span>
            </div>

            <dl class="dfi-list">
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_UPDATE_SERVER_STATUS'); ?></dt><dd><span class="dfi-badge <?= $updateSiteEnabled ? 'is-success' : 'is-danger'; ?>"><?= Text::_($updateSiteEnabled ? 'COM_DECAROFORMS_INFO_CONFIGURED' : 'COM_DECAROFORMS_INFO_NOT_CONFIGURED'); ?></span></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_CHANNEL'); ?></dt><dd><?= Text::_('COM_DECAROFORMS_INFO_STABLE'); ?></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_INSTALLED_VERSION'); ?></dt><dd><?= $this->escape($installedVersion); ?></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_LATEST_DETECTED'); ?></dt><dd><?= $latestVersion !== '' ? $this->escape($latestVersion) : Text::_('COM_DECAROFORMS_INFO_NO_UPDATE_DETECTED'); ?></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_LAST_CHECK'); ?></dt><dd><?= $lastCheck > 0 ? $this->escape(date('d/m/Y H:i', $lastCheck)) : Text::_('COM_DECAROFORMS_INFO_NEVER'); ?></dd></div>
                <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_STATUS'); ?></dt><dd><span class="dfi-badge <?= $updateBadgeClass; ?>"><?= Text::_($updateLabelKey); ?></span></dd></div>
            </dl>

            <?php if ($this->canManageInstaller) : ?>
                <div class="dfi-actions">
                    <a class="btn btn-primary" href="<?= Route::_('index.php?option=com_installer&view=update'); ?>"><?= Text::_('COM_DECAROFORMS_INFO_OPEN_UPDATES'); ?></a>
                    <a class="btn btn-secondary" href="<?= Route::_('index.php?option=com_installer&view=updatesites'); ?>"><?= Text::_('COM_DECAROFORMS_INFO_OPEN_UPDATE_SITES'); ?></a>
                </div>
            <?php endif; ?>
        </section>

        <section class="dfi-card dfi-full">
            <div class="dfi-card-head">
                <div>
                    <span class="dfi-eyebrow"><?= Text::_('COM_DECAROFORMS_INFO_INTEGRATIONS_SECTION'); ?></span>
                    <h2><?= Text::_('COM_DECAROFORMS_INFO_CONNECTED_COMPONENTS'); ?></h2>
                </div>
            </div>
            <p class="dfi-card-intro"><?= Text::_('COM_DECAROFORMS_INFO_CONNECTED_COMPONENTS_DESC'); ?></p>

            <div class="dfi-integrations">
                <?php foreach ($integrations as $integration) : ?>
                    <?php
                    $installed = !empty($integration['installed']);
                    $required = !empty($integration['required']);
                    $integrationVersion = (string) ($integration['version'] ?? '');
                    ?>
                    <article class="dfi-integration">
                        <div>
                            <div class="dfi-integration-name"><?= $this->escape((string) ($integration['name'] ?? '')); ?></div>
                            <div class="dfi-integration-meta">
                                <?= Text::_($required ? 'COM_DECAROFORMS_INFO_REQUIRED_DEPENDENCY' : 'COM_DECAROFORMS_INFO_OPTIONAL_INTEGRATION'); ?>
                                · <code><?= $this->escape((string) ($integration['element'] ?? '')); ?></code>
                            </div>
                        </div>
                        <div class="dfi-integration-status">
                            <div>
                                <span class="dfi-small-label"><?= Text::_('COM_DECAROFORMS_INFO_INSTALLED_VERSION'); ?></span>
                                <strong><?= $integrationVersion !== '' ? $this->escape($integrationVersion) : '—'; ?></strong>
                            </div>
                            <div class="dfi-badges">
                                <span class="dfi-badge <?= $installed ? 'is-success' : ($required ? 'is-danger' : 'is-muted'); ?>"><?= Text::_($installed ? 'COM_DECAROFORMS_INFO_INSTALLED' : 'COM_DECAROFORMS_INFO_NOT_INSTALLED'); ?></span>
                                <span class="dfi-badge <?= $required ? 'is-warning' : 'is-muted'; ?>"><?= Text::_($required ? 'COM_DECAROFORMS_INFO_REQUIRED' : 'COM_DECAROFORMS_INFO_OPTIONAL'); ?></span>
                            </div>
                        </div>
                    </article>
                <?php endforeach; ?>
            </div>
        </section>

        <section class="dfi-card dfi-full">
            <div class="dfi-diagnostic-top">
                <div>
                    <span class="dfi-eyebrow"><?= Text::_('COM_DECAROFORMS_INFO_DIAGNOSTICS_SECTION'); ?></span>
                    <h2><?= Text::_('COM_DECAROFORMS_INFO_HEALTH_TITLE'); ?></h2>
                    <p class="dfi-card-intro"><?= Text::_('COM_DECAROFORMS_INFO_DIAGNOSTICS_PRIVACY'); ?></p>
                </div>
                <span class="dfi-badge <?= $systemOk ? (count($warnings) ? 'is-warning' : 'is-success') : 'is-danger'; ?>">
                    <?php if (!$systemOk) : ?>
                        <?= Text::plural('COM_DECAROFORMS_INFO_CRITICAL_ISSUES_N', count($criticalIssues)); ?>
                    <?php elseif (count($warnings)) : ?>
                        <?= Text::plural('COM_DECAROFORMS_INFO_WARNINGS_N', count($warnings)); ?>
                    <?php else : ?>
                        <?= Text::_('COM_DECAROFORMS_INFO_NO_CRITICAL_ISSUES'); ?>
                    <?php endif; ?>
                </span>
            </div>

            <div class="dfi-checks">
                <div class="dfi-check <?= $installationConsistent ? 'is-ok' : 'is-bad'; ?>"><span aria-hidden="true"><?= $installationConsistent ? '✓' : '!'; ?></span><?= Text::_('COM_DECAROFORMS_INFO_CHECK_VERSIONS'); ?></div>
                <div class="dfi-check <?= $schemaAligned ? 'is-ok' : 'is-bad'; ?>"><span aria-hidden="true"><?= $schemaAligned ? '✓' : '!'; ?></span><?= Text::_('COM_DECAROFORMS_INFO_CHECK_DATABASE'); ?></div>
                <div class="dfi-check <?= !empty($tableHealth['all_present']) ? 'is-ok' : 'is-bad'; ?>"><span aria-hidden="true"><?= !empty($tableHealth['all_present']) ? '✓' : '!'; ?></span><?= Text::_('COM_DECAROFORMS_INFO_CHECK_TABLES'); ?></div>
                <div class="dfi-check <?= $systemPluginEnabled ? 'is-ok' : 'is-bad'; ?>"><span aria-hidden="true"><?= $systemPluginEnabled ? '✓' : '!'; ?></span><?= Text::_('COM_DECAROFORMS_INFO_CHECK_PLUGIN'); ?></div>
                <div class="dfi-check <?= $updateSiteEnabled ? 'is-ok' : 'is-warn'; ?>"><span aria-hidden="true"><?= $updateSiteEnabled ? '✓' : '!'; ?></span><?= Text::_('COM_DECAROFORMS_INFO_CHECK_UPDATE_SERVER'); ?></div>
                <div class="dfi-check <?= $environmentCompatible ? 'is-ok' : 'is-bad'; ?>"><span aria-hidden="true"><?= $environmentCompatible ? '✓' : '!'; ?></span><?= Text::_('COM_DECAROFORMS_INFO_CHECK_ENVIRONMENT'); ?></div>
            </div>

            <details class="dfi-technical">
                <summary><?= Text::_('COM_DECAROFORMS_INFO_TECHNICAL_DETAILS'); ?></summary>
                <dl class="dfi-list">
                    <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_UPDATE_SERVER'); ?></dt><dd><code><?= $this->escape((string) ($info['update_site_url'] ?? '')); ?></code></dd></div>
                    <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_COMPONENT_ID'); ?></dt><dd><code>com_decaroforms</code></dd></div>
                    <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_PACKAGE_ID'); ?></dt><dd><code>pkg_decaroforms</code></dd></div>
                </dl>
            </details>

            <pre class="dfi-diagnostic-data" id="dfi-diagnostic-data" hidden><?= $this->escape($diagnosticText); ?></pre>
            <div class="dfi-actions">
                <button type="button" class="btn btn-outline-secondary" data-dfi-copy><?= Text::_('COM_DECAROFORMS_INFO_COPY_DIAGNOSTICS'); ?></button>
                <button type="button" class="btn btn-outline-secondary" data-dfi-download data-version="<?= $this->escape($installedVersion); ?>"><?= Text::_('COM_DECAROFORMS_INFO_DOWNLOAD_DIAGNOSTICS'); ?></button>
                <a class="btn btn-outline-secondary" href="https://github.com/xdecaro/forms/releases" target="_blank" rel="noopener noreferrer"><?= Text::_('COM_DECAROFORMS_INFO_GITHUB_RELEASES'); ?></a>
            </div>
            <div class="dfi-feedback" data-dfi-feedback aria-live="polite"></div>
        </section>
    </div>
</div>
