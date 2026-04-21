# Homelab Documentation

> Scripts and compose files: https://github.com/ken-driscoll/homelab

---

## Proxmox Host

| Property | Value |
|---|---|
| Hostname | `pve` |
| IP | `192.168.4.41` |
| Proxmox Version | 8.4.1 |
| Kernel | 6.8.12-10-pve |
| CPU | Intel Xeon E3-1245 v6 @ 3.70GHz (4 cores / 8 threads) |
| RAM | 64 GB |
| Boot Drive | 465.8 GB NVMe (nvme2n1) — LVM: 8 GB swap, 456.8 GB root |
| Network | `vmbr0` bridge on `eno2` — `192.168.4.41/22` |

---

## Storage

### `core` — ZFS Mirror (NVMe)

| Property | Value |
|---|---|
| Vdev | mirror-0 (2× Crucial P3 1TB NVMe) |
| Total | ~928 GB |
| Used | ~86 GB |
| Health | ONLINE — 0 errors |

Used for: LXC/VM root volumes, app configs, download staging, scripts.

Key datasets:

| Dataset | Mount | Purpose |
|---|---|---|
| `core/app-configs/media-services` | `/core/app-configs/media-services` | Persistent config for media-services containers |
| `core/app-configs/infra-services` | `/core/app-configs/infra-services` | Persistent config for infra-services containers |
| `core/app-configs/plex` | `/core/app-configs/plex` | Plex Media Server library/metadata |
| `core/scripts` | `/core/scripts` | Homelab scripts (git repo mount) |
| `core/downloads` | `/core/downloads` | Download staging area |

### `tank` — ZFS RAIDZ2 (8× 7.3 TB HDD)

| Property | Value |
|---|---|
| Vdev | raidz2-0 (8× 7.3 TB HDD) |
| Total | ~58 TB raw / ~41 TB usable |
| Used | ~23 TB |
| Health | ONLINE — 0 errors |

Used for: media library, Time Machine backups, Proxmox backups.

Key datasets:

| Dataset | Mount | Purpose |
|---|---|---|
| `tank/media` | `/tank/media` | Main media library (16.2 TB) |
| `tank/timemachine/kens-mac` | `/tank/timemachine/kens-mac` | Time Machine — Ken's Mac (1 TB quota) |
| `tank/timemachine/megs-mac` | `/tank/timemachine/megs-mac` | Time Machine — Meg's Mac (1 TB quota) |
| `tank/proxmox-backups` | `/tank/proxmox-backups` | Proxmox VM/LXC backups (283 GB) |
| `tank/app-configs-backup` | `/tank/app-configs-backup` | App config backups |

### `local` — Proxmox Dir

OS-level directory at the Proxmox root partition. Holds ISOs, CT templates, small misc files (~9 GB used of 471 GB available).

### `backups` — Dir

2 TB backup directory (~298 MB used).

---

## Media Library (`/tank/media`)

| Folder | Notes |
|---|---|
| Movies | |
| TV Shows | |
| Audiobooks | |
| Books | |
| Comics | |
| Gaming | |
| Podcast | |
| Pictures | |
| P90X / P90X3 | Workout videos |
| Video Project Backups | |

---

## Virtual Machines

### VM 222 — Home Assistant OS (`homeassistant`)

| Property | Value |
|---|---|
| IP | `192.168.5.240` |
| RAM | 8 GB |
| Disk | 32 GB (core ZFS, writethrough cache, discard/SSD enabled) |
| CPUs | 8 vCPUs (host passthrough) |
| BIOS | OVMF (UEFI) |
| OS | l26 (Linux / HAOS) |
| Start on boot | Yes |
| QEMU Guest Agent | Enabled |
| USB passthrough | 2× USB devices (host ports 1-11, 1-12) |
| Tags | `home` |

---

## LXC Containers

### LXC 100 — `media-services` (Docker)

| Property | Value |
|---|---|
| IP | `192.168.5.234` (DHCP) |
| RAM | 4 GB |
| Root disk | 32 GB (core ZFS) |
| Swap | 512 MB |
| OS | Debian |
| Start on boot | Yes |
| Features | `nesting=1` (Docker support) |
| Tags | `docker`, `media` |

**Mount Points:**

| Host Path | Container Path | Purpose |
|---|---|---|
| `/core/app-configs/media-services` | `/opt/appdata` | App config persistence |
| `/core/downloads` | `/mnt/downloads` | Download staging |
| `/tank/media` | `/mnt/media` | Media library |
| `/core/scripts/homelab/docker-compose/media-services` | `/opt/compose` | Docker Compose file |

**USB passthrough:** `/dev/ttyUSB0`, `/dev/ttyUSB1`, `/dev/ttyACM0`, `/dev/ttyACM1`, `/dev/serial/by-id`

#### Docker Services

| Container | Image | Port | Purpose |
|---|---|---|---|
| `sonarr` | linuxserver/sonarr | 8989 | TV show management |
| `radarr` | linuxserver/radarr | 7878 | Movie management |
| `readarr` | linuxserver/readarr:develop | 8787 | Book management |
| `speakarr` | linuxserver/readarr:develop | 8788→8787 | Audiobook management |
| `prowlarr` | linuxserver/prowlarr | 9696 | Indexer management |
| `seerr` | seerr-team/seerr | 5055 | Media request manager |
| `sabnzbd` | linuxserver/sabnzbd | 8080 | Usenet downloader |
| `qbittorrentvpn` | binhex/arch-qbittorrentvpn | 8484 (UI), 6881 (TCP/UDP) | Torrent client behind OpenVPN (custom provider, VPN_PROV=custom) |
| `bazarr` | linuxserver/bazarr | 6767 | Subtitle management |
| `audiobookshelf` | advplyr/audiobookshelf | 13378→80 | Audiobook server |
| `tautulli` | linuxserver/tautulli | 8181 | Plex stats/monitoring |
| `homarr` | homarr-labs/homarr | 7575 | Dashboard |
| `homepage` | gethomepage/homepage | 3000 | Dashboard (kdrisc01.uk) |
| `cadvisor` | gcr.io/cadvisor/cadvisor | 9292→8080 | Container metrics |
| `portainer-agent` | portainer/agent | 9001 | Portainer agent |
| `watchtower` | containrrr/watchtower | — | Auto-updates (daily 3am, Pushover notifications) |

All linuxserver containers use `PUID=1000`, `PGID=1000`, `TZ=America/Chicago`.

---

### LXC 102 — `plex` (Bare Metal Plex)

| Property | Value |
|---|---|
| IP | `192.168.5.243` (DHCP) |
| RAM | 16 GB |
| Root disk | 16 GB (core ZFS) |
| Swap | 512 MB |
| OS | Debian |
| Start on boot | Yes |
| Features | `nesting=1` |
| Tags | `media` |
| GPU passthrough | `/dev/dri/card0` (gid=44), `/dev/dri/renderD128` (gid=104) — hardware transcoding |

**Mount Points:**

| Host Path | Container Path | Purpose |
|---|---|---|
| `/core/app-configs/plex` | `/var/lib/plexmediaserver` | Plex library/metadata/config |
| `/tank/media` | `/media` | Media library |

**Plex:**

- Version: `1.43.1.10611-1e34174b1`
- Runs as `plexmediaserver` systemd service
- Memory usage: ~6.2 GB
- GPU hardware transcoding via DRI device passthrough

---

### LXC 110 — `infra-services` (Docker)

| Property | Value |
|---|---|
| IP | `192.168.5.235` (DHCP) |
| RAM | 4 GB |
| Root disk | 32 GB (core ZFS) |
| Swap | 512 MB |
| OS | Debian |
| Start on boot | Yes |
| Features | `nesting=1` (Docker support) |
| Tags | `docker` |

**Mount Points:**

| Host Path | Container Path | Purpose |
|---|---|---|
| `/core/app-configs/infra-services` | `/opt/appdata` | App config persistence |
| `/core/scripts/homelab/docker-compose/infra-services` | `/opt/compose` | Docker Compose file |
| `/core/app-configs/infra-services/samba` | `/etc/samba` | Samba config |
| `/tank/timemachine` | `/mnt/timemachine` | Time Machine shares |
| `/core/downloads` | `/mnt/downloads` | Download staging |
| `/tank/media` | `/mnt/media` | Media library |

#### Docker Services

| Container | Image | Port | Purpose |
|---|---|---|---|
| `nginx-proxy-manager` | jc21/nginx-proxy-manager | 80, 81 (admin), 443 | Reverse proxy + SSL |
| `cloudflare-ddns-root` | oznu/cloudflare-ddns | — | DDNS for `kdrisc01.uk` (proxied) |
| `cloudflare-ddns-wildcard` | oznu/cloudflare-ddns | — | DDNS for `*.kdrisc01.uk` (proxied) |
| `prometheus` | prom/prometheus | 9191→9090 | Metrics collection |
| `influxdb` | influxdb:2 | 8086 | Time-series DB (org: homelab, bucket: proxmox, 90d retention) |
| `grafana` | grafana/grafana | 3000 | Metrics dashboards |
| `cadvisor` | gcr.io/cadvisor/cadvisor | 9292→8080 | Container metrics |
| `portainer-agent` | portainer/agent | 9001 | Portainer agent |
| `watchtower` | containrrr/watchtower | — | Auto-updates (daily 3am, Pushover notifications) |
| `overtalking-booking` | ghcr.io/ken-driscoll/overtalking-booking | 3001 | Podcast guest booking site (`overtalking-booking.kdrisc01.uk`) — env at `/opt/appdata/overtalking-booking/.env` |

Domain: `kdrisc01.uk` — managed via Cloudflare with DDNS, proxied through Cloudflare, SSL via Nginx Proxy Manager.

---

### LXC 10443 — `scrypted`

| Property | Value |
|---|---|
| IP | `192.168.5.237` (DHCP) |
| RAM | 16 GB |
| Swap | 8 GB |
| Root disk | 48 GB (core ZFS, noatime) |
| Data volume | 48 GB (core ZFS, noatime) — mounted at `/root/.scrypted/volume` |
| OS | Ubuntu |
| Privilege | Unprivileged |
| Start on boot | Yes |
| Features | `nesting=1` |
| Tags | `home` |
| Management UI | `https://scrypted:10443/` |

**Device passthrough:** `/dev/kfd`, `/dev/dri`, `/dev/accel`, `/dev/apex_0`, `/dev/apex_1`, `/dev/bus/usb`

Scrypted runs via Docker Compose, managed by a systemd service (`scrypted.service`) that calls `/root/.scrypted/docker-compose.sh`.

---

## Network Summary

| Host | IP | Role |
|---|---|---|
| Proxmox host | 192.168.4.41 | Hypervisor |
| media-services | 192.168.5.234 | Media stack (Docker) |
| infra-services | 192.168.5.235 | Infra/proxy stack (Docker) |
| scrypted | 192.168.5.237 | Camera/security |
| homeassistant | 192.168.5.240 | Home automation |
| plex | 192.168.5.243 | Plex Media Server |

All containers/VMs on `vmbr0` bridge (eno2), using DHCP. Network is `192.168.4.0/22`.

External domain `kdrisc01.uk` uses Cloudflare proxied DDNS, with Nginx Proxy Manager on infra-services handling SSL termination and reverse proxying.

---

## Backups

- Proxmox backups stored on `tank/proxmox-backups` (283 GB used)
- App configs backed up to `tank/app-configs-backup`
- Docker containers auto-updated daily at 3am via Watchtower (both LXCs) with Pushover notifications
- ZFS scrubs run weekly (last clean scrub: April 12, 2026)
- **Sanoid** runs ZFS snapshots hourly via cron (`5 * * * *`) — `core/app-configs` (24h/7d/2m retention) and `tank/media` (7d retention)

---

## Raspberry Pi Stack (optional)

`docker-compose/raspberrypi/compose.yml` — standalone stack for a Raspberry Pi if needed:

| Container | Port | Purpose |
|---|---|---|
| `portainer` | 9443, 9000 | Portainer CE management UI |
| `uptime-kuma` | 3001 | Uptime monitoring |

Configured to manage agents on media-services and infra-services.

---

## Scripts

All scripts live in this repo and are run manually or installed as systemd services on the Proxmox host.

### `helper-scripts/`

| Script / Dir | Purpose |
|---|---|
| `update-homelab.sh` | `git pull` wrapper — also installed as `/usr/local/bin/update-homelab` system command |
| `backup_pve_config.sh` | Backs up `/etc/pve` to `tank/proxmox-backups/pve-config/`, keeps 7 most recent — runs nightly via cron at 3am |
| `fan-script/` | Fan control scripts: `fan_control.py` **(active, installed as `fan_control.service`)**, `fan_control_pid_noctua.sh`, `fan_control_stepped_noctua.sh`, `stepped-fan-control.service` |
| `erc-script/` | ERC/TLER scripts: `set-erc.sh` and `set-erc.service` — installed as `set-erc.service`, sets 7s TLER on all spinning disks at boot |
| `install-fan-and-erc-services.sh` | Installs and enables the fan control + ERC systemd services |
| `setup_samba.sh` | One-time: installs Samba + Cockpit, creates Time Machine shares with 1 TB quotas |
| `setup-datasets-directories.sh` | One-time: creates ZFS datasets and appdata directory structure |
| `map-media-uid-gid.sh <CTID>` | Maps UID 1000 in an unprivileged LXC to host UID 1000 (preserves file ownership across bind mounts) |
| `update-downloads.sh` | One-time migration script (already run — moved download staging from `core/media-downloads` to `core/downloads`) |

### `lxc-scripts/`

| Script | Purpose |
|---|---|
| `setup_media_services_lxc.sh` | Interactive setup for media-services LXC — creates `media` user, binds datasets, pulls and deploys compose stack, registers `media-services.local` via avahi |
| `setup_plex_lxc.sh` | Interactive setup for Plex LXC — creates container via Proxmox community script, binds datasets, enables GPU passthrough for hardware transcoding |

---

## App Configs

`app-configs/recyclarr/recyclarr.yml` — [Recyclarr](https://recyclarr.dev/) quality profile sync config for Radarr and Sonarr. Manages custom formats and quality profiles:

- **Radarr**: UHD Bluray + WEB and HD Bluray + WEB profiles; blocks SDR, x265 HD without HDR
- **Sonarr**: WEB-1080p and WEB-2160p profiles

Recyclarr runs against the Radarr/Sonarr instances directly (not containerized here — run manually or via cron).
