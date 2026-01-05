#!/bin/bash
#
# 一键安装脚本 - 路由测试工具
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}路由测试工具 - 安装脚本${NC}"
echo -e "${BLUE}=================================${NC}\n"

# 检测系统
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo -e "${RED}无法检测操作系统${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}检测到系统: $OS $VERSION${NC}\n"
}

# 检查权限
check_permissions() {
    if [ "$EUID" -eq 0 ]; then
        echo -e "${YELLOW}检测到root权限${NC}"
        SUDO=""
    else
        echo -e "${YELLOW}需要sudo权限安装系统包${NC}"
        SUDO="sudo"
        
        # 检查sudo是否可用
        if ! command -v sudo &> /dev/null; then
            echo -e "${RED}错误: 未安装sudo，请使用root用户运行此脚本${NC}"
            exit 1
        fi
    fi
}

# 安装系统依赖
install_system_deps() {
    echo -e "${GREEN}[1/4] 安装系统依赖...${NC}"
    
    case $OS in
        ubuntu|debian)
            echo "更新包列表..."
            $SUDO apt update
            
            echo "安装必需包..."
            $SUDO apt install -y python3 python3-pip traceroute
            
            echo "安装iperf3 (可选)..."
            $SUDO apt install -y iperf3 || echo -e "${YELLOW}iperf3安装失败，将跳过带宽测试功能${NC}"
            ;;
            
        centos|rhel|fedora)
            echo "安装必需包..."
            $SUDO yum install -y python3 python3-pip traceroute
            
            echo "安装iperf3 (可选)..."
            $SUDO yum install -y iperf3 || echo -e "${YELLOW}iperf3安装失败，将跳过带宽测试功能${NC}"
            ;;
            
        arch|manjaro)
            echo "安装必需包..."
            $SUDO pacman -S --noconfirm python python-pip traceroute
            
            echo "安装iperf3 (可选)..."
            $SUDO pacman -S --noconfirm iperf3 || echo -e "${YELLOW}iperf3安装失败，将跳过带宽测试功能${NC}"
            ;;
            
        *)
            echo -e "${YELLOW}未识别的系统: $OS${NC}"
            echo "请手动安装: python3, python3-pip, traceroute, iperf3"
            read -p "是否继续? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            ;;
    esac
    
    echo -e "${GREEN}✓ 系统依赖安装完成${NC}\n"
}

# 安装Python依赖
install_python_deps() {
    echo -e "${GREEN}[2/4] 安装Python依赖...${NC}"
    
    if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
        pip3 install --user -r "$SCRIPT_DIR/requirements.txt"
        echo -e "${GREEN}✓ Python依赖安装完成${NC}\n"
    else
        echo -e "${YELLOW}未找到 requirements.txt，手动安装...${NC}"
        pip3 install --user requests
        echo -e "${GREEN}✓ Python依赖安装完成${NC}\n"
    fi
}

# 设置脚本权限
setup_permissions() {
    echo -e "${GREEN}[3/4] 设置脚本权限...${NC}"
    
    chmod +x "$SCRIPT_DIR/route_test.py"
    chmod +x "$SCRIPT_DIR/routetest.sh"
    
    echo -e "${GREEN}✓ 权限设置完成${NC}\n"
}

# 创建符号链接（可选）
setup_symlink() {
    echo -e "${GREEN}[4/4] 配置快捷命令...${NC}"
    
    read -p "是否创建全局命令 'routetest'? (y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local BIN_DIR="$HOME/.local/bin"
        
        # 确保目录存在
        mkdir -p "$BIN_DIR"
        
        # 创建符号链接
        ln -sf "$SCRIPT_DIR/routetest.sh" "$BIN_DIR/routetest"
        
        # 检查PATH
        if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
            echo -e "${YELLOW}请将以下内容添加到 ~/.bashrc 或 ~/.zshrc:${NC}"
            echo -e "${BLUE}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
            echo ""
            echo "然后运行: source ~/.bashrc"
        fi
        
        echo -e "${GREEN}✓ 已创建命令 'routetest'${NC}"
        echo -e "${BLUE}使用 'routetest -h' 查看帮助${NC}\n"
    else
        echo -e "${BLUE}跳过符号链接创建${NC}"
        echo -e "${BLUE}使用 './routetest.sh' 运行脚本${NC}\n"
    fi
}

# 验证安装
verify_installation() {
    echo -e "${BLUE}=================================${NC}"
    echo -e "${GREEN}验证安装...${NC}"
    echo -e "${BLUE}=================================${NC}\n"
    
    local all_ok=1
    
    # 检查Python3
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version)
        echo -e "${GREEN}✓ Python3: $PYTHON_VERSION${NC}"
    else
        echo -e "${RED}✗ Python3 未安装${NC}"
        all_ok=0
    fi
    
    # 检查requests
    if python3 -c "import requests" &> /dev/null; then
        echo -e "${GREEN}✓ requests 库已安装${NC}"
    else
        echo -e "${RED}✗ requests 库未安装${NC}"
        all_ok=0
    fi
    
    # 检查traceroute
    if command -v traceroute &> /dev/null; then
        echo -e "${GREEN}✓ traceroute 已安装${NC}"
    else
        echo -e "${YELLOW}⚠ traceroute 未安装${NC}"
    fi
    
    # 检查iperf3
    if command -v iperf3 &> /dev/null; then
        echo -e "${GREEN}✓ iperf3 已安装${NC}"
    else
        echo -e "${YELLOW}⚠ iperf3 未安装 (带宽测试将不可用)${NC}"
    fi
    
    echo ""
    
    if [ $all_ok -eq 1 ]; then
        echo -e "${GREEN}=================================${NC}"
        echo -e "${GREEN}✓ 安装成功！${NC}"
        echo -e "${GREEN}=================================${NC}\n"
        
        echo -e "${BLUE}快速开始:${NC}"
        echo -e "  cd $SCRIPT_DIR"
        echo -e "  ./routetest.sh 8.8.8.8"
        echo -e ""
        echo -e "${BLUE}查看帮助:${NC}"
        echo -e "  ./routetest.sh -h"
        echo -e ""
    else
        echo -e "${RED}安装遇到问题，请检查上述错误${NC}"
        exit 1
    fi
}

# 主流程
main() {
    detect_system
    check_permissions
    install_system_deps
    install_python_deps
    setup_permissions
    setup_symlink
    verify_installation
}

# 运行
main
