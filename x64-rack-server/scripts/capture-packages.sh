#!/bin/bash
# capture-packages.sh — Output installed apt packages in Renovate-compatible format
set -euo pipefail

# Detect suite
if [ -f /etc/os-release ]; then
    SUITE=$(grep "^VERSION_CODENAME=" /etc/os-release | cut -d'=' -f2)
fi
if [ -z "${SUITE:-}" ] && command -v lsb_release &>/dev/null; then
    SUITE=$(lsb_release -cs)
fi
if [ -z "${SUITE:-}" ]; then
    SUITE="trixie"
    echo "# WARNING: Could not detect suite, defaulting to ${SUITE}" >&2
fi

ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
DEBIAN_REPO="https://deb.debian.org/debian?suite=${SUITE}&components=main&binaryArch=${ARCH}"

echo "# Apt Packages - Generated $(date -I)"
echo "# System: ${SUITE} / ${ARCH}"
echo "# Managed by Renovate"
echo ""

apt-mark showmanual | sort | while read -r pkg; do
    version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null || true)

    if [ -n "$version" ]; then
        echo "# renovate: depName=${pkg} registryUrl=${DEBIAN_REPO}"
        echo "${pkg}=${version}"
        echo ""
    fi
done
