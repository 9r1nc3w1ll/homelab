# arr-stack

Docker Compose stack for **torrenting behind VPN** (Gluetun + qBittorrent), **Servarr** automation (Prowlarr, Sonarr, Radarr, Bazarr), **Jellyfin** playback, **Seerr** requests, and **FlareSolverr** for indexer challenges.

## Prerequisites

- **Docker** and **Docker Compose** v2.
- A **Linux** host (or another environment where Gluetun can use `NET_ADMIN` and `/dev/net/tun`). Gluetun is not supported the same way on typical macOS Docker Desktop setups.
- A **VPN** account and the variables Gluetun expects for your provider ([Gluetun wiki](https://github.com/qdm12/gluetun-wiki)).

## Quick start

1. Copy the environment template and edit it (especially VPN settings):

   ```bash
   cp .env.example .env
   ```

2. Create a sensible layout under `DATA_ROOT` (default `./data` next to this file), for example:

   ```text
   data/
     downloads/
     media/
       tv/
       movies/
     config/
       prowlarr/
       sonarr/
       radarr/
       bazarr/
       jellyfin/
     seerr/
   ```

3. Ensure ownership matches `PUID`/`PGID` in `.env` for `data/`. The **Seerr** config directory must be writable by **UID 1000** inside its container (`chown -R 1000:1000 data/seerr` on the host if you see permission errors).

4. Start the stack from **this directory**:

   ```bash
   docker compose up -d
   ```

Do **not** commit `.env`; it is listed in the repo root `.gitignore`.

## Services and default ports

| Service        | Default port | Notes |
| -------------- | ------------ | ----- |
| qBittorrent UI | 8080         | Published via **Gluetun** (`QBIT_WEBUI_PORT`). |
| Prowlarr       | 9696         | |
| Sonarr         | 8989         | |
| Radarr         | 7878         | |
| Bazarr         | 6767         | |
| Jellyfin       | 8096 (HTTP), 8920 (HTTPS) | Add libraries under `/data` (see below). |
| Seerr          | 5055         | [Documentation](https://docs.seerr.dev/) |
| FlareSolverr   | 8191         | |

Torrent traffic uses **UDP/TCP** on `TORRENT_PORT` (default **6881**), also mapped through Gluetun.

## Data layout and hardlinks

`downloads` and `media` should live on the **same filesystem** on the host so Sonarr/Radarr can **hardlink** from completed downloads into library folders instead of copying.

Inside containers:

- **Sonarr:** `/tv`, `/downloads`
- **Radarr:** `/movies`, `/downloads`
- **qBittorrent:** `/downloads`
- **Jellyfin:** `/config`, `/data` (host `data/media` → `/data`; use e.g. `/data/tv` and `/data/movies` as library paths in the UI)

## Jellyfin hardware transcoding (AMD / GMKtec-style mini PC)

The **Jellyfin** service passes **`/dev/dri`** into the container and adds the **`video`** and **`render`** groups so VAAPI can use the AMD GPU (integrated or discrete).

**On the host (before expecting HW transcode to work):**

1. Install AMD/Mesa VAAPI userspace for your distro (names vary), for example on Debian/Ubuntu-family systems you often need packages such as **`mesa-va-drivers`**, **`vainfo`** (from `vainfo` or `mesa-utils`), and ensure the AMDGPU kernel driver is loaded (`amdgpu` for modern AMD).
2. Confirm devices exist: `ls -la /dev/dri` (you should see `card0`, `renderD128`, etc.).
3. Run **`vainfo`** on the host and confirm a non-empty “vainfo: VA-API version” / driver section.

**In Jellyfin (Dashboard → Playback → Transcoding):**

- Enable **hardware acceleration**.
- Choose **Video Acceleration API (VAAPI)**.
- **VA API device** is typically `/dev/dri/renderD128` (use the render node `vainfo` reports if different).

If `group_add` for **`render`** fails on an unusual host (no `render` group), remove that line in `docker-compose.yml` or align with your distro’s DRI group names.

For HDR **tone-mapping** extras on AMD, see LinuxServer **Docker Mods** for Jellyfin on [mods.linuxserver.io](https://mods.linuxserver.io/) (optional; base VAAPI encode/decode works without mods).

## App wiring

- **Sonarr / Radarr → download client:** host **`gluetun`**, port **8080**, URL `http://gluetun:8080` (matches `WEBUI_PORT` in Compose).
- **Prowlarr → FlareSolverr:** set FlareSolverr’s URL in Prowlarr to your FlareSolverr instance (host **`flaresolverr`**, port from `FLARESOLVERR_PORT`; follow current Prowlarr/FlareSolverr docs for path and tags).
- **Prowlarr → Sonarr/Radarr:** configure app sync in Prowlarr after each service is up.
- **Seerr:** connect to Jellyfin (and Sonarr/Radarr as needed) in the Seerr UI.

## Security

- Keep UIs on your **LAN** or behind a **reverse proxy** with authentication and TLS if exposed beyond the home network.
- VPN credentials belong only in `.env` on the server, not in git.

## References

- [Gluetun](https://github.com/qdm12/gluetun)
- [Servarr Docker](https://wiki.servarr.com/docker)
- [Seerr](https://docs.seerr.dev/)
- [LinuxServer.io](https://docs.linuxserver.io/)
