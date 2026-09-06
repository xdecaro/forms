# Forms 1.3.50

Builder core refactor:
- stable logical Row identity independent from numeric position;
- Row title/description/accordion/selection follow the Row during reorder;
- empty Rows persist and can be selected/deleted/duplicated;
- smart empty slots are real drop targets and are consumed into 50/50 layouts;
- Section duplication generates fresh Row identities;
- Builder form + field replacement save is atomic through a database transaction;
- PHP and extracted JavaScript syntax checks passed during build.

SHA256: 90657f83682677fe542cbe9a8332c22d7971c848c9c3440d3343b2956ce75c07
