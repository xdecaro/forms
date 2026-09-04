# Forms 1.3.11

Correzione definitiva dell'apertura facsimile dei template email.

- Nuovo pulsante Anteprima sempre visibile su ogni template email.
- Apertura gestita con event delegation, quindi funziona anche dopo i re-render dinamici del Builder.
- La modal viene spostata direttamente sotto body per evitare problemi di stacking/overflow dell'amministrazione Joomla.
- Z-index e display vengono forzati in apertura per evitare che la modal resti nascosta dietro il Builder.
- Se la generazione dei dati di esempio fallisce, la modal si apre comunque con un contenuto di fallback.
- Il radio resta separato e serve solo a selezionare il template.

SHA-256: 71c2eff825951259e6eb446f8edf3e2578d541c1356e4514327606174df90f0c
Dimensione: 198492 byte
