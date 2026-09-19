#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
python_bin=""
for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1 &&
       "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)' >/dev/null 2>&1; then
        python_bin=$(command -v "$candidate")
        break
    fi
done

if [ -z "$python_bin" ]; then
    printf '%s\n' 'NOT_READY: Python 3.11 or newer was not found. Install a supported Python, then rerun this script.' >&2
    exit 2
fi

exec "$python_bin" "$script_dir/install.py" "$@"
