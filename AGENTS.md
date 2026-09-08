# Forms — Codex Repository Rules

## Xdecaro Core integration

Forms is part of the Xdecaro Joomla ecosystem and must progressively use **Xdecaro Core** for functionality that is genuinely shared across multiple Xdecaro extensions.

Core is infrastructure, not product logic.

Before implementing or refactoring a reusable technical feature, check whether the same responsibility belongs in Core or is already provided by a stable Core API.

Good Core candidates include:

- shared design tokens and `.xdecaro-*` UI primitives;
- light/dark mode foundations;
- responsive administrator UI helpers;
- common buttons, badges, cards, tables, modals, alerts and loading states;
- shared Web Asset Manager registration;
- generic JavaScript utilities;
- AJAX/CSRF helpers that remain Joomla-compliant;
- dependency/version checks;
- common diagnostics;
- Xdecaro extension registry and shared information/update UI.

Keep all Forms-specific business logic in this repository, including:

- form definitions and field configuration;
- Forms-specific Form Builder behavior and canonical serialization;
- field libraries and presets;
- submissions and submission statuses;
- validation rules specific to Forms;
- email-template behavior specific to Forms;
- import/export rules specific to Forms;
- multipage forms, payments and Forms-specific workflows.

Do not move code into Core merely because it could technically be reused. A Core abstraction must be domain-neutral and useful to more than one product.

## Editor Builder integration

The reusable visual layout engine belongs to **Editor by xdecaro**, not to Core and not permanently to Forms.

Editor may provide domain-neutral Builder primitives such as:

- selection;
- drag/drop placement;
- rows and columns;
- automatic width distribution;
- custom width rebalance;
- layout-only history primitives;
- reusable lifecycle/events.

Forms remains the owner of:

- field definitions and field keys;
- required state and validation;
- Forms conditions;
- Section/Row/Field semantics as persisted by Forms;
- submission-facing configuration;
- Forms undo/redo state when it includes domain data;
- persistence and serialization.

Dependency direction may be `Forms -> Editor`. Editor must never depend on Forms. Core must never depend on Editor.

Do not make Editor a mandatory dependency of an already released Forms package until manifests, package/update behavior, minimum version and install/update regression tests are updated together.

### Builder migration rule

Forms already contains a mature smart-drag engine. Do not replace it with a simpler generic implementation.

Any migration to Editor Builder Engine must preserve at least:

- mouse, pointer and touch behavior;
- drag above/below to create/reorder logical rows;
- drag left/right to share a row;
- maximum four fields per row;
- automatic 100%, 50/50, 33/33/34 and 25/25/25/25 distribution;
- custom widths such as 40/60 without unexpected reset;
- preview/drop indicators and movement animation;
- Section, Row and Field hierarchy;
- active-field visual state;
- current data and serialization;
- current Forms undo/redo behavior;
- desktop, tablet and smartphone;
- light and dark mode;
- keyboard/accessibility behavior.

Migrate incrementally through an adapter and keep the current Forms implementation as fallback until parity is verified. Do not create a release whose only architectural benefit causes a user-visible Builder regression.

Core stabilization is not a blocker for this migration. Use Editor's public asset/API directly first; add Core-based discovery/registry integration later only when the relevant Core API is stable.

## Migration rule

When a task touches functionality that is a good Core candidate:

1. inspect the current Forms implementation first;
2. inspect the available Core public API before designing a duplicate;
3. preserve existing Forms behavior and visual output;
4. prefer the stable Core API when it already covers the requirement;
5. migrate incrementally rather than rewriting large working areas;
6. do not remove the local implementation until the Core replacement is verified;
7. avoid circular dependencies: Forms may depend on Core, Core must never depend on Forms;
8. keep backward compatibility during transition;
9. verify clean install and update behavior;
10. verify desktop, tablet, smartphone, light mode and dark mode when UI is affected.

If Core is not available in the current workspace or the required API does not yet exist, do not invent a fake Core API and do not block unrelated Forms work. Keep the implementation safe and local, clearly identifying a genuinely generic part as a future Core candidate when appropriate.

## Dependency policy

Do not make Xdecaro Core a new mandatory runtime dependency of an already released Forms version unless the package, manifests, installer/update path and minimum Core version are all updated together and the migration has been tested.

During a compatibility transition, prefer graceful detection and controlled administrator messaging over fatal errors.

Once Core is intentionally declared mandatory, enforce a documented minimum Core version and fail safely with a clear Joomla administrator message when the dependency is missing or incompatible.

## Public API stability

Treat Core public classes, services, asset identifiers, JavaScript APIs, CSS classes and CSS variables as stable contracts.

Do not copy internal Core implementation details into Forms and do not access Core internals that are not part of its public API.

## Joomla and security

Core integration must not weaken Forms security or Joomla conventions.

Continue to enforce where relevant:

- server-side ACL;
- Joomla CSRF tokens;
- filtered and validated input;
- escaped output;
- bound database queries;
- safe upload validation;
- no authorization decisions made only in JavaScript.

## Regression rule

A Core or Editor migration is complete only when the affected Forms behavior remains verified.

Check as applicable:

- Joomla installation and update;
- administrator and frontend behavior;
- Forms Builder;
- submissions;
- assets loaded once;
- AJAX;
- ACL and CSRF;
- PHP errors/warnings;
- JavaScript console;
- desktop/tablet/smartphone;
- light/dark mode.

Do not combine an opportunistic Core migration with unrelated large refactors.

When the user says **“procedi”**, execute the requested work directly after inspecting the relevant code and dependencies. Do not ask for another confirmation when the requirements are already clear.
