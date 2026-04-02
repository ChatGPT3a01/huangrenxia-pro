. "$PSScriptRoot\common_windows.ps1"

Ensure-Config
$config = Get-Config
Ensure-DeviceToken | Out-Null

$defaultDir = Join-Path $env:LOCALAPPDATA '隨身黃仁蝦AI系統-本機版'
$targetDir = Prompt-Input -Message '請輸入本機安裝位置' -Default ([string](Get-HashtableValue -Table $config -Key 'LOCAL_INSTALL_DIR' -Default $defaultDir))
if ([string]::IsNullOrWhiteSpace($targetDir)) {
    throw '未指定安裝位置。'
}

if (-not (Test-Path -LiteralPath $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir | Out-Null
}

Copy-Item -LiteralPath (Join-Path $Script:BaseDir '*') -Destination $targetDir -Recurse -Force

$targetConfig = Join-Path $targetDir 'data\config.env'
$lines = @(Get-Content -LiteralPath $targetConfig -Encoding UTF8)
$updates = @{
    INSTALL_MODE = 'installed'
    LOCAL_INSTALL_DIR = $targetDir
    USB_LOCK_ENABLED = 'true'
    DEVICE_TOKEN = [string](Get-ConfigValue -Key 'DEVICE_TOKEN')
    WINDOWS_MODE = 'wsl'
}
foreach ($pair in $updates.GetEnumerator()) {
    $serialized = '{0}="{1}"' -f $pair.Key, ([string]$pair.Value).Replace('\', '\\').Replace('"', '\"')
    $matched = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].StartsWith("$($pair.Key)=")) {
            $lines[$i] = $serialized
            $matched = $true
            break
        }
    }
    if (-not $matched) {
        $lines += $serialized
    }
}
Set-Content -LiteralPath $targetConfig -Value $lines -Encoding UTF8

$desktopBat = Join-Path ([Environment]::GetFolderPath('Desktop')) '黃仁蝦AI-本機版.bat'
$desktopLines = @(
    '@echo off'
    'set SCRIPT_DIR=%~dp0'
    ('powershell -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path $targetDir 'scripts\launcher_windows_v2.ps1'))
)
Set-Content -LiteralPath $desktopBat -Value $desktopLines -Encoding ASCII

Save-ConfigValue -Key 'LOCAL_INSTALL_DIR' -Value $targetDir
Write-Host "本機版安裝完成：$targetDir" -ForegroundColor Green
Write-Host "桌面已建立「黃仁蝦AI-本機版.bat」，之後啟動時仍需插著原始 USB。"
