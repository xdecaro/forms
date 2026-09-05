# Forms

**Forms** is a reusable form management component for Joomla 6.

It allows administrators to create custom forms, collect and manage submissions, configure statuses and email notifications, import existing data and export results from a single Joomla administrator interface.

Developed by **Luca De Caro**.

## Current development version

**1.3.24**

## What is Forms?

Forms is designed as a complete form-management system rather than a single-purpose form.

A typical workflow is:

1. Create a new form.
2. Add and configure the required fields.
3. Configure the form settings and submission workflow.
4. Configure email notifications and templates.
5. Make the form available to users.
6. Receive submissions.
7. Review and manage submissions from the Joomla administrator.
8. Change the status of each submission when required.
9. Search, filter and organize received data.
10. Export submissions to Excel, CSV or PDF.

The component is reusable and is not tied to a specific website, organization or database structure.

## Form Builder

The Form Builder allows administrators to create and maintain forms without creating a separate Joomla component for every new form.

Each form can have its own:

- title and configuration;
- fields and field order;
- required or optional fields;
- submission settings;
- status workflow;
- badge colors;
- submission-list columns;
- email configuration;
- email templates.

Configured fields can also be saved as reusable personal presets and re-added later from the custom field library.

Forms are independent from each other, so different forms can use different fields, statuses and submission layouts.

## Form management

Forms provides a central administrator area for managing all forms.

For each form, administrators can:

- edit the form;
- open its submissions;
- configure its settings;
- configure statuses and badge appearance;
- choose which fields appear in the submissions list;
- manage email templates;
- export data.

This keeps day-to-day form administration inside Joomla without requiring source-code changes for normal configuration tasks.

## Joomla editor button

The Forms package includes an **Editors-XTD** plugin for Joomla. In article and other supported editor screens, the **Forms** button opens a searchable form picker and inserts the selected shortcode (for example `{form id="1"}`) at the current cursor position.

The editor button is installed with the package and is enabled automatically during the Forms component update.

## Submissions manager

Every form has its own submissions area.

Administrators can:

- view received submissions;
- open the complete details of a submission;
- search submissions;
- filter submissions by status;
- change the submission status;
- identify submissions using their reference;
- configure the columns shown in the submissions table;
- export the currently filtered data.

The submission list can therefore be adapted to the fields and workflow of each individual form.

## Custom statuses and badges

Each form can use its own submission workflow instead of relying on one fixed list of statuses for the whole component.

For example, a form may use statuses such as:

- Received
- In progress
- Approved
- Rejected
- Completed

Status labels are configurable for each form, and badge colors can also be configured so that different states are easy to recognize in the administrator interface.

## Configurable submission columns

The administrator can choose which form fields should appear as columns in the submissions list.

Typical columns can include:

- Reference
- Name
- Surname
- Email
- Status
- Submission date

Because columns are configurable per form, the list remains useful even when different forms collect completely different information.

## Email notifications and templates

Forms includes configurable email handling for each form.

Email configuration can include:

- To
- CC
- BCC
- Reply-To
- subject
- email content
- administrator notifications
- user confirmation messages

Email template cards are clickable and can be previewed through a modal facsimile preview before being used.

## Dashboard

The Dashboard provides a general overview of Forms and gives quick access to the main administration areas, including forms and recent submissions.

It is intended to act as the starting point for normal day-to-day management.

## Data Import

Forms includes a generic Data Import wizard for bringing existing data into a form.

Supported sources include:

- the current Joomla database;
- CSV files;
- TSV files;
- Google Sheets;
- Google Forms through the linked response spreadsheet;
- external MySQL/MariaDB databases.

Before importing, administrators can preview the source data and map source columns to the corresponding form fields.

A repeat-safe import log helps prevent the same source records from being imported repeatedly.

## Legacy data migration

An optional legacy LSFS Forms migration preset is included for installations that need to migrate data from the previous LSFS form system.

The core Forms component remains generic and reusable for other Joomla websites and projects.

## Export

Submissions can be exported to:

- Excel (.xlsx)
- CSV
- PDF

Exports respect the active search and status filters, allowing administrators to export only the records currently required.

## Multilingual administrator interface

Forms supports:

- Italian
- English
- French

The interface follows the active Joomla administrator language.

## Joomla administrator integration

Forms is designed to integrate with the Joomla administrator interface and includes:

- full-width administrator layouts;
- Joomla administrator dark-mode support;
- Joomla-adaptive primary button styling;
- back navigation from a single submission to its submissions list;
- responsive administration views.

## Main features

- reusable Form Builder and field library;
- reusable saved custom-field presets;
- Dashboard with form/submission overview;
- full-width Joomla administrator layout;
- submissions management with a custom status workflow for each form;
- configurable badge colors for each form status;
- configurable submission-list columns for each form;
- Joomla administrator dark-mode support across all Forms views;
- clickable email template cards with modal facsimile preview;
- Joomla-adaptive primary button styling;
- back navigation from a single submission to its submissions list;
- IT / EN / FR interface following the active Joomla language;
- generic Data Import wizard;
- import from the current Joomla database, CSV/TSV, Google Sheets, Google Forms through the linked response sheet, and external MySQL/MariaDB;
- source preview and column-to-field mapping;
- repeat-safe import log;
- optional legacy LSFS Forms migration preset;
- submissions export to Excel (.xlsx), CSV and PDF;
- export respects active search and status filters;
- package-level Joomla update server.

## Google Forms note

Google Forms responses are imported through the Google Sheets response sheet linked to the form. Direct private Google API/OAuth access is not included.

## In short

Forms manages the complete lifecycle of form data:

**Create → Configure → Receive → Review → Update status → Export**

without requiring a separate Joomla component for every new form.

## Joomla requirements

- Joomla 6.0+
- PHP 8.3+
