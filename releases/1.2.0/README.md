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

`08dc86c56c98713d95fda4f4775acae007b4f34837a55ad30bd190eecf73827d`

The Joomla update feed must only be switched to 1.2.0 after `pkg_decaroforms_1.2.0.zip` is present in this directory.
