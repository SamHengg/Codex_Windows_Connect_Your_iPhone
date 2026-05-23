# Codex Windows Connect Your iPhone

便于方便可以直接将本仓库链接
https://github.com/SamHengg/Codex_Windows_Connect_Your_iPhone 喂给Codex进行配置操作

Make Codex Desktop on Windows reliably connect to Codex / ChatGPT on iPhone.

把 Windows 电脑端 Codex 配好，让 iPhone 端可以稳定发现、连接并同步电脑任务。

> Give this repository to Codex and say:
>
> `Follow this repo and configure my Windows Codex Desktop so my iPhone can connect reliably. Run setup.ps1, verify status=connected, and do not print any tokens.`
>
> 直接把这个仓库发给 Codex，然后说：
>
> `请按照这个仓库配置我的 Windows 电脑端 Codex，让 iPhone 可以稳定连接。运行 setup.ps1，验证 status=connected，不要打印任何 token。`

## What This Fixes

- iPhone says connected, but desktop and phone do not sync.
- Windows Codex remote control stays disabled or stuck at connecting.
- `codex remote-control start` fails on Windows.
- `config.toml` is read-only or has broken feature flags.
- Codex Desktop cannot find Git and fails to identify workspace metadata.

## Quick Start

Open PowerShell in this repository and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

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
