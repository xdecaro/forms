# Forms 1.3.63

Builder visual-state and spacing refinement:
- selected **Section**, **Row** and **Field** now share the same subtle violet background and left accent bar;
- only the currently edited element is highlighted; field selection continues to clear structural selection;
- **Bloccato** active state uses a clear dark-gray background; **Modifica** active state uses violet; inactive mode stays neutral;
- red remains reserved for destructive actions;
- final desktop heights: Section **72px**, Row **68px**, Field **72px**;
- tablet: **68px**; smartphone: **64px**;
- light and dark mode receive explicit active-state contrast;
- approved 1.3.60 Field drag and 1.3.61/1.3.62 Row/Section drag engines are byte-preserved (apart from version text), with no behavior changes;
- Row IDs, stable labels, visual lines, VUOTO 50%, widths, Undo/Redo and atomic save remain unchanged.

SHA256: b30cfb9f233e4d6bfd6447566c6c72ac08aac0bd67aac04c55aae27b695308f9
