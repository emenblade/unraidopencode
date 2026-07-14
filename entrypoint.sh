#!/bin/sh
set -e

# Unraid (and Docker in general) auto-creates missing bind-mount host
# directories as root, but we run opencode as a non-root user. Fix
# ownership on the mount points here (as root, before dropping privileges)
# so it self-heals regardless of who created them on the host side.
echo "[entrypoint] running as: $(id)"
echo "[entrypoint] opencode resolves to: $(id opencode)"
echo "[entrypoint] XDG_CONFIG_HOME=$XDG_CONFIG_HOME XDG_DATA_HOME=$XDG_DATA_HOME"

chown opencode:opencode /workspace 2>&1 || echo "[entrypoint] WARNING: chown /workspace failed"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"
chown -R opencode:opencode "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" 2>&1 || echo "[entrypoint] WARNING: chown config/data failed"

echo "[entrypoint] after chown:"
ls -ld /workspace "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"

echo "[entrypoint] dropping to opencode and exec'ing: $*"
exec runuser -u opencode -- "$@"
