#!/usr/bin/env bash
# apply.sh
# Runs all caps/*.sh with desired state (normal|capped).
#
# Usage:
#   ./apply.sh           # calls ./check.sh
#   ./apply.sh normal
#   ./apply.sh capped
set -euo pipefail

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SH="${BASE_DIR}/check.sh"
CAPS_DIR="${BASE_DIR}/caps"
STATE_FILE="${BASE_DIR}/state.env"
LOCK_FILE="${BASE_DIR}/.apply.lock"

die() { echo "trafficcap/apply.sh: $*" >&2; exit 1; }

[[ -x "$CHECK_SH" ]] || die "missing or not executable: $CHECK_SH"
[[ -d "$CAPS_DIR" ]] || die "missing dir: $CAPS_DIR"

DESIRED="${1:-}"
if [[ -z "$DESIRED" ]]; then
  DESIRED="$("$CHECK_SH")"
fi

case "$DESIRED" in
  normal|capped) ;;
  *) die "invalid state: '$DESIRED' (expected normal|capped)" ;;
esac

# Best-effort lock to avoid concurrent runs
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_FILE"
  flock -n 9 || exit 0
else
  mkdir "${LOCK_FILE}.d" 2>/dev/null || exit 0
  trap 'rmdir "${LOCK_FILE}.d" 2>/dev/null || true' EXIT
fi

shopt -s nullglob
caps=("${CAPS_DIR}"/*.sh)
(( ${#caps[@]} > 0 )) || die "no cap scripts found in: $CAPS_DIR"

for cap in "${caps[@]}"; do
  bash "$cap" "$DESIRED"
done

# Optional local state (debug/visibility)
tmp="${STATE_FILE}.tmp.$$"
cat >"$tmp" <<EOF
DESIRED_STATE="$DESIRED"
LAST_APPLY_EPOCH="$(date +%s)"
EOF
mv -f "$tmp" "$STATE_FILE"
chmod 0600 "$STATE_FILE" 2>/dev/null || true
