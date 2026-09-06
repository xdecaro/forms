# Forms 1.3.54

Stable Row visible identity release:
- automatic **Riga N** is persisted in Row metadata and follows the stable Row ID;
- moving Riga 7 above Riga 6 now displays **Riga 7 / Riga 6 / Riga 8**;
- `layout.row` remains only the technical ordering index for compatibility;
- existing forms migrate automatically in Builder without SQL or data loss;
- new/duplicated Rows receive a unique monotonic automatic display number;
- custom title, description, accordion state, fields and Row ID remain attached to the same logical Row;
- the forgiving 50/50 Row drag UX and dark-mode behavior from 1.3.53 are preserved;
- pre-existing malformed changelog structure was normalized to one valid <changelogs> root;
- PHP, extracted JavaScript, XML and stable-label invariant checks passed.

SHA256: f34f15d9f20cd5d3c58d6fc4aeed02e24cd93c86d02d8052a5d83624add06b5f
