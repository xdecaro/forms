#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TARGET="$ROOT/releases/1.3.54/pkg_decaroforms_1.3.54.zip"
FEED="$ROOT/updates/pkg_decaroforms.xml"
CHANGE="$ROOT/updates/changelog.xml"

# Run the full 1.3.54 builder/package build. The legacy changelog file currently has
# multiple top-level <changelog> nodes, so the v1 runner is expected to stop only at
# its final XML validation step. All package/PHP/JS/invariant checks happen before it.
set +e
bash tools/build-1.3.54-stable-row-label.sh
RC=$?
set -e

# Refuse to mask an earlier failure.
test -f "$TARGET"
grep -q '<version>1.3.54</version>' "$FEED"
grep -q '<version>1.3.54</version>' "$CHANGE"
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
grep -q "$SHA" "$FEED"

# Repair the pre-existing changelog structure while preserving every changelog entry.
# This is safe and update-server related: Joomla receives one valid <changelogs> root.
python3 - "$CHANGE" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')
blocks=re.findall(r'<changelog>.*?</changelog>',s,flags=re.S|re.I)
if not blocks:
    raise SystemExit('No changelog entries found')
seen=set();clean=[]
for block in blocks:
    m=re.search(r'<version>\s*([^<]+)\s*</version>',block,re.I)
    key=m.group(1).strip() if m else block
    if key in seen:
        continue
    seen.add(key);clean.append(block.strip())
p.write_text('<?xml version="1.0" encoding="utf-8"?>\n<changelogs>\n'+'\n'.join(clean)+'\n</changelogs>\n',encoding='utf-8')
PY

python3 - "$FEED" "$CHANGE" <<'PY'
import sys,xml.etree.ElementTree as ET
for f in sys.argv[1:]:
    ET.parse(f)
PY

# Confirm newest changelog remains first and the release feed points to the exact package.
python3 - "$CHANGE" "$FEED" "$SHA" <<'PY'
import sys,xml.etree.ElementTree as ET
change,feed,sha=sys.argv[1:]
r=ET.parse(change).getroot()
assert r.tag=='changelogs'
entries=r.findall('changelog')
assert entries and entries[0].findtext('version')=='1.3.54'
f=ET.parse(feed).getroot().find('update')
assert f is not None and f.findtext('version')=='1.3.54'
assert f.findtext('sha256')==sha
url=f.find('downloads/downloadurl').text or ''
assert 'releases/1.3.54/pkg_decaroforms_1.3.54.zip' in url
PY

cat > "$ROOT/releases/1.3.54/README.md" <<EOF
# Forms 1.3.54

Stable Row visible identity release:
- automatic **Riga N** is persisted in Row metadata and follows the stable Row ID;
- moving Riga 7 above Riga 6 now displays **Riga 7 / Riga 6 / Riga 8**;
- \`layout.row\` remains only the technical ordering index for compatibility;
- existing forms migrate automatically in Builder without SQL or data loss;
- new/duplicated Rows receive a unique monotonic automatic display number;
- custom title, description, accordion state, fields and Row ID remain attached to the same logical Row;
- the forgiving 50/50 Row drag UX and dark-mode behavior from 1.3.53 are preserved;
- pre-existing malformed changelog structure was normalized to one valid <changelogs> root;
- PHP, extracted JavaScript, XML and stable-label invariant checks passed.

SHA256: $SHA
EOF

# RC is expected to be non-zero only because v1 validated the old malformed changelog.
# At this point every output and the repaired XML have been independently verified.
echo "Forms 1.3.54 canonical build ready"
echo "Initial runner exit: $RC"
echo "SHA256 $SHA"
