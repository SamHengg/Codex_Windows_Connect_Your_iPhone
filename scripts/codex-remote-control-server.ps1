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
    $PidText = (Get-Content -LiteralPath $PidFile -Raw).Trim()
    if (-not $PidText) { return $null }
    try { return Get-Process -Id ([int]$PidText) -ErrorAction Stop } catch { return $null }
}

if ($Stop) {
    $Proc = Get-HelperProcess
    if ($Proc) { Stop-Process -Id $Proc.Id -Force }
    Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
    "stopped"
    exit 0
}

if ($Status) {
    $Proc = Get-HelperProcess
    if ($Proc) { "running pid=$($Proc.Id) log=$LogFile" } else { "not running log=$LogFile" }
    if (Test-Path $LogFile) { Get-Content -LiteralPath $LogFile -Tail 20 -Encoding UTF8 }
    exit 0
}

$Node = (Get-Command node -ErrorAction Stop).Source

if ($Background) {
    $Proc = Start-Process -FilePath $Node -ArgumentList @($JsFile) -WindowStyle Hidden -PassThru
    Set-Content -LiteralPath $PidFile -Value $Proc.Id -Encoding ASCII
    "started pid=$($Proc.Id) log=$LogFile"
    exit 0
}

& $Node $JsFile

