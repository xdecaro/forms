# Forms 1.2.16

Rifinitura dell'Elenco moduli: stato più semplice, copia rapida shortcode e animazioni più naturali.

## Modifiche

- il badge dei moduli attivi mostra "In corso";
- i moduli disattivati mostrano direttamente il motivo (es. "Iscrizioni chiuse") senza il badge tecnico "Disattivato" duplicato;
- aggiunta icona copia accanto allo shortcode con conferma visiva "Copiato";
- la ricerca live mantiene il filtro immediato ma le card escluse sfumano prima di scomparire e quelle ritrovate rientrano dolcemente;
- debounce ricerca ridotto a 110 ms per mantenere la sensazione di tempo reale;
- l'accordion mobile "Cerca e filtra" usa una transizione di circa 440 ms calibrata sull'altezza dei 5 controlli, invece di display none/grid immediato;
- animazione Menu leggermente più morbida;
- rispettata prefers-reduced-motion;
- nessuna modifica allo schema database e nessuna perdita di dati.

SHA-256: 6baf303b573c9b73ad70c1d5664b3963cf830f744055e9bf5ee04004f31bc6f0
