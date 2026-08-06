#!/bin/bash
# 10-cockpit-plugins.sh — Third-party Cockpit plugins (DISABLED)
#
# All third-party plugins were tried and removed — each was incompatible
# with this host's setup:
#
#   cockpit-cloudflared — requires a locally managed tunnel (cert.pem); this
#       host uses a token-based (remotely managed) tunnel, so the plugin
#       cannot list tunnels and hangs on loading.
#   cockpit-zfs (45Drives) — requires python3-libzfs which does not build on
#       Debian trixie (Cython/Python 3.13 incompatibility); CLI-fallback mode
#       is limited.
#   cockpit-file-sharing (45Drives) — its Samba tab manages a NATIVE host
#       samba registry (/var/lib/samba via net conf), but this host runs
#       Samba in a container (dperson/samba quadlet); the Samba tab is
#       non-functional.
#
# Currently working/kept: NONE. Cockpit ships with its own tools
# (podman, machines, storage, network) which cover the host needs.
set -euo pipefail

echo "=== Third-party cockpit plugins are intentionally not installed ==="
echo "  See header comment in this file for the history."
echo "Done."
