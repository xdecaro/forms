#!/usr/bin/env bash
set -euo pipefail
ROOT=/tmp/forms-inspect-1214
OUTER="$ROOT/outer"
COMP="$ROOT/component"
OUT="releases/_inspect-1.2.14-deactivation.txt"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP"
unzip -q releases/1.2.14/pkg_decaroforms_1.2.14.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
{
  echo '=== builder files ==='
  find "$COMP/administrator/components/com_decaroforms/tmpl" -maxdepth 3 -type f | sort
  echo
  echo '=== builder: disabled/closed/status/reason/message/max/limit matches ==='
  grep -RniE 'disattiv|disabled|closed|close_reason|reason|messaggio|message|limite|limit|max_sub|max submissions|status' "$COMP/administrator/components/com_decaroforms/tmpl" | head -n 500 || true
  echo
  echo '=== admin src/model/table matches ==='
  grep -RniE 'disattiv|disabled|closed|close_reason|reason|message|limit|max_sub|status' "$COMP/administrator/components/com_decaroforms/src" | head -n 500 || true
  echo
  echo '=== forms default badge/menu/filter sections ==='
  FORM_VIEW="$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
  grep -n -C 4 -E 'df-badge|df-on|df-off|Menu|Cerca e filtra|df-filter|accordion|popover|dropdown|df-menu' "$FORM_VIEW" | head -n 700 || true
  echo
  echo '=== DB/install SQL columns ==='
  grep -RniE 'CREATE TABLE|ALTER TABLE|status|disabled|closed|reason|message|limit|max_sub' "$COMP/administrator/components/com_decaroforms/sql" "$COMP/administrator/components/com_decaroforms" --include='*.sql' --include='*.xml' | head -n 500 || true
} > "$OUT"
