# Linux Shell 快速使用指南

## 快速开始

### 1. 一键安装（首次使用）

```bash
./install.sh
```

这会自动安装所有依赖并配置环境。

### 2. 基本使用

```bash
# 最简单的用法
./routetest.sh 8.8.8.8

# 带宽测试
./routetest.sh example.com -i

# 保存结果
./routetest.sh google.com -i -s
```

## 常用命令速查

| 命令 | 说明 |
|------|------|
| `./routetest.sh 8.8.8.8` | 基本路由测试 |
| `./routetest.sh google.com -i` | 路由 + 上行带宽测试 |
| `./routetest.sh example.com -i -r` | 路由 + 下行带宽测试 |
| `./routetest.sh target -i -s` | 测试并自动保存结果 |
| `./routetest.sh target -i -t 30` | 30秒带宽测试 |
| `./routetest.sh target -m 15` | 限制最大15跳 |
| `./routetest.sh -h` | 查看帮助 |
| `./routetest.sh --check` | 检查依赖 |

## Shell脚本功能

### routetest.sh - 主测试脚本

**优势：**
- 彩色输出，界面友好
- 自动检查依赖
- 参数简化，更易用
- 自动生成结果文件名
- 内置帮助信息

**示例：**
```bash
# 快速测试
./routetest.sh 1.1.1.1

# 完整测试并保存
./routetest.sh myserver.com -i -r -s

# 自定义端口和时长
./routetest.sh 192.168.1.100 -i -p 9000 -t 20
```

### install.sh - 安装脚本

**功能：**
- 自动检测系统类型（Ubuntu/Debian/CentOS/Arch等）
- 安装所有必需依赖
- 设置正确的文件权限
- 可选创建全局命令

**使用：**
```bash
chmod +x install.sh
./install.sh
```

### batch_test.sh - 批量测试脚本

**功能：**
- 一次性测试多个目标
- 自动保存所有结果
- 生成汇总报告

**使用：**
```bash
# 编辑脚本修改目标列表
nano batch_test.sh

# 运行批量测试
./batch_test.sh
```

## 高级技巧

### 1. 创建全局命令

如果在安装时选择了创建全局命令：

```bash
# 在任何目录都可以使用
routetest 8.8.8.8
routetest google.com -i -s
```

如果没有创建，手动添加：
```bash
# 创建符号链接
mkdir -p ~/.local/bin
ln -s $(pwd)/routetest.sh ~/.local/bin/routetest

# 添加到PATH（加入~/.bashrc）
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 2. 定时测试

使用cron定期测试线路：

```bash
# 编辑crontab
crontab -e

# 每天凌晨2点测试
0 2 * * * /path/to/tracerouteScripts/routetest.sh example.com -i -s >> /var/log/route_test.log 2>&1
```

### 3. 监控脚本

创建监控脚本 `monitor.sh`：
```bash
#!/bin/bash
while true; do
    echo "=== $(date) ==="
    ./routetest.sh target.com -s
    sleep 3600  # 每小时测试一次
done
```

### 4. 自定义批量测试

编辑 `batch_test.sh` 添加你的目标：

```bash
TARGETS=(
    "your-server-1.com"
    "your-server-2.com"
    "1.2.3.4"
    "5.6.7.8"
)
```

### 5. 与其他工具结合

```bash
# 测试多个DNS服务器
for dns in 8.8.8.8 1.1.1.1 114.114.114.114; do
    ./routetest.sh $dns -s
done

# 从文件读取目标列表
while IFS= read -r target; do
    ./routetest.sh "$target" -i -s
    sleep 5
done < targets.txt
```

## 结果分析

### 查看JSON结果

```bash
# 美化输出
cat result.json | python3 -m json.tool

# 提取关键信息
cat result.json | python3 -c "import json, sys; data=json.load(sys.stdin); print(f\"线路: {data['route_analysis']['route_type']} - {data['route_analysis']['route_level']}\")"

# 使用jq工具（需安装）
sudo apt install jq
cat result.json | jq '.route_analysis'
```

### 对比多次测试结果

```bash
# 列出所有结果文件
ls -lh result_*.json

# 对比线路变化
for f in result_*.json; do
    echo "$f:"
    python3 -c "import json; print(json.load(open('$f'))['route_analysis']['route_level'])"
done
```

## 故障排除

### 权限问题

```bash
# 确保脚本可执行
chmod +x *.sh *.py

# 如果traceroute需要root权限
sudo ./routetest.sh target
```

### 依赖检查

```bash
# 检查所有依赖
./routetest.sh --check

# 重新安装依赖
./install.sh
```

### Python路径问题

```bash
# 查看Python版本
python3 --version

# 如果python3不可用，尝试
which python3
# 或
whereis python3
```

## 性能优化

### 加速测试

```bash
# 减少最大跳数
./routetest.sh target -m 15

# 跳过带宽测试
./routetest.sh target  # 不加 -i

# 缩短测试时长
./routetest.sh target -i -t 5
```

### 避免API限流

```bash
# 批量测试时添加延迟
for target in $TARGETS; do
    ./routetest.sh $target -s
    sleep 10  # 等待10秒
done
```

## 输出示例

运行 `./routetest.sh 1.1.1.1` 的典型输出：

```
开始测试目标: 1.1.1.1

正在追踪到 1.1.1.1 的路由...

 1  192.168.1.1       1.2 ms  ASN/A      N/A           N/A             Private/Local
 2  10.0.0.1          5.3 ms  AS4134     China         Beijing         Chinanet
 3  202.97.33.1      15.8 ms  AS4134     China         Beijing         Chinanet
 4  1.1.1.1          28.7 ms  AS13335    United States San Francisco   Cloudflare

================================================================================
路由分析结果
================================================================================
线路类型: 电信线路
线路级别: 电信163骨干网
ASN路径: 4134 -> 4134 -> 13335
总跳数: 4

✓ 测试完成
```
