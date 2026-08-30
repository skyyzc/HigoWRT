#!/bin/sh
# H5000M inventory collector. It sends no AT commands and performs no UCI writes.
set -u

stamp=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo unknown)
work="/tmp/h5000m-inventory-$stamp"
archive="$work.tar.gz"
mkdir -p "$work"
umask 077

capture() {
    name=$1
    shift
    {
        echo "command: $*"
        echo
        "$@" 2>&1
    } >"$work/$name.txt"
}

capture_shell() {
    name=$1
    command=$2
    {
        echo "command: $command"
        echo
        sh -c "$command" 2>&1
    } >"$work/$name.txt"
}

capture date date
capture uname uname -a
[ -r /etc/os-release ] && cp /etc/os-release "$work/os-release.txt"
[ -r /etc/openwrt_release ] && cp /etc/openwrt_release "$work/openwrt-release.txt"
command -v ubus >/dev/null 2>&1 && capture ubus-board ubus call system board
command -v ubus >/dev/null 2>&1 && capture ubus-list ubus list
capture_shell package-manager 'if command -v apk >/dev/null 2>&1; then apk --version; apk list --installed; elif command -v opkg >/dev/null 2>&1; then opkg print-architecture; opkg list-installed; else echo no-supported-package-manager; fi'
capture_shell mounts 'mount; echo; df -hT 2>/dev/null || df -h'
capture_shell partitions 'cat /proc/mtd 2>/dev/null; echo; lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT 2>/dev/null; echo; blkid 2>/dev/null'
capture_shell modules 'uname -r; cat /proc/modules'
capture_shell usb 'lsusb -t 2>/dev/null; echo; lsusb 2>/dev/null'
capture_shell devices 'ls -l /dev/ttyUSB* /dev/ttyACM* /dev/cdc-wdm* /dev/mhi* 2>/dev/null'
capture_shell net-drivers 'for n in /sys/class/net/*; do printf "%s " "${n##*/}"; readlink "$n/device/driver" 2>/dev/null || true; done'
capture_shell listeners 'ss -lntup 2>/dev/null || netstat -lntup 2>/dev/null'
capture_shell processes 'ps w'
capture_shell services 'for f in /etc/init.d/*; do "$f" enabled >/dev/null 2>&1 && echo "${f##*/}"; done'
capture_shell tty-holders 'if command -v fuser >/dev/null 2>&1; then fuser /dev/ttyUSB* /dev/ttyACM* /dev/cdc-wdm* /dev/mhi* 2>/dev/null; else echo fuser-not-installed; fi'
capture_shell web-config 'for f in /etc/config/uhttpd /etc/config/nginx /etc/nginx/nginx.conf /etc/lighttpd/lighttpd.conf; do [ -r "$f" ] && { echo "### $f"; sed -n "1,240p" "$f"; }; done'
capture_shell higo-files 'find /etc/init.d /etc/config /usr/bin /usr/sbin /usr/libexec /www -maxdepth 2 \( -iname "*higo*" -o -iname "*modem*" -o -iname "*atd*" -o -iname "*qmodem*" \) -print 2>/dev/null'
capture_shell qmodem-files 'for f in /usr/share/qmodem/modem_support.json /etc/config/qmodem /etc/config/ubus-at-daemon; do [ -r "$f" ] && { echo "### $f"; if command -v sha256sum >/dev/null 2>&1; then sha256sum "$f"; fi; grep -ni -A22 -B3 "rg520\|rm520" "$f" 2>/dev/null || true; }; done'
capture_shell rpcd-acl 'find /usr/share/rpcd/acl.d -maxdepth 1 -type f -print 2>/dev/null | sort'

cat >"$work/README.txt" <<'EOF'
This inventory intentionally sends no AT commands and performs no UCI writes.
Review every file before sharing. Remove device identifiers, MAC addresses, public
addresses, IMSI/IMEI/ICCID, phone numbers, credentials and tokens if present.
EOF

tar -czf "$archive" -C /tmp "${work##*/}"
echo "Inventory created: $archive"
echo "Review and redact it before sharing or committing anywhere."
