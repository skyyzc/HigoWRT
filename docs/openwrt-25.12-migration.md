# OpenWrt 25.12 / Linux 6.12 迁移路线

## 目标

H5000M 运行一个 OpenWrt 实例，同时保留两个管理面：

- Higo 管理界面监听 80；
- 原生 LuCI 监听 8080；
- 两者共享 UCI、ubus、netifd、firewall 和 QModem。

旧量产固件只用于迁移 Higo 用户态组件和核对硬件行为。Linux 6.6 模块不得进入
Linux 6.12 镜像。

## 新基线

- `Hiveton/higowrt@25a3aefa7be5821fa7e5e4809ac34a09fa62ef24`
- OpenWrt 25.12.4 / Linux 6.12
- H5000M MT7987A DTS、eMMC sysupgrade 和 initramfs recovery
- QModem `v3.2.0@667060a8f89d5e8e0bbfe95f5bd5607dc6699c7f`

## 闭源和私有输入

### MTK Wi-Fi 7

官方构建定义引用但不分发：

```text
mt7993_20250919-39602c.tar.xz
warp_20250919-9c1cfa.tar.xz
mt_wifi_osal-a53418.tar.xz
```

公开 Release 和当前未过期的官方 Actions 中未发现可用 6.12 固件或驱动产物。
以后取得官方 6.12 固件时，必须先用 `scripts/audit-vendor-firmware.sh` 核对内核版本、
vermagic、模块依赖和哈希；只有与构建基线完全一致时，才可作为私有输入。旧固件的
6.6.94 模块永不复用。

### Higo 管理面

量产固件包含 `higorosd`、`/www/higoros` 前端和 Lua handler，但公开新基线没有这些
组件。第一阶段以私有 `higo-legacy` 包保留界面；第二阶段记录前端 API 并逐步实现可
维护的兼容后端。

`higorosd` 内置 opkg、sysupgrade、无线、firewall 和 QModem 调用。OpenWrt 25.12
改用 apk，因此初次启动只用于兼容性验证，在线固件升级必须禁用，不能让旧后端直接
执行新系统升级。

## 交付阶段

1. **host skeleton**：能复现拉取锁定基线并验证缺失 vendor 输入。
2. **Higo private package**：从用户固件提取、哈希、打包，维持 80/8080。
3. **open initramfs**：先使用公开可构建组件验证启动、eMMC、以太网、USB和串口。
4. **Wi-Fi lane**：优先审计官方 6.12 产物；没有匹配产物时测试开源 mt76，闭源栈
   保持为独立阻塞项。
5. **5G lane**：Linux 6.12 上游 USB/QMI 驱动优先，集成 QModem 3.2.0 和 RG520N-CN。
6. **testing sysupgrade**：所有 initramfs 检查通过后才生成，且首次迁移不保留旧
   overlay，避免 opkg/apk 和旧 UCI 状态污染。

## 构建门禁

公开探测镜像严格按以下顺序构建，任何阶段失败都不得继续生成或发布镜像：

1. 准备锁定源码并应用本仓库中可审计的兼容补丁；
2. 下载并校验源码归档；
3. 串行完成 host tools 和 AArch64 交叉工具链；
4. 单独执行 `target/linux/compile`，集中暴露 MTK 6.12 内核兼容问题；
5. 内核预检通过后才执行完整 Initramfs 构建；
6. 只收集 H5000M recovery Initramfs、manifest、buildinfo 和校验和。

下载缓存与编译缓存分开管理。失败任务也保存日志和 ccache，但缓存不能替代锁定源码、
补丁 dry-run 或完整编译验证。

### 已确认的 MTK 6.12 基线问题

- `NET_MEDIATEK_HNAT` 在 filogic 内核配置中被全局启用，但厂商 HNAT 代码未通过
  Linux 6.12 原型检查；公开 RAM 探测通道暂时关闭 HNAT，最终硬件加速通道必须另行
  恢复和验证。
- 厂商 PPE 补丁错误暴露内部 helper，并包含无调用者的 queue helper；探测通道保持
  cache helper 为文件内符号并删除死代码。
- `wifi_utility` 导出的 MTD helper 缺少公共原型；兼容补丁补充专用头文件，不改变
  `EXPORT_SYMBOL` 或读写行为。
- `wifi_utility` 的 RBUS pinctrl 状态名使用源字符串长度调用 `strncpy`；兼容补丁将
  固定状态名改为只读常量，移除不必要且会触发边界检查的复制。
- 首次 RAM 启动确认 MT7992 请求 `_23` 固件变体；公开探测通道改用
  `kmod-mt7992-23-firmware`，并保留开源 mt76 的 `/sbin/wifi`。
- 首次 RAM 启动确认镜像缺少 xHCI、RG520N-CN 未枚举；探测通道加入 `kmod-usb3`，
  按 MT7987 官方 USB2 overlay 禁用 USB3 PHY，并关闭无设备且超时的 PCIe1。
- 首次 RAM 启动确认网口角色与 DTS 注释相反；救援镜像将 `eth0`、`eth1` 都放入
  LAN，不配置 WAN，避免无 TTL 环境因单口映射失联。
- 第二次 RAM 启动确认 xHCI 和 MT7992 `_23` 固件均正常，但 MT7992 缺少板级 EEPROM
  绑定，USB 只有根集线器。后续探测通道把已有的 factory EEPROM 单元绑定到 PCIe
  Wi-Fi，并撤销不适合 H5000M 的 USB2-only RFB 假设，恢复 USB2/USB3 PHY。
- 第三次 RAM 启动确认 MT7992 已注册完整的 2.4/5 GHz `phy0`，但 factory EEPROM
  仍未被 mt76 接受；同时发现 MT7987 的 USB3 PHY 在 SoC DTSI 中默认禁用，导致
  xHCI 以 `-110` 失败。后续探测通道显式启用 USB3 PHY 并绑定 3.3 V 电源。
- 第四次 RAM 启动确认 USB3 PHY 和 xHCI 稳定工作，RG520N-CN 以 `2c7c:0801`
  在 5 Gbit/s SuperSpeed 枚举；`option` 生成 `/dev/ttyUSB0..3`，`qmi_wwan`
  生成 `/dev/cdc-wdm0` 和 `wwan0`。公开 Linux 6.12 驱动已覆盖 5G 内核链路，后续
  不需要移植官方固件的 USB/QMI 闭源内核模块。
- QModem 集成通道从锁定的 3.2.0 commit 只复制用户态包和 `quectel-CM-5G-M`，不暴露
  QModem 的替换内核驱动目录；RG520N-CN profile 在暂存树中增量合并。首次 RAM
  集成测试默认关闭自动拨号，只验证发现、AT、ubus 和 LuCI，避免未经确认产生流量。
- 第五次 RAM 启动确认 QModem 3.2.0 自动识别 `rg520n-cn`、选择 `/dev/ttyUSB2`，并
  注册 `qmodem`、`qmodem_sms`、`modem_ctrl`；全局自动拨号保持关闭。实机日志同时
  暴露 Linux USB root hub 被误排队为 `usb1/usb2`，本地小补丁按 VID `1d6b` 过滤。
- QMI 验证使用 `h5000m-qmi-smoke-test` 临时启动 `2_1`，强制从 `wwan0` 发出三个
  ICMP 包，最长运行两分钟并保存报告；正常结束、错误、信号或独立 watchdog 超时都会
  调用 QModem hang。该脚本不修改全局 `enable_dial=0`，不能替代正式联网配置。
- 第六次 RAM 启动确认 QMI 会话能取得 IPv4 `10.96.22.37/30`、IPv6 和默认路由，
  QModem 页面显示已连接，但公网 ICMP 不通。报告同时显示 `quectel-CM-M -d` 已直接
  配置地址，而 netifd 的 `USB` DHCP 客户端仍在 pending 并反复切换 `wwan0` 链路。
  本地兼容补丁因此让 Quectel QMI + `quectel-CM-M` 使用 `proto none`，避免两个地址
  管理器竞争；下一轮测试以公网实际可达而非仅获得地址作为成功条件。
- 第七次 RAM 启动确认 netifd 竞争已经消失（`proto none`、`pending=false`），但
  `raw_ip=N`、TX 有计数而 RX 始终为零，连蜂窝网关也不可达。后续补丁在启动
  `quectel-CM-M` 之前将上游 `qmi_wwan` 切到 raw-IP，并在测试命令返回前记录完成
  hang 后的 procd、进程和地址状态，避免把 PDP 残留误认为测试已安全结束。

只有实际进入目标内核编译后出现的编译器错误才算源码卡点。缺少交叉链接器、缓存目录
或 host tool 属于 CI 依赖错误，禁止据此修改内核代码。

## 发布规则

- 插件更新可自动构建进入 testing，但必须人工晋升 stable。
- 内核、DTS、Wi-Fi/HNAT/WARP 只能随完整固件发布。
- H5000M 没有 A/B rootfs；禁止无人值守自动刷写。
- 私有 Higo 和授权不明的 vendor 文件不得进入公开 Git 历史或公开 Actions artifact。
