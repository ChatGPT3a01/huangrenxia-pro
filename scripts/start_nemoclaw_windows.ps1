. "$PSScriptRoot\common_windows.ps1"

Ensure-Config
Assert-UsbLock

# 檢查 OpenClaw
if (-not (Test-OpenClawInstalled)) {
    throw '找不到 OpenClaw。請先執行安裝。'
}

# 同步配置
Write-OpenClawConfig

# 找可用 port
$port = Find-AvailablePort
Write-Host ""
Write-Host "  正在啟動 OpenClaw (port $port)..." -ForegroundColor Cyan

# 啟動 Gateway
$proc = Start-OpenClawGateway -Port $port

# 等待就緒
$ready = Wait-OpenClawReady -Port $port -TimeoutSeconds 15

if ($ready) {
    Start-Process "http://127.0.0.1:${port}/#token=lobster"
    Write-Host "  OpenClaw 已啟動: http://127.0.0.1:$port" -ForegroundColor Green
    Write-Host "  瀏覽器已開啟。" -ForegroundColor White
} else {
    Write-Host "  OpenClaw 已啟動，但 Gateway 尚未回應。" -ForegroundColor Yellow
    Write-Host "  請稍候數秒後手動開啟：http://127.0.0.1:$port/#token=lobster" -ForegroundColor Yellow
}

Write-Host ""
