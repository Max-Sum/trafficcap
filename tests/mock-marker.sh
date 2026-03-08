#!/usr/bin/env bash
# Mock test for EasyTier marker removal regex in caps/easytier.sh
set -euo pipefail

mkcfg() {
  local f="$1"
  # Include multiple variants of the marker line
  {
    printf 'a = 1\n'
    printf '# --- managed by trafficcap ---\n'
    printf 'b = 2\n'

    # extra spaces after '#'
    printf '#  --- managed by trafficcap ---\n'

    # tabs/spaces mix
    printf '#\t---\tmanaged by trafficcap\t---\n'

    # trailing spaces
    printf '# --- managed by trafficcap ---   \n'

    # CRLF variant (adds \r)
    printf '# --- managed by trafficcap ---\r\n'

    printf 'c = 3\n'
  } >"$f"
}

STRICT_AWK='
  { sub(/\r$/, "", $0) }
  /^[[:space:]]*# --- managed by trafficcap ---[[:space:]]*$/ {next}
  {print}
'

TOLERANT_AWK='
  { sub(/\r$/, "", $0) }
  # still anchored; allows variable whitespace but matches only the exact marker tokens
  /^[[:space:]]*#[[:space:]]*---[[:space:]]*managed by trafficcap[[:space:]]*---[[:space:]]*$/ {next}
  {print}
'

cfg="$(mktemp)"; trap 'rm -f "$cfg"' EXIT
mkcfg "$cfg"

echo '=== Original (cat -A) ==='
cat -A "$cfg"

echo

echo '=== After STRICT_AWK (cat -A) ==='
awk "$STRICT_AWK" "$cfg" | cat -A

echo

echo '=== After TOLERANT_AWK (cat -A) ==='
awk "$TOLERANT_AWK" "$cfg" | cat -A
