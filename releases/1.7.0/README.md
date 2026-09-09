# Forms 1.7.0

Optional Joomla editor integration for HTML email templates.

- Forms detects the public Joomla editor provider `decaroeditor` through `EditorsRegistry`;
- when Editor by xdecaro 0.1.0-alpha6+ is enabled, administrator and user “HTML libero” email templates use the visual editor;
- when Editor is absent, disabled or incompatible, the existing raw textarea remains available automatically;
- AI HTML and additional-email HTML remain raw-code fields in this release;
- email content continues to be stored only in `email_config_json`;
- no new database table/column, package dependency, Core API or product-specific Core logic is introduced;
- ACL, CSRF, Builder save transaction, Forms identifiers and data remain unchanged.

SHA-256 package: `f7fa1987abe73efd614978a0746ba8850e87e3f1a7100abd62f4cb9dec3b90b4`
