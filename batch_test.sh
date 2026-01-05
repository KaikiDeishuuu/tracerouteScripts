#!/bin/bash
#
# 批量测试脚本示例
# 对多个目标进行路由测试
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="$SCRIPT_DIR/batch_results_$TIMESTAMP"

# 测试目标列表
TARGETS=(
    "8.8.8.8"           # Google DNS
    "1.1.1.1"           # Cloudflare DNS
    "114.114.114.114"   # 114 DNS
    "baidu.com"         # 百度
    "google.com"        # Google
)

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

echo "开始批量测试..."
echo "结果将保存到: $OUTPUT_DIR"
echo ""

# 循环测试每个目标
for target in "${TARGETS[@]}"; do
    echo "========================================"
    echo "测试目标: $target"
    echo "========================================"
    
    # 清理目标名称用于文件名
    safe_name=$(echo "$target" | sed 's/[^a-zA-Z0-9._-]/_/g')
    output_file="$OUTPUT_DIR/${safe_name}.json"
    
    # 执行测试（不包含iperf3，加快速度）
    "$SCRIPT_DIR/routetest.sh" "$target" -o "$output_file"
    
    echo ""
    sleep 2  # 短暂延迟避免API限流
done

echo "========================================"
echo "批量测试完成！"
echo "结果保存在: $OUTPUT_DIR"
echo "========================================"

# 生成汇总报告
summary_file="$OUTPUT_DIR/summary.txt"
echo "测试汇总报告" > "$summary_file"
echo "时间: $(date)" >> "$summary_file"
echo "======================================" >> "$summary_file"
echo "" >> "$summary_file"

for target in "${TARGETS[@]}"; do
    safe_name=$(echo "$target" | sed 's/[^a-zA-Z0-9._-]/_/g')
    output_file="$OUTPUT_DIR/${safe_name}.json"
    
    if [ -f "$output_file" ]; then
        route_type=$(python3 -c "import json; data=json.load(open('$output_file')); print(data.get('route_analysis', {}).get('route_type', 'N/A'))" 2>/dev/null || echo "N/A")
        route_level=$(python3 -c "import json; data=json.load(open('$output_file')); print(data.get('route_analysis', {}).get('route_level', 'N/A'))" 2>/dev/null || echo "N/A")
        hop_count=$(python3 -c "import json; data=json.load(open('$output_file')); print(len(data.get('hops', [])))" 2>/dev/null || echo "N/A")
        
        echo "$target:" >> "$summary_file"
        echo "  线路类型: $route_type" >> "$summary_file"
        echo "  线路级别: $route_level" >> "$summary_file"
        echo "  跳数: $hop_count" >> "$summary_file"
        echo "" >> "$summary_file"
    fi
done

echo "汇总报告已生成: $summary_file"
cat "$summary_file"
