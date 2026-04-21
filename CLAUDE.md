# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo Layout

```
docker-compose/
  infra-services/compose.yml   # LXC 110 (192.168.5.235) — nginx-proxy-manager, cloudflare-ddns, prometheus, grafana, overtalking-booking, etc.
  media-services/compose.yml   # LXC 100 (192.168.5.234) — sonarr, radarr, plex tooling, etc.
  prometheus.yml               # Prometheus scrape config
lxc-scripts/                   # Shell scripts run inside LXCs
helper-scripts/                # Misc Proxmox-level helpers
app-configs/                   # Committed config files for specific containers
```

## Critical: How Changes Get Deployed

`/opt/compose` inside each LXC is a **bind mount** from the Proxmox host:

| LXC | Host path |
|---|---|
| infra-services (110) | `/core/scripts/homelab/docker-compose/infra-services` |
| media-services (100) | `/core/scripts/homelab/docker-compose/media-services` |

`/core/scripts/homelab` on the Proxmox host is this git repo. So:

- **Git operations** (pull, status, log) must run on the **Proxmox host** (`192.168.4.41`), not inside the LXC
- **Docker commands** must run inside the LXC — use `pct exec <id> -- <command>`
- SSH to LXCs is disabled (password auth off); always go through the Proxmox host

## Common Commands

```bash
# SSH to Proxmox host
ssh root@192.168.4.41

# Pull latest changes on the host (updates both LXCs' bind mounts immediately)
cd /core/scripts/homelab && git pull

# Apply compose changes in an LXC
pct exec 110 -- bash -c 'cd /opt/compose && docker compose up -d'
pct exec 100 -- bash -c 'cd /opt/compose && docker compose up -d'

# Pull a specific updated image and restart
pct exec 110 -- bash -c 'cd /opt/compose && docker compose pull <service> && docker compose up -d <service>'

# Push a file to an LXC
pct push 110 /path/on/host /path/in/lxc

# View logs for a container
pct exec 110 -- docker logs <container> --tail 50
```

## App Data

Persistent config lives on the Proxmox host and is bind-mounted into each LXC:

| LXC | Host path | Container path |
|---|---|---|
| infra-services | `/core/app-configs/infra-services` | `/opt/appdata` |
| media-services | `/core/app-configs/media-services` | `/opt/appdata` |

`.env` files for individual services (e.g., `overtalking-booking`) live at `/opt/appdata/<service>/.env` inside the LXC — not in this repo.
