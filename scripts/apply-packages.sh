#!/bin/bash
# Applies package versions from apt-packages.txt

PACKAGES_FILE="apt-packages.txt"

if [ ! -f "$PACKAGES_FILE" ]; then
    echo "Error: $PACKAGES_FILE not found"
    exit 1
fi

echo "Updating apt cache..."
sudo apt-get update

echo "Installing/upgrading packages from $PACKAGES_FILE..."

# Parse the file and install packages
grep -E "^[a-zA-Z0-9].*=" "$PACKAGES_FILE" | while read -r line; do
    pkg_spec="$line"  # e.g., "nginx=1.22.1-9"
    pkg_name="${pkg_spec%%=*}"
    pkg_version="${pkg_spec#*=}"

    echo "Processing: $pkg_name version $pkg_version"

    # Check if exact version is available
    if apt-cache show "${pkg_name}=${pkg_version}" &>/dev/null; then
        sudo apt-get install -y "${pkg_name}=${pkg_version}"
    else
        echo "Warning: Exact version ${pkg_version} not available for ${pkg_name}"
        echo "Available versions:"
        apt-cache policy "$pkg_name" | head -10

        # Optionally install latest available
        # sudo apt-get install -y "$pkg_name"
    fi
done

echo "Done!"
