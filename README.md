# Codex Windows Connect Your iPhone

> **Status update, 2026-05-24:** OpenAI's public release notes describe Codex mobile remote access as Mac-first, but Windows Codex Beta users have reported successful mobile connections. This repo documents the Windows configuration and troubleshooting path.
>
> **当前状态，2026-05-24：** OpenAI 官方发布说明偏向 Mac-first，但 Windows Codex Beta 用户确实有可连接手机端的案例。本仓库按 Windows 教程整理配置和排错路径。

本仓库用于把 Windows 电脑端 Codex 配好，让 iPhone / Android ChatGPT App 里的 Codex 尽可能稳定发现、连接并同步电脑端任务。

如果你遇到红点、离线、一直转圈，通常优先检查：Codex Desktop 是否为 Windows Beta 最新版、手机和电脑是否同一个 ChatGPT 账号、ChatGPT 是否开启 MFA、远程控制权限是否开启、`config.toml` 是否可写、Codex CLI / Git 是否在 PATH 中。

Official references:

- [ChatGPT release notes: Codex remote access from the ChatGPT mobile app](https://help.openai.com/en/articles/6825453-chatgpt-release-notes)
- [ChatGPT Business release notes: Codex remote access and access tokens](https://help.openai.com/en/articles/11391654-chatgpt-business-release-notes)

读者可直接将本仓库链接
https://github.com/SamHengg/Codex_Windows_Connect_Your_iPhone 
喂给Codex进行配置操作。若你的 Windows Codex Beta 支持手机远程连接，按本仓库配置后大概率能完成连接；如果仍红点，请按排错部分逐项检查。
手机端说明在文本末尾~

若有问题，请随时与我联系：sunzh25@mails.tsinghua.edu.cn
本项目已完全开源~可按需更新

超详细教程即原理见仓库：Codex_Windows_Connect_Your_iPhone.md

> 直接把这个仓库发给 Codex，然后说：
>
> `请按照这个仓库配置我的 Windows 电脑端 Codex，让 iPhone 可以连接。检查 Codex Desktop、Codex CLI、config.toml、MFA、远程控制状态和红点离线问题；不要打印任何 token。`

> Give this repository to Codex and say:
>
> `Follow this repo to configure my Windows Codex Desktop so my iPhone can connect. Check Codex Desktop, Codex CLI, config.toml, MFA, remote-control status, and red offline-dot issues; do not print any tokens.`
>


## Requirements

 Windows must have both Codex Desktop and the `codex` command available.

中文说明：使用这个仓库前，请先安装 Node.js LTS，然后运行：

```powershell
npm install -g @openai/codex --registry=https://registry.npmmirror.com
codex --version
```

Also open Codex Desktop once and sign in with the same OpenAI / ChatGPT account used on the phone. This creates `%USERPROFILE%\.codex\config.toml`, which `setup.ps1` will repair and configure.

## What This Fixes

- iPhone shows a Windows host with a red offline dot.
- Windows CLI app-server says `status=connected`, but mobile still says offline.
- `codex remote-control start` fails on Windows.
- `config.toml` is read-only or has broken feature flags.
- Codex Desktop cannot find Git and fails to identify workspace metadata.

## Quick Start

Open PowerShell in this repository and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

The setup also creates a Windows logon task named `Codex iPhone Remote Control Helper`, so the helper starts automatically after you sign in.

Check status:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\codex-remote-control-server.ps1" -Status
```

Success looks like:

```text
status=connected
serverName=DESKTOP-XXXXXXX
environmentId=env_e_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## iPhone Setup

Use the same OpenAI / ChatGPT account on iPhone and Windows.

Before connecting, enable ChatGPT MFA:

```text
ChatGPT Settings -> Security -> Multi-factor authentication (MFA)
```

Recommended: `Authenticator app`, such as 1Password, Google Authenticator, Microsoft Authenticator, or Authy.

Basic flow:

1. Open ChatGPT security settings.
2. Enable MFA with an authenticator app.
3. Scan the QR code.
4. Enter the 6-digit code.
5. Save backup recovery codes.
6. Restart both Codex Desktop and the iPhone app.

MFA matters because Codex mobile can remotely control desktop tasks. Without it, the phone may appear connected while the actual remote-control channel never becomes stable.

## How It Works

Windows currently does not support Codex daemon lifecycle commands like:

```powershell
codex remote-control start
codex app-server daemon enable-remote-control
```

This repo uses the Windows-compatible path:

```powershell
codex app-server --listen stdio:// --enable remote_control
```

Then it sends JSON-RPC calls to the local app-server:

```text
remoteControl/status/read
remoteControl/enable
```

The helper keeps checking status and leaves a small log here:

```text
%USERPROFILE%\.codex\logs\remote-control-server.log
```

## Files

- `Codex_Windows_Connect_Your_iPhone.md`: full bilingual guide with principles, detailed steps, iPhone MFA setup, and troubleshooting. Give this file to Codex when you want the most complete guided setup.
- `setup.ps1`: one-shot Windows setup.
- `scripts/codex-remote-control-server.js`: app-server keepalive helper.
- `scripts/codex-remote-control-server.ps1`: start / stop / status wrapper.

中文说明：

- `Codex_Windows_Connect_Your_iPhone.md`：完整中英文教程，包含原理、详细步骤、手机端 MFA 设置和排错。需要详细配置时，可以直接把这个文件喂给 Codex。
- `setup.ps1`：一键配置入口。
- `scripts/`：远程控制保活脚本和启动/停止/状态查看工具。

## Stop / Restart Helper

Stop:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\codex-remote-control-server.ps1" -Stop
```

Start again:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\codex-remote-control-server.ps1" -Background
```

## Troubleshooting

Run:

```powershell
codex doctor --summary
```

Check:

- `websocket` should connect.
- `auth` should be configured.
- `config.toml` should load.
- `git --version` should work.

If the phone still shows a red offline dot:

1. Update Windows Codex Desktop / Codex Beta and the ChatGPT mobile app.
2. Confirm phone and desktop use the same ChatGPT account.
3. Enable ChatGPT MFA in Security settings, preferably with an Authenticator app.
4. Fully quit and reopen both Codex Desktop and the mobile app.
5. Stop duplicate app-server/helper processes, then run `setup.ps1` again.
6. Check `%USERPROFILE%\.codex\logs\remote-control-server.log` for `status=connected`.
7. If the phone shows an old red device and a new device with the same name, choose the newly refreshed one or sign out/in on mobile to refresh the device list.

If `config.toml` is read-only:

```powershell
Set-ItemProperty -LiteralPath "$env:USERPROFILE\.codex\config.toml" -Name IsReadOnly -Value $false
```

If Git is missing:

```powershell
winget install --id Git.Git --exact --accept-package-agreements --accept-source-agreements --scope user
```

## 中文简明说明

这个仓库做三件事：

1. 修复 `C:\Users\<你>\.codex\config.toml`，开启：

   ```toml
   [features]
   remote_connections = true
   remote_control = true
   ```

2. 创建 Windows 可用的远程控制保活脚本。

3. 验证远程控制是否达到：

   ```text
   status=connected
   ```

手机端请先打开 ChatGPT 的多因素身份验证（MFA），推荐使用 Authenticator app。然后重启电脑端 Codex 和 iPhone 端 ChatGPT / Codex，再从手机端选择这台 Windows 电脑。

## Safety

This project does not read, print, or modify `auth.json`, tokens, API keys, cookies, or browser credentials.

## License

MIT
