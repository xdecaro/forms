# Forms 1.3.55

Field drag UX stabilization release:
- top 36% of every field = **SOPRA** across the full field width;
- bottom 36% = **SOTTO** across the full field width;
- center 28% = **SINISTRA / DESTRA** for same-line placement;
- hysteresis keeps the selected direction stable near zone boundaries;
- 22px invisible proximity tolerance around field cards;
- 16px invisible proximity tolerance around **VUOTO 50%** slots;
- stronger light/dark visual emphasis for active field targets;
- no data-model changes: stable Row IDs/names from 1.3.54 and all previous Builder behavior are preserved;
- PHP, extracted JavaScript, XML and deterministic geometry checks passed.

SHA256: be00929eed38ae49ff2df307c8ef14b948d527258d0745fd1a55593a9c0c471a
