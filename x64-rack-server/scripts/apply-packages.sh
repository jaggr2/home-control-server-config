#!/bin/bash
# apply-packages.sh — Apply pinned package versions from apt-packages.txt
set -e

PACKAGES_FILE="/opt/homelab/apt-packages.txt"

if [ ! -f "$PACKAGES_FILE" ]; then
    echo "Error: ${PACKAGES_FILE} not found"
    exit 1
fi

echo "Updating apt cache..."
sudo apt-get update

echo "Installing packages from ${PACKAGES_FILE}..."
grep -E "^[a-zA-Z0-9].*=" "$PACKAGES_FILE" | while IFS= read -r line; do
    pkg_spec="$line"
    pkg_name="${pkg_spec%%=*}"

    # Skip commented entries
    if [[ "$pkg_name" =~ ^# ]]; then
        continue
    fi

    echo "  ${pkg_spec}"

    if apt-cache show "${pkg_spec}" &>/dev/null; then
        sudo apt-get install -y "${pkg_spec}"
    else
        echo "  Warning: ${pkg_spec} not available, skipping."
    fi
done

echo "Done."
