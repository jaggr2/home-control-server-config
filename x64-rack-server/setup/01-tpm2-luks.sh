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
sudo apt-get install -y -qq tpm2-tools clevis-tpm2 clevis-initramfs
# systemd-cryptenroll ships with systemd itself
if ! command -v systemd-cryptenroll &>/dev/null; then
    echo "  systemd-cryptenroll missing — installing systemd..."
    sudo apt-get install -y -qq systemd
fi

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
# 5. Bind TPM2 to LUKS (clevis preferred — works with Debian initramfs)
# ============================================================
echo "=== Binding TPM2 (PCR 0+7) via clevis ==="
if sudo clevis luks list -d "${LUKS_DEV}" 2>/dev/null | grep -q "tpm2"; then
    echo "  Clevis TPM2 binding already exists, skipping."
else
    # Remove any systemd-tpm2 token first (not honored by Debian initramfs-tools)
    if sudo cryptsetup luksDump "${LUKS_DEV}" | grep -q "systemd-tpm2"; then
        echo "  Removing systemd-tpm2 token (clevis is the supported path on Debian)..."
        TOKEN_ID=$(sudo cryptsetup luksDump "${LUKS_DEV}" | awk '/Tokens:/{f=1;next} f&&/systemd-tpm2/{gsub(":","",$1); print $1; exit}')
        [ -n "$TOKEN_ID" ] && sudo cryptsetup token remove --token-id "$TOKEN_ID" "${LUKS_DEV}"
    fi
    # Clevis bind prompts for the existing LUKS passphrase interactively.
    sudo clevis luks bind -d "${LUKS_DEV}" tpm2 '{"pcr_ids":"0,7"}'
    echo "  TPM2 bound via clevis."
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
sudo cryptsetup luksDump "${LUKS_DEV}" | grep -E "clevis|systemd-tpm2|Token [0-9]|Slot [0-9]" || true
sudo clevis luks list -d "${LUKS_DEV}" || true

echo ""
echo "=== TPM2-LUKS setup complete ==="
echo "Reboot to test auto-unlock (no password prompt expected)."
echo "If boot fails, enter the original LUKS passphrase manually — the passphrase slot was preserved."
