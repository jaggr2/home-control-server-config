#!/bin/bash
# 01-tpm2-luks.sh — Bind LUKS to TPM2 for passwordless boot auto-unlock
# Uses clevis + systemd-cryptenroll TPM2 token.
# Requires: TPM2 chip present + a free LUKS keyslot.
set -euo pipefail

# ============================================================
# 1. Install tools
# ============================================================
echo "=== Installing TPM2/clevis tools ==="
sudo apt-get update -qq
sudo apt-get install -y -qq tpm2-tools clevis-tpm2 clevis-initramfs systemd-cryptenroll

# ============================================================
# 2. Detect the LUKS root device
# ============================================================
echo "=== Detecting LUKS device ==="
# Find the backing device of the encrypted root (nvme0n1p3_crypt -> /dev/nvme0n1p3)
ROOT_CRYPT=$(lsblk -n -o NAME,MOUNTPOINT | awk '$2=="/" {print $1}')
echo "  Root is on: /dev/mapper/${ROOT_CRYPT}"

# Walk up the chain to find the physical partition holding the LUKS header
LUKS_DEV=""
for d in /dev/nvme* /dev/sd*; do
    [ -b "$d" ] || continue
    if sudo cryptsetup isLuks "$d" 2>/dev/null; then
        LUKS_DEV="$d"
        break
    fi
done

if [ -z "$LUKS_DEV" ]; then
    echo "ERROR: Could not locate LUKS device."
    exit 1
fi
echo "  LUKS device: ${LUKS_DEV}"

# ============================================================
# 3. Check TPM2 presence
# ============================================================
echo "=== Checking TPM2 ==="
if ! ls /dev/tpm0 &>/dev/null; then
    echo "ERROR: No TPM2 device found (/dev/tpm0 missing)."
    echo "Check BIOS: Security → Trusted Computing → enable TPM/PTT."
    exit 1
fi
if ! sudo tpm2_readpublic 2>/dev/null | grep -q "TPM 2.0"; then
    echo "  Warning: tpm2_readpublic check failed, continuing anyway."
fi
echo "  TPM2 present."

# ============================================================
# 4. Verify existing keyslots (do not clobber the passphrase slot)
# ============================================================
echo "=== Current LUKS keyslots ==="
sudo cryptsetup luksDump "${LUKS_DEV}" | grep -E "Slot [0-9]" || true

# ============================================================
# 5. Bind TPM2 to LUKS
# ============================================================
echo "=== Binding TPM2 (PCR 0+7) ==="
if sudo cryptsetup luksDump "${LUKS_DEV}" | grep -q "systemd-tpm2"; then
    echo "  TPM2 token already present, skipping."
else
    # Use systemd-cryptenroll: keeps existing passphrase slot, adds TPM2 slot.
    # - --tpm2-device=auto --tpm2-pcrs=0,7 (note: PCR 7 requires Secure Boot stable)
    sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0,7 "${LUKS_DEV}"
    echo "  TPM2 bound via systemd-cryptenroll."
fi

# ============================================================
# 6. Update initramfs
# ============================================================
echo "=== Updating initramfs ==="
sudo update-initramfs -u -k all

# ============================================================
# 7. Verify
# ============================================================
echo ""
echo "=== Verify LUKS tokens ==="
sudo cryptsetup luksDump "${LUKS_DEV}" | grep -E "systemd-tpm2|Token [0-9]|Slot [0-9]" || true

echo ""
echo "=== TPM2-LUKS setup complete ==="
echo "Reboot to test auto-unlock (no password prompt expected)."
echo "If boot fails, enter the original LUKS passphrase manually — the passphrase slot was preserved."
