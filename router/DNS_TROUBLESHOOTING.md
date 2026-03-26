# DNS troubleshooting notes (Pi-hole + OpenWrt)

This doc exists because this failure mode is extremely confusing: **Pi-hole shows the query + local record**, but **clients still get “No answer”**.

## Symptom

From a LAN client:

- `nslookup pw.home` returns something like:
  - `*** Can't find pw.home: No answer`

On Pi-hole (Query Log), you still see the query and it looks like Pi-hole knows the answer:

- `pw.home is 192.168.1.200`
- Client appears as `172.17.0.1` (Docker bridge gateway) instead of the real LAN client IP

## What’s actually happening

In this stack, Pi-hole runs in Docker on the router and is **not** bound to host port `53`. Instead, it’s published on host port `5453` and OpenWrt’s `dnsmasq` remains the LAN-facing DNS server on port `53`.

The typical flow is:

- LAN client → OpenWrt `dnsmasq` (port `53`)
- OpenWrt `dnsmasq` → Pi-hole (port `127.0.0.1#5453`)
- Pi-hole resolves using its local records/upstreams and returns an answer to `dnsmasq`
- `dnsmasq` decides whether to pass that answer back to the client

When the name uses a “public-looking” domain (like `.home`) and resolves to a private IP (like `192.168.1.200`), **dnsmasq DNS rebind protection** can drop the response. From the client’s point of view that becomes “No answer” even though Pi-hole logged it.

That’s why Pi-hole shows the query coming from `172.17.0.1`: it’s the forwarder (dnsmasq via the Docker bridge), not the original LAN client.

## Fix: allowlist the domain for rebind protection

### LuCI UI

Go to:

- **Network → DHCP and DNS → Filter**

Then:

- Enable/keep **DNS Rebind protection**
- Add `home` to **Domain whitelist / Rebind domain whitelist** (wording varies by LuCI version)
- **Save & Apply**

### CLI (UCI)

On the OpenWrt router:

```sh
uci add_list dhcp.@dnsmasq[0].rebind_domain='home'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

### Alternative: raw dnsmasq option

If your LuCI doesn’t expose the allowlist cleanly but you have an “Additional dnsmasq options” box, add:

```text
rebind-domain-ok=/home/
```

## Verify

From a LAN client:

```sh
nslookup pw.home
```

Expected: you should now get an `A` record response like `192.168.1.200`.

## Recommended TLD choices for a homelab

If you want names that tend to work without special-casing, prefer:

- **`home.arpa`**: reserved specifically for home networks (good default)
- **`lan`**: common on OpenWrt and typically trouble-free

TLDs to avoid or use with caution:

- **`.local`**: frequently captured by mDNS (Avahi/Bonjour) instead of normal DNS
- **Real public TLDs** (`.com`, `.net`, ...): can conflict with real domains and may trigger security behavior when pointed at RFC1918 IPs
- **`.home`**: often works, but can require the rebind allowlist described above

