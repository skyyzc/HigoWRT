# 现机清单与下一步判定

## 2026-08-30 实机采样结论

采样包 `h5000m-inventory-20260830-193401.tar` 不执行 AT 指令、不修改 UCI。
已核对出以下运行时事实：

| 项目 | 实机结果 | 对升级方案的影响 |
| --- | --- | --- |
| 系统 | ImmortalWrt 24.10-SNAPSHOT, `r33418-34bb738192`, Linux 6.6.94, `aarch64_cortex-a53`, opkg | 用户态 IPK 必须使用该提交及 GCC 13.3/musl 基线构建 |
| Web | `higorosd` 监听 80，`uhttpd` 监听 8080 和 443 | 两个管理面共用同一系统，用户态 QModem 升级不应改动端口配置 |
| QModem | `qmodem 3.0.2-r48`，相关 LuCI/短信/AT 组件均为 3.0.2 系列 | 3.2.0 需作为一组用户态包升级，不只替换 LuCI |
| 模组 | Quectel RG520N-CN，USB `2c7c:0801` | 保留 RG520N-CN 独立 profile |
| 数据通道 | `/dev/cdc-wdm0` + `wwan0`，运行中驱动为厂商 `qmi_wwan_q` | 第一阶段严禁替换或发布 QMI/MHI 内核包 |
| AT 通道 | `/dev/ttyUSB0..3`，`ubus-at-daemon` 运行，ubus 存在 `qmodem`/`qmodem_sms`/`modem_ctrl` | 保留 ubus AT 队列，避免新旧服务同时持有串口 |
| 附加 WebUI | `modemwebui` 已启用，但采样时未见 8001/8765 监听者 | 暂不视为实际端口冲突，安装前后仍需复查 |
| 存储 | eMMC，单 kernel/rootfs，squashfs + f2fs overlay，无 A/B 槽 | 禁止无人值守整机刷写；用户态升级必须先做可回滚备份 |

当前采样局限：设备没有 `fuser`，因此未能确认每个 tty 的持有进程；
本轮也没有发送 `AT+CGMM` 等指令。这两项不阻塞用户态 IPK 构建，
但是正式安装前的预检项。

## 采集目标

采集脚本的输出用于回答以下问题：

| 项目 | 需要判定的内容 |
| --- | --- |
| 系统基线 | OpenWrt/ImmortalWrt 版本、内核、架构、opkg 或 apk |
| 分区 | kernel/rootfs 布局、是否存在真正的 A/B 和回滚机制 |
| Web 服务 | 80/8080 分别由哪个进程和配置提供 |
| Higo 组件 | 软件包、可执行文件、init 服务、ubus 对象和 ACL |
| 5G 组件 | QModem/modem_support、串口、USB/PCIe、拨号驱动 |
| 竞争风险 | 哪些进程持有 `/dev/ttyUSB*`、`/dev/mhi*` 等设备 |
| 升级 ABI | libc、libubus、rpcd、LuCI、firewall 和内核 vermagic |

采集包默认不读取完整 network、wireless、dropbear 配置，也不主动执行任何 AT 指令。
即便如此，公开分享前仍应检查文件内容并删除序列号、MAC、IMSI、IMEI、ICCID、手机号、
公网地址和日志中的认证信息。

采集完成后的决策顺序：

1. 使用锁定基线构建并审计 QModem 3.2.0 用户态 IPK。
2. 生成设备端预检、备份、事务安装和一键回滚脚本。
3. 先验证 Higo 80、LuCI 8080、ubus AT 队列及 QMI 拨号，再晋升软件包。
4. 用户态更新稳定后，再单独评估新基线整机固件和 initramfs 测试；不直接写入 eMMC。
