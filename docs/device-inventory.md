# 现机清单与下一步判定

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

1. 还原 80/8080 服务拓扑及 Higo 5G 后端行为。
2. 判断 Higo 后端能否改用或代理到 `ubus-at-daemon`。
3. 根据实际系统版本选择原位 QModem 兼容构建，或迁移到新 HiGoWRT 基线。
4. 生成并在 initramfs 中验证第一版固件，确认网口/Wi-Fi 后再讨论写入 eMMC。
