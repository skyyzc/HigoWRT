# Vendor inputs

此目录只保存输入规则，不保存授权不明的二进制或 SDK。

允许的本地目录为 `vendor/blobs/`，已被 Git 忽略。文件名不是信任依据；任何候选
固件或驱动必须记录来源、SHA-256、内核 release、vermagic 和依赖关系。

已知缺失的 MTK SDK 输入：

```text
mt7993_20250919-39602c.tar.xz
warp_20250919-9c1cfa.tar.xz
mt_wifi_osal-a53418.tar.xz
```

从旧 6.6 固件提取的内核模块仅供分析，不能进入 6.12 构建。
