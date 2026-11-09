#!/usr/bin/env bash
# Compatibility entry point. DuoDeck owns its own distribution target.
set -euo pipefail
exec "$(dirname "$0")/../script/release_mac.sh" "$@"
