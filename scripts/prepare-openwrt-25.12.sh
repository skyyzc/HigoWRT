#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$repo_root/config/upstreams.env"

if [ "$(uname -s)" != "Linux" ]; then
	echo "OpenWrt 25.12 preparation requires a Linux build host" >&2
	exit 1
fi

build_root=${BUILD_ROOT:-"$repo_root/build/openwrt-25.12"}
source_tree="$build_root/higowrt"
private_higo=${PRIVATE_HIGO:-}

mkdir -p "$build_root"

if [ ! -d "$source_tree/.git" ]; then
	git clone --filter=blob:none --no-checkout "$HIGOWRT_REPOSITORY" "$source_tree"
else
	git -C "$source_tree" diff --quiet || {
		echo "refusing to replace changes in $source_tree" >&2
		exit 1
	}
fi

git -C "$source_tree" fetch --depth=1 origin "$HIGOWRT_REF"
git -C "$source_tree" checkout --detach "$HIGOWRT_REF"

cd "$source_tree"

# The vendor HNAT module currently fails Linux 6.12's mandatory prototype
# checks. Keep the first-boot RAM probe independent from that optional data
# path; a dedicated compatibility lane will restore it after hardware bring-up.
patch -p1 --forward < "$repo_root/patches/hiveton/0001-filogic-disable-vendor-hnat-for-initramfs-probe.patch"
patch -p1 --forward < "$repo_root/patches/hiveton/0002-filogic-keep-local-ppe-helpers-static.patch"
patch -p1 --forward < "$repo_root/patches/hiveton/0003-wifi-utility-declare-exported-mtd-helpers.patch"

./scripts/feeds update -a
./scripts/feeds install -a

cp "$repo_root/config/h5000m-open-initramfs.config" .config
make defconfig

if [ -n "$private_higo" ]; then
	"$repo_root/scripts/stage-higo-legacy.sh" "$private_higo" "$source_tree"
	echo 'CONFIG_PACKAGE_higo-legacy=y' >>.config
	make defconfig
fi

echo "prepared source tree: $source_tree"
echo "config: $source_tree/.config"
