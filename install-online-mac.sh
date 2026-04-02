#!/bin/bash
# =====================================================
#  隨身黃仁蝦AI系統 — Mac 線上安裝腳本
#  一行安裝：curl -sSL https://lobster.ai/install.sh | bash
#
#  作者: 曾慶良 主任（阿亮老師）
#  聯絡: 3a01chatgpt@gmail.com
#  © 2026 阿亮老師 版權所有
# =====================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

INSTALL_DIR="$HOME/.lobster-ai"
NODE_VER="v22.16.0"
NODE_MIRROR="https://nodejs.org/dist"

echo ""
echo -e "  ${BOLD}+----------------------------------------------------+${NC}"
echo -e "  ${BOLD}|${NC}${YELLOW}    隨身黃仁蝦AI系統 — 線上安裝                    ${NC}${BOLD}|${NC}"
echo -e "  ${BOLD}+----------------------------------------------------+${NC}"
echo ""
echo -e "  安裝位置：${CYAN}$INSTALL_DIR${NC}"
echo -e "  作者：曾慶良 主任（阿亮老師）"
echo ""

# --- 1. Detect Architecture ---
echo -e "  ${BOLD}[1/4] 檢測系統${NC}"

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    PLATFORM="darwin-arm64"
    NODE_DIR_NAME="node-mac-arm64"
    echo -e "  ${GREEN}架構: Apple Silicon (M 系列)${NC}"
elif [ "$ARCH" = "x86_64" ]; then
    PLATFORM="darwin-x64"
    NODE_DIR_NAME="node-mac-x64"
    echo -e "  ${GREEN}架構: Intel Mac (x64)${NC}"
else
    echo -e "  ${RED}不支援的架構: $ARCH${NC}"
    exit 1
fi

# --- 2. Create directories ---
echo ""
echo -e "  ${BOLD}[2/4] 建立目錄結構${NC}"

mkdir -p "$INSTALL_DIR/app/core"
mkdir -p "$INSTALL_DIR/app/runtime/$NODE_DIR_NAME"
mkdir -p "$INSTALL_DIR/data/.openclaw"
mkdir -p "$INSTALL_DIR/data/memory/journal"
mkdir -p "$INSTALL_DIR/data/logs"
mkdir -p "$INSTALL_DIR/skills/import"
mkdir -p "$INSTALL_DIR/skills/installed"
mkdir -p "$INSTALL_DIR/config-server/public"

echo -e "  ${GREEN}目錄結構已建立${NC}"

# --- 3. Download Node.js ---
echo ""
echo -e "  ${BOLD}[3/4] 下載 Node.js${NC}"

NODE_BIN="$INSTALL_DIR/app/runtime/$NODE_DIR_NAME/bin/node"

if [ -f "$NODE_BIN" ]; then
    NODE_CUR=$("$NODE_BIN" --version)
    echo -e "  ${GREEN}Node.js 已存在：$NODE_CUR${NC}"
else
    TARBALL="node-${NODE_VER}-${PLATFORM}.tar.gz"
    URL="${NODE_MIRROR}/${NODE_VER}/${TARBALL}"

    echo -e "  ${CYAN}下載 Node.js $NODE_VER ($PLATFORM)...${NC}"
    curl -# -L "$URL" -o "/tmp/$TARBALL"

    echo -e "  ${CYAN}解壓中...${NC}"
    tar -xzf "/tmp/$TARBALL" -C "$INSTALL_DIR/app/runtime/$NODE_DIR_NAME" --strip-components=1
    rm -f "/tmp/$TARBALL"
    chmod +x "$NODE_BIN"

    NODE_CUR=$("$NODE_BIN" --version)
    echo -e "  ${GREEN}Node.js $NODE_CUR 已安裝${NC}"
fi

NPM_BIN="$INSTALL_DIR/app/runtime/$NODE_DIR_NAME/bin/npm"
export PATH="$INSTALL_DIR/app/runtime/$NODE_DIR_NAME/bin:$PATH"

# --- 4. Install OpenClaw ---
echo ""
echo -e "  ${BOLD}[4/4] 安裝 OpenClaw${NC}"

CORE_DIR="$INSTALL_DIR/app/core"
OPENCLAW_MJS="$CORE_DIR/node_modules/openclaw/openclaw.mjs"
PKG_JSON="$CORE_DIR/package.json"

if [ ! -f "$PKG_JSON" ]; then
    echo '{"name":"lobster-core","version":"1.0.0","private":true,"dependencies":{"openclaw":"latest"}}' > "$PKG_JSON"
fi

if [ -f "$OPENCLAW_MJS" ]; then
    echo -e "  ${GREEN}OpenClaw 已安裝${NC}"
else
    echo -e "  ${CYAN}npm install...${NC}"
    cd "$CORE_DIR"
    "$NPM_BIN" install 2>&1 | tail -3

    if [ -f "$OPENCLAW_MJS" ]; then
        echo -e "  ${GREEN}OpenClaw 安裝完成${NC}"
    else
        echo -e "  ${RED}OpenClaw 安裝失敗。請確認網路連線後重試。${NC}"
        exit 1
    fi
fi

# --- Create config ---
CONFIG_ENV="$INSTALL_DIR/data/config.env"
if [ ! -f "$CONFIG_ENV" ]; then
    cat > "$CONFIG_ENV" << 'EOF'
APP_NAME="隨身黃仁蝦AI系統"
INSTALL_MODE="installed"
ENGINE_TYPE="openclaw"
OPENCLAW_AUTH_TOKEN="lobster"
USB_LOCK_ENABLED="false"
FIRST_RUN_DONE="false"
ONBOARD_DONE="false"
EOF
fi

OPENCLAW_JSON="$INSTALL_DIR/data/.openclaw/openclaw.json"
if [ ! -f "$OPENCLAW_JSON" ]; then
    cat > "$OPENCLAW_JSON" << 'EOF'
{"gateway":{"mode":"local","auth":{"token":"lobster"}},"commands":{"native":"auto","nativeSkills":"auto","restart":true,"ownerDisplay":"raw"}}
EOF
fi

# --- Create desktop launcher ---
DESKTOP="$HOME/Desktop"
if [ -d "$DESKTOP" ]; then
    LAUNCHER="$DESKTOP/黃仁蝦AI-啟動.command"
    cat > "$LAUNCHER" << EOLAUNCHER
#!/bin/bash
cd "$INSTALL_DIR"
export PATH="$INSTALL_DIR/app/runtime/$NODE_DIR_NAME/bin:\$PATH"
export OPENCLAW_HOME="$INSTALL_DIR/data"
export OPENCLAW_STATE_DIR="$INSTALL_DIR/data/.openclaw"
export OPENCLAW_CONFIG_PATH="$INSTALL_DIR/data/.openclaw/openclaw.json"

PORT=18789
while lsof -i :\$PORT >/dev/null 2>&1; do
    PORT=\$((PORT + 1))
    [ \$PORT -gt 18799 ] && echo "No available port" && exit 1
done

cd "$CORE_DIR"
"$NODE_BIN" "$OPENCLAW_MJS" gateway run --allow-unconfigured --force --port \$PORT &
PID=\$!

for i in \$(seq 1 30); do
    sleep 0.5
    if curl -s -o /dev/null "http://127.0.0.1:\$PORT/" 2>/dev/null; then
        open "http://127.0.0.1:\$PORT/#token=lobster"
        break
    fi
done

echo "OpenClaw running on port \$PORT. Press Ctrl+C to stop."
wait \$PID
EOLAUNCHER
    chmod +x "$LAUNCHER"
fi

# --- Done ---
echo ""
echo -e "  ${GREEN}+----------------------------------------------------+${NC}"
echo -e "  ${GREEN}|${NC}  ${BOLD}安裝完成！${NC}                                      ${GREEN}|${NC}"
echo -e "  ${GREEN}+----------------------------------------------------+${NC}"
echo ""
echo -e "  安裝位置：${CYAN}$INSTALL_DIR${NC}"
[ -d "$DESKTOP" ] && echo -e "  桌面已建立捷徑「黃仁蝦AI-啟動」"
echo ""
echo -e "  ${YELLOW}下一步：${NC}"
echo -e "  1. 雙擊桌面的「黃仁蝦AI-啟動」"
echo -e "  2. 瀏覽器開啟後，開始使用 AI！"
echo ""
