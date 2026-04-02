# =============================================================================
# uninstall_windows.ps1 — 一鍵卸載（客戶用）
# 隨身黃仁蝦AI系統 v2.0 | 作者：曾慶良 主任（阿亮老師）
# =============================================================================
$ErrorActionPreference = 'Stop'

Write-Host ''
Write-Host '  ╔══════════════════════════════════════╗' -ForegroundColor Yellow
Write-Host '  ║     隨身黃仁蝦AI — 卸載工具         ║' -ForegroundColor Yellow
Write-Host '  ╚══════════════════════════════════════╝' -ForegroundColor Yellow
Write-Host ''

$installDir = Join-Path $env:LOCALAPPDATA '隨身黃仁蝦AI系統-本機版'
$desktopBat = Join-Path ([Environment]::GetFolderPath('Desktop')) '黃仁蝦AI-本機版.bat'

$hasInstall = Test-Path -LiteralPath $installDir
$hasShortcut = Test-Path -LiteralPath $desktopBat

if (-not $hasInstall -and -not $hasShortcut) {
    Write-Host '  未偵測到已安裝的資料，無需卸載。' -ForegroundColor Green
    Write-Host ''
    Read-Host '  按 Enter 離開'
    exit 0
}

Write-Host '  將移除以下項目：' -ForegroundColor White
if ($hasInstall) {
    $size = [math]::Round((Get-ChildItem -Path $installDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 1)
    Write-Host "    [1] 本機資料夾：$installDir ($size MB)" -ForegroundColor Cyan
}
if ($hasShortcut) {
    Write-Host "    [2] 桌面捷徑：黃仁蝦AI-本機版.bat" -ForegroundColor Cyan
}

Write-Host ''
$confirm = Read-Host '  確認卸載？(Y/N)'
if ($confirm -notmatch '^[Yy]') {
    Write-Host '  已取消卸載。' -ForegroundColor Yellow
    Read-Host '  按 Enter 離開'
    exit 0
}

Write-Host ''
if ($hasInstall) {
    Write-Host '  正在刪除本機資料夾...' -ForegroundColor Cyan
    Remove-Item -LiteralPath $installDir -Recurse -Force
    Write-Host '    已刪除' -ForegroundColor Green
}

if ($hasShortcut) {
    Write-Host '  正在刪除桌面捷徑...' -ForegroundColor Cyan
    Remove-Item -LiteralPath $desktopBat -Force
    Write-Host '    已刪除' -ForegroundColor Green
}

Write-Host ''
Write-Host '  ╔══════════════════════════════════════╗' -ForegroundColor Green
Write-Host '  ║          卸載完成！                  ║' -ForegroundColor Green
Write-Host '  ╚══════════════════════════════════════╝' -ForegroundColor Green
Write-Host ''
Write-Host '  隨身碟上的檔案不受影響，可以安全拔出。' -ForegroundColor White
Write-Host '  如需重新安裝，請再次執行「一鍵安裝」即可。' -ForegroundColor White
Write-Host ''
Read-Host '  按 Enter 離開'
