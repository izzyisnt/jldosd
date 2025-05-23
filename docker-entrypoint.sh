#!/usr/bin/env bash
set -euo pipefail

echo ">>> ENTRYPOINT: got args: $*"
echo ">>> PATH is: $PATH"
echo ">>> bash resolves to: $(type -a bash)"
exec "$@"
