#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$repo_root/config/upstreams.env"

qmodem_tree=${1:-}
if [ -z "$qmodem_tree" ]; then
    echo "usage: $0 /path/to/QModem" >&2
    exit 2
fi

support_file="$qmodem_tree/application/qmodem/files/usr/share/qmodem/modem_support.json"
[ -f "$support_file" ] || {
    echo "missing QModem support file: $support_file" >&2
    exit 1
}

actual_commit=$(git -C "$qmodem_tree" rev-parse HEAD)
if [ "$actual_commit" != "$QMODEM_COMMIT" ]; then
    echo "QModem commit mismatch: expected $QMODEM_COMMIT, got $actual_commit" >&2
    exit 1
fi

grep -q '"rm520n-cn"' "$support_file" || {
    echo "expected upstream model rm520n-cn is absent" >&2
    exit 1
}

if grep -q '"rg520n-cn"' "$support_file"; then
    echo "QModem now contains rg520n-cn; review whether the local adaptation is still needed."
else
    echo "Confirmed: QModem $QMODEM_REF has no rg520n-cn profile. Device evidence is required."
fi
