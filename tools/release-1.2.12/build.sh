#!/usr/bin/env bash
set -euo pipefail

ROOT=/tmp/forms1212
OUTER="$ROOT/outer"
COMP="$ROOT/component"
PLUGIN="$ROOT/plugin"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP" "$PLUGIN" releases/1.2.12

unzip -q releases/1.2.11/pkg_decaroforms_1.2.11.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
PLG_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'plg_*decaroforms*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
unzip -q "$PLG_ZIP" -d "$PLUGIN"

# Italian UI labels: shorter, clearer actions.
find "$COMP" -type f \( -name '*.ini' -o -name '*.php' \) -print0 | xargs -0 sed -i \
  -e 's/Modifica modulo/Modifica/g' \
  -e 's/Vedi invii/Apri invii/g'

# Smartphone: all controls inside Cerca e filtra use the same 46px control height.
FORM_VIEW="$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
python3 - <<'PY'
from pathlib import Path
p=Path('/tmp/forms1212/component/administrator/components/com_decaroforms/tmpl/forms/default.php')
s=p.read_text()
needle='@container formslist (max-width:560px){'
if needle not in s:
    raise SystemExit('smartphone container rule not found')
insert='@container formslist (max-width:560px){.df-tools .df-tool input,.df-tools .df-tool select,.df-tools>.df-btn{height:46px;min-height:46px;line-height:normal}.df-tools .df-tool input,.df-tools .df-tool select{padding-top:0;padding-bottom:0}'
s=s.replace(needle,insert,1)
p.write_text(s)
PY

# Version bump inside component/plugin/package manifests and metadata.
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.11/1.2.12/g' "$file"
done < <(find "$COMP" "$PLUGIN" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.11/1.2.12/g' "$file"
done < <(find "$OUTER" -maxdepth 1 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)

COM_NEW="$OUTER/com_decaroforms_1.2.12.zip"
PLG_BASENAME="$(basename "$PLG_ZIP")"
PLG_NEW="$OUTER/${PLG_BASENAME/1.2.11/1.2.12}"
rm -f "$COM_ZIP" "$PLG_ZIP"
(cd "$COMP" && zip -qr "$COM_NEW" .)
(cd "$PLUGIN" && zip -qr "$PLG_NEW" .)

TARGET="$GITHUB_WORKSPACE/releases/1.2.12/pkg_decaroforms_1.2.12.zip"
rm -f "$TARGET"
(cd "$OUTER" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

# Automated validation.
find "$COMP" -type f -name '*.php' -print0 | xargs -0 -n1 php -l >/tmp/forms1212-php.log
python3 - <<'PY'
import xml.etree.ElementTree as ET
ET.parse('/tmp/forms1212/component/com_decaroforms.xml')
PY
unzip -tq "$TARGET" >/dev/null
grep -R -q 'Modifica' "$COMP/administrator/components/com_decaroforms"
grep -R -q 'Apri invii' "$COMP/administrator/components/com_decaroforms"
grep -q '.df-tools .df-tool input,.df-tools .df-tool select,.df-tools>.df-btn{height:46px;min-height:46px' "$FORM_VIEW"

cat > releases/1.2.12/README.md <<EOF
# Forms 1.2.12

Chiusura finale UI dell'Elenco moduli.

## Modifiche

- "Modifica modulo" diventa "Modifica";
- "Vedi invii" diventa "Apri invii";
- su smartphone Cerca, Stato, Ordina, Mostra e Pulisci hanno tutti altezza uniforme di 46 px;
- i controlli interni sono uniformati a Cerca e filtra;
- nessuna modifica allo schema database e nessuna perdita di dati.

SHA-256: $SHA
EOF

cat > updates/pkg_decaroforms.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.2.12</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.2.12/pkg_decaroforms_1.2.12.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF

python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET
p=Path('updates/changelog.xml')
s=p.read_text()
entry='''  <changelog>\n    <element>pkg_decaroforms</element><type>package</type><version>1.2.12</version>\n    <change><item>Shortened form action label from Modifica modulo to Modifica.</item><item>Renamed Vedi invii to Apri invii.</item><item>Unified smartphone filter controls to a 46-pixel height.</item></change>\n  </changelog>\n'''
s=s.replace('<changelogs>\n','<changelogs>\n'+entry,1)
p.write_text(s)
ET.parse('updates/pkg_decaroforms.xml')
ET.parse('updates/changelog.xml')
PY

rm -rf releases/_upload
