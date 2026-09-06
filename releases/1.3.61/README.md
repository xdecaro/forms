# Forms 1.3.61

Uniform Row + Section drag release:
- Row and Section now use the same approved violet drag language as Fields;
- Row/Section placement is vertical only: **SOPRA / SOTTO**, no left/right mode;
- source structure stays visible with an **IN SPOSTAMENTO** badge;
- target area uses a fixed translucent violet half-overlay and pill, without moving the canvas;
- 48px magnetic tolerance makes structural movement faster and less precise;
- structure ghost uses translate3d and pointer updates use requestAnimationFrame;
- drag-only margin expansion was removed to avoid layout jumps;
- moving a Row into a Section remains supported and is shown as **NELLA SEZIONE**;
- approved Field drag 1.3.60, Row IDs, stable labels, visual lines, 50/50 slots, widths, Undo/Redo and atomic save are preserved.

SHA256: 24df607ad3ee297301bf8640ca43b0e4f7cd6d2acd43196cb7188c4d882022e2
