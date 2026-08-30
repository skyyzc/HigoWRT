# HigoWRT for Hiveton H5000M

本仓库用于为 Hiveton H5000M（MT7987A/MT7992）建立可重复构建、可审计升级的
HiGoWRT 固件。目标是在同一 OpenWrt 系统中保留：

- `http://192.168.88.1/` 的 Higo 管理界面；
- `http://192.168.88.1:8080/` 的原生 LuCI；
- QModem 新版及 RG520N-CN 适配；
- 与固件 ABI 严格匹配的自有软件包源和升级清单。

> 当前阶段：基线调查。尚未提供可刷写固件，也不应把仓库内容用于刷机。

## 为什么先采集

公开的 `Hiveton/higowrt` 源码包含 H5000M 板级及 Wi-Fi 驱动适配，但不能据此确认
量产固件中 Higo 服务、双 Web 端口和 5G 后端的全部实现。QModem 与 Higo 后台如果
同时直接访问 AT 串口，也存在竞争风险。因此先从现机采集不含密码的系统清单，再决定
哪些组件迁移、替换或隔离。

## 第一步：在设备上采集

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
scripts/collect-h5000m.sh     现机只读采集脚本
scripts/verify-upstreams.sh   上游版本与 RG520N-CN 缺口检查
```

## 当前锁定上游

- HiGoWRT：`Hiveton/higowrt@25a3aefa7be5821fa7e5e4809ac34a09fa62ef24`
- QModem：`FUjr/QModem@v3.2.0`（commit `667060a8f89d5e8e0bbfe95f5bd5607dc6699c7f`）

后续不会直接跟随 `main` 自动生成稳定固件。依赖更新先进入测试通道，通过 H5000M
实机验证后才晋升稳定通道。
