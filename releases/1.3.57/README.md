# Forms 1.3.57

Intent-aware field drag based on the 2026-09-06 Builder video review:
- compensates the exact point where the field was grabbed;
- vertical field movement resolves to SOPRA/SOTTO even when grabbed near the left or right edge;
- deliberate horizontal movement resolves to SINISTRA/DESTRA;
- hysteresis stabilizes the selected direction;
- SOPRA/SOTTO is shown first in the visual preview;
- preserves stable Row IDs, Sections, visual lines, VUOTO 50% slots, automatic/manual widths, Undo/Redo and atomic save;
- package contains component, system plugin and editors-xtd plugin as separate Joomla child ZIPs;
- component/package/plugin manifests aligned to 1.3.57.

SHA256: cd062d4812032736d2ea6f567861bc3e32120dc57a3f3d3568205195b7bedbc8
