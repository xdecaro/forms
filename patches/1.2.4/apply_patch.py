#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

VERSION = "1.2.4"

if len(sys.argv) != 4:
    raise SystemExit("usage: apply_patch.py COMPONENT_DIR PLUGIN_DIR OUTER_DIR")

component = Path(sys.argv[1]).resolve()
plugin = Path(sys.argv[2]).resolve()
outer = Path(sys.argv[3]).resolve()

# Fix runtime error in single-submission view:
# a static arrow function was trying to access $this->statuses.
submission = component / "administrator/components/com_decaroforms/tmpl/submission/default.php"
text = submission.read_text(encoding="utf-8")
old = "array_map(static fn($st)=>['key'=>(string)($st['key']??''),'label'=>(string)($st['label']??''),'style'=>FormHelper::statusBadgeStyle((string)($st['key']??''),$this->statuses)],$this->statuses)"
new = "array_map(fn($st)=>['key'=>(string)($st['key']??''),'label'=>(string)($st['label']??''),'style'=>FormHelper::statusBadgeStyle((string)($st['key']??''),$this->statuses)],$this->statuses)"
if old not in text:
    raise RuntimeError("1.2.4 target not found: static status preview arrow function")
text = text.replace(old, new, 1)
submission.write_text(text, encoding="utf-8")

# Version shown in administrator footer.
helper = component / "administrator/components/com_decaroforms/src/Helper/FormHelper.php"
h = helper.read_text(encoding="utf-8")
h = re.sub(r"public const VERSION = '[^']+';", f"public const VERSION = '{VERSION}';", h, count=1)
helper.write_text(h, encoding="utf-8")

# Component/plugin/package manifests.
for path in [component / "com_decaroforms.xml", plugin / "decaroforms.xml", outer / "pkg_decaroforms.xml"]:
    t = path.read_text(encoding="utf-8")
    t = re.sub(r"<version>[^<]+</version>", f"<version>{VERSION}</version>", t, count=1)
    path.write_text(t, encoding="utf-8")

pkg = outer / "pkg_decaroforms.xml"
t = pkg.read_text(encoding="utf-8")
t = t.replace("com_decaroforms_1.2.3.zip", "com_decaroforms_1.2.4.zip")
t = t.replace("plg_system_decaroforms_1.2.3.zip", "plg_system_decaroforms_1.2.4.zip")
pkg.write_text(t, encoding="utf-8")

print("Forms 1.2.4 runtime fix applied")
