# Forms 1.3.21

Correzione prioritaria del salvataggio Builder e del token Joomla.

- Prima di ogni salvataggio il Builder richiede il token CSRF corrente alla sessione Joomla e aggiorna il campo nascosto.
- Se il token cambia tra verifica e POST, il salvataggio AJAX aggiorna il token e riprova una sola volta.
- Il gestore di Salva è separato dal resto del JavaScript del Builder: un errore in drag & drop, email o UI non può più causare un POST nativo verso una pagina 403.
- Il fallback server non mostra più la pagina Joomla 403 per token non valido: torna al Builder con messaggio e la bozza locale resta recuperabile.
- La bozza viene salvata prima del tentativo e cancellata solo dopo risposta positiva del server.

SHA-256: 1030efcaa342c250fd740cebe7e45b6f1beb0081a091ff57d53f7f8dd3bd8c4f
Dimensione: 214581 byte
