#!/bin/bash
# Real replay/cancellation bridge, compatible optional wire errors, lock rules and bounded retries.
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/../common.sh"
python3 "$here/../module.py" "$name" "$root" "$out/check"
