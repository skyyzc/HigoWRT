#!/bin/bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$repo_root/config/upstreams.env"

build_root=${BUILD_ROOT:-"$repo_root/build/qmodem-24.10"}
source_tree="$build_root/immortalwrt"
qmodem_tree="$build_root/QModem"
qmodem_feed="$build_root/qmodem-userland-feed"
downloads="$repo_root/downloads"
jobs=${JOBS:-2}
log_dir="$repo_root/artifacts/build-logs"

mkdir -p "$build_root" "$downloads" "$log_dir"

clone_at() {
    repository=$1
    commit=$2
    destination=$3
    if [ ! -d "$destination/.git" ]; then
        git clone --filter=blob:none --no-checkout "$repository" "$destination"
    fi
    git -C "$destination" fetch --depth=1 origin "$commit"
    git -C "$destination" checkout --detach "$commit"
}

clone_at "$IMMORTALWRT_REPOSITORY" "$IMMORTALWRT_REF" "$source_tree"
clone_at "$QMODEM_REPOSITORY" "$QMODEM_COMMIT" "$qmodem_tree"

python3 "$repo_root/scripts/apply-qmodem-profile.py" \
    "$qmodem_tree/application/qmodem/files/usr/share/qmodem/modem_support.json" \
    --profile "$repo_root/overlays/qmodem/rg520n-cn.json"

# Do not expose QModem's driver and legacy-LuCI package definitions to Kconfig.
# Some of their global choice defaults select replacement kernel drivers even
# when luci-app-qmodem itself is disabled. The curated feed is the safety
# boundary for this package-only build.
rm -rf "$qmodem_feed"
mkdir -p "$qmodem_feed"
for relative_path in \
    application/qmodem \
    application/qmodem-seal \
    application/modem_scan \
    application/tom_modem \
    application/ubus_at_daemon \
    application/sms-tool_q \
    application/sms_forwarder_next \
    luci/luci-app-qmodem-next; do
    ln -s "$qmodem_tree/$relative_path" "$qmodem_feed/${relative_path##*/}"
done

cat >"$source_tree/feeds.conf" <<EOF
src-git packages $PACKAGES_REPOSITORY^$PACKAGES_REF
src-git luci $LUCI_REPOSITORY^$LUCI_REF
src-git routing $ROUTING_REPOSITORY^$ROUTING_REF
src-git telephony $TELEPHONY_REPOSITORY^$TELEPHONY_REF
src-link qmodem $qmodem_feed
EOF

cd "$source_tree"
./scripts/feeds update -a
./scripts/feeds install -a
cp "$repo_root/config/qmodem-userland.config" .config
make defconfig

make download -j"$jobs" 2>&1 | tee "$log_dir/download.log"

# A partial OpenWrt staging_dir is not a valid cache unit. Build host tools and
# the cross toolchain serially with verbose output so the first real error is
# retained in CI artifacts.
make tools/install -j1 V=s 2>&1 | tee "$log_dir/tools-install.log"
make toolchain/install -j1 V=s 2>&1 | tee "$log_dir/toolchain-install.log"

# Runtime dependencies of qmodem include stock kmods. OpenWrt's prepare target
# only unpacks and patches the kernel; it does not create linux-*/.config. Build
# the pinned target kernel so package dependency traversal has the exact kernel
# configuration and symbol metadata expected by this source revision. Kernel
# packages remain excluded from the final allowlisted artifact.
make target/linux/prepare -j1 V=s 2>&1 | tee "$log_dir/kernel-prepare.log"
make target/linux/compile -j"$jobs" V=s 2>&1 | tee "$log_dir/kernel-compile.log"

make -j"$jobs" V=s \
    package/qmodem/compile \
    package/qmodem-seal/compile \
    package/modem_scan/compile \
    package/tom_modem/compile \
    package/ubus_at_daemon/compile \
    package/sms-tool_q/compile \
    package/sms_forwarder_next/compile \
    package/luci-app-qmodem-next/compile \
    2>&1 | tee "$log_dir/qmodem-compile.log"

artifact_dir="$repo_root/artifacts/qmodem-3.2.0-immortalwrt-24.10"
rm -rf "$artifact_dir"
mkdir -p "$artifact_dir/packages"

package_allowlist=(
    qmodem
    qmodem-seal
    modem_scan
    tom_modem
    ubus-at-daemon
    sms-tool_q
    sms-forwarder-next
    luci-app-qmodem-next
)
for package_name in "${package_allowlist[@]}"; do
    package_path=$(find bin/packages bin/targets -type f -name "${package_name}_*.ipk" -print -quit)
    if [ -z "$package_path" ]; then
        echo "missing expected package artifact: $package_name" >&2
        exit 1
    fi
    cp -f "$package_path" "$artifact_dir/packages/"
done

if find "$artifact_dir/packages" -type f -name 'kmod-*.ipk' | grep -q .; then
    echo "kernel package leaked into the userland artifact" >&2
    exit 1
fi
cp .config "$artifact_dir/build.config"
cp "$repo_root/config/upstreams.env" "$artifact_dir/upstreams.env"
cp "$repo_root/overlays/qmodem/rg520n-cn.json" "$artifact_dir/rg520n-cn.json"
(
    cd "$artifact_dir"
    sha256sum packages/*.ipk >SHA256SUMS
)

echo "Packages created in $artifact_dir"
echo "Do not install them until device inventory and package metadata checks pass."
