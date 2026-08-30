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

## 发布规则

- 插件更新可自动构建进入 testing，但必须人工晋升 stable。
- 内核、DTS、Wi-Fi/HNAT/WARP 只能随完整固件发布。
- H5000M 没有 A/B rootfs；禁止无人值守自动刷写。
- 私有 Higo 和授权不明的 vendor 文件不得进入公开 Git 历史或公开 Actions artifact。
