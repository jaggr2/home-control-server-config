#!/bin/bash
# 00-system-base.sh — Base system prep: sudo, packages, static IP, SSH key
# Run as the first script after a fresh Debian netinst (as the install user).
set -euo pipefail

# ============================================================
# Config (adjust as needed)
# ============================================================
USERNAME="${1:-$USER}"                       # primary user
HOSTNAME="${2:-derog-rack}"                  # server hostname
STATIC_IP="${3:-192.168.1.10/24}"            # static IP + prefix
GATEWAY="${4:-192.168.1.1}"                  # gateway
DNS1="${5:-1.1.1.1}"
DNS2="${6:-8.8.8.8}"
IFACE="${7:-enp3s0}"                         # primary NIC (adjust!)

# ============================================================
# 1. Enable sudo + passwordless for the user
# ============================================================
echo "=== Setting up sudo ==="
if [ "$EUID" -eq 0 ]; then
    if ! command -v sudo &>/dev/null; then
        apt-get update -qq
        apt-get install -y -qq sudo
    fi
    usermod -aG sudo "${USERNAME}" || true
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME}
    chmod 440 /etc/sudoers.d/${USERNAME}
    echo "  sudo installed, ${USERNAME} has passwordless sudo."
elif [ -n "$(sudo -n true 2>/dev/null && echo ok)" ]; then
    echo "  sudo already works for ${USERNAME}."
else
    echo "  ERROR: Run this script as root or with working sudo."
    exit 1
fi

# ============================================================
# 2. Hostname
# ============================================================
echo "=== Setting hostname ==="
sudo hostnamectl set-hostname "${HOSTNAME}"
echo "  Hostname: ${HOSTNAME}"

# ============================================================
# 3. Base packages
# ============================================================
echo "=== Installing base packages ==="
sudo apt-get update -qq
sudo apt-get install -y -qq \
    git curl wget ca-certificates gnupg htop vim jq rsync \
    openssh-server fail2ban ufw apt-transport-https

# ============================================================
# 4. Static IP (ifupdown). Adjust IFACE if it differs.
# ============================================================
echo "=== Configuring static IP ${STATIC_IP} on ${IFACE} ==="
cat << EOF | sudo tee /etc/network/interfaces.d/${IFACE}
auto ${IFACE}
iface ${IFACE} inet static
    address ${STATIC_IP}
    gateway ${GATEWAY}
    dns-nameservers ${DNS1} ${DNS2}
EOF

# Disable DHCP entry for the same NIC in /etc/network/interfaces if present
sudo sed -i "/^allow-hotplug ${IFACE}$/d; /^iface ${IFACE} inet dhcp$/d" /etc/network/interfaces || true

echo "  Static IP written. Apply with: sudo ifdown ${IFACE} && sudo ifup ${IFACE}"
echo "  (This will disconnect you — reconnect to the new IP.)"

# ============================================================
# 4b. DNS persistence (static resolv.conf)
# ifupdown's dns-nameservers is only applied via resolvconf, which is
# not installed on minimal Debian. Write resolv.conf directly + make it
# immutable so nothing (dhcpcd, systemd-resolved) can clobber it.
# ============================================================
echo "=== Ensuring static DNS ==="
printf "nameserver %s\nnameserver %s\n" "${DNS1}" "${DNS2}" | sudo tee /etc/resolv.conf >/dev/null
sudo chattr +i /etc/resolv.conf 2>/dev/null || true
echo "  resolv.conf written (immutable): ${DNS1}, ${DNS2}"

# ============================================================
# 5. SSH hardening
# ============================================================
echo "=== Hardening SSH ==="
cat << 'EOF' | sudo tee /etc/ssh/sshd_config.d/99-hardening.conf
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

# Ensure the user's public key is installed
mkdir -p ~/.ssh && chmod 700 ~/.ssh
if [ ! -f ~/.ssh/authorized_keys ] || [ ! -s ~/.ssh/authorized_keys ]; then
    echo "  No authorized_keys found. Run the following to add your key:"
    echo "    mkdir -p ~/.ssh && chmod 700 ~/.ssh"
    echo "    echo '<your-public-key>' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
fi

sudo systemctl restart ssh
echo "  SSH hardened. Root login disabled, password auth disabled."

# ============================================================
# 6. Firewall
# ============================================================
echo "=== Configuring UFW ==="
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw --force enable
echo "  UFW enabled (SSH only)."

# ============================================================
# 7. Update + reboot hint
# ============================================================
echo "=== Upgrading system ==="
sudo apt-get upgrade -y -qq || echo "  (upgrade had warnings — review manually)"
sudo apt-get autoremove -y -qq

echo ""
echo "=== Base system setup complete ==="
echo "Next steps:"
echo "  sudo reboot                  # apply kernel + network changes"
echo "  ./setup/01-tpm2-luks.sh      # TPM2 auto-unlock (do before rebooting! run bind then reboot)"
echo "  ./setup/02-zfs.sh            # import ZFS pool"
echo "  ./setup/03-kvm-networking.sh # KVM + VLAN bridge"
echo "  ./setup/04-podman-install.sh # podman + quadlets"
