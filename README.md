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
| VM | Purpose | vCPU/RAM | VLAN |
|----|---------|----------|------|
| unifi-os | UniFi OS Server | 2/2G | Trusted(1) → mgmt(11) |
| ha-os | Home Assistant OS | 2/4G | Trusted(1) + IoT(20) |

## Backup (3-Tier)

| Tier | Mechanism | Schedule | Storage |
|------|-----------|----------|---------|
| T1 | rsync → ZFS pool + snapshot | Daily 3am | `nas/backups/rack-server` |
| T2 | Udev-triggered external USB | Monthly | 5TB disk (tresor) |
| T3 | rclone encrypted | Weekly Sun 4am | Cloud offsite |

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
#       -> KVM/libvirt + VLAN-aware bridge br0 (trusted/mgmt/iot/ai)

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
