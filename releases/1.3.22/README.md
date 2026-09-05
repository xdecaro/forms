# Forms 1.3.22

Correzione definitiva del salvataggio Builder su installazioni Joomla dove il token standard può risultare non valido anche dopo il refresh.

- Mantiene il token CSRF standard Joomla.
- Aggiunge un secondo nonce CSRF dedicato al Builder, generato con random_bytes, memorizzato nella sessione amministratore e verificato con hash_equals.
- Il salvataggio è accettato solo se è valido il token Joomla oppure il nonce Builder della stessa sessione autenticata e autorizzata.
- L'endpoint di refresh restituisce e aggiorna entrambi i token prima del POST.
- In caso di cambio sessione, entrambi i token vengono rinnovati e il salvataggio AJAX riprova una sola volta.
- La bozza locale continua a essere conservata fino a conferma di salvataggio riuscito.

SHA-256: 36203e81f3a15ddfeb99ee6e4c512ee761a04d8e5ccac26fdd51e8f6b5bf8d5b
Dimensione: 214970 byte
