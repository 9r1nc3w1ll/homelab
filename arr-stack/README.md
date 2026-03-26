# arr-stack

Docker Compose stack for **torrenting** (qBittorrent; optional **Gluetun** VPN is commented out in Compose), **Servarr** automation (Prowlarr, Sonarr, Radarr, Lidarr, Bazarr), **LazyLibrarian** for book grabs, **Jellyfin** playback, requests (**Seerr**), and **FlareSolverr** for indexer challenges.

## Prerequisites

- **Docker** and **Docker Compose** v2.
- A **Linux** host (or another environment where Gluetun can use `NET_ADMIN` and `/dev/net/tun` if you re-enable it). Gluetun is not supported the same way on typical macOS Docker Desktop setups.
- If you **uncomment Gluetun** in `docker-compose.yml`: a **VPN** account and the variables Gluetun expects for your provider ([Gluetun wiki](https://github.com/qdm12/gluetun-wiki)).

## Quick start

1. Copy the environment template and edit it (paths; VPN-related keys if you use Gluetun):
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
     books/
     music/
     config/
       prowlarr/
       sonarr/
       radarr/
       lazylibrarian/
       lidarr/
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


| Service        | Default port              | Notes                                          |
| -------------- | ------------------------- | ---------------------------------------------- |
| qBittorrent UI | 8080                      | Published on **qBittorrent** (`QBIT_WEBUI_PORT`). |
| Prowlarr       | 9696                      |                                                |
| Sonarr         | 8989                      |                                                |
| Radarr         | 7878                      |                                                |
| LazyLibrarian  | 5299                      | [LinuxServer docs](https://docs.linuxserver.io/images/docker-lazylibrarian/) (`LAZYLIBRARIAN_PORT`). |
| Lidarr         | 8686                      |                                                |
| Bazarr         | 6767                      |                                                |
| Jellyfin       | 8096 (HTTP), 8920 (HTTPS) | Add libraries under `/data` (see below).       |
| Seerr          | 5055                      | [Documentation](https://docs.seerr.dev/)       |
| FlareSolverr   | 8191                      |                                                |


Torrent traffic uses **UDP/TCP** on `TORRENT_PORT` (default **6881**), published on the qBittorrent service.

## Data layout and hardlinks

`downloads` and library folders should live on the **same filesystem** on the host so Sonarr/Radarr can **hardlink** from completed downloads into library folders instead of copying. The same applies to any other library app in Compose (see volume mounts there).

Inside containers:

- **Sonarr:** `/tv`, `/downloads`
- **Radarr:** `/movies`, `/downloads`
- **LazyLibrarian:** `/books`, `/downloads`, `/config`
- **Lidarr:** `/music`, `/downloads`
- **qBittorrent:** `/downloads`
- **Jellyfin:** `/config`, `/data` (entire `DATA_ROOT` is mounted at `/data`; add libraries for paths that match your `DATA_ROOT` layout and any extra volume mounts in Compose)

## Jellyfin hardware transcoding (AMD / GMKtec-style mini PC)

The **Jellyfin** service passes `**/dev/dri`** into the container and adds the `**video**` and `**render**` groups so VAAPI can use the AMD GPU (integrated or discrete).

**On the host (before expecting HW transcode to work):**

1. Install AMD/Mesa VAAPI userspace for your distro (names vary), for example on Debian/Ubuntu-family systems you often need packages such as `**mesa-va-drivers`**, `**vainfo**` (from `vainfo` or `mesa-utils`), and ensure the AMDGPU kernel driver is loaded (`amdgpu` for modern AMD).
2. Confirm devices exist: `ls -la /dev/dri` (you should see `card0`, `renderD128`, etc.).
3. Run `**vainfo**` on the host and confirm a non-empty “vainfo: VA-API version” / driver section.

**In Jellyfin (Dashboard → Playback → Transcoding):**

- Enable **hardware acceleration**.
- Choose **Video Acceleration API (VAAPI)**.
- **VA API device** is typically `/dev/dri/renderD128` (use the render node `vainfo` reports if different).

If `group_add` for `**render`** fails on an unusual host (no `render` group), remove that line in `docker-compose.yml` or align with your distro’s DRI group names.

For HDR **tone-mapping** extras on AMD, see LinuxServer **Docker Mods** for Jellyfin on [mods.linuxserver.io](https://mods.linuxserver.io/) (optional; base VAAPI encode/decode works without mods).

## App wiring

- **Sonarr / Radarr (and other apps in this Compose file) → download client:** host `**qbittorrent**`, port **8080**, URL `http://qbittorrent:8080` (matches `WEBUI_PORT` in Compose). If you re-enable Gluetun and put qBittorrent behind it again, use host `**gluetun**` and `http://gluetun:8080` instead.
- **Prowlarr → FlareSolverr:** set FlareSolverr’s URL in Prowlarr to your FlareSolverr instance (host `**flaresolverr`**, port from `FLARESOLVERR_PORT`; follow current Prowlarr/FlareSolverr docs for path and tags).
- **Prowlarr → connected apps:** configure app sync in Prowlarr after each service is up. **LazyLibrarian** has no Prowlarr “app” sync; add **Torznab/Newznab** indexer URLs from Prowlarr in the LazyLibrarian UI instead.
- **Seerr:** connect to Jellyfin (and Sonarr/Radarr as needed) in the Seerr UI.

## Security

- Keep UIs on your **LAN** or behind a **reverse proxy** with authentication and TLS if exposed beyond the home network.
- VPN credentials belong only in `.env` on the server, not in git.
- LinuxServer `sonarr`, `radarr`, `prowlarr`, `bazarr`, and `lazylibrarian` containers do not provide supported env vars to set first-run UI username/password.
- LinuxServer `qbittorrent` also does not provide env vars for default WebUI credentials; it prints a temporary `admin` password in container logs on startup until you set persistent credentials in the app.

## References

- [Gluetun](https://github.com/qdm12/gluetun)
- [Servarr Docker](https://wiki.servarr.com/docker)
- [Seerr](https://docs.seerr.dev/)
- [LinuxServer.io](https://docs.linuxserver.io/)
- [LazyLibrarian](https://lazylibrarian.gitlab.io/)

