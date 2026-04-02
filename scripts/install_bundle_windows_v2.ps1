. "$PSScriptRoot\common_windows.ps1"

Write-Host "=== 隨身黃仁蝦AI系統 安裝到本機 ===" -ForegroundColor Cyan
Write-Host ""

Ensure-Config
$deviceToken = Ensure-DeviceToken

# 檢查 Node.js runtime
if (-not (Test-NodeInstalled)) {
    throw "找不到 Node.js runtime。請確認 app\runtime\node-win-x64\ 目錄完整。"
}

$nodeBin = Get-NodeBin
$nodeVer = & $nodeBin --version
Write-Host "  Node.js: $nodeVer" -ForegroundColor Green

# 檢查 OpenClaw
if (-not (Test-OpenClawInstalled)) {
    Write-Host "  正在安裝 OpenClaw 依賴..." -ForegroundColor Cyan
    $npmCmd = $Script:NpmCmd
    & $npmCmd install --prefix $Script:CoreDir 2>&1 | Out-Null
    if (-not (Test-OpenClawInstalled)) {
        throw "OpenClaw 安裝失敗。請確認網路連線後重試。"
    }
}
Write-Host "  OpenClaw: 已就緒" -ForegroundColor Green

# 複製到本機
$targetDir = Join-Path $env:LOCALAPPDATA '隨身黃仁蝦AI系統-本機版'
Write-Host ""
Write-Host "  安裝位置：$targetDir" -ForegroundColor White
Write-Host "  正在複製檔案..." -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir | Out-Null
}

Get-ChildItem -LiteralPath $Script:BaseDir -Force | Where-Object {
    $_.Name -notin @('System Volume Information', '$RECYCLE.BIN', '.git')
} | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $targetDir -Recurse -Force
}

# 更新本機版 config.env
$targetConfigPath = Join-Path $targetDir 'data\config.env'
$targetConfigText = [System.IO.File]::ReadAllText($targetConfigPath)
$updates = @{
    INSTALL_MODE      = 'installed'
    LOCAL_INSTALL_DIR = $targetDir
    USB_LOCK_ENABLED  = 'true'
    DEVICE_TOKEN      = $deviceToken
    ENGINE_TYPE       = 'openclaw'
}

foreach ($pair in $updates.GetEnumerator()) {
    $serialized = '{0}="{1}"' -f $pair.Key, ([string]$pair.Value).Replace('\', '\\').Replace('"', '\"')
    if ($targetConfigText -match ("(?m)^" + [regex]::Escape($pair.Key) + "=")) {
        $targetConfigText = [regex]::Replace($targetConfigText, ("(?m)^" + [regex]::Escape($pair.Key) + "=.*$"), $serialized)
    } else {
        $targetConfigText += [Environment]::NewLine + $serialized
    }
}

[System.IO.File]::WriteAllText($targetConfigPath, $targetConfigText, (New-Object System.Text.UTF8Encoding($true)))

# 同步 USB 上的 config
Save-ConfigValue -Key 'LOCAL_INSTALL_DIR' -Value $targetDir
Save-ConfigValue -Key 'ENGINE_TYPE' -Value 'openclaw'

# 初始化 OpenClaw 配置
Write-OpenClawConfig

# 確保本機版目錄結構完整
$targetMemoryDir = Join-Path $targetDir 'data\memory'
$targetJournalDir = Join-Path $targetMemoryDir 'journal'
$targetOpenClawDir = Join-Path $targetDir 'data\.openclaw'
foreach ($d in @($targetMemoryDir, $targetJournalDir, $targetOpenClawDir)) {
    if (-not (Test-Path -LiteralPath $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
}

# 建立桌面捷徑
$desktopBat = Join-Path ([Environment]::GetFolderPath('Desktop')) '黃仁蝦AI-本機版.bat'
$launcherPath = Join-Path $targetDir 'scripts\launcher_windows_v2.ps1'
$desktopLines = @(
    '@echo off'
    ('powershell -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $launcherPath)
)
[System.IO.File]::WriteAllLines($desktopBat, $desktopLines, (New-Object System.Text.ASCIIEncoding))

Write-Host ""
Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║          安裝完成！                  ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host ('  本機位置：{0}' -f $targetDir) -ForegroundColor White
Write-Host "  桌面已建立捷徑「黃仁蝦AI-本機版」" -ForegroundColor White
Write-Host ""
Write-Host "  ┌─ 下一步 ─────────────────────────────┐" -ForegroundColor Yellow
Write-Host "  │                                       │" -ForegroundColor Yellow
Write-Host "  │  請回到隨身碟資料夾，雙擊：           │" -ForegroundColor Yellow
Write-Host "  │  「點這個啟動-隨身黃仁蝦AI-Windows.bat」│" -ForegroundColor Yellow
Write-Host "  │                                       │" -ForegroundColor Yellow
Write-Host "  │  首次啟動會引導你設定密碼和 API Key   │" -ForegroundColor Yellow
Write-Host "  │                                       │" -ForegroundColor Yellow
Write-Host "  └───────────────────────────────────────┘" -ForegroundColor Yellow
Write-Host ""
