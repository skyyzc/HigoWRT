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
	echo
	echo "## routes"
	ip route show 2>&1 || true
	echo
	echo "## network interface"
	ubus call "network.interface.USB" status 2>&1 || true
	echo
	echo "## forced-interface ping"
	ping -c 3 -W 3 -I "$device" 1.1.1.1 2>&1 || true
	echo
	echo "## dial log"
	tail -n 160 "/var/run/qmodem/${section}_dir/dial_log" 2>&1 || true
	echo
	echo "## system log"
	logread | grep -Ei 'qmodem|quectel|wwan|qmi|udhcpc' | tail -n 200
} >>"$report"

if ip -f inet addr show dev "$device" 2>/dev/null | grep -q 'inet '; then
	echo "QMI session obtained an IPv4 address. Report: $report"
	exit 0
fi

echo "QMI session did not obtain an IPv4 address. Report: $report" >&2
exit 1
