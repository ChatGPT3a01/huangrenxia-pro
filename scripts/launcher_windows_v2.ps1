. "$PSScriptRoot\common_windows.ps1"

$AppVersion = 'Windows Key Edition v2.0'
$AuthorName = '曾慶良 主任（阿亮老師）'
$AuthorContact = '3a01chatgpt@gmail.com'

# ===== UI 工具函式 =====

function Write-Divider {
    param([ConsoleColor]$Color = 'DarkGray', [string]$Char = '-', [int]$Width = 54)
    Write-Host ('  ' + ($Char * $Width)) -ForegroundColor $Color
}

function Write-SectionTitle {
    param([string]$Title, [ConsoleColor]$Color = 'Cyan')
    Write-Host ''
    Write-Divider -Color DarkCyan -Char '='
    Write-Host "    $Title" -ForegroundColor $Color
    Write-Divider -Color DarkCyan -Char '='
    Write-Host ''
}

function Write-FieldHint {
    param([string]$Label, [string]$Hint, [ConsoleColor]$LabelColor = 'Yellow', [ConsoleColor]$HintColor = 'DarkGray')
    Write-Host "    $Label " -ForegroundColor $LabelColor -NoNewline
    Write-Host $Hint -ForegroundColor $HintColor
}

function Write-StepNumber {
    param([string]$Number, [string]$Title)
    Write-Host ''
    Write-Host '    ' -NoNewline
    Write-Host " $Number " -ForegroundColor Black -BackgroundColor Cyan -NoNewline
    Write-Host "  $Title" -ForegroundColor White
    Write-Host ''
}

# ===== 核心功能 =====

function Prompt-NewMasterPassword {
    while ($true) {
        $first = Prompt-Secret -Message '    密碼'
        if ([string]::IsNullOrWhiteSpace($first)) {
            Write-Host '    密碼不能空白。' -ForegroundColor Red
            continue
        }

        $second = Prompt-Secret -Message '    再輸入一次'
        if ($first -ne $second) {
            Write-Host '    兩次不一致，請重新設定。' -ForegroundColor Red
            continue
        }

        return $first
    }
}

function Run-FirstRunWizard {
    $config = Get-Config
    if ([string](Get-HashtableValue -Table $config -Key 'FIRST_RUN_DONE' -Default 'false') -eq 'true') {
        return
    }

    # 若尚未綁定，先跑啟動流程
    if ([string]::IsNullOrWhiteSpace([string](Get-HashtableValue -Table $config -Key 'BOUND_EMAIL' -Default ''))) {
        $activated = Invoke-CustomerActivation
        if (-not $activated) {
            throw '啟動失敗，系統無法使用。'
        }
    }

    Clear-Host
    Write-Host ''
    Write-Host '  +----------------------------------------------------+' -ForegroundColor Magenta
    Write-Host '  |                                                    |' -ForegroundColor Magenta
    Write-Host '  |' -ForegroundColor Magenta -NoNewline
    Write-Host '             首 次 使 用 設 定                  ' -ForegroundColor White -NoNewline
    Write-Host '|' -ForegroundColor Magenta
    Write-Host '  |                                                    |' -ForegroundColor Magenta
    Write-Host '  +----------------------------------------------------+' -ForegroundColor Magenta
    Write-Host ''
    Write-Host '    沒有的欄位直接按 ' -ForegroundColor DarkGray -NoNewline
    Write-Host 'Enter' -ForegroundColor White -NoNewline
    Write-Host ' 略過，之後可從主選單修改' -ForegroundColor DarkGray

    # --- 1. 密碼 ---
    Write-StepNumber '1/5' '設定終極密碼'
    $masterPassword = Prompt-NewMasterPassword

    # --- 2. AI 金鑰 ---
    Write-StepNumber '2/5' 'AI 服務金鑰'
    Write-Host ''
    Write-Host '    +-- 費用參考 ----------------------------------------+' -ForegroundColor DarkYellow
    Write-Host '    | Qwen         1000次對話 ~60 台幣（最便宜）         |' -ForegroundColor DarkGray
    Write-Host '    | Groq         免費（有速率限制）                    |' -ForegroundColor DarkGray
    Write-Host '    | DeepSeek     極低價，比 OpenAI 便宜 10 倍         |' -ForegroundColor DarkGray
    Write-Host '    | OpenRouter   一個 Key 用遍所有模型                |' -ForegroundColor DarkGray
    Write-Host '    | MiniMax      中國大模型，語音/影片生成強         |' -ForegroundColor DarkGray
    Write-Host '    +---------------------------------------------------+' -ForegroundColor DarkYellow
    Write-Host ''

    Write-FieldHint 'Groq' '(免費快速)  申請: console.groq.com' -LabelColor Yellow -HintColor DarkGray
    $groqKey = Prompt-Input -Message '    Key'
    Write-Host ''
    Write-FieldHint 'DeepSeek' '(極低價)  申請: platform.deepseek.com' -LabelColor Yellow -HintColor DarkGray
    $deepseekKey = Prompt-Input -Message '    Key'
    Write-Host ''
    Write-FieldHint 'Qwen' '(推薦最便宜)  申請: bailian.console.aliyun.com' -LabelColor Yellow -HintColor DarkGray
    $qwenKey = Prompt-Input -Message '    Key'
    Write-Host ''
    Write-FieldHint 'OpenAI' '(可略過)  申請: platform.openai.com/api-keys' -LabelColor Green
    $openaiKey = Prompt-Input -Message '    Key'
    Write-Host ''
    Write-FieldHint 'Anthropic' '(可略過)  申請: console.anthropic.com' -LabelColor Green
    $anthropicKey = Prompt-Input -Message '    Key'
    Write-Host ''
    Write-FieldHint 'Gemini' '(可略過)  申請: aistudio.google.com/apikey' -LabelColor Green
    $geminiKey = Prompt-Input -Message '    Key'
    Write-Host ''
    Write-FieldHint 'OpenRouter' '(一Key多模型)  申請: openrouter.ai' -LabelColor Green -HintColor DarkGray
    $openrouterKey = Prompt-Input -Message '    Key'
    Write-Host ''
    Write-FieldHint 'Mistral' '(可略過)  申請: console.mistral.ai' -LabelColor Green -HintColor DarkGray
    $mistralKey = Prompt-Input -Message '    Key'
    Write-Host ''
    Write-FieldHint 'MiniMax' '(語音/影片生成)  申請: platform.minimaxi.com' -LabelColor Green -HintColor DarkGray
    $minimaxKey = Prompt-Input -Message '    Key'
    Write-Host ''
    Write-FieldHint 'Ollama' '(本地模型，不需Key)  安裝: ollama.ai' -LabelColor Green -HintColor DarkGray
    $ollamaUrl = Prompt-Input -Message '    Base URL (例: http://localhost:11434)'

    # --- 3. 通訊頻道 ---
    Write-StepNumber '3/5' '通訊頻道（不需要的直接略過）'

    Write-Host '   ' -NoNewline
    Write-Host ' LINE ' -ForegroundColor Black -BackgroundColor Green
    Write-FieldHint '申請位置' 'developers.line.biz' -LabelColor Cyan
    $lineChannelId = Prompt-Input -Message '    Channel ID'
    $lineChannelSecret = Prompt-Input -Message '    Channel Secret'
    $lineAccessToken = Prompt-Input -Message '    Access Token'
    Write-Host ''

    Write-Host '   ' -NoNewline
    Write-Host ' Telegram ' -ForegroundColor White -BackgroundColor Blue
    Write-FieldHint '設定方式' '在 Telegram 搜尋 @BotFather，發送 /newbot' -LabelColor Cyan
    $telegramBotToken = Prompt-Input -Message '    Bot Token'
    $telegramUsers = Prompt-Input -Message '    允許的 User ID（逗號分隔，搜尋 @userinfobot 取得）'
    Write-Host ''

    Write-Host '   ' -NoNewline
    Write-Host ' Discord ' -ForegroundColor White -BackgroundColor DarkMagenta
    Write-FieldHint '設定方式' 'discord.com/developers 建立 App + Bot' -LabelColor Cyan
    $discordBotToken = Prompt-Input -Message '    Bot Token'
    $discordChannelId = Prompt-Input -Message '    Channel ID'
    Write-Host ''

    Write-Host '   ' -NoNewline
    Write-Host ' WhatsApp ' -ForegroundColor White -BackgroundColor DarkGreen
    Write-FieldHint '設定方式' '啟動後從 OpenClaw 掃碼登錄，不需 Business API' -LabelColor Cyan
    $whatsappEnabled = 'false'
    if (Confirm-Choice -Message '    是否啟用 WhatsApp？' -DefaultYes $false) {
        $whatsappEnabled = 'true'
    }

    # --- 4. 需求 ---
    Write-StepNumber '4/5' '使用需求（可略過）'
    $useCase = Prompt-Input -Message '    主要用途（例如：教學、客服、寫作）'
    $notes = Prompt-Input -Message '    其他備註'

    # --- 儲存 ---
    Save-ConfigValue -Key 'MASTER_PASSWORD' -Value $masterPassword
    if ($minimaxKey) { Save-ConfigValue -Key 'MINIMAX_API_KEY' -Value $minimaxKey }
    if ($qwenKey) { Save-ConfigValue -Key 'QWEN_API_KEY' -Value $qwenKey }
    if ($groqKey) { Save-ConfigValue -Key 'GROQ_API_KEY' -Value $groqKey }
    if ($deepseekKey) { Save-ConfigValue -Key 'DEEPSEEK_API_KEY' -Value $deepseekKey }
    if ($openaiKey) { Save-ConfigValue -Key 'OPENAI_API_KEY' -Value $openaiKey }
    if ($anthropicKey) { Save-ConfigValue -Key 'ANTHROPIC_API_KEY' -Value $anthropicKey }
    if ($geminiKey) { Save-ConfigValue -Key 'GEMINI_API_KEY' -Value $geminiKey }
    if ($openrouterKey) { Save-ConfigValue -Key 'OPENROUTER_API_KEY' -Value $openrouterKey }
    if ($mistralKey) { Save-ConfigValue -Key 'MISTRAL_API_KEY' -Value $mistralKey }
    if ($ollamaUrl) { Save-ConfigValue -Key 'OLLAMA_BASE_URL' -Value $ollamaUrl }
    if ($lineChannelId) { Save-ConfigValue -Key 'LINE_CHANNEL_ID' -Value $lineChannelId }
    if ($lineChannelSecret) { Save-ConfigValue -Key 'LINE_CHANNEL_SECRET' -Value $lineChannelSecret }
    if ($lineAccessToken) { Save-ConfigValue -Key 'LINE_CHANNEL_ACCESS_TOKEN' -Value $lineAccessToken }
    if ($telegramBotToken) { Save-ConfigValue -Key 'TELEGRAM_BOT_TOKEN' -Value $telegramBotToken }
    if ($telegramUsers) { Save-ConfigValue -Key 'TELEGRAM_ALLOWED_USERS' -Value $telegramUsers }
    if ($discordBotToken) { Save-ConfigValue -Key 'DISCORD_BOT_TOKEN' -Value $discordBotToken }
    if ($discordChannelId) { Save-ConfigValue -Key 'DISCORD_CHANNEL_ID' -Value $discordChannelId }
    Save-ConfigValue -Key 'WHATSAPP_ENABLED' -Value $whatsappEnabled
    if ($useCase) { Save-ConfigValue -Key 'CUSTOMER_USE_CASE' -Value $useCase }
    if ($notes) { Save-MultilineConfigValue -Key 'REQUIREMENTS_NOTES' -Value $notes }
    if ($lineChannelId -or $telegramBotToken -or $discordBotToken -or $whatsappEnabled -eq 'true') {
        Save-ConfigValue -Key 'NEED_MESSAGING_INTEGRATION' -Value 'true'
    }

    Save-ConfigValue -Key 'FIRST_RUN_DONE' -Value 'true'
    Write-CustomerProfile
    Write-OpenClawConfig

    Write-Host ''
    Write-Host '  ╔══════════════════════════════════════╗' -ForegroundColor Green
    Write-Host '  ║        首次設定完成！                ║' -ForegroundColor Green
    Write-Host '  ╚══════════════════════════════════════╝' -ForegroundColor Green
    Write-Host ''
    Write-Host '    所有設定已儲存，接下來將進入主選單。' -ForegroundColor White
    Write-Host '    你可以從主選單選 [1] 啟動 AI 系統。' -ForegroundColor Cyan
    Write-Host ''
    Read-Host '    按 Enter 繼續'
}

function Edit-Settings {
    Assert-MasterPassword

    Write-SectionTitle '修改設定'
    Write-Host '    留空直接 Enter = 不修改' -ForegroundColor DarkGray
    Write-Host ''

    $config = Get-Config
    $fields = [ordered]@{
        'MASTER_PASSWORD'           = @('終極密碼',              '', 'White')
        'MINIMAX_API_KEY'           = @('MiniMax API Key',      'platform.minimaxi.com (語音/影片)', 'Green')
        'QWEN_API_KEY'              = @('Qwen API Key',         'bailian.console.aliyun.com (最便宜)', 'Yellow')
        'GROQ_API_KEY'              = @('Groq API Key',         'console.groq.com (免費)', 'Yellow')
        'DEEPSEEK_API_KEY'          = @('DeepSeek API Key',     'platform.deepseek.com', 'Green')
        'OPENAI_API_KEY'            = @('OpenAI API Key',       'platform.openai.com/api-keys', 'Green')
        'ANTHROPIC_API_KEY'         = @('Anthropic API Key',    'console.anthropic.com', 'Green')
        'GEMINI_API_KEY'            = @('Gemini API Key',       'aistudio.google.com/apikey', 'Green')
        'OPENROUTER_API_KEY'        = @('OpenRouter API Key',   'openrouter.ai', 'Green')
        'MISTRAL_API_KEY'           = @('Mistral API Key',      'console.mistral.ai', 'Green')
        'OLLAMA_BASE_URL'           = @('Ollama Base URL',      'ollama.ai (本地)', 'Green')
        'LINE_CHANNEL_ID'           = @('LINE Channel ID',      'developers.line.biz', 'Cyan')
        'LINE_CHANNEL_SECRET'       = @('LINE Secret',          '', 'Cyan')
        'LINE_CHANNEL_ACCESS_TOKEN' = @('LINE Token',           '', 'Cyan')
        'TELEGRAM_BOT_TOKEN'        = @('Telegram Bot Token',   '@BotFather', 'Cyan')
        'TELEGRAM_ALLOWED_USERS'    = @('Telegram User IDs',    '逗號分隔', 'Cyan')
        'DISCORD_BOT_TOKEN'         = @('Discord Bot Token',    'discord.com/developers', 'Cyan')
        'DISCORD_CHANNEL_ID'        = @('Discord Channel ID',   '', 'Cyan')
        'WHATSAPP_ENABLED'          = @('WhatsApp 啟用',        'true/false', 'Cyan')
    }

    foreach ($entry in $fields.GetEnumerator()) {
        $label = $entry.Value[0]
        $url = $entry.Value[1]
        $color = $entry.Value[2]
        Write-Host "    $label" -ForegroundColor $color -NoNewline
        if ($url) { Write-Host "  ($url)" -ForegroundColor DarkGray } else { Write-Host '' }
        $current = [string](Get-HashtableValue -Table $config -Key $entry.Key -Default '')
        $value = Prompt-Input -Message '    ' -Default $current
        if ($value -ne $current) {
            Save-ConfigValue -Key $entry.Key -Value $value
        }
        Write-Host ''
    }

    Write-OpenClawConfig
    Write-Host '    設定已保存。' -ForegroundColor Green
}

function Validate-BoundEmail {
    $config = Get-Config
    $bound = [string](Get-HashtableValue -Table $config -Key 'BOUND_EMAIL' -Default '')

    if ([string]::IsNullOrWhiteSpace($bound)) {
        # 尚未啟動 → 走白名單啟動流程
        $activated = Invoke-CustomerActivation
        if (-not $activated) {
            throw '啟動失敗，系統無法使用。'
        }
        return
    }

    # 已綁定 → 驗證 Email
    $email = Prompt-Input -Message '  請輸入綁定 Email'
    if ($email.Trim().ToLowerInvariant() -ne $bound.Trim().ToLowerInvariant()) {
        throw '帳號不符，無法啟動。'
    }
}

function Show-IntroHeader {
    Clear-Host
    Write-Host ''
    Write-Host '       ___                    ____ _                ' -ForegroundColor DarkRed
    Write-Host '      / _ \ _ __   ___ _ __  / ___| | __ ___      __' -ForegroundColor Red
    Write-Host '     | | | |  _ \ / _ \  _ \| |   | |/ _` \ \ /\ / /' -ForegroundColor Yellow
    Write-Host '     | |_| | |_) |  __/ | | | |___| | (_| |\ V  V / ' -ForegroundColor Green
    Write-Host '      \___/| .__/ \___|_| |_|\____|_|\__,_| \_/\_/  ' -ForegroundColor Cyan
    Write-Host '           |_|                                       ' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  +----------------------------------------------------+' -ForegroundColor DarkCyan
    Write-Host '  |' -ForegroundColor DarkCyan -NoNewline
    Write-Host '          隨 身 黃 仁 蝦 A I 系 統              ' -ForegroundColor Yellow -NoNewline
    Write-Host '|' -ForegroundColor DarkCyan
    Write-Host '  +----------------------------------------------------+' -ForegroundColor DarkCyan
    Write-Host ''
    Write-Host '    版本  ' -ForegroundColor DarkGray -NoNewline
    Write-Host $AppVersion -ForegroundColor White
    Write-Host '    作者  ' -ForegroundColor DarkGray -NoNewline
    Write-Host $AuthorName -ForegroundColor White
    Write-Host '    聯絡  ' -ForegroundColor DarkGray -NoNewline
    Write-Host $AuthorContact -ForegroundColor Cyan
}

function Show-Menu {
    Write-Host ''
    Write-Divider -Color DarkGray
    Write-Host ''
    Write-Host '   ' -NoNewline; Write-Host ' 1 ' -ForegroundColor Black -BackgroundColor Green -NoNewline; Write-Host '  啟動並開始使用' -ForegroundColor Green
    Write-Host '   ' -NoNewline; Write-Host ' 2 ' -ForegroundColor Black -BackgroundColor Cyan -NoNewline; Write-Host '  安裝到這台 Windows 電腦' -ForegroundColor Cyan
    Write-Host '   ' -NoNewline; Write-Host ' 3 ' -ForegroundColor Black -BackgroundColor Magenta -NoNewline; Write-Host '  初始化 OpenClaw' -ForegroundColor Magenta
    Write-Host '   ' -NoNewline; Write-Host ' 4 ' -ForegroundColor Black -BackgroundColor Yellow -NoNewline; Write-Host '  查看 OpenClaw 狀態' -ForegroundColor Yellow
    Write-Host '   ' -NoNewline; Write-Host ' 5 ' -ForegroundColor Black -BackgroundColor DarkYellow -NoNewline; Write-Host '  設定（API Key / 通訊頻道 / 密碼）' -ForegroundColor DarkYellow
    Write-Host '   ' -NoNewline; Write-Host ' 6 ' -ForegroundColor Black -BackgroundColor Blue -NoNewline; Write-Host '  使用教學 / 案例庫' -ForegroundColor Blue
    Write-Host '   ' -NoNewline; Write-Host ' 7 ' -ForegroundColor Black -BackgroundColor DarkRed -NoNewline; Write-Host '  開啟 Web 管理面板' -ForegroundColor DarkRed
    Write-Host '   ' -NoNewline; Write-Host ' 8 ' -ForegroundColor Black -BackgroundColor White -NoNewline; Write-Host '  技能管理' -ForegroundColor White
    Write-Host '   ' -NoNewline; Write-Host ' 9 ' -ForegroundColor White -BackgroundColor DarkGray -NoNewline; Write-Host '  離開' -ForegroundColor DarkGray
    Write-Host ''
    Write-Divider -Color DarkGray
}

function Show-Tutorial {
    Write-SectionTitle '使用教學'

    Write-Host '   ' -NoNewline
    Write-Host ' 第一次使用 ' -ForegroundColor Black -BackgroundColor Yellow
    Write-Host ''
    Write-Host '    1. 插入 USB' -ForegroundColor White
    Write-Host '    2. 雙擊' -ForegroundColor White -NoNewline
    Write-Host ' 一鍵安裝-隨身黃仁蝦AI-Windows版.bat' -ForegroundColor Yellow
    Write-Host '    3. 若跳出權限確認，按「允許」' -ForegroundColor White
    Write-Host '    4. 若要求重開機，重開後再按一次安裝檔' -ForegroundColor White

    Write-Host ''
    Write-Host '   ' -NoNewline
    Write-Host ' 平常使用 ' -ForegroundColor Black -BackgroundColor Green
    Write-Host ''
    Write-Host '    1. 插入 USB' -ForegroundColor White
    Write-Host '    2. 雙擊' -ForegroundColor White -NoNewline
    Write-Host ' 點這個啟動-隨身黃仁蝦AI-Windows.bat' -ForegroundColor Green
    Write-Host '    3. 輸入綁定 Email，進入系統' -ForegroundColor White

    Write-Host ''
    Write-Host '   ' -NoNewline
    Write-Host ' 重要觀念 ' -ForegroundColor Black -BackgroundColor Cyan
    Write-Host ''
    Write-Host '    USB' -ForegroundColor Cyan -NoNewline
    Write-Host ' = 身份鑰匙（認證用）' -ForegroundColor DarkGray
    Write-Host '    電腦' -ForegroundColor Cyan -NoNewline
    Write-Host ' = AI 主機（運算用）' -ForegroundColor DarkGray
    Write-Host '    啟動失敗？先確認 USB 有插著' -ForegroundColor DarkGray
}

function Show-TutorialAndExamples {
    while ($true) {
        Write-Host ''
        Write-Host '  ═══ 使用教學 / 案例庫 ═══' -ForegroundColor Yellow
        Write-Host ''
        Write-Host '    [1] 快速上手教學' -ForegroundColor Green
        Write-Host '    [2] 瀏覽使用案例（AI 能幫你做什麼？）' -ForegroundColor Cyan
        Write-Host '    [3] 返回主選單' -ForegroundColor DarkGray
        Write-Host ''
        $sel = Read-Host '    請選擇 [1-3]'
        switch ($sel) {
            '1' {
                Show-Tutorial
                Wait-ReturnToMenu
            }
            '2' {
                Show-ExampleBrowser
            }
            '3' { return }
            default { Write-Host '    請輸入 1 到 3。' -ForegroundColor Yellow }
        }
    }
}

function Wait-ReturnToMenu {
    Write-Host ''
    Read-Host '  按 Enter 回到主選單' | Out-Null
}

function Test-LocalInstallReady {
    $config = Get-Config
    $dir = [string](Get-HashtableValue -Table $config -Key 'LOCAL_INSTALL_DIR' -Default '')
    if (-not $dir) { return $false }
    return (Test-Path -LiteralPath (Join-Path $dir 'scripts\common_windows.ps1'))
}

function Assert-LocalInstall {
    param([string]$ActionName = '這個功能')
    if (Test-LocalInstallReady) { return $true }
    Write-Host ''
    Write-Host '  +----------------------------------------------------+' -ForegroundColor Red
    Write-Host '  |' -ForegroundColor Red -NoNewline
    Write-Host '  尚未安裝到本機，請先執行安裝             ' -ForegroundColor Yellow -NoNewline
    Write-Host '|' -ForegroundColor Red
    Write-Host '  +----------------------------------------------------+' -ForegroundColor Red
    Write-Host ''
    Write-Host "    $ActionName 需要先安裝到本機電腦。" -ForegroundColor White
    Write-Host '    請先選' -ForegroundColor DarkGray -NoNewline
    Write-Host ' [2] 安裝到這台 Windows 電腦' -ForegroundColor Cyan -NoNewline
    Write-Host '。' -ForegroundColor DarkGray
    Write-Host ''
    Wait-ReturnToMenu
    return $false
}

function Start-UseNowFlow {
    if (-not (Assert-LocalInstall -ActionName '啟動 OpenClaw')) { return }

    $config = Get-Config
    if ([string](Get-HashtableValue -Table $config -Key 'ONBOARD_DONE' -Default 'false') -ne 'true') {
        Write-Host '  尚未完成初始化，現在先執行初始化...' -ForegroundColor Yellow
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'onboard_nemoclaw_windows.ps1')
    }

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'start_nemoclaw_windows.ps1')

    Write-Host ''
    Write-Host '  OpenClaw 已嘗試啟動。' -ForegroundColor Green
    Write-Host '  沒看到介面？從主選單選「4. 查看狀態」' -ForegroundColor DarkGray
    Wait-ReturnToMenu
}

# ===== 主流程 =====
try {

Ensure-Config
Ensure-DeviceTokenIntegrity
Assert-LicenseValid
Run-FirstRunWizard
Validate-BoundEmail
Assert-UsbLock

$heartbeatJob = Start-UsbHeartbeat -IntervalMinutes 5

while ($true) {
    Show-IntroHeader

    # 安裝狀態指示
    if (Test-LocalInstallReady) {
        Write-Host ''
        Write-Host '    狀態  ' -ForegroundColor DarkGray -NoNewline
        Write-Host '已安裝到本機' -ForegroundColor Green
    } else {
        Write-Host ''
        Write-Host '    狀態  ' -ForegroundColor DarkGray -NoNewline
        Write-Host '尚未安裝 — 請先選 [2]' -ForegroundColor Red
    }

    Show-Menu

    $choice = Read-Host '  請選擇 [1-9]'
    switch ($choice) {
        '1' { Start-UseNowFlow }
        '2' {
            & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'install_bundle_windows_v2.ps1')
            Wait-ReturnToMenu
        }
        '3' {
            if (Assert-LocalInstall -ActionName '初始化 OpenClaw') {
                & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'onboard_nemoclaw_windows.ps1')
                Wait-ReturnToMenu
            }
        }
        '4' {
            if (Assert-LocalInstall -ActionName '查看 OpenClaw 狀態') {
                & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'status_nemoclaw_windows.ps1')
                Wait-ReturnToMenu
            }
        }
        '5' {
            Edit-Settings
            Wait-ReturnToMenu
        }
        '6' {
            Show-TutorialAndExamples
        }
        '7' {
            if (Assert-LocalInstall -ActionName '開啟 Web 管理面板') {
                & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'start_dashboard_windows.ps1')
                Start-Process 'http://localhost:18788'
                Write-Host '  已在瀏覽器開啟管理面板。' -ForegroundColor Green
                Wait-ReturnToMenu
            }
        }
        '8' {
            Show-SkillManager
        }
        '9' {
            Stop-UsbHeartbeat -Job $heartbeatJob
            break
        }
        default { Write-Host '  請輸入 1 到 9。' -ForegroundColor Yellow }
    }
}

Stop-UsbHeartbeat -Job $heartbeatJob

} catch {
    Write-Host ''
    Write-Host '  ╔══════════════════════════════════════╗' -ForegroundColor Red
    Write-Host '  ║          系統發生錯誤                ║' -ForegroundColor Red
    Write-Host '  ╚══════════════════════════════════════╝' -ForegroundColor Red
    Write-Host ''
    Write-Host "  錯誤訊息：$($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  請截圖此畫面，聯絡賣家：3a01chatgpt@gmail.com' -ForegroundColor White
    Write-Host ''
    Read-Host '  按 Enter 離開'
}
