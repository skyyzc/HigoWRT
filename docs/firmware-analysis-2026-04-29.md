# HiGoROS-H5000M-1-26-04-29-09.bin 静态分析

## 文件身份

- 原文件：`inputs/firmware/latest/HiGoROS-H5000M-1-26-04-29-09.bin`
- SHA-256：`e89cf36d537fb8f2945a4e06c8efff67dbe083f1a1b3571480270b296a69208c`
- 格式：标准 OpenWrt sysupgrade tar
- 设备目录：`sysupgrade-hiveton,h5000m`
- kernel：4,598,468 字节，FIT/DTB，Linux 6.6.94
- rootfs：SquashFS 4.0，XZ，101,099,520 字节

该文件不是 Hiveton 公开仓库当前 README 所述的 OpenWrt 25.12/Linux 6.12 固件，而是
ImmortalWrt 24.10 snapshot/Linux 6.6.94 的量产固件。

## 运行基线

rootfs 中记录：

```text
ImmortalWrt 24.10-SNAPSHOT
r33418-34bb738192
mediatek/filogic
aarch64_cortex-a53
Linux 6.6.94
opkg
```

`OPENWRT_RELEASE` 声称由 Snowflakes 于 2026-04-29 构建；SquashFS 创建时间及
`OPENWRT_BUILD_DATE=1765722143` 对应 2025-12-14 22:22:23 +0800。此不一致可能来自
可重复构建时间戳或发布方自定义版本字段，不能只依据文件名判断源码快照。

内核包严格依赖：

```text
kernel = 6.6.94~dc205e5aadad7e3c79366ba8cf01397f-r1
```

因此不能安装其他固件编译的 QModem 内核驱动包。

## 两个主要管理面

### HigoOS，端口 80

`/etc/init.d/higoros` 启动 `/usr/sbin/higorosd`，并设置：

```text
HIGOROS_ADDR=0.0.0.0:80
HIGOROS_FRONTEND_DIR=/www/higoros
```

`higorosd` 是带调试信息的 aarch64 Go ELF。静态符号表明确显示它通过 QModem/ubus
取得模组列表、基本信息、短信及执行 `send_at`，而不是一个完全独立的拨号栈。它也会
识别 QModem 的 `use_ubus` 配置。这证明 Higo 主页面和新版 QModem具备继续集成的基础。

### 原生 LuCI，端口 8080

同一个 Higo init 脚本会删除 uhttpd 的 80 监听并改为：

```text
0.0.0.0:8080
[::]:8080
```

因此 80/8080 是同一 OpenWrt 上的两个 Web 服务，不是两个系统。

## 第三个模组 Web 服务

固件还启用了 `/etc/init.d/modemwebui`。它根据 `lsusb` 选择 `/www/webui` 下的前端，
后端 `/usr/bin/webuiserver` 使用：

```text
HTTP 8001
WebSocket 8765
SERIAL auto/sendat
```

该二进制包含直接调用 `sendat` 和 `tom_modem` 的路径，可能绕开统一 AT 队列。其启动
型号名单有 RM520N、RG520F 等，但没有 RG520N-CN。现机采集需确认它是否因 USB 描述
匹配到其他名字而实际运行。如果运行，应改造为 ubus 模式或停止这个服务；HigoOS 主
页面本身不需要因此移除。

## 当前 QModem 栈

| 软件包 | 固件版本 |
| --- | --- |
| qmodem | 3.0.2-r48 |
| luci-app-qmodem-next | 3.0.2-r1 |
| ubus-at-daemon | 3.0.2-r1 |
| tom_modem | 3.0.2-r2 |

固件已经包含纯 JS/ucode 的 QModem Next、rpcd ACL 和 `ubus-at-daemon`。因此升级到
3.2.0 的首选方案不是先迁移 OpenWrt 25.12，而是针对这一 ImmortalWrt 24.10 基线
重编译 QModem 3.2.0 的完整用户态包组，并复用固件现有、ABI 匹配的内核驱动。

不能只替换 `luci-app-qmodem-next`，需要以事务方式同步升级 qmodem、modem_scan、
tom_modem、ubus-at-daemon、sms-tool/sms-forwarder 和相关 rpcd 文件。

## RG520N-CN JSON

上传文件：`inputs/modem_support.json`

```text
SHA-256 0a4cad4c0d06bb0d2922fbe58346178a2480bc5961bfadfe7416b811781d7b48
```

与固件自带 JSON 的规范化差分只有一项：新增 USB 型号 `rg520n-cn`。没有修改其他
型号。这非常适合保存为小补丁，而无需维护完整 JSON 分叉。

该条目的主要能力为：

```text
VID manufacturer_id: 2c7c
data_interface: usb
modes: qmi, gobinet, ecm, mbim, rndis, ncm
LTE: 1/3/5/8/34/38/39/40/41
NSA/SA: 1/8/28/41/78
```

正式采用前仍需以模组 AT 输出或厂商规格核实频段字段；“能够识别”不等于所有锁频
操作都正确。

## 当前推荐路线

1. 先锁定量产固件对应的 ImmortalWrt 源码/SDK和内核 ABI。
2. 用该基线编译 QModem 3.2.0 用户态完整包组，不替换内核模块。
3. 将 RG520N-CN 作为单独补丁和测试 fixture 合入。
4. 确认 HigoOS 通过新版 QModem ubus API 的兼容性。
5. 现机确认 `modemwebui` 是否运行及是否持有 AT 口。
6. 先生成可回滚的 IPK 测试包；验证后再集成完整固件。
7. OpenWrt 25.12/Linux 6.12 迁移作为第二阶段，不与 QModem 3.2.0 升级同时冒险。

## 仍需现机采集的结论

- overlay 中实际生成的 QModem section、AT 口和 `use_ubus` 值；
- `modemwebui`、`webuiserver` 和 `ubus-at-daemon` 的实际运行状态；
- 哪个进程持有 `/dev/ttyUSB*`；
- RG520N-CN 的 USB 描述、VID/PID和当前拨号模式；
- eMMC 实际分区及升级回滚能力；
- sysupgrade 保留配置后 Higo/QModem 的覆盖行为。
