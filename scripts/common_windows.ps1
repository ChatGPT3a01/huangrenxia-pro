Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Script:BaseDir = Split-Path -Parent $PSScriptRoot
$Script:DataDir = Join-Path $Script:BaseDir 'data'
$Script:SkillsDir = Join-Path $Script:BaseDir 'skills'
$Script:SkillsImportDir = Join-Path $Script:SkillsDir 'import'
$Script:SkillsInstalledDir = Join-Path $Script:SkillsDir 'installed'
$Script:ConfigFile = Join-Path $Script:DataDir 'config.env'
$Script:ExampleConfig = Join-Path $Script:DataDir 'config.env.example'
$Script:LogDir = Join-Path $Script:DataDir 'logs'
$Script:MemoryDir = Join-Path $Script:DataDir 'memory'
$Script:JournalDir = Join-Path $Script:MemoryDir 'journal'
$Script:ExamplesDir = Join-Path $Script:BaseDir 'examples'
$Script:AppName = '隨身黃仁蝦AI系統'

# OpenClaw 路徑
$Script:AppDir = Join-Path $Script:BaseDir 'app'
$Script:CoreDir = Join-Path $Script:AppDir 'core'
$Script:RuntimeDir = Join-Path $Script:AppDir 'runtime'
$Script:NodeBin = Join-Path $Script:RuntimeDir 'node-win-x64\node.exe'
$Script:NpmCmd = Join-Path $Script:RuntimeDir 'node-win-x64\npm.cmd'
$Script:OpenClawMjs = Join-Path $Script:CoreDir 'node_modules\openclaw\openclaw.mjs'
$Script:OpenClawConfigDir = Join-Path $Script:DataDir '.openclaw'
$Script:OpenClawConfigFile = Join-Path $Script:OpenClawConfigDir 'openclaw.json'

foreach ($dir in @($Script:DataDir, $Script:LogDir, $Script:SkillsImportDir, $Script:SkillsInstalledDir, $Script:MemoryDir, $Script:JournalDir, $Script:OpenClawConfigDir)) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
}

function Ensure-Config {
    if (-not (Test-Path -LiteralPath $Script:ConfigFile)) {
        Copy-Item -LiteralPath $Script:ExampleConfig -Destination $Script:ConfigFile
    }
}

function ConvertFrom-ConfigValue {
    param([string]$Value)

    $trimmed = $Value.Trim()
    if ($trimmed.Length -eq 0) {
        return ''
    }

    try {
        return ConvertFrom-Json -InputObject $trimmed -ErrorAction Stop
    } catch {
        if ($trimmed.StartsWith('"') -and $trimmed.EndsWith('"')) {
            return $trimmed.Substring(1, $trimmed.Length - 2).Replace('\"', '"')
        }
        return $trimmed
    }
}

function Get-Config {
    Ensure-Config
    $config = @{}
    foreach ($line in Get-Content -LiteralPath $Script:ConfigFile -Encoding UTF8) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
            continue
        }

        $parts = $line -split '=', 2
        if ($parts.Count -ne 2) {
            continue
        }

        $config[$parts[0]] = ConvertFrom-ConfigValue -Value $parts[1]
    }
    return $config
}

function Get-ConfigFromFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $config = @{}
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
            continue
        }

        $parts = $line -split '=', 2
        if ($parts.Count -ne 2) {
            continue
        }

        $config[$parts[0]] = ConvertFrom-ConfigValue -Value $parts[1]
    }
    return $config
}

function Save-ConfigValue {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [AllowNull()][object]$Value
    )

    Ensure-Config
    $stringValue = if ($null -eq $Value) { '' } else { [string]$Value }
    $escaped = $stringValue.Replace('\', '\\').Replace('"', '\"')
    $serialized = '{0}="{1}"' -f $Key, $escaped

    $lines = @(Get-Content -LiteralPath $Script:ConfigFile -Encoding UTF8)
    $updated = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].StartsWith("$Key=")) {
            $lines[$i] = $serialized
            $updated = $true
            break
        }
    }

    if (-not $updated) {
        $lines += $serialized
    }

    Set-Content -LiteralPath $Script:ConfigFile -Value $lines -Encoding UTF8
}

function Save-MultilineConfigValue {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [AllowNull()][string]$Value
    )

    $jsonValue = ConvertTo-Json -InputObject $(if ($null -eq $Value) { '' } else { $Value }) -Compress
    Ensure-Config
    $lines = @(Get-Content -LiteralPath $Script:ConfigFile -Encoding UTF8)
    $updated = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].StartsWith("$Key=")) {
            $lines[$i] = '{0}={1}' -f $Key, $jsonValue
            $updated = $true
            break
        }
    }
    if (-not $updated) {
        $lines += '{0}={1}' -f $Key, $jsonValue
    }
    Set-Content -LiteralPath $Script:ConfigFile -Value $lines -Encoding UTF8
}

function Get-ConfigValue {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [AllowNull()][object]$Default = ''
    )

    $config = Get-Config
    if ($config.ContainsKey($Key)) {
        return $config[$Key]
    }
    return $Default
}

function Get-HashtableValue {
    param(
        [hashtable]$Table,
        [string]$Key,
        [AllowNull()][object]$Default = ''
    )

    if ($null -ne $Table -and $Table.ContainsKey($Key) -and $null -ne $Table[$Key]) {
        return $Table[$Key]
    }
    return $Default
}

function Ensure-DeviceToken {
    $token = [string](Get-ConfigValue -Key 'DEVICE_TOKEN')
    if (-not [string]::IsNullOrWhiteSpace($token)) {
        return $token
    }

    $token = [guid]::NewGuid().ToString().ToLowerInvariant()
    Save-ConfigValue -Key 'DEVICE_TOKEN' -Value $token
    return $token
}

# ===== OpenClaw 環境函式 =====

function Test-NodeInstalled {
    return (Test-Path -LiteralPath $Script:NodeBin)
}

function Test-OpenClawInstalled {
    return (Test-Path -LiteralPath $Script:OpenClawMjs)
}

function Get-NodeBin {
    if (Test-Path -LiteralPath $Script:NodeBin) {
        return $Script:NodeBin
    }
    $sysNode = Get-Command node -ErrorAction SilentlyContinue
    if ($sysNode) {
        $ver = & $sysNode.Source --version 2>$null
        if ($ver -match '^v(\d+)' -and [int]$matches[1] -ge 20) {
            return $sysNode.Source
        }
    }
    throw '找不到 Node.js 執行環境。請確認 app\runtime\node-win-x64\ 完整。'
}

function Write-OpenClawConfig {
    $config = Get-Config
    $token = [string](Get-HashtableValue -Table $config -Key 'OPENCLAW_AUTH_TOKEN' -Default 'lobster')

    $openclawConfig = [ordered]@{
        gateway = [ordered]@{
            mode = 'local'
            auth = [ordered]@{ token = $token }
        }
        commands = [ordered]@{
            native = 'auto'
            nativeSkills = 'auto'
            restart = $true
            ownerDisplay = 'raw'
        }
    }

    # 建立 model providers
    $providers = [ordered]@{}

    $providerMap = [ordered]@{
        OPENAI_API_KEY    = @{ name = 'openai';    baseUrl = 'https://api.openai.com/v1';           model = 'gpt-4o' }
        ANTHROPIC_API_KEY = @{ name = 'anthropic';  baseUrl = 'https://api.anthropic.com/v1';        model = 'claude-sonnet-4-20250514' }
        GEMINI_API_KEY    = @{ name = 'gemini';     baseUrl = 'https://generativelanguage.googleapis.com/v1beta'; model = 'gemini-2.5-flash' }
        DEEPSEEK_API_KEY  = @{ name = 'deepseek';   baseUrl = 'https://api.deepseek.com/v1';        model = 'deepseek-chat' }
        GROQ_API_KEY      = @{ name = 'groq';       baseUrl = 'https://api.groq.com/openai/v1';     model = 'llama-3.3-70b-versatile' }
        QWEN_API_KEY      = @{ name = 'qwen';       baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1'; model = 'qwen-plus' }
        OPENROUTER_API_KEY = @{ name = 'openrouter'; baseUrl = 'https://openrouter.ai/api/v1';      model = 'auto' }
        MISTRAL_API_KEY   = @{ name = 'mistral';    baseUrl = 'https://api.mistral.ai/v1';          model = 'mistral-large-latest' }
        MINIMAX_API_KEY   = @{ name = 'minimax';    baseUrl = 'https://api.minimax.chat/v1';        model = 'MiniMax-Text-01' }
    }

    $firstModel = $null
    foreach ($entry in $providerMap.GetEnumerator()) {
        $apiKey = [string](Get-HashtableValue -Table $config -Key $entry.Key -Default '')
        if ($apiKey) {
            $info = $entry.Value
            $providers[$info.name] = [ordered]@{
                baseUrl = $info.baseUrl
                apiKey  = $apiKey
                api     = 'openai-completions'
                models  = @(
                    [ordered]@{
                        id            = $info.model
                        name          = $info.model
                        contextWindow = 128000
                        maxTokens     = 8192
                    }
                )
            }
            if (-not $firstModel) {
                $firstModel = '{0}/{1}' -f $info.name, $info.model
            }
        }
    }

    # Ollama 本地模型
    $ollamaUrl = [string](Get-HashtableValue -Table $config -Key 'OLLAMA_BASE_URL' -Default '')
    if ($ollamaUrl) {
        $providers['ollama'] = [ordered]@{
            baseUrl = $ollamaUrl
            apiKey  = 'ollama'
            api     = 'openai-completions'
            models  = @(
                [ordered]@{ id = 'llama3.1'; name = 'llama3.1'; contextWindow = 128000; maxTokens = 4096 }
            )
        }
        if (-not $firstModel) { $firstModel = 'ollama/llama3.1' }
    }

    if ($providers.Count -gt 0) {
        $openclawConfig['models'] = [ordered]@{
            mode      = 'merge'
            providers = $providers
        }
        $openclawConfig['agents'] = [ordered]@{
            defaults = [ordered]@{
                model = [ordered]@{ primary = $firstModel }
            }
        }
    }

    $json = ConvertTo-Json -InputObject $openclawConfig -Depth 10
    if (-not (Test-Path -LiteralPath $Script:OpenClawConfigDir)) {
        New-Item -ItemType Directory -Path $Script:OpenClawConfigDir -Force | Out-Null
    }
    Set-Content -LiteralPath $Script:OpenClawConfigFile -Value $json -Encoding UTF8
}

function Find-AvailablePort {
    param([int]$Start = 18789, [int]$End = 18799)
    $listeners = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()
    $usedPorts = @($listeners | ForEach-Object { $_.Port })
    for ($port = $Start; $port -le $End; $port++) {
        if ($port -notin $usedPorts) {
            return $port
        }
    }
    throw '找不到可用的通訊埠 (18789-18799)。請關閉佔用埠號的程式後再試。'
}

function Set-OpenClawEnvVars {
    $env:OPENCLAW_HOME = $Script:DataDir
    $env:OPENCLAW_STATE_DIR = $Script:OpenClawConfigDir
    $env:OPENCLAW_CONFIG_PATH = $Script:OpenClawConfigFile

    $config = Get-Config
    $apiKeys = @(
        'OPENAI_API_KEY', 'NVIDIA_API_KEY', 'ANTHROPIC_API_KEY',
        'GEMINI_API_KEY', 'QWEN_API_KEY', 'DEEPSEEK_API_KEY',
        'GROQ_API_KEY', 'OPENROUTER_API_KEY', 'MISTRAL_API_KEY',
        'MINIMAX_API_KEY', 'OLLAMA_BASE_URL'
    )
    foreach ($key in $apiKeys) {
        $val = [string](Get-HashtableValue -Table $config -Key $key -Default '')
        if ($val) {
            [Environment]::SetEnvironmentVariable($key, $val, 'Process')
        }
    }
}

function Start-OpenClawGateway {
    param([int]$Port)
    $nodeBin = Get-NodeBin
    Set-OpenClawEnvVars
    Write-OpenClawConfig

    $proc = Start-Process -FilePath $nodeBin -ArgumentList @(
        $Script:OpenClawMjs, 'gateway', 'run',
        '--allow-unconfigured', '--force', '--port', $Port
    ) -PassThru -NoNewWindow
    Save-ConfigValue -Key 'OPENCLAW_PORT' -Value $Port
    Save-ConfigValue -Key 'OPENCLAW_PID' -Value $proc.Id
    return $proc
}

function Stop-OpenClawGateway {
    $pid = [string](Get-ConfigValue -Key 'OPENCLAW_PID' -Default '')
    if ($pid) {
        try {
            Stop-Process -Id ([int]$pid) -Force -ErrorAction SilentlyContinue
        } catch { }
        Save-ConfigValue -Key 'OPENCLAW_PID' -Value ''
    }
}

function Test-OpenClawGatewayRunning {
    $port = [string](Get-ConfigValue -Key 'OPENCLAW_PORT' -Default '18789')
    try {
        $null = Invoke-WebRequest -Uri "http://127.0.0.1:$port/" -TimeoutSec 2 -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Wait-OpenClawReady {
    param([int]$Port, [int]$TimeoutSeconds = 15)
    for ($i = 0; $i -lt ($TimeoutSeconds * 2); $i++) {
        Start-Sleep -Milliseconds 500
        try {
            $null = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/" -TimeoutSec 2 -ErrorAction Stop
            return $true
        } catch { }
    }
    return $false
}

function Prompt-Input {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$Default = ''
    )

    if ($Default) {
        $value = Read-Host "$Message [$Default]"
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $Default
        }
        return $value.Trim()
    }

    return (Read-Host $Message).Trim()
}

function Prompt-Secret {
    param([Parameter(Mandatory = $true)][string]$Message)
    $secure = Read-Host $Message -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function Confirm-Choice {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [bool]$DefaultYes = $false
    )

    $suffix = if ($DefaultYes) { '[Y/n]' } else { '[y/N]' }
    $reply = Read-Host "$Message $suffix"
    if ([string]::IsNullOrWhiteSpace($reply)) {
        return $DefaultYes
    }
    return $reply -match '^[Yy]'
}

function Assert-MasterPassword {
    $expected = [string](Get-ConfigValue -Key 'MASTER_PASSWORD' -Default '')
    if ([string]::IsNullOrWhiteSpace($expected)) {
        throw '尚未設定終極密碼，請先完成第一次使用設定。'
    }
    $entered = Prompt-Secret -Message '請輸入終極密碼'
    if ($entered -ne $expected) {
        throw '終極密碼錯誤。'
    }
}

function Find-UsbLockDir {
    $config = Get-Config
    $token = [string](Get-HashtableValue -Table $config -Key 'DEVICE_TOKEN' -Default '')
    $enabled = [string](Get-HashtableValue -Table $config -Key 'USB_LOCK_ENABLED' -Default 'true')
    if (-not $token -or $enabled -ne 'true') {
        return $null
    }

    $drives = [System.IO.DriveInfo]::GetDrives() | Where-Object {
        $_.IsReady -and $_.DriveType -in @([System.IO.DriveType]::Removable, [System.IO.DriveType]::Fixed)
    }

    foreach ($drive in $drives) {
        $rootsToCheck = @(
            $drive.RootDirectory.FullName,
            (Join-Path $drive.RootDirectory.FullName '隨身黃仁蝦AI系統')
        )

        foreach ($candidate in $rootsToCheck) {
            $candidateConfig = Join-Path $candidate 'data\config.env'
            if (-not (Test-Path -LiteralPath $candidateConfig)) {
                continue
            }
            $candidateData = Get-ConfigFromFile -Path $candidateConfig
            if ([string](Get-HashtableValue -Table $candidateData -Key 'DEVICE_TOKEN' -Default '') -eq $token) {
                return $candidate
            }
        }
    }
    return $null
}

function Assert-UsbLock {
    $config = Get-Config
    $installMode = [string](Get-HashtableValue -Table $config -Key 'INSTALL_MODE' -Default 'portable')
    $enabled = [string](Get-HashtableValue -Table $config -Key 'USB_LOCK_ENABLED' -Default 'true')
    if ($installMode -eq 'portable' -or $enabled -ne 'true') {
        return
    }
    if (-not (Find-UsbLockDir)) {
        throw '未偵測到授權 USB。請插入原始的「隨身黃仁蝦AI系統」隨身碟後再啟動。'
    }
}

function Test-UsbLockPresent {
    return $null -ne (Find-UsbLockDir)
}

# ===== 商業安全機制 =====

function Get-DeviceTokenHmac {
    param([string]$Token)
    $secretKey = 'lobster-ai-hmac-2026-v2'
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($secretKey)
    $hash = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Token))
    return [Convert]::ToBase64String($hash)
}

function Ensure-DeviceTokenIntegrity {
    $config = Get-Config
    $token = [string](Get-HashtableValue -Table $config -Key 'DEVICE_TOKEN' -Default '')
    if (-not $token) { return }

    $storedHmac = [string](Get-HashtableValue -Table $config -Key 'DEVICE_TOKEN_HMAC' -Default '')
    $expectedHmac = Get-DeviceTokenHmac -Token $token

    if ($storedHmac -and $storedHmac -ne $expectedHmac) {
        throw '系統偵測到 DEVICE_TOKEN 被竄改。此為安全違規，系統拒絕啟動。'
    }

    if (-not $storedHmac) {
        Save-ConfigValue -Key 'DEVICE_TOKEN_HMAC' -Value $expectedHmac
    }
}

function Get-EncryptionKey {
    param([string]$DeviceToken, [string]$MasterPassword)
    $material = '{0}:{1}:lobster-aes-2026' -f $DeviceToken, $MasterPassword
    $sha = [System.Security.Cryptography.SHA256]::Create()
    return $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($material))
}

function Protect-SensitiveValue {
    param(
        [Parameter(Mandatory = $true)][string]$PlainText,
        [Parameter(Mandatory = $true)][byte[]]$Key
    )
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $Key
    $aes.GenerateIV()
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

    $encryptor = $aes.CreateEncryptor()
    $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
    $encrypted = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)

    $combined = New-Object byte[] ($aes.IV.Length + $encrypted.Length)
    [Array]::Copy($aes.IV, 0, $combined, 0, $aes.IV.Length)
    [Array]::Copy($encrypted, 0, $combined, $aes.IV.Length, $encrypted.Length)

    $aes.Dispose()
    return 'ENC:' + [Convert]::ToBase64String($combined)
}

function Unprotect-SensitiveValue {
    param(
        [Parameter(Mandatory = $true)][string]$CipherText,
        [Parameter(Mandatory = $true)][byte[]]$Key
    )
    if (-not $CipherText.StartsWith('ENC:')) {
        return $CipherText
    }

    $data = [Convert]::FromBase64String($CipherText.Substring(4))
    $iv = $data[0..15]
    $encrypted = $data[16..($data.Length - 1)]

    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $Key
    $aes.IV = $iv
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

    $decryptor = $aes.CreateDecryptor()
    $decrypted = $decryptor.TransformFinalBlock($encrypted, 0, $encrypted.Length)

    $aes.Dispose()
    return [System.Text.Encoding]::UTF8.GetString($decrypted)
}

# ── 續約碼機制（遠端續約，一次性使用）────────────────────
# 續約碼格式：RENEW-<Base64(email|license_type|expires_at|nonce|hmac)>
# nonce = 時間戳，確保每次產生的碼都不同
# 用過的碼的 SHA256 hash 存在 USED_RENEWAL_CODES，防止重放
# HMAC key = 'lobster-renew-2026-v2'
$script:RenewalHmacKey = 'lobster-renew-2026-v2'

function New-RenewalCode {
    param(
        [Parameter(Mandatory)][string]$Email,
        [Parameter(Mandatory)][string]$LicenseType,
        [string]$ExpiresAt = ''
    )
    # nonce = 時間戳，讓同樣參數產生不同碼
    $nonce = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
    $payload = "$Email|$LicenseType|$ExpiresAt|$nonce"
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($script:RenewalHmacKey)
    $hash = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($payload))
    $sig = [Convert]::ToBase64String($hash).Substring(0, 16)

    $full = "$payload|$sig"
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($full))
    return "RENEW-$encoded"
}

function Get-CodeFingerprint {
    param([Parameter(Mandatory)][string]$Code)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Code))
    return [Convert]::ToBase64String($bytes).Substring(0, 12)
}

function Test-RenewalCode {
    param([Parameter(Mandatory)][string]$Code)
    try {
        if (-not $Code.StartsWith('RENEW-')) { return $null }
        $b64 = $Code.Substring(6)
        $decoded = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
        $parts = $decoded -split '\|'
        if ($parts.Count -lt 5) { return $null }

        $email = $parts[0]
        $licenseType = $parts[1]
        $expiresAt = $parts[2]
        $nonce = $parts[3]
        $sig = $parts[4]

        # Verify HMAC
        $payload = "$email|$licenseType|$expiresAt|$nonce"
        $hmac = New-Object System.Security.Cryptography.HMACSHA256
        $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($script:RenewalHmacKey)
        $hash = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($payload))
        $expectedSig = [Convert]::ToBase64String($hash).Substring(0, 16)

        if ($sig -ne $expectedSig) { return $null }

        return @{
            Email       = $email
            LicenseType = $licenseType
            ExpiresAt   = $expiresAt
        }
    } catch {
        return $null
    }
}

function Apply-RenewalCode {
    param([Parameter(Mandatory)][string]$Code)
    $info = Test-RenewalCode -Code $Code
    if (-not $info) {
        throw '續約碼無效。請確認是否輸入正確，或聯絡賣家重新產生。'
    }

    # Check if code already used (anti-replay)
    $fingerprint = Get-CodeFingerprint -Code $Code
    $config = Get-Config
    $usedCodes = [string](Get-HashtableValue -Table $config -Key 'USED_RENEWAL_CODES' -Default '')
    if ($usedCodes -and ($usedCodes -split ',') -contains $fingerprint) {
        throw '此續約碼已使用過，無法重複使用。請聯絡賣家取得新的續約碼。'
    }

    # Verify email matches
    $boundEmail = [string](Get-HashtableValue -Table $config -Key 'BOUND_EMAIL' -Default '')
    if ($boundEmail -and $info.Email -and ($info.Email.ToLower() -ne $boundEmail.ToLower())) {
        throw '續約碼的 Email 與此裝置綁定的帳號不符。'
    }

    # Apply license
    Save-ConfigValue -Key 'LICENSE_TYPE' -Value $info.LicenseType
    if ($info.ExpiresAt) {
        Save-ConfigValue -Key 'LICENSE_EXPIRES_AT' -Value $info.ExpiresAt
    } elseif ($info.LicenseType -eq 'perpetual') {
        Save-ConfigValue -Key 'LICENSE_EXPIRES_AT' -Value ''
    }

    # Mark code as used (store fingerprint)
    if ($usedCodes) {
        $newUsed = "$usedCodes,$fingerprint"
    } else {
        $newUsed = $fingerprint
    }
    Save-ConfigValue -Key 'USED_RENEWAL_CODES' -Value $newUsed

    return $info
}

function Assert-LicenseValid {
    $config = Get-Config
    $licenseType = [string](Get-HashtableValue -Table $config -Key 'LICENSE_TYPE' -Default 'perpetual')

    if ($licenseType -eq 'perpetual') { return }

    $expiresAt = [string](Get-HashtableValue -Table $config -Key 'LICENSE_EXPIRES_AT' -Default '')
    if (-not $expiresAt) { return }

    try {
        $expiryDate = [datetime]::ParseExact($expiresAt, 'yyyy-MM-dd', $null)
        if ([datetime]::Now -gt $expiryDate) {
            Write-Host ''
            Write-Host "  授權已於 $expiresAt 到期。" -ForegroundColor Red
            Write-Host '  如已續約，請輸入續約碼；或聯絡 3a01chatgpt@gmail.com' -ForegroundColor Yellow
            Write-Host ''
            $code = Prompt-Input -Message '  續約碼（無則直接按 Enter 離開）'
            if ($code) {
                $info = Apply-RenewalCode -Code $code
                $typeLabel = switch ($info.LicenseType) {
                    'perpetual' { '永久授權' }
                    'subscription' { '訂閱制' }
                    'trial' { '試用版' }
                    default { $info.LicenseType }
                }
                Write-Host ''
                Write-Host "  續約成功！授權類型：$typeLabel" -ForegroundColor Green
                if ($info.ExpiresAt) {
                    Write-Host "  新到期日：$($info.ExpiresAt)" -ForegroundColor Cyan
                }
                Write-Host ''
                return
            }
            throw ('授權已到期。請聯絡 3a01chatgpt@gmail.com 取得續約碼。')
        }
    } catch [System.FormatException] {
        throw '授權日期格式錯誤。請聯絡技術支援。'
    }
}

function Get-LicenseStatus {
    $config = Get-Config
    $licenseType = [string](Get-HashtableValue -Table $config -Key 'LICENSE_TYPE' -Default 'perpetual')
    $expiresAt = [string](Get-HashtableValue -Table $config -Key 'LICENSE_EXPIRES_AT' -Default '')

    $status = [ordered]@{
        Type = $licenseType
        ExpiresAt = $expiresAt
        IsValid = $true
        DaysRemaining = -1
    }

    if ($licenseType -ne 'perpetual' -and $expiresAt) {
        try {
            $expiryDate = [datetime]::ParseExact($expiresAt, 'yyyy-MM-dd', $null)
            $remaining = ($expiryDate - [datetime]::Now).Days
            $status['DaysRemaining'] = $remaining
            $status['IsValid'] = $remaining -ge 0
        } catch {
            $status['IsValid'] = $false
        }
    }

    return $status
}

function Write-CustomerProfile {
    $config = Get-Config
    $lineStat = if ([string](Get-HashtableValue -Table $config -Key 'LINE_CHANNEL_ID' -Default '')) { 'Y' } else { 'N' }
    $tgStat = if ([string](Get-HashtableValue -Table $config -Key 'TELEGRAM_BOT_TOKEN' -Default '')) { 'Y' } else { 'N' }
    $dcStat = if ([string](Get-HashtableValue -Table $config -Key 'DISCORD_BOT_TOKEN' -Default '')) { 'Y' } else { 'N' }
    $waStat = [string](Get-HashtableValue -Table $config -Key 'WHATSAPP_ENABLED' -Default 'false')
    $lines = @(
        '綁定帳號：{0}' -f ([string](Get-HashtableValue -Table $config -Key 'BOUND_EMAIL' -Default (Get-HashtableValue -Table $config -Key 'OWNER_EMAIL' -Default '未設定')))
        '安裝模式：{0}' -f ([string](Get-HashtableValue -Table $config -Key 'INSTALL_MODE' -Default 'portable'))
        '主要需求：{0}' -f ([string](Get-HashtableValue -Table $config -Key 'CUSTOMER_USE_CASE' -Default ''))
        ('通訊頻道：LINE={0}, Telegram={1}, Discord={2}, WhatsApp={3}' -f $lineStat, $tgStat, $dcStat, $waStat)
        '需求備註：{0}' -f ([string](Get-HashtableValue -Table $config -Key 'REQUIREMENTS_NOTES' -Default ''))
    )
    Set-Content -LiteralPath (Join-Path $Script:DataDir 'customer_profile.txt') -Value $lines -Encoding UTF8
}

function Start-UsbHeartbeat {
    param([int]$IntervalMinutes = 10)

    $config = Get-Config
    $token = [string](Get-HashtableValue -Table $config -Key 'DEVICE_TOKEN' -Default '')
    $enabled = [string](Get-HashtableValue -Table $config -Key 'USB_LOCK_ENABLED' -Default 'true')
    $installMode = [string](Get-HashtableValue -Table $config -Key 'INSTALL_MODE' -Default 'portable')

    if ($installMode -eq 'portable' -or $enabled -ne 'true' -or -not $token) {
        return $null
    }

    $heartbeatScript = Join-Path $PSScriptRoot 'usb_heartbeat_windows.ps1'
    $job = Start-Job -FilePath $heartbeatScript -ArgumentList @($token, $IntervalMinutes)
    return $job
}

function Stop-UsbHeartbeat {
    param($Job)
    if ($null -ne $Job) {
        Stop-Job -Job $Job -ErrorAction SilentlyContinue
        Remove-Job -Job $Job -Force -ErrorAction SilentlyContinue
    }
}

# ===== 白名單驗證系統 =====

function Get-Whitelist {
    $wlPath = Join-Path $Script:DataDir 'whitelist.json'
    if (-not (Test-Path -LiteralPath $wlPath)) {
        return @{}
    }
    $json = Get-Content -LiteralPath $wlPath -Encoding UTF8 -Raw
    return ConvertFrom-Json $json
}

function Test-WhitelistEmail {
    param([Parameter(Mandatory)][string]$Email)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Email.Trim().ToLowerInvariant())
    $hash = $sha.ComputeHash($bytes)
    $sha.Dispose()
    $hexHash = ($hash | ForEach-Object { $_.ToString('x2') }) -join ''

    $whitelist = Get-Whitelist
    if ($whitelist.PSObject.Properties.Name -contains $hexHash) {
        return $whitelist.$hexHash
    }
    return $null
}

function Invoke-CustomerActivation {
    Write-Host ''
    Write-Host '  +----------------------------------------------------+' -ForegroundColor Cyan
    Write-Host '  |' -ForegroundColor Cyan -NoNewline
    Write-Host '              帳 號 啟 動                        ' -ForegroundColor Yellow -NoNewline
    Write-Host '|' -ForegroundColor Cyan
    Write-Host '  +----------------------------------------------------+' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '    請輸入您購買時登記的 Email 進行啟動' -ForegroundColor White
    Write-Host ''

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $email = (Read-Host '    您的 Email').Trim()
        if ([string]::IsNullOrWhiteSpace($email)) {
            Write-Host '    未輸入 Email。' -ForegroundColor Red
            continue
        }

        $customerName = Test-WhitelistEmail -Email $email
        if ($null -ne $customerName) {
            Write-Host ''
            Write-Host "    歡迎，$customerName！" -ForegroundColor Green
            Write-Host '    正在啟動您的授權...' -ForegroundColor Cyan

            # 綁定此裝置
            Save-ConfigValue -Key 'BOUND_EMAIL' -Value $email.Trim().ToLowerInvariant()
            $deviceToken = Ensure-DeviceToken
            $hmac = Get-DeviceTokenHmac -Token $deviceToken
            Save-ConfigValue -Key 'DEVICE_TOKEN_HMAC' -Value $hmac
            Save-ConfigValue -Key 'DEVICE_READY' -Value 'true'

            Write-Host "    啟動完成！此裝置已綁定到 $email" -ForegroundColor Green
            Write-Host ''
            return $true
        }

        $remaining = 3 - $attempt
        if ($remaining -gt 0) {
            Write-Host "    此 Email 未在授權名單中。還可嘗試 $remaining 次。" -ForegroundColor Red
        }
    }

    Write-Host ''
    Write-Host '    啟動失敗：Email 不在授權名單中。' -ForegroundColor Red
    Write-Host '    請確認您使用購買時登記的 Email。' -ForegroundColor Yellow
    Write-Host '    如有疑問請聯絡：3a01chatgpt@gmail.com' -ForegroundColor White
    Write-Host ''
    return $false
}

# ===== 技能管理系統 =====

function Get-InstalledSkills {
    $skills = @()
    if (-not (Test-Path -LiteralPath $Script:SkillsInstalledDir)) { return $skills }
    foreach ($dir in Get-ChildItem -LiteralPath $Script:SkillsInstalledDir -Directory) {
        $skillMd = Join-Path $dir.FullName 'SKILL.md'
        if (Test-Path -LiteralPath $skillMd) {
            $info = Read-SkillMeta -Path $skillMd
            $info['path'] = $dir.FullName
            $info['folder'] = $dir.Name
            $skills += $info
        }
    }
    return $skills
}

function Get-ImportableSkills {
    $items = @()
    if (-not (Test-Path -LiteralPath $Script:SkillsImportDir)) { return $items }
    foreach ($file in Get-ChildItem -LiteralPath $Script:SkillsImportDir -Filter '*.zip') {
        $items += @{ type = 'zip'; name = $file.BaseName; path = $file.FullName }
    }
    foreach ($dir in Get-ChildItem -LiteralPath $Script:SkillsImportDir -Directory) {
        $skillMd = Join-Path $dir.FullName 'SKILL.md'
        if (Test-Path -LiteralPath $skillMd) {
            $items += @{ type = 'dir'; name = $dir.Name; path = $dir.FullName }
        }
    }
    return $items
}

function Read-SkillMeta {
    param([Parameter(Mandatory = $true)][string]$Path)
    $meta = @{ name = ''; description = ''; version = ''; author = '' }
    $inFrontMatter = $false
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8 -TotalCount 20) {
        if ($line.Trim() -eq '---') {
            if ($inFrontMatter) { break }
            $inFrontMatter = $true
            continue
        }
        if ($inFrontMatter -and $line -match '^\s*(\w+)\s*:\s*(.+)$') {
            $meta[$matches[1].ToLowerInvariant()] = $matches[2].Trim()
        }
    }
    if (-not $meta['name']) {
        $meta['name'] = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    }
    return $meta
}

function Install-Skill {
    param([Parameter(Mandatory = $true)][hashtable]$Item)
    $targetDir = Join-Path $Script:SkillsInstalledDir $Item['name']
    if (Test-Path -LiteralPath $targetDir) {
        throw ('技能 "{0}" 已安裝。如需重裝，請先移除。' -f $Item['name'])
    }
    if ($Item['type'] -eq 'zip') {
        Expand-Archive -LiteralPath $Item['path'] -DestinationPath $targetDir -Force
        $subDirs = Get-ChildItem -LiteralPath $targetDir -Directory
        if ($subDirs.Count -eq 1 -and (Test-Path -LiteralPath (Join-Path $subDirs[0].FullName 'SKILL.md'))) {
            $innerDir = $subDirs[0].FullName
            Get-ChildItem -LiteralPath $innerDir -Force | Move-Item -Destination $targetDir -Force
            Remove-Item -LiteralPath $innerDir -Force
        }
    } elseif ($Item['type'] -eq 'dir') {
        Copy-Item -LiteralPath $Item['path'] -Destination $targetDir -Recurse -Force
    }
    if (-not (Test-Path -LiteralPath (Join-Path $targetDir 'SKILL.md'))) {
        Remove-Item -LiteralPath $targetDir -Recurse -Force -ErrorAction SilentlyContinue
        throw ('安裝失敗：解壓後找不到 SKILL.md')
    }
}

function Remove-Skill {
    param([Parameter(Mandatory = $true)][string]$FolderName)
    $targetDir = Join-Path $Script:SkillsInstalledDir $FolderName
    if (-not (Test-Path -LiteralPath $targetDir)) {
        throw ('找不到技能：{0}' -f $FolderName)
    }
    Remove-Item -LiteralPath $targetDir -Recurse -Force
}

function Show-SkillManager {
    while ($true) {
        $installed = @(Get-InstalledSkills)
        $importable = @(Get-ImportableSkills)

        Write-Host ''
        Write-Host '  ═══ 技能管理 ═══' -ForegroundColor Yellow
        Write-Host ''
        Write-Host ('    已安裝：{0} 個技能' -f $installed.Count) -ForegroundColor Cyan
        Write-Host ('    可匯入：{0} 個技能包（skills\import\ 資料夾）' -f $importable.Count) -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '    [1] 查看已安裝技能' -ForegroundColor Green
        Write-Host '    [2] 安裝新技能（從 import 資料夾）' -ForegroundColor Cyan
        Write-Host '    [3] 移除技能' -ForegroundColor Red
        Write-Host '    [4] 從 ClawHub 安裝技能' -ForegroundColor Magenta
        Write-Host '    [5] 返回主選單' -ForegroundColor DarkGray
        Write-Host ''

        $choice = Read-Host '    請選擇 [1-5]'
        switch ($choice) {
            '1' {
                if ($installed.Count -eq 0) {
                    Write-Host '    尚未安裝任何技能。' -ForegroundColor Yellow
                } else {
                    Write-Host ''
                    for ($i = 0; $i -lt $installed.Count; $i++) {
                        $s = $installed[$i]
                        Write-Host ('    [{0}] {1}' -f ($i + 1), $s['name']) -ForegroundColor White
                        if ($s['description']) {
                            Write-Host ('        {0}' -f $s['description']) -ForegroundColor DarkGray
                        }
                        if ($s['version']) {
                            Write-Host ('        版本：{0}  作者：{1}' -f $s['version'], $s['author']) -ForegroundColor DarkGray
                        }
                    }
                }
                Write-Host ''
                Read-Host '    按 Enter 繼續'
            }
            '2' {
                if ($importable.Count -eq 0) {
                    Write-Host '    skills\import\ 資料夾中沒有可安裝的技能包。' -ForegroundColor Yellow
                    Write-Host '    請將 .zip 技能包或技能資料夾放入該目錄。' -ForegroundColor DarkGray
                } else {
                    Write-Host ''
                    for ($i = 0; $i -lt $importable.Count; $i++) {
                        Write-Host ('    [{0}] {1} ({2})' -f ($i + 1), $importable[$i]['name'], $importable[$i]['type']) -ForegroundColor Cyan
                    }
                    Write-Host ''
                    $sel = Read-Host '    輸入編號安裝（0 取消）'
                    $idx = 0
                    if ([int]::TryParse($sel, [ref]$idx) -and $idx -ge 1 -and $idx -le $importable.Count) {
                        try {
                            Install-Skill -Item $importable[$idx - 1]
                            Write-Host ('    技能 "{0}" 安裝成功！' -f $importable[$idx - 1]['name']) -ForegroundColor Green
                        } catch {
                            Write-Host ('    安裝失敗：{0}' -f $_.Exception.Message) -ForegroundColor Red
                        }
                    }
                }
                Write-Host ''
                Read-Host '    按 Enter 繼續'
            }
            '3' {
                if ($installed.Count -eq 0) {
                    Write-Host '    沒有已安裝的技能可移除。' -ForegroundColor Yellow
                } else {
                    Write-Host ''
                    for ($i = 0; $i -lt $installed.Count; $i++) {
                        Write-Host ('    [{0}] {1}' -f ($i + 1), $installed[$i]['name']) -ForegroundColor Red
                    }
                    Write-Host ''
                    $sel = Read-Host '    輸入編號移除（0 取消）'
                    $idx = 0
                    if ([int]::TryParse($sel, [ref]$idx) -and $idx -ge 1 -and $idx -le $installed.Count) {
                        $skillName = $installed[$idx - 1]['folder']
                        if (Confirm-Choice -Message ('    確定要移除技能 "{0}"？' -f $skillName)) {
                            try {
                                Remove-Skill -FolderName $skillName
                                Write-Host ('    技能 "{0}" 已移除。' -f $skillName) -ForegroundColor Green
                            } catch {
                                Write-Host ('    移除失敗：{0}' -f $_.Exception.Message) -ForegroundColor Red
                            }
                        }
                    }
                }
                Write-Host ''
                Read-Host '    按 Enter 繼續'
            }
            '4' {
                Write-Host ''
                Write-Host '  ═══ ClawHub 技能市集 ═══' -ForegroundColor Magenta
                Write-Host ''
                Write-Host '    ClawHub 是 OpenClaw 官方技能市場。' -ForegroundColor White
                Write-Host '    瀏覽: https://clawhub.ai/skills?sort=downloads' -ForegroundColor Cyan
                Write-Host ''
                $skillName = Prompt-Input -Message '    輸入技能名稱（例: translation）'
                if ($skillName) {
                    Write-Host ''
                    Write-Host "    正在從 ClawHub 安裝 $skillName..." -ForegroundColor Cyan
                    try {
                        $nodeBin = Get-NodeBin
                        $npmCmd = $Script:NpmCmd
                        $npxCmd = Join-Path (Split-Path $npmCmd) 'npx.cmd'
                        & $npxCmd clawhub@latest install $skillName 2>&1 | ForEach-Object {
                            Write-Host "    $_" -ForegroundColor DarkGray
                        }
                        Write-Host "    安裝完成！" -ForegroundColor Green
                    } catch {
                        Write-Host "    安裝失敗：$($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                Write-Host ''
                Read-Host '    按 Enter 繼續'
            }
            '5' { return }
            default { Write-Host '    請輸入 1 到 5。' -ForegroundColor Yellow }
        }
    }
}

# ===== 持久記憶系統 =====

function Ensure-MemoryFile {
    $memFile = Join-Path $Script:MemoryDir 'MEMORY.md'
    if (-not (Test-Path -LiteralPath $memFile)) {
        $initContent = @(
            '# 隨身黃仁蝦AI — 長期記憶'
            ''
            '## 使用者資訊'
            '（系統會在互動過程中自動記錄您的偏好）'
            ''
            '## 常用指令'
            ''
            '## 備忘錄'
            ''
        )
        Set-Content -LiteralPath $memFile -Value $initContent -Encoding UTF8
    }
}

function Get-MemorySummary {
    Ensure-MemoryFile
    $memFile = Join-Path $Script:MemoryDir 'MEMORY.md'
    return Get-Content -LiteralPath $memFile -Encoding UTF8 -Raw
}

function Append-JournalEntry {
    param([Parameter(Mandatory = $true)][string]$Entry)
    $today = Get-Date -Format 'yyyy-MM-dd'
    $journalFile = Join-Path $Script:JournalDir ('{0}.md' -f $today)
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $line = '- [{0}] {1}' -f $timestamp, $Entry
    if (-not (Test-Path -LiteralPath $journalFile)) {
        Set-Content -LiteralPath $journalFile -Value @("# 日誌 $today", '', $line) -Encoding UTF8
    } else {
        Add-Content -LiteralPath $journalFile -Value $line -Encoding UTF8
    }
}

# ===== 使用案例瀏覽 =====

function Show-ExampleBrowser {
    if (-not (Test-Path -LiteralPath $Script:ExamplesDir)) {
        Write-Host '    使用案例資料夾不存在。' -ForegroundColor Yellow
        return
    }
    $categories = @(Get-ChildItem -LiteralPath $Script:ExamplesDir -Directory | Sort-Object Name)
    if ($categories.Count -eq 0) {
        Write-Host '    尚無使用案例。' -ForegroundColor Yellow
        return
    }

    while ($true) {
        Write-Host ''
        Write-Host '  ═══ 使用案例庫 ═══' -ForegroundColor Yellow
        Write-Host ''
        for ($i = 0; $i -lt $categories.Count; $i++) {
            $catName = $categories[$i].Name
            $exCount = @(Get-ChildItem -LiteralPath $categories[$i].FullName -Filter '*.md').Count
            Write-Host ('    [{0}] {1}（{2} 個範例）' -f ($i + 1), $catName, $exCount) -ForegroundColor Cyan
        }
        Write-Host ''
        Write-Host ('    [0] 返回') -ForegroundColor DarkGray
        Write-Host ''
        $sel = Read-Host '    選擇分類'
        if ($sel -eq '0') { return }
        $idx = 0
        if (-not ([int]::TryParse($sel, [ref]$idx)) -or $idx -lt 1 -or $idx -gt $categories.Count) {
            continue
        }
        $catDir = $categories[$idx - 1].FullName
        $examples = @(Get-ChildItem -LiteralPath $catDir -Filter '*.md' | Sort-Object Name)
        if ($examples.Count -eq 0) {
            Write-Host '    此分類尚無範例。' -ForegroundColor Yellow
            Read-Host '    按 Enter 繼續'
            continue
        }

        while ($true) {
            Write-Host ''
            Write-Host ('  ─── {0} ───' -f $categories[$idx - 1].Name) -ForegroundColor Cyan
            Write-Host ''
            for ($j = 0; $j -lt $examples.Count; $j++) {
                $title = $examples[$j].BaseName -replace '^\d+-', ''
                Write-Host ('    [{0}] {1}' -f ($j + 1), $title) -ForegroundColor White
            }
            Write-Host ''
            Write-Host '    [0] 返回分類選單' -ForegroundColor DarkGray
            Write-Host ''
            $exSel = Read-Host '    選擇範例'
            if ($exSel -eq '0') { break }
            $exIdx = 0
            if ([int]::TryParse($exSel, [ref]$exIdx) -and $exIdx -ge 1 -and $exIdx -le $examples.Count) {
                Write-Host ''
                $content = Get-Content -LiteralPath $examples[$exIdx - 1].FullName -Encoding UTF8
                foreach ($line in $content) {
                    if ($line.StartsWith('# ')) {
                        Write-Host ('  {0}' -f $line.Substring(2)) -ForegroundColor Yellow
                    } elseif ($line.StartsWith('## ')) {
                        Write-Host ('  {0}' -f $line.Substring(3)) -ForegroundColor Cyan
                    } elseif ($line.StartsWith('> ')) {
                        Write-Host ('    {0}' -f $line.Substring(2)) -ForegroundColor Green
                    } else {
                        Write-Host ('    {0}' -f $line)
                    }
                }
                Write-Host ''
                Read-Host '    按 Enter 繼續'
            }
        }
    }
}
