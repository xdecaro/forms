# Forms

Reusable Joomla 6 form builder, submissions manager and data importer.

Developed by **Luca De Caro**.

## Current development version

**1.1.2**

### Main features

- reusable Form Builder and field library;
- submissions management;
- IT / EN / FR interface following the active Joomla language;
- generic Data Import wizard;
- import from the current Joomla database, CSV/TSV, Google Sheets, Google Forms through the linked response sheet, and external MySQL/MariaDB;
- source preview and column-to-field mapping;
- import into an existing form or create a new disabled form from source columns;
- repeat-safe import log;
- optional legacy LSFS Forms migration preset;
- submissions export to Excel (.xlsx), CSV and PDF;
- export respects active search and status filters;
- package-level Joomla update server.

## 1.1.2 test release

Version 1.1.2 is a minimal maintenance build used to test automatic Joomla extension update detection from GitHub. It contains no database schema changes and no changes to existing form/submission data.

### Google Forms note

Google Forms responses are imported through the Google Sheets response sheet linked to the form. Direct private Google API/OAuth access is not included in 1.1.x.

## Joomla requirements

- Joomla 6.0+
- PHP 8.3+
