# Enable Gemini in Chrome (macOS) ✨

为 macOS 上的 Chrome Stable 配置 Gemini 侧边栏。

## 📋 要求

- macOS、Google Chrome Stable
- `jq`（如未安装：`brew install jq`）

## 🚀 启用

```bash
./enable-chrome-ai-modern-macos.sh
```

脚本会优雅退出 Chrome，备份并更新当前活动 Profile 的配置，然后带必要参数重启 Chrome。若 Chrome 未能正常退出，脚本会停止，不会强制结束进程。

## 🔧 技术原理

脚本通过修正 Chrome 的地区实验配置和当前 Profile 的 GLIC 资格，让 Gemini 侧边栏通过 Chrome 的本地资格检查：

| 配置 | 修改值 | 作用 |
|---|---|---|
| `variations_country` | `"us"` | 将实验地区设为美国 |
| `variations_*country` | 当前版本号 + `"us"` | 同步 permanent、safe-seed 地区，避免被 `cn` session 覆盖 |
| `variations_safe_seed_locale` | `"en-US"` | 配套 safe-seed 语言环境 |
| `is_glic_eligible` | `true` | 标记当前 Profile 具备 GLIC 资格 |
| `glic.previously_not_allowed` | `false` | 清除当前 Profile 的“不允许使用”状态 |
| `sync.glic_rollout_eligibility` | `true` | 启用 Profile 的 GLIC rollout 资格 |
| `--variations-override-country=us` | 启动参数 | 启动时覆盖地区判断 |
| `--disable-features=GlicUseSessionCountryForFiltering` | 启动参数 | 禁用按实际 session 地区过滤 |

这不是修改 Google 账号地区，也不能绕过账号资格、网络出口或服务端限制。

## 🔄 恢复

恢复最近一次运行前的配置：

```bash
./restore-chrome-ai-modern-macos.sh
```

备份保存在 `backups/`。恢复脚本会先备份当前配置，再恢复指定快照；恢复配置不保证 Gemini 仍可用。

## ⚠️ 注意

- 仅支持 Chrome Stable 的当前活动 Profile。
- 本工具会修改 Chrome 本地配置，Chrome 更新可能改变其行为；账号资格或 Google 服务端限制仍可能阻止 Gemini。
- 不要添加 `--glic-dev`，它曾导致侧边栏部分文字/图标显示异常。
- `enable-chrome-ai.sh` 是旧脚本，不建议使用。
- `backups/` 可能包含个人资料设置，请勿公开分享或提交。

## 📜 Credit

本项目的基础思路参考：

- [lcandy2/enable-chrome-ai](https://github.com/lcandy2/enable-chrome-ai)：发现并分享 Chrome AI 本地配置方法。
- [tianlelyd/enable-chrome-ai](https://github.com/tianlelyd/enable-chrome-ai)：提供 macOS Shell 版本实现。

本版本在此基础上针对 Chrome 157 和 macOS 做了适配：补充 safe-seed 地区、Profile GLIC 资格及启动参数，并通过实际测试移除会导致界面文字/图标异常的 `--glic-dev`。
