#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
qmodem_tree=${1:-}
[ -n "$qmodem_tree" ] || {
    echo "usage: $0 /path/to/QModem" >&2
    exit 2
}

source_file="$qmodem_tree/application/qmodem/files/usr/share/qmodem/modem_support.json"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/higowrt-profile.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
cp "$source_file" "$test_dir/modem_support.json"

python3 "$repo_root/scripts/apply-qmodem-profile.py" \
    "$test_dir/modem_support.json" \
    --profile "$repo_root/overlays/qmodem/rg520n-cn.json"

jq -e \
    --slurpfile profile "$repo_root/overlays/qmodem/rg520n-cn.json" \
    '.modem_support.usb["rg520n-cn"] == $profile[0]' \
    "$test_dir/modem_support.json" >/dev/null

# A second application must be idempotent.
python3 "$repo_root/scripts/apply-qmodem-profile.py" \
    "$test_dir/modem_support.json" \
    --profile "$repo_root/overlays/qmodem/rg520n-cn.json" >/dev/null

echo "RG520N-CN overlay test passed"
