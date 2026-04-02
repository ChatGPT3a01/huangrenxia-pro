#!/bin/bash
# =====================================================
#  隨身黃仁蝦AI系統 — Mac 啟動器
#  雙擊即可啟動 OpenClaw AI 助手
#
#  作者: 曾慶良 主任（阿亮老師）
#  聯絡: 3a01chatgpt@gmail.com
#  YouTube: https://www.youtube.com/@Liang-yt02
#  © 2026 阿亮老師 版權所有
# =====================================================

set -e

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

# Resolve script directory (handle symlinks)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/app"
CORE_DIR="$APP_DIR/core"
DATA_DIR="$SCRIPT_DIR/data"
CONFIG_ENV="$DATA_DIR/config.env"
OPENCLAW_DIR="$DATA_DIR/.openclaw"
OPENCLAW_JSON="$OPENCLAW_DIR/openclaw.json"
SKILLS_DIR="$SCRIPT_DIR/skills"
MEMORY_DIR="$DATA_DIR/memory"
CONFIG_SERVER="$SCRIPT_DIR/config-server/server.js"

GW_PID=""
CS_PID=""

cleanup() {
    echo ""
    echo -e "  ${YELLOW}正在關閉服務...${NC}"
    [ -n "$GW_PID" ] && kill "$GW_PID" 2>/dev/null || true
    [ -n "$CS_PID" ] && kill "$CS_PID" 2>/dev/null || true
    # Kill any remaining openclaw processes on our ports
    for PORT in $(seq 18789 18799); do
        lsof -ti :$PORT 2>/dev/null | xargs kill 2>/dev/null || true
    done
    lsof -ti :18788 2>/dev/null | xargs kill 2>/dev/null || true
    echo -e "  ${GREEN}已關閉。${NC}"
    exit 0
}
trap cleanup INT TERM

# ===== Banner =====
clear
echo ""
echo -e "  ${RED}   ___                    ____ _                ${NC}"
echo -e "  ${YELLOW}  / _ \ _ __   ___ _ __  / ___| | __ ___      __${NC}"
echo -e "  ${YELLOW} | | | |  _ \ / _ \  _ \| |   | |/ _\` \ \ /\ / /${NC}"
echo -e "  ${GREEN} | |_| | |_) |  __/ | | | |___| | (_| |\ V  V / ${NC}"
echo -e "  ${CYAN}  \___/| .__/ \___|_| |_|\____|_|\__,_| \_/\_/  ${NC}"
echo -e "  ${CYAN}       |_|                                       ${NC}"
echo ""
echo -e "  ${BOLD}+----------------------------------------------------+${NC}"
echo -e "  ${BOLD}|${NC}${YELLOW}          隨 身 黃 仁 蝦 A I 系 統              ${NC}${BOLD}|${NC}"
echo -e "  ${BOLD}+----------------------------------------------------+${NC}"
echo ""
echo -e "  作者  ${BOLD}曾慶良 主任（阿亮老師）${NC}"
echo -e "  聯絡  ${CYAN}3a01chatgpt@gmail.com${NC}"
echo ""

# ===== 1. CPU Architecture =====
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    NODE_DIR="$APP_DIR/runtime/node-mac-arm64"
    echo -e "  ${GREEN}架構: Apple Silicon (M 系列)${NC}"
elif [ "$ARCH" = "x86_64" ]; then
    NODE_DIR="$APP_DIR/runtime/node-mac-x64"
    echo -e "  ${GREEN}架構: Intel Mac (x64)${NC}"
else
    echo -e "  ${RED}不支援的架構: $ARCH${NC}"
    read -p "  按 Enter 離開..."
    exit 1
fi

NODE_BIN="$NODE_DIR/bin/node"
NPM_BIN="$NODE_DIR/bin/npm"
OPENCLAW_MJS="$CORE_DIR/node_modules/openclaw/openclaw.mjs"

# ===== 2. Remove macOS Quarantine =====
if xattr -l "$NODE_BIN" 2>/dev/null | grep -q "com.apple.quarantine"; then
    echo -e "  ${YELLOW}移除 macOS 安全限制...${NC}"
    xattr -rd com.apple.quarantine "$SCRIPT_DIR" 2>/dev/null || true
    echo -e "  ${GREEN}完成${NC}"
fi

# ===== 3. Verify Node.js =====
if [ ! -f "$NODE_BIN" ]; then
    echo -e "  ${RED}找不到 Node.js runtime。${NC}"
    echo -e "  ${YELLOW}請確認 app/runtime/node-mac-$( [ "$ARCH" = "arm64" ] && echo "arm64" || echo "x64" )/ 目錄完整。${NC}"
    echo -e "  ${YELLOW}或執行 Mac-安裝.command 進行安裝。${NC}"
    read -p "  按 Enter 離開..."
    exit 1
fi

NODE_VER=$("$NODE_BIN" --version)
echo -e "  ${GREEN}Node.js: $NODE_VER${NC}"

# ===== 4. Verify OpenClaw =====
if [ ! -f "$OPENCLAW_MJS" ]; then
    echo -e "  ${YELLOW}OpenClaw 未安裝，正在安裝...${NC}"
    export PATH="$NODE_DIR/bin:$PATH"
    cd "$CORE_DIR"
    "$NPM_BIN" install 2>&1 | tail -1
    if [ ! -f "$OPENCLAW_MJS" ]; then
        echo -e "  ${RED}OpenClaw 安裝失敗。請確認網路連線。${NC}"
        read -p "  按 Enter 離開..."
        exit 1
    fi
fi
echo -e "  ${GREEN}OpenClaw: 已就緒${NC}"

# ===== 5. Initialize Data Directories =====
mkdir -p "$DATA_DIR" "$OPENCLAW_DIR" "$MEMORY_DIR" "$MEMORY_DIR/journal" "$DATA_DIR/logs"
mkdir -p "$SKILLS_DIR/import" "$SKILLS_DIR/installed"

# ===== 6. Read config.env =====
read_config() {
    local key="$1" default="$2"
    if [ -f "$CONFIG_ENV" ]; then
        local val
        val=$(grep "^${key}=" "$CONFIG_ENV" 2>/dev/null | head -1 | sed "s/^${key}=\"\{0,1\}\(.*\)\"\{0,1\}$/\1/")
        [ -n "$val" ] && echo "$val" || echo "$default"
    else
        echo "$default"
    fi
}

DEVICE_TOKEN=$(read_config "DEVICE_TOKEN" "")
BOUND_EMAIL=$(read_config "BOUND_EMAIL" "")
AUTH_TOKEN=$(read_config "OPENCLAW_AUTH_TOKEN" "lobster")

# ===== 7. USB / Device Token Check =====
if [ -n "$DEVICE_TOKEN" ]; then
    USB_FOUND=false
    # Check all mounted volumes for matching DEVICE_TOKEN
    for vol in /Volumes/*/; do
        for candidate in "$vol" "${vol}隨身黃仁蝦AI系統/"; do
            cfg="${candidate}data/config.env"
            if [ -f "$cfg" ]; then
                token=$(grep "^DEVICE_TOKEN=" "$cfg" 2>/dev/null | head -1 | sed 's/^DEVICE_TOKEN="\{0,1\}\(.*\)\"\{0,1\}$/\1/')
                if [ "$token" = "$DEVICE_TOKEN" ]; then
                    USB_FOUND=true
                    break 2
                fi
            fi
        done
    done

    USB_LOCK=$(read_config "USB_LOCK_ENABLED" "true")
    INSTALL_MODE=$(read_config "INSTALL_MODE" "portable")
    if [ "$USB_LOCK" = "true" ] && [ "$INSTALL_MODE" != "portable" ] && [ "$USB_FOUND" = "false" ]; then
        echo ""
        echo -e "  ${RED}+----------------------------------------------------+${NC}"
        echo -e "  ${RED}|${NC}  ${YELLOW}未偵測到授權 USB，請插入隨身黃仁蝦AI USB${NC}  ${RED}|${NC}"
        echo -e "  ${RED}+----------------------------------------------------+${NC}"
        echo ""
        read -p "  按 Enter 離開..."
        exit 1
    fi
fi

# ===== 8. Email Validation (if bound) =====
if [ -n "$BOUND_EMAIL" ]; then
    echo ""
    read -p "  請輸入綁定 Email: " input_email
    if [ "$input_email" != "$BOUND_EMAIL" ]; then
        echo -e "  ${RED}帳號不符，無法啟動。${NC}"
        read -p "  按 Enter 離開..."
        exit 1
    fi
    echo -e "  ${GREEN}驗證通過${NC}"
fi

# ===== 9. Write OpenClaw Config =====
write_openclaw_config() {
    local providers="[]"
    local provider_list=""

    add_provider() {
        local name="$1" type="$2" key="$3" model="$4"
        local val
        val=$(read_config "$key" "")
        if [ -n "$val" ]; then
            [ -n "$provider_list" ] && provider_list="$provider_list,"
            provider_list="${provider_list}{\"name\":\"${name}\",\"provider\":\"${type}\",\"apiKey\":\"${val}\""
            [ -n "$model" ] && provider_list="${provider_list},\"model\":\"${model}\""
            provider_list="${provider_list}}"
        fi
    }

    add_provider "openai" "openai" "OPENAI_API_KEY" ""
    add_provider "anthropic" "anthropic" "ANTHROPIC_API_KEY" ""
    add_provider "gemini" "google" "GEMINI_API_KEY" ""
    add_provider "deepseek" "openai-compatible" "DEEPSEEK_API_KEY" "deepseek-chat"
    add_provider "groq" "openai-compatible" "GROQ_API_KEY" "llama-3.3-70b-versatile"
    add_provider "qwen" "openai-compatible" "QWEN_API_KEY" "qwen-max"
    add_provider "openrouter" "openai-compatible" "OPENROUTER_API_KEY" ""
    add_provider "mistral" "openai-compatible" "MISTRAL_API_KEY" "mistral-large-latest"
    add_provider "minimax" "openai-compatible" "MINIMAX_API_KEY" "MiniMax-Text-01"

    providers="[${provider_list}]"

    cat > "$OPENCLAW_JSON" << EOJSON
{
  "gateway": {
    "mode": "local",
    "auth": { "token": "${AUTH_TOKEN}" }
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto",
    "restart": true,
    "ownerDisplay": "raw"
  },
  "models": {
    "providers": ${providers}
  }
}
EOJSON
}

write_openclaw_config
echo -e "  ${GREEN}OpenClaw 配置已同步${NC}"

# ===== 10. Set Environment Variables =====
export PATH="$NODE_DIR/bin:$PATH"
export OPENCLAW_HOME="$DATA_DIR"
export OPENCLAW_STATE_DIR="$OPENCLAW_DIR"
export OPENCLAW_CONFIG_PATH="$OPENCLAW_JSON"

# Export API keys
for key in OPENAI_API_KEY ANTHROPIC_API_KEY GEMINI_API_KEY DEEPSEEK_API_KEY \
           GROQ_API_KEY QWEN_API_KEY OPENROUTER_API_KEY MISTRAL_API_KEY MINIMAX_API_KEY; do
    val=$(read_config "$key" "")
    [ -n "$val" ] && export "$key=$val"
done

# ===== 11. Find Available Port =====
PORT=18789
while lsof -i :$PORT >/dev/null 2>&1; do
    echo -e "  ${YELLOW}Port $PORT 已被占用，嘗試下一個...${NC}"
    PORT=$((PORT + 1))
    if [ $PORT -gt 18799 ]; then
        echo -e "  ${RED}端口 18789-18799 全被占用${NC}"
        read -p "  按 Enter 離開..."
        exit 1
    fi
done

# ===== 12. Start Config Server =====
if [ -f "$CONFIG_SERVER" ]; then
    echo -e "  ${CYAN}啟動管理面板 (port 18788)...${NC}"
    "$NODE_BIN" "$CONFIG_SERVER" > /dev/null 2>&1 &
    CS_PID=$!
fi

# ===== 13. Start OpenClaw Gateway =====
echo ""
echo -e "  ${CYAN}正在啟動 OpenClaw (port $PORT)...${NC}"

cd "$CORE_DIR"
"$NODE_BIN" "$OPENCLAW_MJS" gateway run --allow-unconfigured --force --port $PORT > /dev/null 2>&1 &
GW_PID=$!

# ===== 14. Wait for Gateway =====
READY=false
for i in $(seq 1 30); do
    sleep 0.5
    if curl -s -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; then
        READY=true
        break
    fi
done

echo ""
if [ "$READY" = "true" ]; then
    echo -e "  ${GREEN}+----------------------------------------------------+${NC}"
    echo -e "  ${GREEN}|${NC}  ${BOLD}OpenClaw 已啟動！${NC}                                ${GREEN}|${NC}"
    echo -e "  ${GREEN}+----------------------------------------------------+${NC}"
    echo ""
    echo -e "  AI 助手:  ${CYAN}http://127.0.0.1:$PORT/#token=$AUTH_TOKEN${NC}"
    [ -n "$CS_PID" ] && echo -e "  管理面板: ${CYAN}http://127.0.0.1:18788/${NC}"
    echo ""

    # Open browser
    open "http://127.0.0.1:$PORT/#token=$AUTH_TOKEN" 2>/dev/null || true
else
    echo -e "  ${YELLOW}OpenClaw 已啟動，但 Gateway 尚未回應。${NC}"
    echo -e "  ${YELLOW}請稍候數秒後手動開啟：http://127.0.0.1:$PORT/#token=$AUTH_TOKEN${NC}"
fi

# ===== 15. Start USB Heartbeat =====
HEARTBEAT_MJS="$APP_DIR/heartbeat.mjs"
if [ -f "$HEARTBEAT_MJS" ] && [ -n "$DEVICE_TOKEN" ]; then
    "$NODE_BIN" "$HEARTBEAT_MJS" "$DEVICE_TOKEN" "$CONFIG_ENV" &
fi

echo ""
echo -e "  ${YELLOW}按 Ctrl+C 關閉所有服務${NC}"
echo ""

# Keep running
wait $GW_PID 2>/dev/null || true
