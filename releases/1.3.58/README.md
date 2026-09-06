# Forms 1.3.58

Fluid magnetic field-drag release based on the 2026-09-06 21:23 screen recording:
- the Builder canvas stays geometrically static while dragging; fields no longer jump/reflow under the pointer;
- drop targeting follows the projected center of the dragged field, compensating the exact grab point;
- vertical/horizontal intent locks quickly and changes only after a deliberate orthogonal gesture;
- field magnet tolerance increased to **44px** and VUOTO 50% slot tolerance to **30px**;
- lightweight fixed overlays show SOPRA/SOTTO/SINISTRA/DESTRA without moving the form before drop;
- drag ghost uses GPU-friendly translate3d and pointer processing is throttled with requestAnimationFrame;
- mouse start threshold is 4px; touch/pen hold reduced to 300ms;
- previous Row IDs, stable Riga labels, Sections, visual lines, 50/50 slots, widths, Undo/Redo and atomic save are preserved;
- component, system plugin and editors-xtd plugin remain separate Joomla child ZIPs.

SHA256: ec9fd6b57c3e331238c45a835dd277162f2d084db875ed4baaee0071970b3f0a
