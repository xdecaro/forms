# Xdecaro Core integration

Forms uses the Xdecaro Core cross-product reference contract when exchanging entity references with other Xdecaro products.

Current Joomla component element: `com_decaroforms`.

Use:

- `Xdecaro\Core\Integration\EntityReference` for `component/entity/id` references;
- `Xdecaro\Core\Integration\RelationReference` for typed links between two references.

Do not use another product's private database tables as an integration API.

Forms remains the owner of forms, fields, submissions, statuses and Forms workflows. A consuming product remains the owner of the business entity created from or related to a submission.

Typical integrations include:

- Membership retaining a Forms submission as `source_submission` for an application or renewal;
- Courses retaining a source submission for an enrollment workflow;
- Competitions retaining a source submission for a participation workflow;
- Documents associating managed documents with a form or submission through the Documents public API;
- Events using Forms for configurable registration/intake while Events owns event capacity, participant state and check-in.

Entity type names become public API only when Forms explicitly publishes them. Do not freeze a new entity name merely from an internal table or class name.

Core integration does not by itself make Core a mandatory dependency of an already released Forms package. Dependency changes require coherent package/manifest/update handling and regression testing.
