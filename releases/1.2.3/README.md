# Forms 1.2.3

Administrator workflow and status-color release.

## Added

- configurable **badge color** for every status of each form;
- sensible default colors: blue for New, amber for Processing, green for Replied, grey for Closed and red for Spam;
- status colors are reused consistently in submission lists, recent submissions and the single-submission status preview;
- per-form submissions page now includes summary cards, full filters, rows selector and an explicit Back button;
- **Columns** menu in Recent submissions to show or hide Form, Reference, Email, Status and Date;
- Recent-submissions column preferences are remembered in the current browser.

## Changed

- **Colonne della tabella** in form settings is now a single vertical list with one boxed row per column;
- custom status configuration now stores label, technical key and badge color in the existing status JSON configuration;
- no database schema change is required.

## Compatibility

- Joomla 6.0+
- PHP 8.3+
- existing forms and submissions are preserved;
- forms created before 1.2.3 automatically receive suitable default badge colors.

Official package SHA-256:

`99aca8e1ba27b9e3798a7ea9304a4b8efae303598e924cdbff3c97afad609ea1`
