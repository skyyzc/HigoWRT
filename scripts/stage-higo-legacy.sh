#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
	echo "usage: $0 /path/to/private-higo /path/to/higowrt-source" >&2
	exit 2
}

private_payload=$1
source_tree=$2
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
target="$source_tree/package/higowrt/higo-legacy"

[ -x "$private_payload/root/usr/sbin/higorosd" ] || {
	echo "private Higo payload is incomplete" >&2
	exit 1
}
[ -f "$source_tree/rules.mk" ] || { echo "not an OpenWrt source tree" >&2; exit 1; }
[ ! -e "$target" ] || { echo "target already exists: $target" >&2; exit 1; }

mkdir -p "$target/files"
cp "$repo_root/package/higo-legacy/Makefile" "$target/Makefile"
tar -C "$private_payload/root" -cf - . | tar -C "$target/files" -xf -
cp "$repo_root/package/higo-legacy/files/etc/init.d/higoros" "$target/files/etc/init.d/higoros"
chmod 0755 "$target/files/etc/init.d/higoros"

echo "staged private Higo package at: $target"
