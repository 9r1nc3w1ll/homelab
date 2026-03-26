# Docker firewall troubleshooting (OpenWrt + fw4 + dockerd)

This doc exists because this failure mode is extremely confusing and wastes a lot of time: **containers are “Up”**, ports may even be published, but the container suddenly **cannot reach the internet** (DNS timeouts, `Connection refused`, gravity downloads fail, etc.).

It’s not “a Linux thing” in general. The key pieces here are **OpenWrt’s `dockerd` UCI config** (`/etc/config/dockerd`) and the **OpenWrt init script** (`/etc/init.d/dockerd`) which can auto-install iptables rules in `DOCKER-USER`.

## Symptom patterns

### 1) Pi-hole dashboard works on-router, but not from LAN

- `docker ps` shows `0.0.0.0:8081->80/tcp` published
- From the router: `http://127.0.0.1:8081/admin/` works
- From LAN: `http://192.168.1.1:8081/admin/` times out

This is usually an OpenWrt firewall forwarding issue: you need **`lan -> docker` forwarding** (see below).

### 2) Container loses outbound internet (DNS, HTTPS, ping)

From inside the container:

- `nslookup raw.githubusercontent.com 1.1.1.1` times out
- `wget https://...` fails, gravity lists become “inaccessible”
- even `ping 1.1.1.1` fails

This often happens when OpenWrt’s dockerd integration inserts a broad `DOCKER-USER` reject rule that blocks return traffic from WAN back to the Docker bridge.

## Quick diagnostics

On the router:

```sh
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker exec pihole sh -lc 'ping -c 1 -W 2 1.1.1.1 || true'
docker exec pihole sh -lc 'nslookup raw.githubusercontent.com 1.1.1.1 || true'
docker exec pihole sh -lc 'wget -O- -T 10 https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts | head -n 5 || true'
```

If DNS/ping fails, inspect the Docker firewall integration:

```sh
uci show dockerd
iptables -S DOCKER-USER
logread | grep -i dockerd-init | tail -n 50
```

## Fix A: LAN access to Docker-published ports (Pi-hole UI from LAN)

If localhost works but LAN times out, add forwarding `lan -> docker`:

```sh
sec=$(uci add firewall forwarding)
uci set firewall.${sec}.name='lan_to_docker'
uci set firewall.${sec}.src='lan'
uci set firewall.${sec}.dest='docker'
uci commit firewall
/etc/init.d/firewall reload
```

## Fix B: Restore container outbound internet while still blocking WAN -> containers

### Why the break happens

OpenWrt’s `/etc/init.d/dockerd` includes logic that, when configured, inserts a rule like:

```text
-A DOCKER-USER -i eth1 -o docker0 -j REJECT
```

It’s meant to block **WAN → Docker bridge** traffic. However, without a conntrack exception it can also block **reply traffic** for outbound connections initiated by containers (replies arrive on `wan`/`eth1` and must be forwarded to `docker0`).

This behavior is controlled by `/etc/config/dockerd`:

```text
config firewall 'firewall'
  option device 'docker0'
  list blocked_interfaces 'wan'
  # option extra_iptables_args '...'
```

### The durable fix

Keep the WAN block, but limit it to NEW inbound by adding a conntrack exception:

```sh
uci set dockerd.firewall.extra_iptables_args='--match conntrack ! --ctstate RELATED,ESTABLISHED'
uci commit dockerd
/etc/init.d/dockerd reload
```

Verify:

```sh
iptables -S DOCKER-USER
```

Expected rule shape:

```text
-A DOCKER-USER -i eth1 -o docker0 -m conntrack ! --ctstate RELATED,ESTABLISHED -j REJECT
```

Then re-test from inside the container and re-run gravity:

```sh
docker exec pihole sh -lc 'nslookup raw.githubusercontent.com 1.1.1.1'
docker exec pihole pihole -g
```

## “Did Docker enable this automatically?”

Typically, yes: when you enable/start `dockerd` on OpenWrt, the init script will apply the configured `blocked_interfaces` behavior and may log:

- `dockerd-init: Drop traffic from eth1 to docker0`

The *intent* (block WAN → containers) is reasonable; the “gotcha” is that the default rule can be too broad for fw4/nft + Docker’s iptables compatibility layer, so you need the conntrack exception.

## Can I configure this in LuCI?

Often **not** with DockerMan alone (`luci-app-dockerman`). That UI focuses on managing Docker, but it usually does **not** expose OpenWrt’s `dockerd` firewall integration knobs (`blocked_interfaces`, `extra_iptables_args`).

If you don’t see a dedicated “dockerd configuration” page in LuCI, manage it via `/etc/config/dockerd` (UCI).

