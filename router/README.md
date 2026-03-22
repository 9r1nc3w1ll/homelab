# Home Lab - Home Assistant & Portainer Deployment

This Ansible setup deploys Home Assistant and Portainer on a remote OpenWrt device using Docker Compose.

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
- **Port conflicts**: Modify ports in `docker-compose.yml` if ports 9000, 9443, or 8123 are already in use
