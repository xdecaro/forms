# Forms 1.3.69

Selection-state fix for the Builder:
- Field selection now redraws the canvas, removing stale Section/Row selection classes;
- only one real selection is active at a time;
- selected Field gets visible purple 9% background, 4px purple left bar and clearer purple border;
- parent Row remains contextual at 11%; parent Section remains contextual at 16%;
- selecting a Row clears the previous active Field state;
- Section/Row/Field remain 59px high;
- approved Field/Row/Section drag engines are regression-checked and unchanged;
- Row IDs/labels, empty Rows, 50/50 slots, widths, Undo/Redo, AI import and atomic save are preserved.

SHA256: 6fcc80bc8a39f27c85172594758aa6487e772d8f67d04ebd78c71461752a627f
