#!/bin/sh
set -u

section=${1:-2_1}
duration=${QMI_TEST_DURATION:-120}
report=${QMI_TEST_REPORT:-/tmp/h5000m-qmi-smoke-test.txt}
watchdog=
cleaned=0

cleanup()
{
	[ "$cleaned" -eq 0 ] || return 0
	cleaned=1
	[ -z "$watchdog" ] || kill "$watchdog" 2>/dev/null || true
	/etc/init.d/qmodem_network hang "$section" >/dev/null 2>&1 || true
}

finish()
{
	status=$?
	cleanup
	exit "$status"
}

trap finish EXIT HUP INT TERM

if ! uci -q get "qmodem.$section" >/dev/null; then
	echo "missing QModem section: $section" >&2
	exit 2
fi

device=$(uci -q get "qmodem.$section.network")
[ -n "$device" ] || device=wwan0

: >"$report"
{
	echo "H5000M QMI smoke test"
	echo "section=$section"
	echo "device=$device"
	echo "duration=$duration"
	echo "global_enable_dial=$(uci -q get qmodem.main.enable_dial)"
	echo "device_enable_dial=$(uci -q get qmodem.$section.enable_dial)"
} >>"$report"

# Independent rollback remains active if the interactive SSH shell disappears.
(
	sleep "$duration"
	/etc/init.d/qmodem_network hang "$section" >/dev/null 2>&1 || true
) &
watchdog=$!

echo "Starting temporary QMI session; automatic hang in ${duration}s."
/etc/init.d/qmodem_network dial "$section"

elapsed=0
while [ "$elapsed" -lt 90 ]; do
	if ip -f inet addr show dev "$device" 2>/dev/null | grep -q 'inet '; then
		break
	fi
	sleep 5
	elapsed=$((elapsed + 5))
done

# The address may appear just before raw-IP mode, routes and carrier settle.
sleep 5
gateway=$(ip route show dev "$device" 2>/dev/null | awk '$1 == "default" { print $3; exit }')
public_reachable=0
gateway_reachable=0
if [ -n "$gateway" ] && ping -c 1 -W 3 -I "$device" "$gateway" >/dev/null 2>&1; then
	gateway_reachable=1
fi
if ping -c 3 -W 3 -I "$device" 1.1.1.1 >/dev/null 2>&1; then
	public_reachable=1
fi

{
	echo
	echo "## qmodem"
	uci -q show "qmodem.$section"
	echo
	echo "## process"
	pgrep -af 'quectel-CM|modem_dial' || true
	echo
	echo "## address"
	ip addr show dev "$device" 2>&1 || true
	echo "raw_ip=$(cat /sys/class/net/$device/qmi/raw_ip 2>/dev/null || echo unavailable)"
	echo "gateway=$gateway"
	echo "gateway_reachable=$gateway_reachable"
	echo "public_reachable=$public_reachable"
	cat "/sys/class/net/$device/statistics/rx_packets" 2>/dev/null | sed 's/^/rx_packets=/' || true
	cat "/sys/class/net/$device/statistics/tx_packets" 2>/dev/null | sed 's/^/tx_packets=/' || true
	echo
	echo "## routes"
	ip route show 2>&1 || true
	echo
	echo "## network interface"
	ubus call "network.interface.USB" status 2>&1 || true
	echo
	echo "## forced-interface ping"
	[ -z "$gateway" ] || ping -c 3 -W 3 -I "$device" "$gateway" 2>&1 || true
	ping -c 3 -W 3 -I "$device" 1.1.1.1 2>&1 || true
	echo
	echo "## dial log"
	tail -n 160 "/var/run/qmodem/${section}_dir/dial_log" 2>&1 || true
	echo
	echo "## system log"
	logread | grep -Ei 'qmodem|quectel|wwan|qmi|udhcpc' | tail -n 200
} >>"$report"

# Do not return control to the operator while the temporary PDP session is
# still active. The EXIT trap remains as a second cleanup path.
cleanup
sleep 5
{
	echo
	echo "## post-cleanup"
	/etc/init.d/qmodem_network modem_status "$section" 2>&1 || true
	pgrep -af 'quectel-CM|modem_dial' || true
	ip addr show dev "$device" 2>&1 || true
	echo "raw_ip=$(cat /sys/class/net/$device/qmi/raw_ip 2>/dev/null || echo unavailable)"
} >>"$report"

if [ "$public_reachable" -eq 1 ]; then
	echo "QMI data path is reachable. Report: $report"
	exit 0
fi

echo "QMI data path is not reachable. Report: $report" >&2
exit 1
