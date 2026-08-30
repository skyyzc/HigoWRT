# HigoWRT for Hiveton H5000M

本仓库用于为 Hiveton H5000M（MT7987A/MT7992）建立可重复构建、可审计升级的
HiGoWRT 固件。目标是在同一 OpenWrt 系统中保留：

- `http://192.168.88.1/` 的 Higo 管理界面；
- `http://192.168.88.1:8080/` 的原生 LuCI；
- QModem 新版及 RG520N-CN 适配；
- 与固件 ABI 严格匹配的自有软件包源和升级清单。

> 当前阶段：OpenWrt 25.12/Linux 6.12 迁移。尚未提供可刷写固件，也不应把仓库内容用于刷机。

## 当前实施路线

硬件和内核基线采用锁定的 `Hiveton/higowrt` 25.12 提交。旧量产固件仅作为 Higo
管理面和运行行为的私有迁移输入，不再作为新软件包的编译基线。

1. 先构建 initramfs 并从内存启动验证，不直接写入 eMMC。
2. Higo `higorosd` 和前端从用户持有的官方固件私下提取，公开仓库不分发二进制。
3. Higo 继续监听 80；LuCI 由 uhttpd 监听 8080。
4. QModem 3.2.0 在 25.12 基线上重新编译，RG520N-CN 适配保持为小型覆盖层。
5. 内核模块只允许来自同一次完整构建，禁止跨内核复制或强制安装。

完整边界和阻塞项见 `docs/openwrt-25.12-migration.md`。

## 设备采集

把 `scripts/collect-h5000m.sh` 上传到路由器，在 SSH 中运行：

```sh
sh /tmp/collect-h5000m.sh
```

脚本只查询系统状态，不发送 AT 指令、不修改 UCI。它会在 `/tmp` 生成一个
`h5000m-inventory-*.tar.gz`。下载后先自行检查内容，再放到本仓库外沟通分析；不要将
可能包含设备身份信息的原始采集包直接提交到公开 GitHub。

## 仓库布局

```text
config/upstreams.env          固定并可审计的上游版本
docs/architecture.md          目标架构和安全边界
docs/device-inventory.md      采集项及判定标准
docs/firmware-analysis-*.md   官方固件静态分析报告
docs/openwrt-25.12-migration.md 新系统迁移路线与闭源边界
package/higo-legacy/          私有 Higo payload 的公开打包骨架
scripts/extract-higo-legacy.sh 从用户固件提取私有 Higo payload
scripts/audit-vendor-firmware.sh 审计候选 6.12 固件及内核模块 ABI
scripts/collect-h5000m.sh     现机只读采集脚本
scripts/verify-upstreams.sh   上游版本与 RG520N-CN 缺口检查
```

## 当前锁定上游

- HiGoWRT：`Hiveton/higowrt@25a3aefa7be5821fa7e5e4809ac34a09fa62ef24`
- QModem：`FUjr/QModem@v3.2.0`（commit `667060a8f89d5e8e0bbfe95f5bd5607dc6699c7f`）

后续不会直接跟随 `main` 自动生成稳定固件。依赖更新先进入测试通道，通过 H5000M
实机验证后才晋升稳定通道。
