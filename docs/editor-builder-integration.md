# Forms ↔ Editor Builder integration

## Decision

The Form Builder remains a Forms feature. The reusable visual layout engine is provided by Editor by xdecaro.

This is a code-responsibility split, not a navigation change: a Forms user continues to work entirely inside **Forms → Builder**.

## Current Forms baseline

Forms 1.5.1 already contains a mature smart-drag implementation inside:

`administrator/components/com_decaroforms/tmpl/builder/default.php`

The current implementation includes behavior that must not be lost during extraction:

- pointer-based drag handling;
- left/right placement in the same row;
- above/below placement in a new logical row;
- four-field row limit;
- automatic row distribution;
- source-row reflow while dragging;
- ghost/placeholder preview;
- movement animation;
- logical row metadata updates;
- active Field/Row/Section selection;
- Forms history and canonical sync.

Because the released source is currently rebuilt from versioned ZIP packages by `tools/build-*.sh`, a direct runtime replacement must be done as an explicit Forms release migration, not by silently adding an unrelated JavaScript file to the repository.

## Target dependency

```text
Forms
  └─ Form Builder domain adapter
       └─ Editor: com_decaroeditor.builder-engine

Editor
  └─ optional/stable Core infrastructure
```

Core does not own the Builder engine and is not a blocker for this migration.

## Forms adapter responsibilities

The future Forms adapter must translate between Editor layout events and Forms canonical state.

Mapping from the current Builder:

| Forms runtime | Editor Builder concept |
| --- | --- |
| `.df-layout-row` | row |
| `.df-layout-card` | item |
| `data-field-key` | stable item id |
| `field.config.layout.row` | row order |
| `field.config.layout.col` | column order |
| `field.config.layout.width` | item width |
| `selected[]` | host-owned domain state |
| `sync()` | host persistence bridge |
| `pushHistory()` | host/domain history |

Editor must never write directly to `selected[]` or Forms configuration objects. It emits visual-layout intent/state; Forms validates and commits it.

## Incremental migration

### Stage A — shared engine foundation

Editor publishes the independent Joomla Web Asset Manager asset:

`com_decaroeditor.builder-engine`

Forms runtime remains unchanged.

### Stage B — compatibility adapter

Forms loads the Editor asset only when the supported Editor version is present. The adapter maps existing `.df-layout-*` DOM without changing stored Forms data.

During this stage the current smart-drag engine remains the fallback.

### Stage C — parity mode

Enable the Editor engine behind a controlled feature flag/development switch and compare it with the existing runtime.

Required parity checks:

1. one field stays 100%;
2. two fields auto-balance 50/50;
3. three fields auto-balance 33/33/34;
4. four fields auto-balance 25/25/25/25;
5. a fifth field cannot silently create an invalid five-column row;
6. custom 40/60 survives refresh and save/reload;
7. drag left/right creates/reorders within the same row;
8. drag above/below creates/reorders logical rows;
9. moving the only field out of a row removes the empty row safely;
10. Section/Row/Field active selection remains correct;
11. undo/redo restores both visual layout and Forms state;
12. mouse, touch/pointer and keyboard/accessibility behavior remain usable;
13. desktop/tablet/smartphone remain correct;
14. light/dark mode remains correct;
15. no duplicate listeners, double commits or duplicate history entries.

### Stage D — Editor engine authoritative

Only after parity tests pass may Forms remove its duplicated generic drag/layout implementation. Forms-specific state, validation, serialization and workflows remain local permanently.

## Dependency/fallback policy

Do not make Editor mandatory during the compatibility migration.

If Editor or the minimum Builder Engine API is not available:

- Forms must continue with its existing Builder runtime;
- no fatal PHP/JavaScript error;
- no data conversion;
- no changed saved layout.

If Editor later becomes a declared package dependency, update package manifests, update-server metadata, installer checks and clean-update tests together.

## Release policy

Do not ship the first integration by modifying Forms 1.5.1 in place. Use a new Forms version and preserve the 1.5.1 package/checksum as immutable release history.
