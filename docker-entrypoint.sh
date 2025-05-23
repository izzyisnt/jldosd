#!/usr/bin/env bash
set -eo pipefail

# First-boot copy if the mounted /workspace is empty
if [ ! -d "/workspace/SurfDock/.git" ]; then
    echo "[entrypoint] Populating /workspace with SurfDock..."
    cp -R /usr/local/SurfDock /workspace/
fi

exec "$@"
