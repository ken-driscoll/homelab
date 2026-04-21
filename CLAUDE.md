# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo Layout

```
docker-compose/
  infra-services/compose.yml      # LXC 110 (192.168.5.235) — nginx-proxy-manager, cloudflare-ddns, prometheus, grafana, overtalking-booking, etc.
  infra-services/.env.example     # Documents CLOUDFLARE_API_KEY; actual .env is gitignored
  media-services/compose.yml      # LXC 100 (192.168.5.234) — sonarr, radarr, sabnzbd, plex tooling, etc.
  prometheus.yml                  # Prometheus scrape config (node_exporter, smartctl, cAdvisor)
  raspberrypi/compose.yml         # Optional Raspberry Pi stack (Portainer + Uptime Kuma)
helper-scripts/                   # Proxmox host-level scripts (fan control, ERC, setup, backups)
lxc-scripts/                      # LXC provisioning scripts (run on Proxmox host via pct)
app-configs/recyclarr/            # Recyclarr quality profile config for Radarr + Sonarr
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
- Changes committed and pushed here take effect after running `update-homelab.sh` on the host

## Common Commands

```bash
# SSH to Proxmox host
ssh root@192.168.4.41

# Pull latest changes on the host (updates both LXCs' bind mounts immediately)
/core/scripts/homelab/helper-scripts/update-homelab.sh
# or: cd /core/scripts/homelab && git pull

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

The infra-services Cloudflare API key lives at `docker-compose/infra-services/.env` on the host (gitignored — see `.env.example` for the key name).

## Helper Scripts

Run on the **Proxmox host**, not inside LXCs:

| Script | When to use |
|---|---|
| `update-homelab.sh` | After pushing changes — syncs repo to host so LXC bind mounts pick up the update |
| `backup_pve_config.sh` | Manual or cron — backs up `/etc/pve` with 7-backup rotation |
| `install-fan-and-erc-services.sh` | One-time after fresh Proxmox install — installs fan control + ERC systemd services |
| `fan_control_stepped_noctua.sh` | **Active fan control script** (installed as `stepped-fan-control.service`) |
| `set-erc.sh` | Installed as `set-erc.service` — runs at boot, sets 7s TLER on all spinning disks |
| `map-media-uid-gid.sh <CTID>` | Run when adding a new unprivileged LXC that needs UID 1000 bind mount access |
| `setup_samba.sh` | One-time infra-services Samba/Time Machine setup |
| `setup-datasets-directories.sh` | One-time ZFS dataset + appdata directory scaffolding |

## LXC Setup Scripts (`lxc-scripts/`)

Interactive scripts run on the Proxmox host to provision new LXC containers:

- `setup_media_services_lxc.sh` — prompts for CTID, creates media user, binds all datasets, deploys compose stack
- `setup_plex_lxc.sh` — prompts for CTID, uses Proxmox community script, enables GPU passthrough for Intel Quick Sync

## Recyclarr

`app-configs/recyclarr/recyclarr.yml` manages custom format and quality profile sync for Radarr (port 30025) and Sonarr (port 30027) on the Proxmox host. Run Recyclarr manually or via cron — it's not containerized in this repo.
