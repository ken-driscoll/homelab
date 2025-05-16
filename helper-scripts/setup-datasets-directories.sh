# Ensure host user/group
if ! id -u media &>/dev/null || [[ $(id -u media) -ne 1000 ]] || [[ $(id -g media) -ne 1000 ]]; then
  echo "Creating media:1000 user/group on host..."
  getent group media >/dev/null || groupadd -g 1000 media
  id -u media &>/dev/null || useradd -u 1000 -g 1000 -M -N -r -s /usr/sbin/nologin media
else
  echo "Host user/group media:1000 already exists."
fi

# Create app-configs and docker-compose datasets
echo "📂 Creating ZFS datasets..."
zfs list core/app-configs >/dev/null 2>&1 || zfs create core/app-configs
zfs list core/app-configs/media-services >/dev/null 2>&1 || zfs create core/app-configs/media-services
zfs list core/app-configs/plex >/dev/null 2>&1 || zfs create core/app-configs/plex
zfs list core/docker-compose >/dev/null 2>&1 || zfs create core/docker-compose
zfs list core/media-downloads >/dev/null 2>&1 || zfs create core/media-downloads

# Restore Plex config if valid
BACKUP_PATH="/tank/app-configs-backup/plex-app/config"
TARGET_PATH="/core/app-configs/plex"

echo "📥 Copying valid backup into place..."
mkdir -p "$(dirname "$TARGET_PATH")"
rsync -a "$BACKUP_PATH/" "$TARGET_PATH/"
echo "✅ Plex configuration restored into mounted dataset."

# Ensure appdata subfolders exist and have proper ownership
for dir in sabnzbd sonarr radarr readarr prowlarr overseerr homarr; do
  mkdir -p "/core/app-configs/media-services/$dir"
  chown -R 1000:1000 "/core/app-configs/media-services/$dir"
done

# Ensure media and download subfolders exist and have proper ownership
for dir in complete incomplete; do
  mkdir -p "/core/media-downloads/$dir"
  chown -R 1000:1000 "/core/media-downloads/$dir"
done

mkdir -p "/tank/media"
chown -R 1000:1000 "/tank/media"
chmod g+s "/tank/media"