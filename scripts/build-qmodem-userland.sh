#!/bin/bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$repo_root/config/upstreams.env"

build_root=${BUILD_ROOT:-"$repo_root/build/qmodem-24.10"}
source_tree="$build_root/immortalwrt"
qmodem_tree="$build_root/QModem"
downloads="$repo_root/downloads"
jobs=${JOBS:-2}

mkdir -p "$build_root" "$downloads"

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

cat >"$source_tree/feeds.conf" <<EOF
src-git packages $PACKAGES_REPOSITORY^$PACKAGES_REF
src-git luci $LUCI_REPOSITORY^$LUCI_REF
src-git routing $ROUTING_REPOSITORY^$ROUTING_REF
src-git telephony $TELEPHONY_REPOSITORY^$TELEPHONY_REF
src-link qmodem $qmodem_tree
EOF

cd "$source_tree"
./scripts/feeds update -a
./scripts/feeds install -a
cp "$repo_root/config/qmodem-userland.config" .config
make defconfig

if grep -Eq '^CONFIG_PACKAGE_kmod-(qmi_wwan_[qfs]|pcie_mhi)' .config; then
    echo "refusing to build replacement QModem kernel drivers in phase 1" >&2
    exit 1
fi

make download -j"$jobs"
make -j"$jobs" \
    package/qmodem/compile \
    package/qmodem-seal/compile \
    package/modem_scan/compile \
    package/tom_modem/compile \
    package/ubus-at-daemon/compile \
    package/sms-tool_q/compile \
    package/sms-forwarder-next/compile \
    package/luci-app-qmodem-next/compile

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
