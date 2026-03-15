#!/usr/bin/env bash
# check.sh
# Decide desired state based on vnstat monthly total traffic.
# Output: normal | capped
set -euo pipefail

IFACE="ens17"
LIMIT="240"
LIMIT_UNIT="GiB"

command -v vnstat >/dev/null 2>&1 || { echo "missing vnstat" >&2; exit 127; }

# Use exit=5 so alert and real errors are distinguishable:
#   0 => under limit
#   2 => over limit
#   1 => vnstat/runtime error
# Keep the command inside an if-condition so set -e doesn't abort on alert/error.
if vnstat --alert 0 5 monthly total "$LIMIT" "$LIMIT_UNIT" -i "$IFACE" >/dev/null 2>&1; then
  echo "normal"
  exit 0
else
  rc=$?
fi

case "$rc" in
  2)
    echo "capped"
    exit 0
    ;;
  1)
    echo "vnstat failed (exit=$rc)" >&2
    exit "$rc"
    ;;
  *)
    echo "vnstat failed (unexpected exit=$rc)" >&2
    exit "$rc"
    ;;
esac
