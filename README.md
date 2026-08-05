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
| Cloudflared | Cloudflare Tunnel |
| Samba | SMB file sharing |

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

## License

See file LICENSE
