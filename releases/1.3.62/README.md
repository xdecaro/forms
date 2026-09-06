# Forms 1.3.62

Lock/drag consistency fix based on the manual Console recording:
- the recording showed pointer movement up to 108px while Field drag correctly stayed inactive in locked state;
- Row and Section drag from 1.3.61 did not honor the same editor lock and could still start;
- **Bloccato** now disables drag for Campo, Riga and Sezione uniformly;
- **Modifica** keeps all three drag systems active;
- structure drag checks the lock both before starting and before committing;
- locked drag handles use a disabled cursor/opacity for clearer UX;
- approved Field drag engine from 1.3.60/1.3.61 is preserved byte-for-byte;
- approved Row/Section vertical SOPRA/SOTTO drag from 1.3.61 is preserved;
- Row IDs, stable labels, visual lines, 50/50 slots, widths, Undo/Redo and atomic save are unchanged.

SHA256: 87be8107a9511ff26b375e4f6ed1d47c23c2c57809a62580ffea3feb682b24b4
