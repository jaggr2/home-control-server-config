# Home Control Server Config

Dual-device homelab configuration, fully GitOps-managed.

```text
home-control-server-config/
├── arm-n2-odroid/            # Odroid N2 (ARM64, Armbian)
│   ├── docker-compose.yml    # Docker Compose stack
│   ├── apt-packages.txt      # Pinned ARM packages
│   ├── renovate.json         # Renovate config
│   ├── setup/                # Device setup scripts
│   └── scripts/              # CI/CD webhook scripts
├── x64-rack-server/          # Debian Rack Server (AMD64)
│   ├── quadlets/             # Podman Quadlet container definitions
│   ├── apt-packages.txt      # Pinned x64 packages
│   ├── renovate.json         # Renovate config
│   ├── vm-definitions/       # KVM/libvirt VM configs
│   ├── setup/                # Device setup scripts
│   └── scripts/              # CI/CD webhook scripts
├── .github/workflows/        # CI/CD pipelines for both devices
├── README.md
└── LICENSE
```

## Architecture

| Device | Runtime | Approach | GitOps |
|--------|---------|----------|--------|
| **Odroid N2** | Docker Compose | ARM64 containers | webhookd + Renovate |
| **Rack Server** | Podman Quadlets | Rootless containers + KVM VMs | webhookd + Renovate |

## GitOps Pipeline

```
Renovate → PR (version bump)
  ↓
Merge to main
  ↓
GitHub Actions → Cloudflare Tunnel → webhookd
  ↓
apply-config.sh (git pull → daemon-reload → restart)
```

## Rack Server Services

### Quadlet Containers
| Service | Description |
|---------|-------------|
| Plex | Media server (ZFS: nas/media) |
| Sonarr | TV series automation |
| Radarr | Movie automation |
| Prowlarr | Indexer management |
| SABnzbd | Usenet downloader |
| Samba | SMB file sharing |

> **Non-container exception**: **Cloudflared** runs as a native apt/systemd service
> (`setup/cloudflared-setup.sh`) because its sd_notify behavior is incompatible with
> rootless podman quadlets. This is the *only* non-container service on the host.

### KVM Virtual Machines
| VM | Purpose | vCPU/RAM | IP | Network |
|----|---------|----------|-----|---------|
| unifi-os | UniFi OS Server | 2/2G | 192.168.11.8 (static) | mgmt (br11, vlan 11) |
| ha-os | Home Assistant OS | 2/4G | DHCP | trusted (br1, vlan 1) + iot (vlan 20) |

> **Host mgmt**: rack server is on **192.168.11.11** (mgmt, VLAN 11).

## Network Architecture (per-VLAN bridges)

```
enp3s0 (physical trunk, no IP)
├── enp3s0.1   → br1    (VLAN 1  / trusted)   [VMs]
├── enp3s0.11  → br11   (VLAN 11 / mgmt)      [host 192.168.11.11 + VMs]
├── enp3s0.20  → br20   (VLAN 20 / iot)       [VMs]
└── enp3s0.30  → br30   (VLAN 30 / ai)        [VMs]
```

Each VLAN gets a subinterface on the physical NIC + a plain bridge.
libvirt networks bridge VMs to the per-VLAN bridges.
> Note: a single VLAN-aware bridge (`bridge_vlan_aware yes`) cannot serve
> the host IP via a VLAN subinterface — use per-VLAN bridges instead.

## Backup (3-Tier)

| Tier | Mechanism | Schedule | Storage |
|------|-----------|----------|---------|
| T1 | rsync → ZFS pool + snapshot | Daily 3am | `nas/backups/rack-server` |
| T2 | Udev-triggered external USB | Monthly | 5TB disk (tresor) |
| T3 | rclone encrypted | Weekly Sun 4am | Cloud offsite |

## Disk / LVM Layout (2TB NVMe)

```
nvme0n1
├── p1  976M   /boot/efi
├── p2  977M   /boot
└── p3  1.8T   LUKS (TPM2 auto-unlock)
    └── derog-server-vg
        ├── root          100G    /
        ├── containers    200G    /var/lib/containers   (podman storage)
        ├── libvirt       1.49T   /var/lib/libvirt      (VM images)
        ├── swap_1        31G     [SWAP]
        └── (headroom)    ~100G   free in VG
```

> `/tmp` intentionally stays **tmpfs** (RAM). If the LVM layout ever needs
> changing, use `setup/rescue-repartition.sh` from Debian rescue mode
> (Advanced → Rescue mode → shell in installer env → run the script).

## Rack Server Setup Order

Run on a fresh Debian 13 netinst (as the primary user):

```bash
cd /opt/homelab/x64-rack-server/setup

./00-system-base.sh <user> <hostname> <ip/24> <gateway> <dns1> <dns2> <iface>
#       -> sudo, packages, static IP, SSH hardening, UFW (apply network, then reboot)

./01-tpm2-luks.sh
#       -> TPM2 auto-unlock for encrypted root (REQUIRED before rebooting after base)

./02-zfs.sh
#       -> install ZFS (headers+DKMS), import pool, create datasets

./03-kvm-networking.sh <iface>
#       -> KVM/libvirt + per-VLAN bridges (br1/br11/br20/br30)

./04-podman-install.sh
#       -> podman + rootless lingering + auto-update timer

./05-webhookd.sh
#       -> webhookd for GitHub Actions CI/CD triggers

./06-quadlet-deploy.sh
#       -> symlink quadlets + start all containers

./cloudflared-setup.sh
#       -> cloudflared via apt (native systemd service — the only non-container exception)

./07-vm-create.sh
#       -> UniFi OS + HA OS VMs (needs installer URL for UniFi)

./08-backup-setup.sh
#       -> 3-tier backup (ZFS sync + udev USB + rclone)
```

## License

See file LICENSE
