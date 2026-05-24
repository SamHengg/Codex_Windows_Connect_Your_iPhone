$ErrorActionPreference = "Stop"

$CodexHome = Join-Path $env:USERPROFILE ".codex"
$Config = Join-Path $CodexHome "config.toml"
$BackupDir = Join-Path $CodexHome "backups"
$LogDir = Join-Path $CodexHome "logs"

if (-not (Test-Path $Config)) {
    throw "Cannot find Codex config: $Config. Open Codex Desktop once, sign in, then rerun setup.ps1."
}

New-Item -ItemType Directory -Force -Path $BackupDir, $LogDir | Out-Null

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item -LiteralPath $Config -Destination (Join-Path $BackupDir "config.$Stamp.iphone-connect.backup.toml") -Force
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

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$JsSource = Join-Path $RepoRoot "scripts\codex-remote-control-server.js"
$PsSource = Join-Path $RepoRoot "scripts\codex-remote-control-server.ps1"
$JsTarget = Join-Path $CodexHome "codex-remote-control-server.js"
$PsTarget = Join-Path $CodexHome "codex-remote-control-server.ps1"

Copy-Item -LiteralPath $JsSource -Destination $JsTarget -Force
Copy-Item -LiteralPath $PsSource -Destination $PsTarget -Force

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js LTS and npm are required. Install Node.js LTS, then rerun setup.ps1."
}
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    throw "Codex CLI is required because this setup calls 'codex app-server'. Install with: npm install -g @openai/codex --registry=https://registry.npmmirror.com"
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warning "Git was not found in PATH. Install Git for Windows if Codex Desktop logs workspace metadata errors."
}

$TaskName = "Codex iPhone Remote Control Helper"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PsTarget`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Days 30)
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "Keeps Codex remote control connected for iPhone." -Force | Out-Null

Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 10
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PsTarget -Status
