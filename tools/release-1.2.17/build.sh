#!/usr/bin/env bash
set -euo pipefail

ROOT=/tmp/forms1217
OUTER="$ROOT/outer"
COMP="$ROOT/component"
PLUGIN="$ROOT/plugin"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP" "$PLUGIN" releases/1.2.17

unzip -q releases/1.2.16/pkg_decaroforms_1.2.16.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
PLG_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'plg_*decaroforms*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
unzip -q "$PLG_ZIP" -d "$PLUGIN"

FORM_VIEW="$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
python3 - <<'PY'
from pathlib import Path
p=Path('/tmp/forms1217/component/administrator/components/com_decaroforms/tmpl/forms/default.php')
s=p.read_text()
css='''
/* Forms 1.2.17: keep disabled-reason badges visibly filled in dark mode */
html[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-closed,
html[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-closed,
body[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-closed,
body[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-closed,
.df-wrap.df-dark-theme .df-badge.df-reason-closed{background:#fff0e5!important;color:#8f3600!important;border-color:#ffc79f!important}

html[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-limit,
html[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-limit,
body[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-limit,
body[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-limit,
.df-wrap.df-dark-theme .df-badge.df-reason-limit{background:#fff7d6!important;color:#725100!important;border-color:#efd36c!important}

html[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-deadline,
html[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-deadline,
body[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-deadline,
body[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-deadline,
.df-wrap.df-dark-theme .df-badge.df-reason-deadline{background:#ffebe5!important;color:#963216!important;border-color:#efb29f!important}

html[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-temporary,
html[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-temporary,
body[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-temporary,
body[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-temporary,
.df-wrap.df-dark-theme .df-badge.df-reason-temporary{background:#eef2f6!important;color:#344054!important;border-color:#cfd7e3!important}

html[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-custom,
html[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-custom,
body[data-bs-theme="dark"] .df-wrap .df-badge.df-reason-custom,
body[data-color-scheme="dark"] .df-wrap .df-badge.df-reason-custom,
.df-wrap.df-dark-theme .df-badge.df-reason-custom{background:#f4ebff!important;color:#5b35b2!important;border-color:#d6bbfb!important}
'''
if '</style>' not in s:
    raise SystemExit('Style close not found')
s=s.replace('</style>',css+'\n</style>',1)
for marker in ['df-dark-theme .df-badge.df-reason-closed','df-dark-theme .df-badge.df-reason-limit','df-dark-theme .df-badge.df-reason-deadline','df-dark-theme .df-badge.df-reason-temporary','df-dark-theme .df-badge.df-reason-custom']:
    if marker not in s:
        raise SystemExit('Missing '+marker)
p.write_text(s)
PY

# Version bump in metadata and visible version references.
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.16/1.2.17/g' "$file"
done < <(find "$COMP" "$PLUGIN" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.16/1.2.17/g' "$file"
done < <(find "$OUTER" -maxdepth 1 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)

COM_NEW="$OUTER/com_decaroforms_1.2.17.zip"
PLG_BASENAME="$(basename "$PLG_ZIP")"
PLG_NEW="$OUTER/${PLG_BASENAME/1.2.16/1.2.17}"
rm -f "$COM_ZIP" "$PLG_ZIP"
(cd "$COMP" && zip -qr "$COM_NEW" .)
(cd "$PLUGIN" && zip -qr "$PLG_NEW" .)

TARGET="$GITHUB_WORKSPACE/releases/1.2.17/pkg_decaroforms_1.2.17.zip"
rm -f "$TARGET"
(cd "$OUTER" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

find "$COMP" -type f -name '*.php' -print0 | xargs -0 -n1 php -l >/tmp/forms1217-php.log
unzip -tq "$TARGET" >/dev/null

grep -q 'df-dark-theme .df-badge.df-reason-custom' "$FORM_VIEW"

cat > releases/1.2.17/README.md <<EOF
# Forms 1.2.17

Rifinitura dark mode dei badge di chiusura nell'Elenco moduli.

- In dark mode tutti i motivi di chiusura mantengono uno sfondo pieno e leggibile, coerente con il badge "In corso".
- Colori semantici distinti per Iscrizioni chiuse, Limite raggiunto, Termine scaduto, Chiuso temporaneamente e Messaggio personalizzato.
- Light mode invariato.
- Nessuna modifica al database.

SHA-256: $SHA
EOF

cat > updates/pkg_decaroforms.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.2.17</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.2.17/pkg_decaroforms_1.2.17.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF

# Keep changelog simple and current.
cat > updates/changelog.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<changelogs>
  <changelog>
    <element>pkg_decaroforms</element>
    <type>package</type>
    <version>1.2.17</version>
    <security></security>
    <fix>Dark mode: filled semantic backgrounds for disabled-reason badges.</fix>
    <language>it-IT</language>
  </changelog>
</changelogs>
EOF

rm -rf releases/_upload
printf 'Built Forms 1.2.17 %s\n' "$SHA"
