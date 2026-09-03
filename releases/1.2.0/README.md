# Forms 1.2.0

Administration and workflow release.

## Added

- full-width administrator layout;
- Dashboard;
- selectable submission-list columns per form;
- custom status workflow per form;
- dark-mode support across all Forms administrator views.

## Changed

- the first configured status is assigned to new submissions;
- custom status values are supported by filters and exports;
- the component main menu opens the Dashboard.

## Database

Existing data is preserved. The installer adds `statuses_json` and `list_columns_json` to `#__decaroforms_forms` when missing.

Official package SHA-256:

`ce83bffd7b91f73df5e097c92b08d449add05da71c53c9029b5ad39f9d091d56`

The Joomla update feed must only be switched to 1.2.0 after `pkg_decaroforms_1.2.0.zip` is present in this directory.
