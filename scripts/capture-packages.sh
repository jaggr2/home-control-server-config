#!/bin/bash
# Outputs installed apt packages in Renovate-compatible format to stdout
# Auto-detects suite (codename) and architecture

# Auto-detect suite/codename from /etc/os-release
if [ -f /etc/os-release ]; then
    SUITE=$(grep "^VERSION_CODENAME=" /etc/os-release | cut -d'=' -f2)
fi

# Fallback: try lsb_release
if [ -z "$SUITE" ] && command -v lsb_release &>/dev/null; then
    SUITE=$(lsb_release -cs)
fi

# Final fallback
if [ -z "$SUITE" ]; then
    SUITE="bookworm"
    echo "# WARNING: Could not detect suite, defaulting to $SUITE" >&2
fi

# Auto-detect architecture using dpkg (returns amd64, arm64, armhf, etc.)
if command -v dpkg &>/dev/null; then
    ARCH=$(dpkg --print-architecture)
else
    # Fallback: map uname -m to Debian arch names
    case $(uname -m) in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l)  ARCH="armhf" ;;
        i686)    ARCH="i386" ;;
        *)       ARCH="amd64" ;;  # Default fallback
    esac
fi

ARMBIAN_REPO="https://apt.armbian.com?suite=${SUITE}&components=main&binaryArch=${ARCH}"
DEBIAN_REPO="https://deb.debian.org/debian?suite=${SUITE}&components=main&binaryArch=${ARCH}"

echo "# Apt Packages - Generated $(date -I)"
echo "# System: ${SUITE} / ${ARCH}"
echo "# Managed by Renovate"
echo ""

apt-mark showmanual | sort | while read -r pkg; do
    version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)

    if [ -n "$version" ]; then
        origin=$(apt-cache policy "$pkg" 2>/dev/null | grep -A1 "\*\*\*" | tail -1)

        if echo "$origin" | grep -qi "armbian"; then
            repo_url="$ARMBIAN_REPO"
        else
            repo_url="$DEBIAN_REPO"
        fi

        echo "# renovate: depName=${pkg} registryUrl=${repo_url}"
        echo "${pkg}=${version}"
        echo ""
    fi
done
