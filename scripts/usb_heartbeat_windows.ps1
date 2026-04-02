param(
    [Parameter(Mandatory = $true)][string]$DeviceToken,
    [int]$IntervalMinutes = 10
)

Add-Type -AssemblyName System.Windows.Forms

function Test-UsbPresent {
    param([string]$Token)

    $drives = [System.IO.DriveInfo]::GetDrives() | Where-Object {
        $_.IsReady -and $_.DriveType -in @([System.IO.DriveType]::Removable, [System.IO.DriveType]::Fixed)
    }

    foreach ($drive in $drives) {
        $rootsToCheck = @(
            $drive.RootDirectory.FullName,
            [System.IO.Path]::Combine($drive.RootDirectory.FullName, '隨身黃仁蝦AI系統')
        )

        foreach ($candidate in $rootsToCheck) {
            $candidateConfig = [System.IO.Path]::Combine($candidate, 'data', 'config.env')
            if (-not [System.IO.File]::Exists($candidateConfig)) {
                continue
            }
            try {
                $lines = [System.IO.File]::ReadAllLines($candidateConfig, [System.Text.Encoding]::UTF8)
                foreach ($line in $lines) {
                    if ($line.StartsWith('DEVICE_TOKEN=')) {
                        $value = $line.Substring('DEVICE_TOKEN='.Length).Trim().Trim('"')
                        if ($value -eq $Token) {
                            return $true
                        }
                    }
                }
            } catch {
                continue
            }
        }
    }
    return $false
}

$timer = New-Object System.Timers.Timer
$timer.Interval = $IntervalMinutes * 60 * 1000
$timer.AutoReset = $true

Register-ObjectEvent -InputObject $timer -EventName Elapsed -MessageData $DeviceToken -Action {
    if (-not (Test-UsbPresent -Token $Event.MessageData)) {
        [System.Windows.Forms.MessageBox]::Show(
            "隨身黃仁蝦AI需要讀取關鍵設定檔以繼續執行，`n請插入隨身黃仁蝦AI USB",
            '隨身黃仁蝦AI系統',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
    }
} | Out-Null

$timer.Start()

while ($true) {
    Start-Sleep -Seconds 60
}
