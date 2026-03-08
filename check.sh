#!/usr/bin/env bash
# check.sh
# Decide desired state based on vnstat monthly total traffic.
# Output: normal | capped
set -euo pipefail

IFACE="ens17"
LIMIT="240"
LIMIT_UNIT="GiB"

command -v vnstat >/dev/null 2>&1 || { echo "missing vnstat" >&2; exit 127; }

# vnstat --alert exit=3 => exit status 1 when limit is exceeded
if vnstat --alert 0 3 monthly total "$LIMIT" "$LIMIT_UNIT" -i "$IFACE" >/dev/null 2>&1; then
  echo "normal"
  exit 0
fi

rc=$?
if [[ "$rc" -eq 1 ]]; then
  echo "capped"
  exit 0
fi

echo "vnstat failed (exit=$rc)" >&2
exit "$rc"
