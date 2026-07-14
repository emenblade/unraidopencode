#!/bin/sh
set -e

# Unraid (and Docker in general) auto-creates missing bind-mount host
# directories as root, and also auto-creates root-owned parent directories
# for nested mount points before this script ever runs. To avoid chasing
# individual XDG subdirectories (config, data, state, cache, ...) one at a
# time, the whole home directory is a single bind mount, and we chown the
# whole thing recursively here before dropping to the non-root user.
echo "[entrypoint] running as: $(id)"
echo "[entrypoint] opencode resolves to: $(id opencode)"

chown -R opencode:opencode /workspace /home/opencode 2>&1 || echo "[entrypoint] WARNING: chown failed"

echo "[entrypoint] after chown:"
ls -ld /workspace /home/opencode

echo "[entrypoint] dropping to opencode and exec'ing: $*"
exec runuser -u opencode -- "$@"
