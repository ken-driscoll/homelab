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

Run on the **Proxmox host**, not inside LXCs. `update-homelab` is installed as a system command at `/usr/local/bin/update-homelab`.

| Script | When to use |
|---|---|
| `update-homelab.sh` | After pushing changes — also available as `update-homelab` system command |
| `backup_pve_config.sh` | Runs nightly via cron at 3am (`/usr/local/sbin/backup_pve_config.sh`) |
| `install-fan-and-erc-services.sh` | One-time after fresh Proxmox install — installs fan control + ERC systemd services |
| `fan-script/fan_control.py` | **Active fan control** — installed at `/usr/local/bin/fan_control.py`, running as `fan_control.service` (Python PID). The stepped/noctua shell scripts in the same directory are alternatives, not currently in use. |
| `erc-script/set-erc.sh` | Installed as `set-erc.service` — oneshot at boot, sets 7s TLER on all spinning disks |
| `map-media-uid-gid.sh <CTID>` | Run when adding a new unprivileged LXC that needs UID 1000 bind mount access |
| `setup_samba.sh` | One-time infra-services Samba/Time Machine setup |
| `setup-datasets-directories.sh` | One-time ZFS dataset + appdata directory scaffolding |
| `update-downloads.sh` | Already run — one-time migration script, kept for reference |

Useful installed utilities: `tail-fanlog` (streams `/var/log/fan_control.log`).

**Sanoid** manages ZFS snapshots, running every hour via cron. Config at `/etc/sanoid/sanoid.conf` — snapshots `core/app-configs` and `tank/media`.

## LXC Setup Scripts (`lxc-scripts/`)

Interactive scripts run on the Proxmox host to provision new LXC containers:

- `setup_media_services_lxc.sh` — prompts for CTID, creates media user, binds all datasets, deploys compose stack
- `setup_plex_lxc.sh` — prompts for CTID, uses Proxmox community script, enables GPU passthrough for Intel Quick Sync

## DNS & External Domains

Three `cloudflare-ddns` containers in infra-services keep `kdrisc01.uk` up to date:

| Container | Record | Proxied | Purpose |
|---|---|---|---|
| `cloudflare-ddns-root` | `kdrisc01.uk` (@) | Yes | Root domain |
| `cloudflare-ddns-wildcard` | `*.kdrisc01.uk` | Yes | All subdomains |
| `cloudflare-ddns-home` | `home.kdrisc01.uk` | **No** | CNAME target for external domains |

`home.kdrisc01.uk` is the unproxied record to use as a CNAME target when pointing external domains (e.g. Namecheap) at the homelab. Proxied records can't be used as CNAME targets from outside Cloudflare because Cloudflare can't issue TLS certs for domains it doesn't manage.

### External domains

| Domain | Registrar | DNS | Points to | Notes |
|---|---|---|---|---|
| `overtalkingpod.party` | Namecheap | Cloudflare | Cloudflare Redirect Rule → `https://overtalkingpod.libsyn.com/` (301) | Apex + `www` are proxied A records to `192.0.2.1` — a dummy IP that exists only so the redirect rule fires at the edge |
| `booking.overtalkingpod.party` | Namecheap | Cloudflare | CNAME → `home.kdrisc01.uk` → NPM → `overtalking-booking:3001` | Must stay **DNS only** (unproxied) or NPM's Let's Encrypt renewal breaks. Google OAuth credentials must include this domain |

`overtalkingpod.party` uses Cloudflare nameservers (a separate zone from `kdrisc01.uk`) rather than Namecheap BasicDNS. It was migrated because Namecheap's URL Forwarding serves HTTP only — port 443 on their forwarder is closed — and browsers now upgrade typed bare domains to HTTPS by default, so the redirect stopped resolving for visitors. Cloudflare terminates TLS at the edge and issues the cert automatically.

Moving the nameservers also disabled Namecheap Email Forwarding (the `eforward*.registrar-servers.com` MX records), which only works on Namecheap BasicDNS. Cloudflare Email Routing replaces it if mail on this domain is ever needed.

### Adding a new external domain

1. Add a CNAME in the registrar pointing the subdomain to `home.kdrisc01.uk`
2. Add a proxy host in NPM ([http://192.168.5.235:81](http://192.168.5.235:81)) with Let's Encrypt SSL
3. If the service uses Google OAuth, add the new domain to the authorized origins/redirect URIs in [Google Cloud Console](https://console.cloud.google.com) → APIs & Services → Credentials

## Recyclarr

`app-configs/recyclarr/recyclarr.yml` manages custom format and quality profile sync for Radarr (port 30025) and Sonarr (port 30027) on the Proxmox host. Run Recyclarr manually or via cron — it's not containerized in this repo.
