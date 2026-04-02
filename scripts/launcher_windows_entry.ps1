. "$PSScriptRoot\common_windows.ps1"

Ensure-Config
$config = Get-Config
$localInstallDir = [string](Get-HashtableValue -Table $config -Key 'LOCAL_INSTALL_DIR' -Default '')
$localLauncher = if ($localInstallDir) { Join-Path $localInstallDir 'scripts\launcher_windows_v2.ps1' } else { '' }

if ($localInstallDir -and (Test-Path -LiteralPath $localLauncher)) {
    # 已安裝本機版，啟動本機的 launcher
    & powershell -NoProfile -ExecutionPolicy Bypass -File $localLauncher
} else {
    # 尚未安裝，直接從 USB 啟動 launcher（可攜模式）
    Write-Host '尚未偵測到本機安裝版本，以可攜模式啟動。' -ForegroundColor Yellow
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'launcher_windows_v2.ps1')
}
