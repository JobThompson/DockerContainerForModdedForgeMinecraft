# modded-minecraft-server-docker

A production-ready Docker container for hosting **Forge** and **Fabric** modded Minecraft servers.  
Drop your modpack files into a folder, set a few environment variables, and run `docker compose up`.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Forge Setup](#forge-setup)
- [Fabric Setup](#fabric-setup)
- [Updating Modpacks](#updating-modpacks)
- [Volume Reference](#volume-reference)
- [Environment Variable Reference](#environment-variable-reference)
- [Repository Structure](#repository-structure)
- [Backups](#backups)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/JobThompson/DockerContainerForModdedForgeMinecraft.git
cd DockerContainerForModdedForgeMinecraft

# 2. Create local directories
mkdir -p data modpack backups

# 3. Copy your mod files into modpack/
cp -r /path/to/your/mods/*  modpack/mods/
cp -r /path/to/your/config/* modpack/config/

# 4. Edit docker-compose.yml (or supply an env file) and set your versions

# 5. Build and start
docker compose up --build
```

---

## Forge Setup

1. Copy `examples/forge.env` and adjust values:

```env
MODLOADER=forge
MINECRAFT_VERSION=1.20.1
FORGE_VERSION=47.2.0
JAVA_MEMORY=6G
EULA=true
```

2. Pass the file to Docker Compose:

```bash
docker compose --env-file examples/forge.env up --build
```

Or inline in `docker-compose.yml`:

```yaml
environment:
  MODLOADER: forge
  MINECRAFT_VERSION: 1.20.1
  FORGE_VERSION: 47.2.0
  JAVA_MEMORY: 6G
  EULA: "true"
```

---

## Fabric Setup

1. Copy `examples/fabric.env` and adjust values:

```env
MODLOADER=fabric
MINECRAFT_VERSION=1.20.1
FABRIC_LOADER_VERSION=0.15.7
JAVA_MEMORY=6G
EULA=true
```

2. Pass the file to Docker Compose:

```bash
docker compose --env-file examples/fabric.env up --build
```

---

## Updating Modpacks

No image rebuild is required to update mods or configs:

1. Replace files in your `./modpack` directory (maps to `/servers/modpack` in the container).
2. Restart the container:

```bash
docker compose restart
```

The entrypoint script syncs `/servers/modpack` into `/data` on every startup.

---

## Volume Reference

| Host Path    | Container Path    | Purpose                                |
|-------------|-------------------|----------------------------------------|
| `./data`    | `/data`           | Server root (world, logs, jar files)   |
| `./modpack` | `/servers/modpack`| Modpack files (mods, config, etc.)     |
| `./backups` | `/backups`        | Automated world backups                |

### Modpack directory layout

```
modpack/
├── mods/           # Mod .jar files
├── config/         # Mod configuration files
├── defaultconfigs/ # Default config files (applied on first run)
├── server.properties
├── ops.json
└── whitelist.json
```

---

## Environment Variable Reference

| Variable               | Required      | Default | Description                                          |
|------------------------|---------------|---------|------------------------------------------------------|
| `MODLOADER`            | ✅ Yes        | —       | `forge` or `fabric`                                  |
| `MINECRAFT_VERSION`    | ✅ Yes        | —       | Minecraft version (e.g. `1.20.1`)                    |
| `FORGE_VERSION`        | Forge only    | —       | Forge build version (e.g. `47.2.0`)                  |
| `FABRIC_LOADER_VERSION`| Fabric only   | —       | Fabric loader version (e.g. `0.15.7`)                |
| `JAVA_MEMORY`          | No            | `4G`    | Heap size for `-Xms` and `-Xmx` (e.g. `6G`, `8G`)   |
| `EULA`                 | ✅ Yes        | —       | Must be `true` to accept the Minecraft EULA          |
| `WORLD_NAME`           | No            | `world` | World folder name to back up (or `level-name` value) |
| `BACKUP_RETAIN_DAYS`   | No            | `7`     | Days to keep automated backups                       |

---

## Repository Structure

```
.
├── Dockerfile
├── entrypoint.sh
├── docker-compose.yml
├── README.md
├── scripts/
│   ├── install_forge.sh
│   ├── install_fabric.sh
│   └── backup.sh
└── examples/
    ├── forge.env
    └── fabric.env
```

---

## Backups

Run `backup.sh` manually or schedule it via cron to back up your world:

```bash
docker exec mc-server /scripts/backup.sh
```

`backup.sh` backs up `/data/<WORLD_NAME>` (default: `world`). If `WORLD_NAME` is not set, it also auto-detects `level-name` from `/data/server.properties` when available.  
Backups are stored in `/backups` (mapped to `./backups` on the host) as timestamped `.tar.gz` archives.  
Archives older than `BACKUP_RETAIN_DAYS` (default: 7) are automatically removed.

---

## Troubleshooting

### Server fails to start with "EULA must be accepted"
Set `EULA=true` in your environment variables.

### Forge/Fabric installer download fails
- Verify `MINECRAFT_VERSION` and `FORGE_VERSION` / `FABRIC_LOADER_VERSION` are correct.
- Check that the container has internet access.
- For Forge, verify the version exists at [Forge Files](https://files.minecraftforge.net/).
- For Fabric, verify at [Fabric Meta](https://meta.fabricmc.net/).

### Mods not loading after update
Make sure you copied files into `./modpack/mods/` on the host and restarted the container.  
Files are synced from `/servers/modpack` to `/data` on every container start.

### Out of memory errors
Increase `JAVA_MEMORY` (e.g. `JAVA_MEMORY=8G`). Ensure your host has sufficient RAM.

### Container exits immediately
Check logs with:
```bash
docker compose logs -f
```

### Port already in use
Ensure port `25565` is not in use by another process. Change the host port mapping in `docker-compose.yml`:
```yaml
ports:
  - "25566:25565"
```
