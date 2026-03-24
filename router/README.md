# Home Lab - Home Assistant, Portainer, and Pi-hole Deployment

This Ansible setup deploys Home Assistant, Portainer, and Pi-hole on a remote OpenWrt device using Docker Compose.

## Prerequisites

1. **Ansible installed** on your local machine:

   ```bash
   pip install ansible
   # or
   brew install ansible  # macOS
   ```

2. **SSH access** to the OpenWrt device as root

   - SSH key should be set up for passwordless access, or you'll need to use `ansible-playbook --ask-pass`

3. **Docker installed** on the OpenWrt device
   - The playbook will check for Docker and fail if not found
   - Docker Compose will be automatically installed if missing

## Setup

1. **Update the inventory file** (`inventory.ini`):

   - Replace `YOUR_OPENWRT_IP` with the actual IP address of your OpenWrt device

2. **Optional: Customize the deployment directory**:

   - By default, everything is deployed to `/opt/lab` on the remote device
   - To use a different directory, override the variable when running the playbook:
     ```bash
     ansible-playbook playbook.yml -e "lab_dir=/path/to/custom/dir"
     ```

3. **Test SSH connection**:

   ```bash
   ssh root@YOUR_OPENWRT_IP
   ```

3. **Run the playbook**:

   ```bash
   ansible-playbook playbook.yml
   ```

   If you need to provide an SSH password:

   ```bash
   ansible-playbook playbook.yml --ask-pass
   ```

## Services

After deployment, the following services will be available:

- **Home Assistant**: Accessible on the host network (typically port 8123)

  - Configuration directory: `/opt/lab/homeassistant` on the remote device
  - Access via: `http://YOUR_OPENWRT_IP:8123`

- **Portainer**: Web-based Docker management
  - HTTP: `http://YOUR_OPENWRT_IP:9000`
  - HTTPS: `https://YOUR_OPENWRT_IP:9443`
  - First-time setup: Create an admin account when accessing Portainer

- **Pi-hole**: DNS filtering + dashboard (OpenWrt-friendly ports)
  - DNS listener (host): `5353/tcp` and `5353/udp`
  - Dashboard HTTP: `http://YOUR_OPENWRT_IP:8081/admin`
  - Dashboard HTTPS: `https://YOUR_OPENWRT_IP:8443/admin`
  - Persistent data: Docker named volumes `pihole_config` and `pihole_dnsmasq_config`

## Using Pi-hole with OpenWrt

Pi-hole in this stack is intentionally mapped to non-default host ports to avoid clashing with OpenWrt services:

- OpenWrt `dnsmasq` usually owns host port `53`
- LuCI/uhttpd usually owns host ports `80` and `443`

Current mappings in `compose.yml`:

- `5353 -> 53` (Pi-hole DNS)
- `8081 -> 80` (Pi-hole web UI HTTP)
- `8443 -> 443` (Pi-hole web UI HTTPS)

### Configure OpenWrt to forward DNS to Pi-hole

Keep OpenWrt `dnsmasq` enabled for LAN clients on port `53`, and forward upstream queries to Pi-hole on localhost port `5353`.

UCI example:

```bash
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5353'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

Equivalent `/etc/config/dhcp` line:

```text
list server '127.0.0.1#5353'
```

### Upstream resolver notes

Pi-hole is configured to use Cloudflare upstream DNS:

- `DNS1=1.1.1.1`
- `DNS2=1.0.0.1`

Google alternatives are left commented in `compose.yml` for quick switching.

Do not point Pi-hole upstream back to the router IP in this on-router setup, or you can create DNS loops.

### Quick verification

1. Open Pi-hole UI at `http://YOUR_OPENWRT_IP:8081/admin`
2. Query any domain from a LAN client and confirm responses
3. Check Pi-hole Query Log to verify requests are passing through Pi-hole

## Managing Containers

You can manage the containers directly on the OpenWrt device:

```bash
# SSH into the device
ssh root@YOUR_OPENWRT_IP

# View container status
docker compose -f /opt/lab/docker-compose.yml ps

# View logs
docker compose -f /opt/lab/docker-compose.yml logs -f

# Stop containers
docker compose -f /opt/lab/docker-compose.yml down

# Start containers
docker compose -f /opt/lab/docker-compose.yml up -d

# Restart containers
docker compose -f /opt/lab/docker-compose.yml restart
```

## Updating Services

To update the containers, run the playbook again:

```bash
ansible-playbook playbook.yml
```

Or manually on the device:

```bash
docker compose -f /opt/lab/docker-compose.yml pull
docker compose -f /opt/lab/docker-compose.yml up -d
```

## Troubleshooting

- **Connection refused**: Check that Docker is running on the OpenWrt device
- **Permission denied**: Ensure SSH key has proper permissions (`chmod 600 ~/.ssh/id_rsa`)
- **Port conflicts**: Modify ports in `compose.yml` if ports 9000, 9443, 8123, 5353, 8081, or 8443 are already in use
