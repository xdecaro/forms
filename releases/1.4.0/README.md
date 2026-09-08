# Forms 1.4.0

Prima integrazione runtime opzionale con **Xdecaro Core 1.0+**.

- rilevamento sicuro di `pkg_xdecarocore` e della public API `Xdecaro\Core\Version`;
- Core mostrato nella pagina Informazioni con versione installata, disponibilità API e versione minima;
- nuovo controllo Core nella Diagnostica e nel testo diagnostico esportabile;
- Core resta opzionale: la sua assenza non provoca errori fatali né blocca Forms;
- se Core è presente ma la public API non è disponibile/compatibile, Informazioni mostra uno stato da verificare;
- Courses continua a essere rilevato con il conteggio già introdotto in 1.3.74;
- Builder, drag & drop, invii, email, import/export, database e frontend Forms non modificati.

SHA-256 pacchetto: `ec2b1aa79820d52ceb500f7125c6912306425a23da8cda38e2a21e811d952ccd`
