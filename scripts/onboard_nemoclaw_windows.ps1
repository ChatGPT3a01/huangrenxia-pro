. "$PSScriptRoot\common_windows.ps1"

Ensure-Config

Write-Host ""
Write-Host "  ═══ 初始化 OpenClaw ═══" -ForegroundColor Yellow
Write-Host ""

# 檢查 Node.js
if (-not (Test-NodeInstalled)) {
    throw '找不到 Node.js runtime。請確認 app\runtime\node-win-x64\ 完整。'
}

$nodeBin = Get-NodeBin
$nodeVer = & $nodeBin --version
Write-Host "  Node.js: $nodeVer" -ForegroundColor Green

# 檢查 / 安裝 OpenClaw
if (-not (Test-OpenClawInstalled)) {
    Write-Host "  正在安裝 OpenClaw 依賴..." -ForegroundColor Cyan
    & $Script:NpmCmd install --prefix $Script:CoreDir 2>&1 | Out-Null
    if (-not (Test-OpenClawInstalled)) {
        throw 'OpenClaw 安裝失敗。請確認網路連線後重試。'
    }
    Write-Host "  OpenClaw 安裝完成。" -ForegroundColor Green
} else {
    Write-Host "  OpenClaw: 已安裝" -ForegroundColor Green
}

# 產生預設配置
Write-OpenClawConfig
Write-Host "  OpenClaw 配置已同步。" -ForegroundColor Green

Save-ConfigValue -Key 'ONBOARD_DONE' -Value 'true'
Save-ConfigValue -Key 'ENGINE_TYPE' -Value 'openclaw'

Write-Host ""
Write-Host "  初始化完成！現在可以從主選單啟動 AI 助手。" -ForegroundColor Green
Write-Host ""
