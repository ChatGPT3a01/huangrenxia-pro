<#
.SYNOPSIS
  隨身黃仁蝦AI系統 — Windows 線上安裝腳本

.DESCRIPTION
  一行安裝：
  irm https://lobster.ai/install.ps1 | iex

  流程：偵測系統 → 下載 Node.js → npm install openclaw → 設定 → 產生啟動腳本

  作者: 曾慶良 主任（阿亮老師）
  聯絡: 3a01chatgpt@gmail.com
  © 2026 阿亮老師 版權所有
#>

$ErrorActionPreference = 'Stop'

$InstallDir = Join-Path $env:LOCALAPPDATA '隨身黃仁蝦AI系統'
$NodeVer = 'v22.16.0'
$NodeUrl = "https://nodejs.org/dist/$NodeVer/node-$NodeVer-win-x64.zip"

function Write-Step {
    param([string]$Number, [string]$Title)
    Write-Host ''
    Write-Host '  ' -NoNewline
    Write-Host " $Number " -ForegroundColor Black -BackgroundColor Cyan -NoNewline
    Write-Host "  $Title" -ForegroundColor White
}

Write-Host ''
Write-Host '  +----------------------------------------------------+' -ForegroundColor Cyan
Write-Host '  |          隨身黃仁蝦AI系統 — 線上安裝              |' -ForegroundColor Yellow
Write-Host '  +----------------------------------------------------+' -ForegroundColor Cyan
Write-Host ''
Write-Host "  安裝位置：$InstallDir" -ForegroundColor White
Write-Host '  作者：曾慶良 主任（阿亮老師）' -ForegroundColor DarkGray
Write-Host ''

# --- 1. Create directories ---
Write-Step '1/4' '建立目錄結構'

$dirs = @(
    $InstallDir
    (Join-Path $InstallDir 'app\core')
    (Join-Path $InstallDir 'app\runtime\node-win-x64')
    (Join-Path $InstallDir 'data\.openclaw')
    (Join-Path $InstallDir 'data\memory\journal')
    (Join-Path $InstallDir 'data\logs')
    (Join-Path $InstallDir 'skills\import')
    (Join-Path $InstallDir 'skills\installed')
    (Join-Path $InstallDir 'config-server\public')
)
foreach ($d in $dirs) {
    if (-not (Test-Path -LiteralPath $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
}
Write-Host '  目錄結構已建立。' -ForegroundColor Green

# --- 2. Download Node.js ---
Write-Step '2/4' '下載 Node.js'

$nodeExe = Join-Path $InstallDir 'app\runtime\node-win-x64\node.exe'
if (Test-Path -LiteralPath $nodeExe) {
    $ver = & $nodeExe --version
    Write-Host "  Node.js 已存在：$ver" -ForegroundColor Green
} else {
    Write-Host "  下載 Node.js $NodeVer..." -ForegroundColor Cyan
    $zipPath = Join-Path $env:TEMP 'node-win-x64.zip'

    Invoke-WebRequest -Uri $NodeUrl -OutFile $zipPath -UseBasicParsing

    Write-Host '  解壓中...' -ForegroundColor Cyan
    $extractDir = Join-Path $env:TEMP 'node-extract'
    if (Test-Path -LiteralPath $extractDir) { Remove-Item -Recurse -Force $extractDir }
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    $innerDir = Get-ChildItem -Path $extractDir -Directory | Select-Object -First 1
    Get-ChildItem -Path $innerDir.FullName | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $InstallDir 'app\runtime\node-win-x64') -Recurse -Force
    }

    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $extractDir -Recurse -Force -ErrorAction SilentlyContinue

    $ver = & $nodeExe --version
    Write-Host "  Node.js $ver 已安裝。" -ForegroundColor Green
}

# --- 3. Install OpenClaw ---
Write-Step '3/4' '安裝 OpenClaw'

$coreDir = Join-Path $InstallDir 'app\core'
$openclawMjs = Join-Path $coreDir 'node_modules\openclaw\openclaw.mjs'
$npmCmd = Join-Path $InstallDir 'app\runtime\node-win-x64\npm.cmd'

# Create package.json if missing
$pkgJson = Join-Path $coreDir 'package.json'
if (-not (Test-Path -LiteralPath $pkgJson)) {
    [System.IO.File]::WriteAllText($pkgJson, '{"name":"lobster-core","version":"1.0.0","private":true,"dependencies":{"openclaw":"latest"}}', [System.Text.UTF8Encoding]::new($false))
}

if (Test-Path -LiteralPath $openclawMjs) {
    Write-Host '  OpenClaw 已安裝。' -ForegroundColor Green
} else {
    Write-Host '  正在安裝 OpenClaw...' -ForegroundColor Cyan
    & $npmCmd install --prefix $coreDir 2>&1 | Out-Null
    if (Test-Path -LiteralPath $openclawMjs) {
        Write-Host '  OpenClaw 安裝完成。' -ForegroundColor Green
    } else {
        throw 'OpenClaw 安裝失敗。請確認網路連線後重試。'
    }
}

# --- 4. Create config & launcher ---
Write-Step '4/4' '產生配置與啟動腳本'

# Default config.env
$configEnv = Join-Path $InstallDir 'data\config.env'
if (-not (Test-Path -LiteralPath $configEnv)) {
    $configContent = @"
APP_NAME="隨身黃仁蝦AI系統"
INSTALL_MODE="installed"
ENGINE_TYPE="openclaw"
OPENCLAW_AUTH_TOKEN="lobster"
USB_LOCK_ENABLED="false"
FIRST_RUN_DONE="false"
ONBOARD_DONE="false"
"@
    [System.IO.File]::WriteAllText($configEnv, ([char]0xFEFF).ToString() + $configContent, [System.Text.UTF8Encoding]::new($true))
}

# Default openclaw.json
$openclawJson = Join-Path $InstallDir 'data\.openclaw\openclaw.json'
if (-not (Test-Path -LiteralPath $openclawJson)) {
    $jsonContent = '{"gateway":{"mode":"local","auth":{"token":"lobster"}},"commands":{"native":"auto","nativeSkills":"auto","restart":true,"ownerDisplay":"raw"}}'
    [System.IO.File]::WriteAllText($openclawJson, $jsonContent, [System.Text.UTF8Encoding]::new($false))
}

# Desktop shortcut
$desktopBat = Join-Path ([Environment]::GetFolderPath('Desktop')) '黃仁蝦AI-啟動.bat'
$nodeDir = Join-Path $InstallDir 'app\runtime\node-win-x64'
$batContent = @"
@echo off
set PATH=$nodeDir;%PATH%
set OPENCLAW_HOME=$InstallDir\data
set OPENCLAW_STATE_DIR=$InstallDir\data\.openclaw
set OPENCLAW_CONFIG_PATH=$InstallDir\data\.openclaw\openclaw.json
cd /d "$coreDir"
start "" "http://127.0.0.1:18789/#token=lobster"
"$nodeExe" "$openclawMjs" gateway run --allow-unconfigured --force --port 18789
pause
"@
[System.IO.File]::WriteAllLines($desktopBat, $batContent.Split("`n"), [System.Text.Encoding]::ASCII)

Write-Host ''
Write-Host '  +----------------------------------------------------+' -ForegroundColor Green
Write-Host '  |          安裝完成！                                |' -ForegroundColor Green
Write-Host '  +----------------------------------------------------+' -ForegroundColor Green
Write-Host ''
Write-Host "  安裝位置：$InstallDir" -ForegroundColor White
Write-Host '  桌面已建立捷徑「黃仁蝦AI-啟動」' -ForegroundColor White
Write-Host ''
Write-Host '  下一步：' -ForegroundColor Yellow
Write-Host '  1. 雙擊桌面的「黃仁蝦AI-啟動」' -ForegroundColor White
Write-Host '  2. 瀏覽器開啟後，開始使用 AI！' -ForegroundColor White
Write-Host ''
