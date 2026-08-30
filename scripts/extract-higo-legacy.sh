#!/bin/sh
set -eu

usage() {
	echo "usage: $0 /path/to/h5000m-sysupgrade.bin /path/to/private-output" >&2
	exit 2
}

[ "$#" -eq 2 ] || usage
firmware=$1
output=$2

[ -f "$firmware" ] || { echo "firmware not found: $firmware" >&2; exit 1; }
[ ! -e "$output" ] || { echo "output already exists: $output" >&2; exit 1; }
command -v unsquashfs >/dev/null 2>&1 || { echo "unsquashfs is required" >&2; exit 1; }

work=$(mktemp -d "${TMPDIR:-/tmp}/higo-extract.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

tar -xf "$firmware" -C "$work"
root_image=$(find "$work" -type f -name root -print -quit)
[ -n "$root_image" ] || { echo "sysupgrade root image not found" >&2; exit 1; }

mkdir -p "$work/rootfs"
# Device nodes such as /dev/console cannot be recreated by an unprivileged
# user. They are irrelevant to this package, so retain non-fatal diagnostics
# without turning that expected omission into an extraction failure.
unsquashfs -no-progress -no-exit-code -d "$work/rootfs" "$root_image" >/dev/null

for package_name in higorosd luci-app-higoros; do
	list="$work/rootfs/usr/lib/opkg/info/$package_name.list"
	[ -f "$list" ] || { echo "missing package list: $package_name" >&2; exit 1; }
	sed 's#^/##' "$list" >>"$work/files.list"
done

sort -u "$work/files.list" -o "$work/files.list"
mkdir -p "$output/root"
tar -C "$work/rootfs" -cf - -T "$work/files.list" | tar -C "$output/root" -xf -

cp "$work/rootfs/usr/lib/opkg/info/higorosd.control" "$output/higorosd.control"
cp "$work/rootfs/usr/lib/opkg/info/luci-app-higoros.control" "$output/luci-app-higoros.control"

(
	cd "$output/root"
	find . -type f -print | sort | while IFS= read -r file; do
		sha256sum "$file"
	done >"../SHA256SUMS"
)

sha256sum "$firmware" >"$output/SOURCE_FIRMWARE_SHA256"
cat >"$output/PRIVATE-NOTICE.txt" <<'EOF'
Extracted from a user-owned official firmware for compatibility testing.
Do not commit this directory or upload it as a public CI artifact.
EOF

echo "private Higo payload extracted to: $output"
