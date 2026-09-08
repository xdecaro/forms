# Forms 1.5.0

Prima adozione reale e controllata del design system di **Core by xdecaro**.

- la pagina Informazioni/Diagnostica usa Core UI solo con Core >= 1.1.0;
- caricamento tramite `Xdecaro\Core\Asset\AssetService` e Joomla Web Asset Manager;
- nuovo layout isolato `core.php` con `.xdecaro-scope` e primitive condivise;
- bridge locale dei token `--dfi-*` verso `--xdecaro-*`;
- il layout 1.4.2 originale resta invariato come fallback automatico;
- nessuna modifica a Builder, campi, invii, email, import/export, pagamenti o database.

SHA-256 pacchetto: `92245d5a72e303333c85fd5d8be16d4db45c30b39d1d426a651747ef4a418765`
