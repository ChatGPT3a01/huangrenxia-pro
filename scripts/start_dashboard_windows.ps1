. "$PSScriptRoot\common_windows.ps1"

Write-Host ''
Write-Host '  正在啟動管理面板...' -ForegroundColor Cyan

$configServerDir = Join-Path $Script:BaseDir 'config-server'
$serverJs = Join-Path $configServerDir 'server.js'

if (-not (Test-Path -LiteralPath $serverJs)) {
    Write-Host '  找不到 config-server/server.js' -ForegroundColor Red
    Write-Host '  請確認系統檔案完整。' -ForegroundColor Yellow
    return
}

if (-not (Test-NodeInstalled)) {
    throw '找不到 Node.js runtime。'
}

$nodeBin = Get-NodeBin

# 設定環境變數
$env:OPENCLAW_CONFIG_PATH = $Script:OpenClawConfigFile
$env:LOBSTER_CONFIG_PATH = $Script:ConfigFile
$env:LOBSTER_DATA_DIR = $Script:DataDir

# 啟動 Config Server
Start-Process -FilePath $nodeBin -ArgumentList @($serverJs) -NoNewWindow
Start-Sleep -Seconds 2

Start-Process 'http://127.0.0.1:18788/'
Write-Host '  管理面板已啟動: http://127.0.0.1:18788' -ForegroundColor Green
Write-Host ''
