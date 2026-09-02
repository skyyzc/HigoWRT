#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
	echo "usage: $0 /path/to/qmodem-source /path/to/higowrt-source" >&2
	exit 2
}

qmodem_source=$1
source_tree=$2
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
target="$source_tree/package/higowrt/qmodem-3.2.0"

[ -f "$qmodem_source/version.mk" ] || {
	echo "invalid QModem source tree: $qmodem_source" >&2
	exit 1
}
[ -f "$source_tree/rules.mk" ] || {
	echo "invalid HiGoWRT source tree: $source_tree" >&2
	exit 1
}

rm -rf "$target"
mkdir -p "$target/application" "$target/luci"
cp "$qmodem_source/version.mk" "$target/version.mk"

for package in \
	qmodem \
	qmodem-seal \
	modem_scan \
	tom_modem \
	ubus_at_daemon \
	sms-tool_q \
	sms_forwarder_next \
	quectel_CM_5G_M; do
	cp -R "$qmodem_source/application/$package" "$target/application/$package"
done
cp -R "$qmodem_source/luci/luci-app-qmodem-next" "$target/luci/luci-app-qmodem-next"

for qmodem_patch in "$repo_root"/patches/qmodem/*.patch; do
	patch -d "$target" -p1 <"$qmodem_patch"
done

python3 "$repo_root/scripts/apply-qmodem-profile.py" \
	"$target/application/qmodem/files/usr/share/qmodem/modem_support.json" \
	--profile "$repo_root/overlays/qmodem/rg520n-cn.json"

# The RAM integration lane validates discovery and AT/ubus first. Do not start
# a billable cellular data session until the operator explicitly enables it.
qmodem_config="$target/application/qmodem/files/etc/config/qmodem"
sed 's/option enable_dial '\''1'\''/option enable_dial '\''0'\''/' \
	"$qmodem_config" >"$qmodem_config.tmp"
mv "$qmodem_config.tmp" "$qmodem_config"

mkdir -p "$target/application/qmodem/files/usr/sbin"
cp "$repo_root/scripts/h5000m-qmi-smoke-test.sh" \
	"$target/application/qmodem/files/usr/sbin/h5000m-qmi-smoke-test"
chmod 0755 "$target/application/qmodem/files/usr/sbin/h5000m-qmi-smoke-test"

echo "staged curated QModem 3.2.0 packages at: $target"
