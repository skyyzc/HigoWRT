# 目标架构与边界

## 系统关系

80 端口的 Higo 和 8080 端口的 LuCI 是同一 OpenWrt 实例上的两个管理面，不是两套
隔离操作系统。它们共享内核、UCI、ubus、netifd、firewall 和 5G 模组。

```text
Higo :80 -----------+
                     +--> ubus / UCI / netifd --> 同一个 OpenWrt
LuCI :8080 ---------+
                              |
                       ubus-at-daemon 队列
                              |
                         RG520N-CN AT 口
```

## 不可破坏的约束

1. 只有一个服务负责模组发现、拨号及状态生命周期，默认选择 QModem。官方量产固件
   的 HigoOS 后端已通过 QModem ubus 接口集成，应保持这种关系。
2. 所有并发 AT 请求必须经过同一队列；不得让 Higo 后端与 QModem分别打开 AT 口。
3. 单独的 `modemwebui/webuiserver` 可能直接调用 sendat；如果现机确认其运行，则改用
   ubus 队列或停止该附加服务，不影响 HigoOS 主页面。
4. 不使用 `--force-depends` 安装内核 ABI 不匹配的软件包。
5. 应用包更新失败必须可回滚；在确认分区具备可靠回滚前，不启用无人值守刷机。
6. 稳定构建固定上游 commit、软件源和工具链，不直接构建移动的 `main`。

## 更新通道

- `testing`：上游更新后自动构建，需实机验证网络、Wi-Fi、5G 和两个 Web 管理面。
- `stable`：只接收由测试版本晋升的、签名的固件和软件包索引。

应用包和整机固件分开发布。QModem 的用户态组件必须作为同一事务升级；涉及内核驱动
时必须发布整机固件或与目标 kernel ABI 完全匹配的包。

## RG520N-CN 适配策略

QModem v3.2.0 有 RM520N-CN 和 RG520N-EU/EB，但没有 RG520N-CN。不能盲目复制
RM520N-CN 条目。2026-08-30 现机采样已确认 USB ID 为 `2c7c:0801`，
运行通道为 `/dev/cdc-wdm0` + `wwan0`，并由厂商 `qmi_wwan_q` 驱动。
因此第一阶段只升级 QModem 用户态组件，复用官方固件的内核驱动。

安装前仍需要确认：

- `AT+CGMM` 与 QModem 归一化的 model key 是否稳定匹配 `rg520n-cn`；
- 安装后仍使用 QMI，且 `/dev/cdc-wdm0`/`wwan0` 布局未变；
- 中国版支持的 LTE/NSA/SA 频段；
- Higo 后台是否持有 AT 端口。

最终适配以一个小型上游补丁和测试 fixture 保存，不整体覆盖上游
`modem_support.json`。
