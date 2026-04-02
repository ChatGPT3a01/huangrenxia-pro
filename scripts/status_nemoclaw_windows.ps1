. "$PSScriptRoot\common_windows.ps1"

Ensure-Config

Write-Host ''
Write-Host '  ═══ 系統狀態 ═══' -ForegroundColor Yellow
Write-Host ''

# Node.js
if (Test-NodeInstalled) {
    $nodeBin = Get-NodeBin
    $nodeVer = & $nodeBin --version
    Write-Host "    Node.js:    $nodeVer" -ForegroundColor Green
} else {
    Write-Host '    Node.js:    未安裝' -ForegroundColor Red
}

# OpenClaw
if (Test-OpenClawInstalled) {
    Write-Host '    OpenClaw:   已安裝' -ForegroundColor Green
} else {
    Write-Host '    OpenClaw:   未安裝' -ForegroundColor Red
}

# Gateway 狀態
$port = [string](Get-ConfigValue -Key 'OPENCLAW_PORT' -Default '18789')
if (Test-OpenClawGatewayRunning) {
    Write-Host "    Gateway:    運行中 (port $port)" -ForegroundColor Green
} else {
    Write-Host '    Gateway:    未啟動' -ForegroundColor DarkGray
}

# API Key 統計
$cfg = Get-Config
$keyChecks = @('OPENAI_API_KEY', 'ANTHROPIC_API_KEY', 'GEMINI_API_KEY',
               'DEEPSEEK_API_KEY', 'GROQ_API_KEY', 'QWEN_API_KEY',
               'OPENROUTER_API_KEY', 'MISTRAL_API_KEY', 'MINIMAX_API_KEY',
               'NVIDIA_API_KEY', 'MINIMAX_API_KEY')
$configuredCount = 0
foreach ($k in $keyChecks) {
    $v = [string](Get-HashtableValue -Table $cfg -Key $k -Default '')
    if ($v) { $configuredCount++ }
}
Write-Host "    API Keys:   $configuredCount 個已設定" -ForegroundColor Cyan

# 安裝模式
$installMode = [string](Get-HashtableValue -Table $cfg -Key 'INSTALL_MODE' -Default 'portable')
Write-Host "    安裝模式:   $installMode" -ForegroundColor White

# USB 狀態
$usbEnabled = [string](Get-HashtableValue -Table $cfg -Key 'USB_LOCK_ENABLED' -Default 'true')
if ($usbEnabled -eq 'true' -and $installMode -ne 'portable') {
    if (Test-UsbLockPresent) {
        Write-Host '    USB 鎖定:   已偵測到 USB' -ForegroundColor Green
    } else {
        Write-Host '    USB 鎖定:   未偵測到 USB' -ForegroundColor Yellow
    }
}

# 授權狀態
$licenseStatus = Get-LicenseStatus
$licenseLabel = switch ($licenseStatus.Type) {
    'perpetual' { '永久授權' }
    'subscription' { '訂閱制' }
    'trial' { '試用版' }
    default { $licenseStatus.Type }
}
if ($licenseStatus.DaysRemaining -ge 0 -and $licenseStatus.Type -ne 'perpetual') {
    $licenseLabel += " (剩 $($licenseStatus.DaysRemaining) 天)"
}
$licenseColor = if ($licenseStatus.IsValid) { 'Green' } else { 'Red' }
Write-Host "    授權狀態:   $licenseLabel" -ForegroundColor $licenseColor

# 技能數量
$installed = @(Get-InstalledSkills)
Write-Host "    已裝技能:   $($installed.Count) 個" -ForegroundColor White

Write-Host ''
