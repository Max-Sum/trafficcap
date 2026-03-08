#!/usr/bin/env bash
# caps/proxy-probe.sh
# Idempotent iptables cap for blocking inbound 62119/tcp on ens17.
#
# capped: ensure rule present
# normal: ensure rule absent
set -euo pipefail

DESIRED="${1:-}"
[[ "$DESIRED" == "normal" || "$DESIRED" == "capped" ]] || {
  echo "usage: $0 normal|capped" >&2
  exit 2
}

IFACE="ens17"
BLOCK_PORT="62119"
RULE_COMMENT="trafficcap:block-62119"

die() { echo "trafficcap/proxy-probe.sh: $*" >&2; exit 1; }
command -v iptables >/dev/null 2>&1 || die "missing iptables"

ensure_present() {
  iptables -w 5 -C INPUT -i "$IFACE" -p tcp --dport "$BLOCK_PORT" \
    -m comment --comment "$RULE_COMMENT" -j DROP 2>/dev/null \
  || iptables -w 5 -I INPUT 1 -i "$IFACE" -p tcp --dport "$BLOCK_PORT" \
    -m comment --comment "$RULE_COMMENT" -j DROP
}

ensure_absent() {
  while iptables -w 5 -C INPUT -i "$IFACE" -p tcp --dport "$BLOCK_PORT" \
      -m comment --comment "$RULE_COMMENT" -j DROP 2>/dev/null; do
    iptables -w 5 -D INPUT -i "$IFACE" -p tcp --dport "$BLOCK_PORT" \
      -m comment --comment "$RULE_COMMENT" -j DROP || true
  done
}

case "$DESIRED" in
  capped) ensure_present ;;
  normal) ensure_absent ;;
esac
