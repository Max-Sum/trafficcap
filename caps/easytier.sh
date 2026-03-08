#!/usr/bin/env bash
# caps/easytier.sh
# Idempotent EasyTier cap by editing /root/docker/easytier/config.toml in-place.
#
# capped:  relay_network_whitelist = ""  + relay_all_peer_rpc = true
# normal:  remove both keys (fall back to defaults)
#
# Restart policy:
# - Always runs `docker compose up -d` (ensure container exists/running)
# - Only restarts the EasyTier service if config.toml content actually changed
set -euo pipefail

DESIRED="${1:-}"
[[ "$DESIRED" == "normal" || "$DESIRED" == "capped" ]] || {
  echo "usage: $0 normal|capped" >&2
  exit 2
}

EASY_DIR="/root/docker/easytier"
# Compose filename: prefer .yaml, fall back to .yml for compatibility
COMPOSE_FILE="${EASY_DIR}/docker-compose.yaml"
if [[ ! -f "$COMPOSE_FILE" && -f "${EASY_DIR}/docker-compose.yml" ]]; then
  COMPOSE_FILE="${EASY_DIR}/docker-compose.yml"
fi
SERVICE_NAME="easytier"   # change if your docker-compose service name differs
CONFIG_FILE="${EASY_DIR}/config.toml"

die() { echo "trafficcap/easytier.sh: $*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

need_cmd docker
need_cmd sha256sum
need_cmd awk
need_cmd mktemp
need_cmd install

[[ -d "$EASY_DIR" ]] || die "missing dir: $EASY_DIR"
[[ -f "$COMPOSE_FILE" ]] || die "missing compose file: $COMPOSE_FILE"
[[ -f "$CONFIG_FILE" ]] || die "missing config file: $CONFIG_FILE"

before="$(sha256sum "$CONFIG_FILE" | awk '{print $1}')"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Remove existing keys (supports underscore and dash styles) and the trafficcap marker line.
# We normalize CRLF (strip trailing \r) and then match the marker tokens with anchored regex.
# This is strict about the text, but tolerant to extra whitespace (spaces/tabs).
awk '
  {
    sub(/\r$/, "", $0)
  }
  /^[[:space:]]*(relay_network_whitelist|relay-network-whitelist)[[:space:]]*=/ {next}
  /^[[:space:]]*(relay_all_peer_rpc|relay-all-peer-rpc)[[:space:]]*=/ {next}
  /^[[:space:]]*#[[:space:]]*---[[:space:]]*managed by trafficcap[[:space:]]*---[[:space:]]*$/ {next}
  {print}
' "$CONFIG_FILE" > "$tmp"

if [[ "$DESIRED" == "capped" ]]; then
  cat >>"$tmp" <<'EOF'

# --- managed by trafficcap ---
relay_network_whitelist = ""
relay_all_peer_rpc = true
EOF
fi

after="$(sha256sum "$tmp" | awk '{print $1}')"

cd "$EASY_DIR"

# Ensure container is up (idempotent)
docker compose -f "$COMPOSE_FILE" up -d

# Restart only if config changed
if [[ "$before" != "$after" ]]; then
  install -m 0644 "$tmp" "$CONFIG_FILE"
  docker compose -f "$COMPOSE_FILE" restart "$SERVICE_NAME"
fi
