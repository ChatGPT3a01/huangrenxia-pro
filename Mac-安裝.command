#!/bin/bash
# =====================================================
#  隨身黃仁蝦AI系統 — Mac 安裝到本機
#  將系統安裝到 ~/.lobster-ai/
#
#  作者: 曾慶良 主任（阿亮老師）
#  聯絡: 3a01chatgpt@gmail.com
#  YouTube: https://www.youtube.com/@Liang-yt02
#  © 2026 阿亮老師 版權所有
# =====================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/app"
CORE_DIR="$APP_DIR/core"
DATA_DIR="$SCRIPT_DIR/data"
CONFIG_ENV="$DATA_DIR/config.env"

TARGET_DIR="$HOME/.lobster-ai"

clear
echo ""
echo -e "  ${BOLD}=== 隨身黃仁蝦AI系統 — 安裝到本機 ===${NC}"
echo ""

# ===== 1. Check Architecture =====
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
fi

# ===== 3. Verify Node.js =====
if [ ! -f "$NODE_BIN" ]; then
    echo -e "  ${RED}找不到 Node.js runtime。${NC}"
    echo -e "  ${YELLOW}請先執行 app/setup.sh 下載 Node.js。${NC}"
    read -p "  按 Enter 離開..."
    exit 1
fi

NODE_VER=$("$NODE_BIN" --version)
echo -e "  ${GREEN}Node.js: $NODE_VER${NC}"

# ===== 4. Check/Install OpenClaw =====
if [ ! -f "$OPENCLAW_MJS" ]; then
    echo -e "  ${CYAN}正在安裝 OpenClaw 依賴...${NC}"
    export PATH="$NODE_DIR/bin:$PATH"
    cd "$CORE_DIR"
    "$NPM_BIN" install 2>&1 | tail -3
    if [ ! -f "$OPENCLAW_MJS" ]; then
        echo -e "  ${RED}OpenClaw 安裝失敗。${NC}"
        read -p "  按 Enter 離開..."
        exit 1
    fi
fi
echo -e "  ${GREEN}OpenClaw: 已就緒${NC}"

# ===== 5. Check Existing Installation =====
if [ -d "$TARGET_DIR" ]; then
    echo ""
    echo -e "  ${YELLOW}偵測到已有安裝於 $TARGET_DIR${NC}"
    read -p "  是否覆蓋？(y/N) " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "  ${YELLOW}取消安裝。${NC}"
        read -p "  按 Enter 離開..."
        exit 0
    fi
fi

# ===== 6. Copy Files =====
echo ""
echo -e "  ${CYAN}安裝位置：$TARGET_DIR${NC}"
echo -e "  ${CYAN}正在複製檔案...${NC}"

mkdir -p "$TARGET_DIR"

# Copy everything except .git, System Volume Information, etc.
rsync -a --exclude='.git' --exclude='System Volume Information' \
    --exclude='$RECYCLE.BIN' --exclude='.DS_Store' \
    "$SCRIPT_DIR/" "$TARGET_DIR/"

echo -e "  ${GREEN}檔案複製完成${NC}"

# ===== 7. Update local config =====
TARGET_CONFIG="$TARGET_DIR/data/config.env"
if [ -f "$TARGET_CONFIG" ]; then
    # Helper to set config value
    set_config() {
        local key="$1" val="$2" file="$3"
        if grep -q "^${key}=" "$file" 2>/dev/null; then
            sed -i '' "s|^${key}=.*|${key}=\"${val}\"|" "$file"
        else
            echo "${key}=\"${val}\"" >> "$file"
        fi
    }

    set_config "INSTALL_MODE" "installed" "$TARGET_CONFIG"
    set_config "LOCAL_INSTALL_DIR" "$TARGET_DIR" "$TARGET_CONFIG"
    set_config "USB_LOCK_ENABLED" "true" "$TARGET_CONFIG"
    set_config "ENGINE_TYPE" "openclaw" "$TARGET_CONFIG"
fi

# ===== 8. Ensure directories =====
mkdir -p "$TARGET_DIR/data/.openclaw"
mkdir -p "$TARGET_DIR/data/memory/journal"
mkdir -p "$TARGET_DIR/data/logs"
mkdir -p "$TARGET_DIR/skills/import"
mkdir -p "$TARGET_DIR/skills/installed"

# ===== 9. Make scripts executable =====
chmod +x "$TARGET_DIR/Mac-啟動.command" 2>/dev/null || true
chmod +x "$TARGET_DIR/Mac-安裝.command" 2>/dev/null || true

# Ensure Node.js binaries are executable
ARCH_CHECK=$(uname -m)
if [ "$ARCH_CHECK" = "arm64" ]; then
    chmod +x "$TARGET_DIR/app/runtime/node-mac-arm64/bin/node" 2>/dev/null || true
    chmod +x "$TARGET_DIR/app/runtime/node-mac-arm64/bin/npm" 2>/dev/null || true
else
    chmod +x "$TARGET_DIR/app/runtime/node-mac-x64/bin/node" 2>/dev/null || true
    chmod +x "$TARGET_DIR/app/runtime/node-mac-x64/bin/npm" 2>/dev/null || true
fi

# ===== 10. Create Desktop Alias =====
DESKTOP="$HOME/Desktop"
if [ -d "$DESKTOP" ]; then
    ALIAS_PATH="$DESKTOP/黃仁蝦AI-本機版.command"
    cat > "$ALIAS_PATH" << 'EOALIAS'
#!/bin/bash
cd "$HOME/.lobster-ai"
exec bash "$HOME/.lobster-ai/Mac-啟動.command"
EOALIAS
    chmod +x "$ALIAS_PATH"
    echo -e "  ${GREEN}桌面已建立捷徑「黃仁蝦AI-本機版」${NC}"
fi

# ===== Done =====
echo ""
echo -e "  ${GREEN}+----------------------------------------------------+${NC}"
echo -e "  ${GREEN}|${NC}  ${BOLD}安裝完成！${NC}                                      ${GREEN}|${NC}"
echo -e "  ${GREEN}+----------------------------------------------------+${NC}"
echo ""
echo -e "  本機位置：${CYAN}$TARGET_DIR${NC}"
echo -e "  之後插入 USB，雙擊「Mac-啟動.command」即可使用。"
echo ""
read -p "  按 Enter 離開..."
