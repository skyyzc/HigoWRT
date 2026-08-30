#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
	echo "usage: $0 /path/to/sysupgrade.bin /path/to/report.txt" >&2
	exit 2
}

firmware=$1
report=$2
[ -f "$firmware" ] || { echo "firmware not found: $firmware" >&2; exit 1; }
[ ! -e "$report" ] || { echo "report already exists: $report" >&2; exit 1; }
command -v unsquashfs >/dev/null 2>&1 || { echo "unsquashfs is required" >&2; exit 1; }

work=$(mktemp -d "${TMPDIR:-/tmp}/vendor-audit.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
tar -xf "$firmware" -C "$work"
root_image=$(find "$work" -type f -name root -print -quit)
[ -n "$root_image" ] || { echo "sysupgrade root image not found" >&2; exit 1; }
mkdir -p "$work/rootfs"
unsquashfs -no-progress -no-exit-code -d "$work/rootfs" "$root_image" >/dev/null

{
	echo "firmware_sha256=$(sha256sum "$firmware" | awk '{print $1}')"
	echo "openwrt_release:"
	sed -n '1,80p' "$work/rootfs/etc/openwrt_release" 2>/dev/null || true
	echo
	echo "module_directories:"
	find "$work/rootfs/lib/modules" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null || true
	echo
	echo "vendor_candidate_modules:"
	find "$work/rootfs/lib/modules" -type f -name '*.ko' 2>/dev/null | \
		sort | while IFS= read -r module; do
		case "${module##*/}" in
			mt_wifi*|mt799*|mtk_*|connac_if.ko|pcie_mhi.ko|qmi_wwan_[qfs].ko)
				hash=$(sha256sum "$module" | awk '{print $1}')
				vermagic=$(strings "$module" | sed -n 's/^vermagic=//p' | head -n 1)
				printf '%s sha256=%s vermagic=%s\n' "${module#$work/rootfs}" "$hash" "$vermagic"
				;;
		esac
	done
} >"$report"

if ! rg -q "6\\.12" "$report" 2>/dev/null && ! grep -q "6\.12" "$report"; then
	echo "REJECT: candidate is not a Linux 6.12 firmware" >>"$report"
	echo "candidate rejected: not Linux 6.12" >&2
	exit 1
fi

echo "candidate audit written to: $report"
