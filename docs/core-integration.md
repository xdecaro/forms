# Xdecaro Core integration

Forms uses the Xdecaro Core public contract for optional integrations with other Xdecaro products.

Current Joomla component element: `com_decaroforms`.

From Forms 1.6.0, new Core API calls use the canonical lowercase namespace introduced by Core 1.3.0:

- `xdecaro\Core\Integration\EntityReference` for `component/entity/id` references;
- `xdecaro\Core\Integration\RelationReference` for typed links between two references;
- `xdecaro\Core\Version` for optional Core detection;
- `xdecaro\Core\Asset\AssetService` for the opt-in shared Information UI.

The deprecated `Xdecaro\Core` compatibility namespace shipped by Core 1.3.0 is not used by Forms 1.6.0.

Core remains optional for Forms as a whole. Core-dependent diagnostics and shared UI integration require Core by xdecaro 1.3.0 or newer. If Core is absent, too old or unavailable, Forms keeps its local Information UI and normal product behavior.

Do not use another product's private database tables as an integration API.

Forms remains the owner of forms, fields, submissions, statuses and Forms workflows. A consuming product remains the owner of the business entity created from or related to a submission.

Typical integrations include:

- Membership retaining a Forms submission as `source_submission` for an application or renewal;
- Courses retaining a source submission for an enrollment workflow;
- Competitions retaining a source submission for a participation workflow;
- Documents associating managed documents with a form or submission through the Documents public API;
- Events using Forms for configurable registration/intake while Events owns event capacity, participant state and check-in.

Entity type names become public API only when Forms explicitly publishes them. Do not freeze a new entity name merely from an internal table or class name.

Optional integrations must fail gracefully and must not create circular mandatory dependencies.
