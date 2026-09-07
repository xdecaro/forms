# Forms 1.3.68

Builder structure actions and clearer direct selection:
- added **Aggiungi sezione** and **Aggiungi riga** beside the existing Aggiungi campo / Importa con AI actions;
- Aggiungi sezione creates a new empty Section at the end and selects it immediately;
- Aggiungi riga creates a persistent empty Row inside the currently selected Section/Row/Field context, otherwise in General;
- clicking the center of a Section or Row now both selects it (purple state) and toggles its accordion; edit icons remain available;
- hierarchical purple is intentionally stronger outside-in: Section 16%, Row 11%, Field 8%; the real active Field also has a solid 4px purple bar and clearer border;
- 2x2 action grid on desktop/tablet and single-column actions on narrow smartphones;
- existing Field library behavior, AI import, 59px rhythm, Row IDs/labels, empty Rows, 50/50 slots, Undo/Redo, atomic save, light/dark mode and approved drag engines are preserved.

SHA256: 088f4ac4e89b9807f92a66935ebe2655ead33e6ad82e2c44a0d4391f60d4a637
