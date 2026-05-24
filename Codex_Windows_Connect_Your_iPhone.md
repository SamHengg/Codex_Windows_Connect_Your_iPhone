# Codex_Windows_Connect_Your_iPhone

> Quick use: give this file, `Codex_Windows_Connect_Your_iPhone.md`, directly to Codex and say:
>
> `Please follow this Markdown guide and configure my Windows Codex desktop so my iPhone can connect to it reliably. Run the setup, verify the remote-control status, and tell me the final status.`
>
> 快速使用：把这个文件 `Codex_Windows_Connect_Your_iPhone.md` 直接发给 Codex，然后说：
>
> `请按照这个 Markdown 教程检查我的 Windows 电脑端 Codex 远程连接状态。先判断官方是否支持 Windows host，再执行安全诊断，不要打印 token。`

---

## 中文版

### 先说结论

截至 2026-05-24，OpenAI 官方发布说明中写明：ChatGPT 手机端的 Codex remote access 当前用于连接运行在 **macOS host** 上的 Codex。Windows 可以安装 Codex Desktop 和 Codex CLI，但 iPhone 稳定远程控制 Windows host 目前不属于官方稳定支持能力。

因此，如果你在 Windows 上看到：

- 电脑端脚本或 CLI 日志显示 `status=connected`；
- 手机端仍显示红点、离线、重新连接失败；
- `codex remote-control start` 报 `daemon lifecycle is only supported on Unix platforms`；

这通常不是你配置错了，而是 Windows host 远程连接路径还没有官方完整支持。本文保留 Windows 排查记录和实验脚本，适合学习原理、定位问题、等待后续版本；如果你要稳定手机远程连接，请优先使用 macOS 版 Codex App。

官方参考：

- [ChatGPT release notes: Codex remote access from the ChatGPT mobile app](https://help.openai.com/en/articles/6825453-chatgpt-release-notes)
- [ChatGPT Business release notes: Codex remote access and access tokens](https://help.openai.com/en/articles/11391654-chatgpt-business-release-notes)

### 目标

本教程用于记录 Windows 电脑上配置 Codex Desktop 与 Codex CLI 远程连接时的排查过程。它可以帮助你理解为什么 Windows 端实验 app-server 可能显示 connected，但 iPhone 端仍然显示离线。

适用场景：

- iPhone 端显示已经连接，但电脑端和手机端不同步。
- Codex Desktop 里远程控制开关打开了，但手机端看不到电脑或连接不稳定。
- `config.toml` 已经写了 `remote_control = true`，但实际仍然无法连接。
- Windows 上 `codex remote-control start` 或 `codex app-server daemon enable-remote-control` 报错。

本教程的实验方案：

1. 确保 `~\.codex\config.toml` 里开启远程连接功能。
2. 取消 `config.toml` 的只读状态，避免 Codex Desktop 无法写入配置。
3. 安装并确认 `git` 在 PATH 中可用，避免 Codex Desktop 无法识别工作区元数据。
4. 在 Windows 上使用一个 Node.js 保活脚本启动 `codex app-server`，主动调用 `remoteControl/enable`。
5. 通过日志确认状态从 `disabled` 到 `connecting`，最终变为 `connected`，但这不等同于手机端一定可控制 Windows host。

### 前置要求：需要安装 Codex CLI 吗？

需要。本仓库脚本会调用 `codex app-server`，所以电脑上必须有 `codex` 命令。这里说的是 **Codex CLI**，不是 CML。

你需要准备：

1. **Codex Desktop**：先打开一次并登录，确保生成 `C:\Users\<你的用户名>\.codex\config.toml`。
2. **Node.js LTS / npm**：用于安装 Codex CLI。
3. **Codex CLI**：提供 `codex app-server` 命令，本仓库的保活脚本依赖它。
4. **Git for Windows**：建议安装；缺少 Git 时，Codex Desktop 可能无法识别工作区元数据。

安装 Codex CLI：

```powershell
npm install -g @openai/codex --registry=https://registry.npmmirror.com
codex --version
```

如果 `codex --version` 能输出版本号，再运行本仓库的 `setup.ps1`。

### 原理

Codex Desktop 的手机连接依赖远程控制功能。配置文件中的两个开关很关键：

```toml
[features]
remote_connections = true
remote_control = true
```

但是在 Windows 上，仅仅写入这两个开关可能不够。原因有三类：

1. **配置文件被设为只读**

   如果 `C:\Users\<你的用户名>\.codex\config.toml` 是只读文件，Codex Desktop 可能无法自动更新远程连接或插件状态。日志中常见错误是：

   ```text
   拒绝访问。 (os error 5)
   ```

2. **配置文件出现重复 TOML key**

   如果配置中有重复的 `[features]` 表或重复字段，Codex Desktop 的 app-server 会启动失败。日志中常见错误是：

   ```text
   duplicate key
   Invalid TOML document
   ```

3. **Windows CLI 的 daemon 管理命令不可用**

   在 Windows 上，下面这些命令可能会失败：

   ```powershell
   codex remote-control start
   codex app-server daemon enable-remote-control
   ```

   常见报错：

   ```text
   codex app-server daemon lifecycle is only supported on Unix platforms
   ```

   因此在 Windows 上更稳定的方式是直接启动：

   ```powershell
   codex app-server --listen stdio:// --enable remote_control
   ```

   然后通过 JSON-RPC 调用：

   ```text
   remoteControl/status/read
   remoteControl/enable
   ```

### 一键配置提示词

你可以把下面这段话连同本文件一起发给 Codex：

```text
请按照 Codex_Windows_Connect_Your_iPhone.md 帮我配置 Windows 电脑端 Codex，让 iPhone 可以稳定连接。

要求：
1. 检查并修复 C:\Users\<用户名>\.codex\config.toml。
2. 确保 [features] 下有 remote_connections = true 和 remote_control = true。
3. 确保 config.toml 不是只读，先备份再修改。
4. 检查 git 是否存在；如果没有，请安装 Git for Windows。
5. 创建并启动 Windows 兼容的 remote-control 保活脚本。
6. 验证远程控制状态，最终目标是 status=connected。
7. 不要打印 auth.json、token、密钥或任何登录凭据。
```

### 手机端与账号安全配置

在配置电脑端之前，先把 iPhone 端和 ChatGPT 账号安全设置好。这一步不是可选项：Codex 手机端可以远程接管你的电脑任务，所以 OpenAI 通常会要求账号启用更强的安全保护。

#### 1. 在 iPhone 上准备 ChatGPT / Codex

1. 在 iPhone 上安装或更新 ChatGPT 应用。
2. 使用和电脑端 Codex Desktop 相同的 OpenAI / ChatGPT 账号登录。
3. 保持 iPhone 网络可访问 `chatgpt.com`，不要让 VPN、代理或公司网络拦截 WebSocket 连接。
4. 如果手机端提示选择电脑，请等待电脑端显示 `status=connected` 后，再重新打开手机端页面并选择这台 Windows 电脑。

#### 2. 开启 ChatGPT 多因素身份验证（MFA）

开始设置电脑端远程连接后，系统可能会自动打开 ChatGPT 的安全设置页面。请进入：

```text
ChatGPT Settings -> Security -> Multi-factor authentication (MFA)
```

中文界面通常是：

```text
ChatGPT 设置 -> 安全 -> 多因素身份验证（MFA）
```

推荐开启 `Authenticator app`，也就是验证器应用。常用选择包括：

- 1Password
- Google Authenticator
- Microsoft Authenticator
- Authy

基本流程：

1. 在 ChatGPT 安全设置中找到 `多因素身份验证（MFA）`。
2. 选择 `添加另一种方法以防止锁定` 或 `Authenticator app`。
3. 用验证器应用扫描 ChatGPT 页面显示的二维码。
4. 输入验证器应用里显示的 6 位数字。
5. 保存备用恢复码，避免以后手机丢失或换机后无法登录。

不要跳过 MFA。没有开启 MFA 时，手机端远程控制电脑的连接可能会卡住、反复要求验证，或者显示已经连接但不同步。

#### 3. 手机端连接电脑的顺序

建议按这个顺序操作：

1. 先完成 ChatGPT 账号 MFA。
2. 再完成本教程后面的 Windows 电脑端配置。
3. 确认电脑端日志里出现：

   ```text
   status=connected
   ```

4. 关闭并重新打开 iPhone 上的 ChatGPT 应用。
5. 在 iPhone 端进入 Codex / 远程电脑相关入口。
6. 选择你的电脑名称，例如：

   ```text
   DESKTOP-XXXXXXX
   ```

7. 如果手机端仍显示旧状态，退出账号后重新登录，或同时重启电脑端 Codex Desktop 和 iPhone 端应用。

### 手动配置步骤

#### 1. 检查 Codex CLI

打开 PowerShell，运行：

```powershell
codex --version
codex doctor --summary
```

如果 `codex` 命令不存在，先安装 Codex CLI：

```powershell
npm install -g @openai/codex --registry=https://registry.npmmirror.com
```

如果 `npm` 不存在，请先安装 Node.js LTS。

#### 2. 检查并修复 config.toml

配置文件位置通常是：

```text
C:\Users\<你的用户名>\.codex\config.toml
```

PowerShell 中可以这样定位：

```powershell
$Config = Join-Path $env:USERPROFILE ".codex\config.toml"
$Config
```

确保文件中只有一个 `[features]` 表，并包含：

```toml
[features]
remote_connections = true
remote_control = true
```

如果文件是只读，请取消只读：

```powershell
$Config = Join-Path $env:USERPROFILE ".codex\config.toml"
Set-ItemProperty -LiteralPath $Config -Name IsReadOnly -Value $false
```

#### 3. 安装 Git for Windows

Codex Desktop 会用 Git 识别工作区来源和稳定元数据。如果日志里有 `Failed to locate git executable in PATH`，请安装 Git：

```powershell
winget install --id Git.Git --exact --accept-package-agreements --accept-source-agreements --scope user
```

验证：

```powershell
git --version
where.exe git
```

#### 4. 创建 Windows 远程控制保活脚本

在 PowerShell 中运行以下脚本。它会：

- 备份 `config.toml`
- 修复 `[features]`
- 创建 `codex-remote-control-server.js`
- 创建 `codex-remote-control-server.ps1`
- 启动保活进程

```powershell
$ErrorActionPreference = "Stop"

$CodexHome = Join-Path $env:USERPROFILE ".codex"
$Config = Join-Path $CodexHome "config.toml"
$BackupDir = Join-Path $CodexHome "backups"
$LogDir = Join-Path $CodexHome "logs"
New-Item -ItemType Directory -Force -Path $BackupDir, $LogDir | Out-Null

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item -LiteralPath $Config -Destination (Join-Path $BackupDir "config.$Stamp.backup.toml") -Force
Set-ItemProperty -LiteralPath $Config -Name IsReadOnly -Value $false

$Content = [System.IO.File]::ReadAllText($Config, [System.Text.UTF8Encoding]::new($false))
if ($Content -notmatch '(?m)^\s*\[features\]\s*$') {
    $Content = $Content.TrimEnd() + "`r`n`r`n[features]`r`n"
}
if ($Content -notmatch '(?m)^\s*remote_connections\s*=\s*true\s*$') {
    $Content = [regex]::Replace($Content, '(?m)^(\s*\[features\]\s*)$', "`$1`r`nremote_connections = true", 1)
}
if ($Content -notmatch '(?m)^\s*remote_control\s*=\s*true\s*$') {
    $Content = [regex]::Replace($Content, '(?m)^(\s*\[features\]\s*)$', "`$1`r`nremote_control = true", 1)
}
[System.IO.File]::WriteAllText($Config, $Content, [System.Text.UTF8Encoding]::new($false))

$JsFile = Join-Path $CodexHome "codex-remote-control-server.js"
$Js = @'
const { spawn } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const codexHome = path.join(os.homedir(), ".codex");
const logDir = path.join(codexHome, "logs");
const logFile = path.join(logDir, "remote-control-server.log");
fs.mkdirSync(logDir, { recursive: true });

let child = null;
let buffer = "";
let initialized = false;
let requestCounter = 0;
let stopping = false;

function log(message) {
  const line = `[${new Date().toISOString()}] ${message}`;
  fs.appendFileSync(logFile, line + "\n", "utf8");
}

function send(method, params = null, id = undefined) {
  if (!child || !child.stdin.writable) return;
  const payload = { jsonrpc: "2.0", id: id || `${method}-${++requestCounter}`, method, params };
  child.stdin.write(JSON.stringify(payload) + "\n");
  log(`[send] ${method}`);
}

function readStatus(label) {
  send("remoteControl/status/read", null, label || `remote-status-${++requestCounter}`);
}

function enableRemote() {
  send("remoteControl/enable", null, "remote-enable");
}

function handleMessage(obj) {
  if (obj.method === "remoteControl/status/changed" && obj.params) {
    const p = obj.params;
    log(`[remoteControl/status/changed] status=${p.status} server=${p.serverName || p.server || ""} installation=${p.installationId || ""} environment=${p.environmentId || p.environment || ""}`);
    return;
  }
  if (obj.id) {
    const data = obj.result || obj.error || {};
    log(`[response] id=${obj.id} ${JSON.stringify(data)}`);
    const text = JSON.stringify(data);
    if (obj.id === "remote-status-before-enable" && /disabled/i.test(text)) enableRemote();
    return;
  }
  log(`[message] ${JSON.stringify(obj)}`);
}

function start() {
  child = spawn("codex.cmd", ["app-server", "--listen", "stdio://", "--enable", "remote_control"], {
    cwd: os.homedir(),
    env: process.env,
    windowsHide: true,
    shell: true,
    stdio: ["pipe", "pipe", "pipe"]
  });
  initialized = false;
  buffer = "";
  log(`[start] pid=${child.pid}`);

  child.stdout.on("data", chunk => {
    buffer += chunk.toString("utf8");
    let idx;
    while ((idx = buffer.indexOf("\n")) >= 0) {
      const line = buffer.slice(0, idx).trim();
      buffer = buffer.slice(idx + 1);
      if (!line) continue;
      try { handleMessage(JSON.parse(line)); } catch { log(`[stdout] ${line}`); }
    }
  });

  child.stderr.on("data", chunk => {
    const text = chunk.toString("utf8").trim();
    if (text) log(`[stderr] ${text}`);
  });

  child.on("exit", (code, signal) => {
    log(`[exit] code=${code} signal=${signal}`);
    child = null;
    if (!stopping) setTimeout(start, 5000);
  });

  setTimeout(() => {
    send("initialize", {
      clientInfo: { name: "codex-remote-control-server", version: "1.0.0" },
      capabilities: { experimentalApi: true }
    }, "initialize");
    initialized = true;
    setTimeout(() => readStatus("remote-status-before-enable"), 1000);
  }, 1000);
}

process.on("SIGTERM", () => { stopping = true; if (child) child.kill(); process.exit(0); });
process.on("SIGINT", () => { stopping = true; if (child) child.kill(); process.exit(0); });
setInterval(() => { if (initialized) readStatus(); }, 30000);
log("[boot] remote control helper starting");
start();
'@
[System.IO.File]::WriteAllText($JsFile, $Js, [System.Text.UTF8Encoding]::new($false))

$PsFile = Join-Path $CodexHome "codex-remote-control-server.ps1"
$Ps = @'
param(
    [switch]$Background,
    [switch]$Status,
    [switch]$Stop
)

$ErrorActionPreference = "Stop"
$CodexHome = Join-Path $env:USERPROFILE ".codex"
$LogDir = Join-Path $CodexHome "logs"
$PidFile = Join-Path $CodexHome "remote-control-server.pid"
$JsFile = Join-Path $CodexHome "codex-remote-control-server.js"
$LogFile = Join-Path $LogDir "remote-control-server.log"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Get-HelperProcess {
    if (-not (Test-Path $PidFile)) { return $null }
    $pidText = (Get-Content -LiteralPath $PidFile -Raw).Trim()
    if (-not $pidText) { return $null }
    try { return Get-Process -Id ([int]$pidText) -ErrorAction Stop } catch { return $null }
}

if ($Stop) {
    $proc = Get-HelperProcess
    if ($proc) { Stop-Process -Id $proc.Id -Force }
    Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
    "stopped"
    exit 0
}

if ($Status) {
    $proc = Get-HelperProcess
    if ($proc) { "running pid=$($proc.Id) log=$LogFile" } else { "not running log=$LogFile" }
    if (Test-Path $LogFile) { Get-Content -LiteralPath $LogFile -Tail 20 -Encoding UTF8 }
    exit 0
}

$node = (Get-Command node -ErrorAction Stop).Source
if ($Background) {
    $proc = Start-Process -FilePath $node -ArgumentList @($JsFile) -WindowStyle Hidden -PassThru
    Set-Content -LiteralPath $PidFile -Value $proc.Id -Encoding ASCII
    "started pid=$($proc.Id) log=$LogFile"
    exit 0
}

& $node $JsFile
'@
[System.IO.File]::WriteAllText($PsFile, $Ps, [System.Text.UTF8Encoding]::new($false))

powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PsFile -Background
```

#### 5. 查看连接状态

运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\codex-remote-control-server.ps1" -Status
```

成功时你会看到类似：

```text
status=connected
serverName=DESKTOP-XXXXXXX
environmentId=env_e_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

如果短时间内先出现 `connecting` 或 `errored`，不要立刻判断失败。它可能会自动重试，最终变成 `connected`。

#### 6. 重启双端应用

配置完成后：

1. 关闭电脑端 Codex Desktop。
2. 重新打开电脑端 Codex Desktop。
3. 关闭 iPhone 上的 ChatGPT / Codex 相关页面或应用。
4. 重新打开 iPhone 端。
5. 在手机端重新选择这台电脑。

### 常见问题

#### `codex app-server daemon lifecycle is only supported on Unix platforms`

这是 Windows 上的正常限制。不要继续使用 daemon 命令。改用本教程里的保活脚本。

#### `status=connecting` 一直不变

检查网络是否能访问：

```text
https://chatgpt.com
```

也可以运行：

```powershell
codex doctor --summary
```

重点看 `Connectivity` 和 `websocket` 是否正常。

#### `duplicate key`

检查 `config.toml` 是否有多个 `[features]` 表，或者同一个 key 写了多次。保留一个 `[features]` 表即可。

#### `拒绝访问。 (os error 5)`

检查 `config.toml` 是否只读：

```powershell
$Config = Join-Path $env:USERPROFILE ".codex\config.toml"
Set-ItemProperty -LiteralPath $Config -Name IsReadOnly -Value $false
```

#### `Failed to locate git executable in PATH`

安装 Git for Windows：

```powershell
winget install --id Git.Git --exact --accept-package-agreements --accept-source-agreements --scope user
```

然后重启 Codex Desktop。

### 停止保活服务

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\codex-remote-control-server.ps1" -Stop
```

### 再次启动保活服务

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\codex-remote-control-server.ps1" -Background
```

---

## English Version

### Current Status

As of 2026-05-24, OpenAI's public release notes describe Codex mobile remote access as connecting the ChatGPT mobile app to Codex running on a **macOS host**. Windows can run Codex Desktop and Codex CLI, but reliable iPhone remote access to a Windows host is not currently documented as an officially supported stable path.

If Windows shows a local CLI app-server as `status=connected` while the phone still shows a red offline dot, that does not necessarily mean your setup is wrong. It usually means the experimental Windows app-server path is not being accepted by the mobile remote-access experience as a controllable host. For stable phone remote access, use the macOS Codex App.

Official references:

- [ChatGPT release notes: Codex remote access from the ChatGPT mobile app](https://help.openai.com/en/articles/6825453-chatgpt-release-notes)
- [ChatGPT Business release notes: Codex remote access and access tokens](https://help.openai.com/en/articles/11391654-chatgpt-business-release-notes)

### Goal

This guide documents the Windows troubleshooting path for Codex Desktop and Codex CLI remote-control experiments. It explains why Windows may report `status=connected` locally while the iPhone still shows the host as offline.

Use this when:

- The iPhone says it is connected, but the phone and desktop do not sync.
- Remote control appears enabled, but the iPhone cannot reliably see the Windows desktop.
- `config.toml` already contains `remote_control = true`, but the connection still does not work.
- Windows reports that `codex remote-control start` or `codex app-server daemon enable-remote-control` is unsupported.

The practical Windows fix is:

1. Enable remote connection features in `~\.codex\config.toml`.
2. Ensure `config.toml` is writable.
3. Install and verify Git for Windows, because Codex Desktop uses Git to identify workspace metadata.
4. Start a small Node.js helper that launches `codex app-server` and calls `remoteControl/enable`.
5. Verify that remote control reaches `status=connected`.

### How It Works

Codex remote control depends on these feature flags:

```toml
[features]
remote_connections = true
remote_control = true
```

On Windows, those flags alone may not be sufficient.

Common blockers:

1. **`config.toml` is read-only**

   Codex Desktop may need to update local connection or plugin state. If the config file is read-only, logs may show:

   ```text
   Access is denied. (os error 5)
   ```

2. **Duplicate TOML keys**

   Multiple `[features]` tables or duplicate keys can prevent app-server startup:

   ```text
   duplicate key
   Invalid TOML document
   ```

3. **Unix-only daemon commands**

   On Windows, these commands may fail:

   ```powershell
   codex remote-control start
   codex app-server daemon enable-remote-control
   ```

   The expected error is:

   ```text
   codex app-server daemon lifecycle is only supported on Unix platforms
   ```

   The Windows-compatible approach is to start:

   ```powershell
   codex app-server --listen stdio:// --enable remote_control
   ```

   Then send JSON-RPC calls:

   ```text
   remoteControl/status/read
   remoteControl/enable
   ```

### Prerequisites: Is Codex CLI Required?

Yes. This repository requires Codex CLI because the helper scripts call `codex app-server`. If someone says "Codex CML", they usually mean **Codex CLI**.

Prepare these first:

1. **Codex Desktop**: open it once and sign in, so `C:\Users\<your username>\.codex\config.toml` exists.
2. **Node.js LTS / npm**: required to install Codex CLI.
3. **Codex CLI**: provides the `codex app-server` command used by this repo.
4. **Git for Windows**: recommended, because Codex Desktop may need it for workspace metadata.

Install Codex CLI:

```powershell
npm install -g @openai/codex --registry=https://registry.npmmirror.com
codex --version
```

After `codex --version` prints a version number, run this repository's `setup.ps1`.

### One-Shot Prompt for Codex

Paste this guide into Codex and use this prompt:

```text
Please follow Codex_Windows_Connect_Your_iPhone.md and inspect my Windows Codex Desktop remote-connection status.

Requirements:
1. First check whether Windows host remote access is officially supported by the current Codex/ChatGPT mobile release.
2. Check and repair C:\Users\<username>\.codex\config.toml.
3. Ensure [features] contains remote_connections = true and remote_control = true.
4. Ensure config.toml is writable; back it up before editing.
5. Check whether git exists; if missing, install Git for Windows.
6. If running any experimental Windows helper, clearly state that local status=connected may still show as offline on mobile.
7. Prefer safe diagnostics over changing tokens or credentials.
8. Do not print auth.json, tokens, secrets, or login credentials.
```

### iPhone and Account Security Setup

Before configuring the Windows desktop side, prepare the iPhone app and secure the ChatGPT account. This step matters: Codex mobile can remotely manage tasks on your computer, so OpenAI may require stronger account protection before remote control works reliably.

#### 1. Prepare ChatGPT / Codex on iPhone

1. Install or update the ChatGPT app on your iPhone.
2. Sign in with the same OpenAI / ChatGPT account used by Codex Desktop on Windows.
3. Make sure the iPhone network can reach `chatgpt.com`; VPN, proxy, enterprise firewall, or DNS filtering can break WebSocket connectivity.
4. If the phone asks you to select a computer, wait until the Windows side reaches `status=connected`, then reopen the phone app and select the Windows machine again.

#### 2. Enable ChatGPT Multi-Factor Authentication (MFA)

When you start the desktop remote-control setup, the system may open the ChatGPT security page automatically. Go to:

```text
ChatGPT Settings -> Security -> Multi-factor authentication (MFA)
```

Use `Authenticator app` if possible. Recommended authenticator options include:

- 1Password
- Google Authenticator
- Microsoft Authenticator
- Authy

The usual flow is:

1. Open ChatGPT security settings.
2. Find `Multi-factor authentication (MFA)`.
3. Choose `Add another method to prevent lockout` or `Authenticator app`.
4. Scan the QR code with your authenticator app.
5. Enter the 6-digit code shown in the authenticator app.
6. Save the backup recovery codes so you can recover the account after changing or losing your phone.

Do not skip MFA. Without MFA, iPhone remote control can stall, repeatedly ask for verification, or appear connected while the desktop and phone do not actually sync.

#### 3. Recommended iPhone Connection Order

Use this order:

1. Enable ChatGPT MFA first.
2. Complete the Windows desktop setup in the next section.
3. Confirm that the desktop helper log shows:

   ```text
   status=connected
   ```

4. Fully close and reopen the ChatGPT app on iPhone.
5. Open the Codex / remote computer entry point on iPhone.
6. Select your Windows computer name, for example:

   ```text
   DESKTOP-XXXXXXX
   ```

7. If the phone still shows stale state, sign out and sign in again, or restart both Codex Desktop on Windows and the ChatGPT app on iPhone.

### Manual Setup

#### 1. Check Codex CLI

Open PowerShell:

```powershell
codex --version
codex doctor --summary
```

If `codex` is missing, install it:

```powershell
npm install -g @openai/codex --registry=https://registry.npmmirror.com
```

If `npm` is missing, install Node.js LTS first.

#### 2. Repair config.toml

The config path is usually:

```text
C:\Users\<your username>\.codex\config.toml
```

Locate it in PowerShell:

```powershell
$Config = Join-Path $env:USERPROFILE ".codex\config.toml"
$Config
```

Ensure there is exactly one `[features]` table:

```toml
[features]
remote_connections = true
remote_control = true
```

Make the file writable:

```powershell
$Config = Join-Path $env:USERPROFILE ".codex\config.toml"
Set-ItemProperty -LiteralPath $Config -Name IsReadOnly -Value $false
```

#### 3. Install Git for Windows

If Codex logs mention `Failed to locate git executable in PATH`, install Git:

```powershell
winget install --id Git.Git --exact --accept-package-agreements --accept-source-agreements --scope user
```

Verify:

```powershell
git --version
where.exe git
```

#### 4. Create the Remote-Control Keepalive Helper

Use the PowerShell setup script in the Chinese section above, or ask Codex to run it for you. It creates:

```text
C:\Users\<username>\.codex\codex-remote-control-server.js
C:\Users\<username>\.codex\codex-remote-control-server.ps1
C:\Users\<username>\.codex\logs\remote-control-server.log
```

The helper starts `codex app-server`, initializes it, checks remote-control status, and calls `remoteControl/enable` when needed.

#### 5. Check Status

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\codex-remote-control-server.ps1" -Status
```

Success looks like:

```text
status=connected
serverName=DESKTOP-XXXXXXX
environmentId=env_e_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Temporary `connecting` or `errored` states can happen during retry. The important final state is `connected`.

#### 6. Restart Both Apps

After setup:

1. Quit Codex Desktop on Windows.
2. Reopen Codex Desktop.
3. Quit the iPhone ChatGPT / Codex app view.
4. Reopen the iPhone app.
5. Select the Windows computer again.

### Troubleshooting

#### `codex app-server daemon lifecycle is only supported on Unix platforms`

This is expected on Windows. Use the helper script instead of daemon commands.

#### `status=connecting` never becomes `connected`

Check that you can reach:

```text
https://chatgpt.com
```

Run:

```powershell
codex doctor --summary
```

Look at `Connectivity` and `websocket`.

#### `duplicate key`

Remove duplicate `[features]` tables or repeated keys in `config.toml`.

#### `Access is denied. (os error 5)`

Make `config.toml` writable:

```powershell
$Config = Join-Path $env:USERPROFILE ".codex\config.toml"
Set-ItemProperty -LiteralPath $Config -Name IsReadOnly -Value $false
```

#### `Failed to locate git executable in PATH`

Install Git for Windows:

```powershell
winget install --id Git.Git --exact --accept-package-agreements --accept-source-agreements --scope user
```

Restart Codex Desktop afterward.

### Stop the Helper

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\codex-remote-control-server.ps1" -Stop
```

### Start the Helper Again

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\codex-remote-control-server.ps1" -Background
```

---

## Notes for Maintainers

This guide intentionally avoids printing or editing `auth.json`. Remote control should be enabled through feature flags and app-server JSON-RPC, not by manually changing tokens or credentials.

The successful target state is:

```text
remoteControl/status/read -> status=connected
```

If the status reaches `connected`, the desktop side is ready. If the iPhone still cannot connect, restart both the desktop and iPhone app, confirm both use the same OpenAI/ChatGPT account, and verify that corporate VPN, proxy, or firewall rules are not blocking `chatgpt.com` WebSocket traffic.
