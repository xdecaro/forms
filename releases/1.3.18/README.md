# Forms 1.3.18

Salvataggio Builder più sicuro, recupero automatico delle bozze e miglioramenti prestazioni/UX.

- Corretto il salvataggio che poteva terminare con errore 403 senza creare il modulo: token scaduto e autorizzazioni sono ora distinti.
- Il Builder salva automaticamente una bozza locale mentre lavori; in caso di sessione scaduta la bozza resta disponibile dopo il reload.
- Il salvataggio usa una risposta AJAX esplicita e la bozza viene cancellata solo dopo conferma positiva dal server.
- Per i moduli esistenti viene usato il permesso core.edit; per i nuovi moduli core.create.
- “Quando disattivato” e “Messaggio di chiusura” sono nascosti quando il modulo è Attivo e compaiono solo quando viene disattivato.
- Il messaggio di conferma può essere Testo semplice o HTML; il toggle Modal è sincronizzato con “Validazione e conferma”.
- Il frontend usa una vera modal di conferma invece di alert(), con sanitizzazione HTML lato browser.
- “Modifica campo” è più veloce perché il pannello proprietà renderizza soltanto il campo attivo.
- Le miniature iframe dei template email vengono caricate solo quando si apre “Impostazioni email”.
- Pannello Impostazioni campo più compatto e pulsante “Salva struttura” uniformato al rosso Forms.

SHA-256: c89a9ce647b5ca825619379b9eb52285d66701a86e90e600b822ea74248c5014
Dimensione: 210957 byte
