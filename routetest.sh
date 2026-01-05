#!/bin/bash
#
# 路由测试便捷脚本
# 使用方法: ./routetest.sh <目标IP/域名> [选项]
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/route_test.py"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查Python脚本是否存在
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo -e "${RED}错误: 找不到 route_test.py${NC}"
    exit 1
fi

# 确定使用的Python命令（优先使用虚拟环境）
PYTHON_CMD="python3"
if [ -d "$SCRIPT_DIR/venv" ]; then
    PYTHON_CMD="$SCRIPT_DIR/venv/bin/python"
    echo -e "${BLUE}使用虚拟环境中的Python${NC}"
fi

# 检查是否安装了Python3
if ! command -v python3 &> /dev/null && [ ! -f "$SCRIPT_DIR/venv/bin/python" ]; then
    echo -e "${RED}错误: 未安装 python3${NC}"
    echo "请安装Python3: sudo apt install python3 python3-pip"
    exit 1
fi

# 检查依赖
check_dependencies() {
    local missing_deps=0
    
    # 检查requests库
    if ! $PYTHON_CMD -c "import requests" &> /dev/null; then
        echo -e "${YELLOW}警告: 未安装 requests 库${NC}"
        echo "运行安装脚本: ./install.sh"
        echo "或手动创建虚拟环境:"
        echo "  python3 -m venv venv"
        echo "  source venv/bin/activate"
        echo "  pip install requests"
        missing_deps=1
    fi
    
    # 检查traceroute
    if ! command -v traceroute &> /dev/null; then
        echo -e "${YELLOW}警告: 未安装 traceroute${NC}"
        echo "运行: sudo apt install traceroute"
        missing_deps=1
    fi
    
    # 检查iperf3（可选）
    if ! command -v iperf3 &> /dev/null; then
        echo -e "${YELLOW}提示: 未安装 iperf3 (带宽测试需要)${NC}"
        echo "安装: sudo apt install iperf3"
    fi
    
    if [ $missing_deps -eq 1 ]; then
        echo ""
        read -p "是否继续? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
${GREEN}路由测试工具 - 便捷Shell脚本${NC}

${BLUE}使用方法:${NC}
  ./routetest.sh <目标> [选项]

${BLUE}常用命令:${NC}
  ./routetest.sh 8.8.8.8              # 基本路由测试
  ./routetest.sh google.com -i        # 路由测试 + 带宽测试
  ./routetest.sh 1.1.1.1 -i -r        # 路由测试 + 下行带宽
  ./routetest.sh example.com -s       # 保存结果到自动命名文件
  ./routetest.sh -h                   # 显示此帮助

${BLUE}选项:${NC}
  -i, --iperf         执行iperf3带宽测试
  -r, --reverse       iperf3反向测试(下行)
  -p PORT             iperf3端口 (默认: 5201)
  -t SECONDS          iperf3测试时长 (默认: 10)
  -m HOPS             最大跳数 (默认: 30)
  -s, --save          自动保存结果到文件
  -o FILE             指定输出文件名
  -h, --help          显示帮助信息
  --check             检查依赖安装情况
  --install           安装所有依赖

${BLUE}示例:${NC}
  # 快速测试到目标的路由
  ./routetest.sh 1.1.1.1
  
  # 完整测试并保存结果
  ./routetest.sh myserver.com -i -s
  
  # 下行带宽测试，30秒
  ./routetest.sh speedtest.example.com -i -r -t 30
  
  # 自定义iperf3端口
  ./routetest.sh 192.168.1.100 -i -p 9000

EOF
}

# 安装依赖
install_deps() {
    echo -e "${GREEN}正在安装依赖...${NC}"
    
    # 检查是否为root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}某些操作需要sudo权限${NC}"
        SUDO="sudo"
    else
        SUDO=""
    fi
    
    # 安装系统包
    echo "安装系统包..."
    $SUDO apt update
    $SUDO apt install -y python3 python3-pip traceroute iperf3
    
    # 安装Python包
    echo "安装Python依赖..."
    pip3 install -r "$SCRIPT_DIR/requirements.txt"
    
    echo -e "${GREEN}依赖安装完成！${NC}"
}

# 主函数
main() {
    # 特殊命令处理
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        show_help
        exit 0
    fi
    
    if [ "$1" == "--check" ]; then
        check_dependencies
        echo -e "${GREEN}依赖检查完成${NC}"
        exit 0
    fi
    
    if [ "$1" == "--install" ]; then
        install_deps
        exit 0
    fi
    
    # 检查是否提供了目标
    if [ -z "$1" ]; then
        echo -e "${RED}错误: 请提供目标IP或域名${NC}"
        echo "使用 ./routetest.sh -h 查看帮助"
        exit 1
    fi
    
    TARGET="$1"
    shift
    
    # 构建参数
    ARGS=()
    AUTO_SAVE=0
    OUTPUT_FILE=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--save)
                AUTO_SAVE=1
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -o)
                OUTPUT_FILE="$2"
                ARGS+=("-o" "$2")
                shift 2
                ;;
            *)
                ARGS+=("$1")
                shift
                ;;
        esac
    done
    
    # 自动保存文件名
    if [ $AUTO_SAVE -eq 1 ] && [ -z "$OUTPUT_FILE" ]; then
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        SAFE_TARGET=$(echo "$TARGET" | sed 's/[^a-zA-Z0-9._-]/_/g')
        OUTPUT_FILE="result_${SAFE_TARGET}_${TIMESTAMP}.json"
        ARGS+=("-o" "$OUTPUT_FILE")
        echo -e "${BLUE}结果将保存到: $OUTPUT_FILE${NC}\n"
    $PYTHON_CMD
    
    # 执行Python脚本
    echo -e "${GREEN}开始测试目标: $TARGET${NC}\n"
    python3 "$PYTHON_SCRIPT" "$TARGET" "${ARGS[@]}"
    
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "\n${GREEN}✓ 测试完成${NC}"
        if [ -n "$OUTPUT_FILE" ]; then
            echo -e "${BLUE}结果已保存到: $OUTPUT_FILE${NC}"
        fi
    else
        echo -e "\n${RED}✗ 测试失败 (退出码: $EXIT_CODE)${NC}"
    fi
    
    exit $EXIT_CODE
}

# 运行主函数
main "$@"
