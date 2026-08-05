# Home Assistant OS VM Setup

## Prerequisites

- KVM/libvirt installed (setup/01-kvm-networking.sh)
- VLAN-aware bridge br0 configured
- Internet access to download image

## Initial Setup

Run `setup/05-vm-create.sh` which will:

1. Download the latest HA OS QCOW2 image from GitHub releases
2. Verify the SHA256 checksum
3. Extract the `.xz` archive
4. Create the VM with:
   - 4 GB RAM, 2 vCPUs
   - 32 GB virtio disk
   - Bridged to VLAN 1 (Trusted)
   - Serial console

## Post-Install

1. **Find IP**: `virsh domifaddr ha-os` or check DHCP leases
2. **Access**: http://<ip>:8123
3. **Complete wizard**: user account, location, timezone
4. **Restore backup** (if applicable)

## Adding IoT VLAN Access

HA OS needs access to both Trusted (VLAN 1) and IoT (VLAN 20) networks.
Add a second interface after VM creation:

```bash
virsh attach-interface ha-os bridge br0.20 --model virtio --persistent
virsh reboot ha-os
```

Then configure the IoT interface inside HA:
- Settings → System → Network → Configure the second interface
- Assign static IP on VLAN 20 subnet (192.168.20.x)

## Add-Ons to Install

| Add-on | Purpose |
|--------|---------|
| Node-RED | Automation (replaces standalone container) |
| File Editor | Edit configs from UI |
| Terminal & SSH | CLI access |
| Samba Backup | Share backups to NAS |
| Mosquitto broker | MQTT for IoT devices |
| Zigbee2MQTT | Zigbee device management |
| ESPHome | ESP8266/ESP32 management |
| Studio Code Server | VS Code in browser for YAML editing |

## Maintenance

- **Updates**: HA OS auto-updates via Supervisor (Settings → System → Updates)
- **Backups**: Schedule automatic backups to NAS:
  - Settings → System → Backups → Add backup location
  - Mount NAS path: `\\192.168.1.10\backups\ha-os` or NFS
- **Snapshots**: Pre-update snapshots via Supervisor → Snapshots

## Troubleshooting

```bash
virsh console ha-os        # Serial console access
virsh domiflist ha-os      # Check network interfaces
virsh domblklist ha-os     # Check disk attachments
journalctl -u libvirtd -f  # Hypervisor logs
```

## Reset / Rebuild

To rebuild HA OS VM:
```bash
virsh destroy ha-os
virsh undefine ha-os --remove-all-storage
# Then re-run setup/05-vm-create.sh
```
