# 去程路由测试工具

一个功能强大的去程路由测试脚本，支持ASN识别、地区查询、线路级别分析和iperf3带宽测试。

## 功能特性

- ✅ **路由追踪**: 追踪到目标主机的完整路由路径
- ✅ **ASN识别**: 自动识别每个跳点的ASN（自治系统号）
- ✅ **地理位置**: 显示每个跳点的国家和城市信息
- ✅ **线路识别**: 智能识别线路类型和级别
  - CN2 GIA/GT
  - CN2普通线路
  - 联通AS9929 (A网)
  - 联通169骨干网
  - 电信163骨干网
  - 移动骨干网
- ✅ **延迟测量**: 显示每个跳点的往返延迟(RTT)
- ✅ **带宽测试**: 集成iperf3进行上行/下行带宽测试
- ✅ **结果导出**: 支持将测试结果保存为JSON格式

## 系统要求

### Windows
- Python 3.6+
- requests库
- iperf3 (可选，用于带宽测试)

### Linux/Mac
- Python 3.6+
- requests库
- traceroute命令
- iperf3 (可选，用于带宽测试)

## 安装

### Linux 一键安装（推荐）

```bash
# 运行安装脚本，自动安装所有依赖
chmod +x install.sh
./install.sh
```

安装脚本会自动：
- 检测系统类型（Ubuntu/Debian/CentOS/Arch等）
- 安装系统依赖（python3, traceroute, iperf3）
- 安装Python依赖（requests）
- 自动处理Python 3.11+的externally-managed-environment问题
- 必要时自动创建虚拟环境
- 设置脚本权限
- 可选创建全局命令 `routetest`

**注意**: 在较新的Debian/Ubuntu系统（Python 3.11+），安装脚本会自动创建虚拟环境以避免系统包管理冲突。

### 手动安装

#### 1. 安装Python依赖

**Python 3.11+系统（推荐使用虚拟环境）：**

如果遇到 `externally-managed-environment` 错误，使用虚拟环境：

```bash
# 安装虚拟环境支持
sudo apt install -y python3-full python3-venv

# 创建虚拟环境
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt

# 使用完后可以停用
deactivate
```

**旧版Python系统：**

```bash
pip3 install --user requests
# 或
pip3 install --user -r requirements.txt
```

**注意**: `routetest.sh` 脚本会自动检测并使用虚拟环境（如果存在）。

#### 2. 安装系统依赖

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install python3 python3-pip traceroute iperf3
```

**Linux (CentOS/RHEL):**
```bash
sudo yum install python3 python3-pip traceroute iperf3
```

**Linux (Arch):**
```bash
sudo pacman -S python python-pip traceroute iperf3
```

**Windows:**
从 [iperf.fr](https://iperf.fr/iperf-download.php) 下载并安装iperf3

**Mac:**
```bash
brew install python3 traceroute iperf3
```

## 使用方法

### Linux 便捷方式（推荐）

使用 `routetest.sh` 脚本，更加简便：

```bash
# 基本路由测试
./routetest.sh 8.8.8.8

# 路由测试 + 带宽测试
./routetest.sh example.com -i

# 路由测试 + 下行带宽测试
./routetest.sh example.com -i -r

# 自动保存结果（自动生成文件名）
./routetest.sh google.com -i -s

# 自定义测试参数
./routetest.sh example.com -i -t 30 -p 5201

# 查看帮助
./routetest.sh -h

# 检查依赖
./routetest.sh --check
```

如果运行了安装脚本并创建了全局命令，可以直接使用：
```bash
routetest 8.8.8.8
routetest google.com -i -s
```

### 批量测试

```bash
# 编辑 batch_test.sh 中的目标列表，然后运行
./batch_test.sh
```

### 直接使用Python脚本

```bash
# 追踪路由到指定主机
python3 route_test.py 8.8.8.8

# 追踪路由到域名
python3 route_test.py google.com

# 路由追踪 + iperf3上行带宽测试
python3 route_test.py example.com -i

# 路由追踪 + iperf3下行带宽测试
python3 route_test.py example.com -i -r

# 自定义iperf3端口和测试时长
python3 route_test.py example.com -i -p 5201 -t 30

# 保存结果到文件
python3 route_test.py example.com -i -o result.json
```

### 命令行参数

```
必需参数:
  target              目标主机IP或域名

可选参数:
  -h, --help          显示帮助信息
  -m, --max-hops N    最大跳数 (默认: 30)
  -i, --iperf         执行iperf3带宽测试
  -p, --port PORT     iperf3端口 (默认: 5201)
  -t, --time SECONDS  iperf3测试时长(秒) (默认: 10)
  -r, --reverse       iperf3反向测试(下行带宽)
  -o, --output FILE   保存结果到JSON文件
```

## 使用示例

### 示例1: 基本路由追踪

```bash
python route_test.py 1.1.1.1
```

输出示例:
```
正在追踪到 1.1.1.1 的路由...

 1  192.168.1.1       1.2 ms  ASN/A      N/A           N/A             Private/Local
 2  10.0.0.1          5.3 ms  AS4134     China         Beijing         Chinanet
 3  202.97.33.1      15.8 ms  AS4134     China         Beijing         Chinanet
...

================================================================================
路由分析结果
================================================================================
线路类型: 电信线路
线路级别: 电信163骨干网
ASN路径: 4134 -> 4134 -> 13335
总跳数: 15
```

### 示例2: 完整测试(路由+带宽)

```bash
python route_test.py speedtest.example.com -i -t 20 -o results.json
```

这将:
1. 追踪到目标的完整路由
2. 识别每个跳点的ASN和地理位置
3. 分析线路类型和级别
4. 进行20秒的iperf3带宽测试
5. 将所有结果保存到results.json

## 线路类型说明

### CN2线路
- **CN2 GIA/GT**: 最优质的电信出国线路，AS4809
- **CN2**: 电信CN2线路，使用AS4809或部分AS4134

### 联通线路
- **AS9929 (联通A网)**: 联通高质量出国线路
- **联通169骨干网**: 联通普通骨干网，AS4837/AS10099

### 电信线路
- **电信163骨干网**: 电信普通骨干网，AS4134

### 移动线路
- **移动骨干网**: 中国移动骨干网，AS9808/AS56040

## 注意事项

1. **管理员权限**: Windows可能需要管理员权限运行
2. **防火墙**: 确保防火墙允许ICMP和iperf3端口
3. **API限流**: IP查询使用公共API，频繁查询可能被限流
4. **iperf3服务器**: 带宽测试需要目标主机运行iperf3服务器

## 输出文件格式

使用 `-o` 参数保存的JSON文件包含:

```json
{
  "target": "example.com",
  "target_ip": "1.2.3.4",
  "timestamp": "2026-01-05 12:00:00",
  "hops": [
    {
      "hop": 1,
      "ip": "192.168.1.1",
      "rtt": "1.2",
      "asn": "N/A",
      "as_name": "Private/Local",
      "country": "N/A",
      "city": "N/A",
      "isp": "N/A"
    }
  ],
  "route_analysis": {
    "route_type": "电信线路",
    "route_level": "CN2 GIA/GT",
    "asn_path": "4134 -> 4809 -> 13335",
    "cn2_hops": 2,
    "as9929_hops": 0,
    "cmcc_hops": 0
  },
  "iperf_result": {
    "sent_mbps": 95.3,
    "received_mbps": 0,
    "sent_bytes": 119125000,
    "received_bytes": 0
  }
}
```

## 故障排除

### Windows下tracert速度慢
Windows的tracert默认会进行DNS反向查询，已使用`-d`参数禁用。

### iperf3连接失败
确保:
1. 目标服务器运行了iperf3服务: `iperf3 -s`
2. 防火墙允许指定端口(默认5201)
3. 使用正确的端口号

### ASN查询失败
- 检查网络连接
- 等待一段时间后重试(可能是API限流)
- 脚本会缓存查询结果避免重复请求

## 许可证

MIT License

## 作者

tracerouteScripts

## 更新日志

### v1.0.0 (2026-01-05)
- 初始版本
- 支持路由追踪
- ASN和地理位置识别
- 线路级别分析
- iperf3带宽测试集成
