# Forms 1.3.23

Pulizia e consolidamento del sistema colori dei pulsanti nel Builder.

- Rimossa la vecchia regola globale che ricolorava tutti i pulsanti secondari tramite variabili di tema e poteva renderli neri in light mode.
- Rimossi override duplicati per .df-btn, .df-primary, .df-danger e Salva struttura.
- Introdotto un solo sistema di pulsanti con variabili dedicate per light e dark mode.
- In light mode i pulsanti secondari sono bianchi/grigio chiaro con testo scuro; in dark mode usano superfici scure esplicite.
- Salva struttura è ora semanticamente un pulsante primario rosso Forms.
- Salva modulo e le azioni primarie restano rosse; le azioni distruttive mantengono uno stile dedicato.
- I pulsanti dentro le modal usano lo stesso sistema, evitando differenze di colore tra Builder e finestre di conferma.

SHA-256: 0cdd38a733a485f8c8d642d016384957bdadcefee855583421aab0baaf09303f
Dimensione: 215327 byte
