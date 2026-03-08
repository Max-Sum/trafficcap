# trafficcap

Traffic cap automation for a VPS:

- **Measure** monthly traffic using `vnstat` (interface: `ens17`, month rotates on day 11)
- **Enforce** caps when usage exceeds `240 GiB`:
  - EasyTier: set `relay_network_whitelist = []` + `relay_all_peer_rpc = true` (RPC only)
  - Block inbound `62119/tcp` on `ens17` (probe avoidance)

## Layout

- `check.sh` -> prints `normal` or `capped`
- `apply.sh` -> runs all `caps/*.sh` with that state
- `caps/easytier.sh` -> edits `/root/docker/easytier/config.toml` and restarts docker compose service only if needed
- `caps/proxy-probe.sh` -> idempotent iptables rule enforcement
- `systemd/` -> unit + timer templates

## Install (example)

Clone into `~/scripts`:

```bash
mkdir -p ~/scripts
cd ~/scripts
git clone <YOUR_PRIVATE_REPO_URL> trafficcap
cd trafficcap
chmod +x apply.sh check.sh caps/*.sh
```

Install systemd units:

```bash
cp systemd/trafficcap.service /etc/systemd/system/trafficcap.service
cp systemd/trafficcap.timer /etc/systemd/system/trafficcap.timer
systemctl daemon-reload
systemctl enable --now trafficcap.timer
```

## Notes

- `vnstat` must be installed + monitoring `ens17`.
- `caps/easytier.sh` assumes docker compose v2 (`docker compose`) and the service name `easytier`.
- Edit interface/limit/port inside scripts if your environment differs.
