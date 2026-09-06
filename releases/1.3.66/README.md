# Forms 1.3.66

Builder UI cleanup release:
- removed duplicated/conflicting lock-toggle CSS accumulated across earlier revisions;
- removed the broad high-specificity light/dark toolbar button override that was winning over the active-state color;
- editor mode now has one authoritative `data-editor-mode` state plus `aria-pressed` on the two mode buttons;
- active **Modifica** = solid purple with white text;
- active **Bloccato** = solid slate with white text;
- inactive mode remains neutral; dark mode has explicit neutral/active treatment;
- Section, Row and Field remain uniformly **59px**;
- approved Field/Row/Section drag engines are byte-regression-checked and unchanged;
- Row IDs, stable labels, visual lines, 50/50 slots, widths, Undo/Redo and atomic save are unchanged.

SHA256: c9ffd84e2bce37cc0515f33a63b54df9de8f559e9bea658490e44227960b41c5
