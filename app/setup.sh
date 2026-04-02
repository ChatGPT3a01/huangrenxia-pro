#!/bin/bash
# =====================================================
#  隨身黃仁蝦AI系統 — 開發環境設置（下載 Node.js + npm install）
#  在 Mac 上執行此腳本以準備 runtime
#  Usage: bash app/setup.sh [--all-platforms]
# =====================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
RUNTIME_DIR="$SCRIPT_DIR/runtime"
CORE_DIR="$SCRIPT_DIR/core"

NODE_VER="v22.16.0"
NODE_MIRROR="https://nodejs.org/dist"

ALL_PLATFORMS=false
[ "$1" = "--all-platforms" ] && ALL_PLATFORMS=true

echo ""
echo -e "  ${BOLD}=== 隨身黃仁蝦AI系統 — 開發環境設置 ===${NC}"
echo ""

OS=$(uname -s)
ARCH=$(uname -m)

# Determine current platform
if [ "$OS" = "Darwin" ]; then
    if [ "$ARCH" = "arm64" ]; then
        CURRENT_PLATFORM="darwin-arm64"
        CURRENT_DIR="node-mac-arm64"
    else
        CURRENT_PLATFORM="darwin-x64"
        CURRENT_DIR="node-mac-x64"
    fi
elif [ "$OS" = "Linux" ]; then
    CURRENT_PLATFORM="linux-x64"
    CURRENT_DIR="node-linux-x64"
else
    echo -e "  ${RED}請在 Mac 或 Linux 上執行此腳本。Windows 請用 setup.bat${NC}"
    exit 1
fi

download_node() {
    local platform="$1" dir_name="$2"
    local target="$RUNTIME_DIR/$dir_name"

    if [ -f "$target/bin/node" ] || [ -f "$target/node.exe" ]; then
        echo -e "  ${GREEN}$dir_name: 已存在，跳過${NC}"
        return
    fi

    echo -e "  ${CYAN}下載 Node.js $NODE_VER ($platform)...${NC}"
    mkdir -p "$target"

    if [[ "$platform" == *"win"* ]]; then
        # Windows: download zip
        local url="${NODE_MIRROR}/${NODE_VER}/node-${NODE_VER}-${platform}.zip"
        curl -# -L "$url" -o "/tmp/node-${platform}.zip"
        cd /tmp
        unzip -q "node-${platform}.zip"
        cp -R "node-${NODE_VER}-${platform}/"* "$target/"
        rm -rf "node-${platform}.zip" "node-${NODE_VER}-${platform}"
    else
        # Unix: download tar.gz
        local url="${NODE_MIRROR}/${NODE_VER}/node-${NODE_VER}-${platform}.tar.gz"
        curl -# -L "$url" -o "/tmp/node-${platform}.tar.gz"
        tar -xzf "/tmp/node-${platform}.tar.gz" -C "$target" --strip-components=1
        rm -f "/tmp/node-${platform}.tar.gz"
        chmod +x "$target/bin/node"
    fi

    echo -e "  ${GREEN}$dir_name: 完成${NC}"
}

# Download Node.js for current platform
echo -e "  ${BOLD}[1/2] 下載 Node.js Runtime${NC}"
download_node "$CURRENT_PLATFORM" "$CURRENT_DIR"

if [ "$ALL_PLATFORMS" = "true" ]; then
    echo -e "  ${CYAN}下載所有平台的 Node.js...${NC}"
    [ "$CURRENT_DIR" != "node-mac-arm64" ] && download_node "darwin-arm64" "node-mac-arm64"
    [ "$CURRENT_DIR" != "node-mac-x64" ] && download_node "darwin-x64" "node-mac-x64"
    download_node "win-x64" "node-win-x64"
fi

# Install OpenClaw
echo ""
echo -e "  ${BOLD}[2/2] 安裝 OpenClaw${NC}"

if [ -f "$CORE_DIR/node_modules/openclaw/openclaw.mjs" ]; then
    echo -e "  ${GREEN}OpenClaw: 已安裝${NC}"
else
    NODE_BIN="$RUNTIME_DIR/$CURRENT_DIR/bin/node"
    NPM_BIN="$RUNTIME_DIR/$CURRENT_DIR/bin/npm"
    export PATH="$RUNTIME_DIR/$CURRENT_DIR/bin:$PATH"

    cd "$CORE_DIR"
    echo -e "  ${CYAN}npm install...${NC}"
    "$NPM_BIN" install 2>&1 | tail -3
    echo -e "  ${GREEN}OpenClaw: 安裝完成${NC}"
fi

echo ""
echo -e "  ${GREEN}設置完成！${NC}"
echo ""
