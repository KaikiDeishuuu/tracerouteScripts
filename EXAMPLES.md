# 去程路由测试工具示例

## 示例1: 测试到CloudFlare DNS的路由

```bash
python route_test.py 1.1.1.1
```

预期输出:
```
正在追踪到 1.1.1.1 的路由...

 1  192.168.1.1       1.5 ms  ASN/A      N/A           N/A             Private/Local
 2  10.0.0.1          8.2 ms  AS4134     China         Beijing         Chinanet
 3  202.97.33.1      12.5 ms  AS4134     China         Beijing         Chinanet
 4  202.97.94.1      25.3 ms  AS4809     China         Shanghai        Chinanet
 5  1.1.1.1          28.7 ms  AS13335    United States San Francisco   Cloudflare

================================================================================
路由分析结果
================================================================================
线路类型: CN2线路
线路级别: CN2 GIA/GT
ASN路径: 4134 -> 4809 -> 13335
总跳数: 5
CN2节点数: 1
```

## 示例2: 测试联通线路

```bash
python route_test.py -m 20 www.google.com
```

可能的输出:
```
域名 www.google.com 解析为: 142.250.185.68

正在追踪到 142.250.185.68 的路由...

 1  192.168.1.1       1.2 ms  ASN/A      N/A           N/A             Private/Local
 2  10.20.30.1        5.8 ms  AS4837     China         Beijing         China Unicom
 3  219.158.3.1      15.2 ms  AS9929     China         Beijing         China Unicom
 4  219.158.98.1     45.3 ms  AS9929     China         Hong Kong       China Unicom
 5  142.250.185.68   48.5 ms  AS15169    United States Mountain View   Google LLC

================================================================================
路由分析结果
================================================================================
线路类型: 联通线路
线路级别: AS9929(联通A网)
ASN路径: 4837 -> 9929 -> 9929 -> 15169
总跳数: 5
AS9929节点数: 2
```

## 示例3: 带宽测试(需要iperf3服务器)

假设你在服务器上运行了iperf3服务:
```bash
# 在服务器上
iperf3 -s
```

然后在客户端测试:
```bash
# 上行带宽测试
python route_test.py example.com -i -t 10

# 下行带宽测试
python route_test.py example.com -i -r -t 10
```

输出:
```
正在追踪到 example.com 的路由...
[路由信息...]

================================================================================
路由分析结果
================================================================================
线路类型: CN2线路
线路级别: CN2 GIA/GT
[其他分析...]

正在进行iperf3带宽测试 (example.com:5201)...
测试方向: 上行 (客户端 -> 服务器)

================================================================================
iperf3带宽测试结果
================================================================================
上行带宽: 95.34 Mbps
发送数据: 112.50 MB
```

## 示例4: 完整测试并保存结果

```bash
python route_test.py 8.8.8.8 -i -t 20 -o test_results_20260105.json
```

这将:
1. 追踪到8.8.8.8的路由
2. 识别所有跳点的ASN和位置
3. 分析线路类型
4. 进行20秒的上行带宽测试
5. 保存所有结果到JSON文件

输出的JSON文件示例:
```json
{
  "target": "8.8.8.8",
  "target_ip": "8.8.8.8",
  "timestamp": "2026-01-05 14:30:25",
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
    },
    {
      "hop": 2,
      "ip": "10.0.0.1",
      "rtt": "8.5",
      "asn": "4134",
      "as_name": "Chinanet",
      "country": "China",
      "city": "Beijing",
      "isp": "China Telecom"
    },
    {
      "hop": 3,
      "ip": "202.97.33.1",
      "rtt": "15.3",
      "asn": "4809",
      "as_name": "Chinanet",
      "country": "China",
      "city": "Shanghai",
      "isp": "China Telecom CN2"
    },
    {
      "hop": 4,
      "ip": "8.8.8.8",
      "rtt": "28.7",
      "asn": "15169",
      "as_name": "Google LLC",
      "country": "United States",
      "city": "Mountain View",
      "isp": "Google LLC"
    }
  ],
  "route_analysis": {
    "route_type": "CN2线路",
    "route_level": "CN2 GIA/GT",
    "asn_path": "4134 -> 4809 -> 15169",
    "cn2_hops": 1,
    "as9929_hops": 0,
    "cmcc_hops": 0
  },
  "iperf_result": {
    "sent_mbps": 98.76,
    "received_mbps": 0.0,
    "sent_bytes": 123450000,
    "received_bytes": 0
  }
}
```

## 示例5: 测试不同端口的iperf3服务器

如果iperf3服务器运行在非标准端口:
```bash
# 服务器端
iperf3 -s -p 9000

# 客户端测试
python route_test.py example.com -i -p 9000 -t 15
```

## 批量测试脚本示例

创建一个批处理脚本测试多个目标:

**Windows (test_multiple.bat):**
```batch
@echo off
python route_test.py 1.1.1.1 -i -o result_cloudflare.json
python route_test.py 8.8.8.8 -i -o result_google.json
python route_test.py www.bing.com -i -o result_bing.json
echo 所有测试完成!
```

**Linux/Mac (test_multiple.sh):**
```bash
#!/bin/bash
python3 route_test.py 1.1.1.1 -i -o result_cloudflare.json
python3 route_test.py 8.8.8.8 -i -o result_google.json
python3 route_test.py www.bing.com -i -o result_bing.json
echo "所有测试完成!"
```

## 使用技巧

### 1. 快速诊断线路质量
```bash
# 只看路由，不做带宽测试
python route_test.py your-vps-ip
```

### 2. 完整性能测试
```bash
# 路由 + 双向带宽测试
python route_test.py your-vps-ip -i -t 30 -o full_test.json
python route_test.py your-vps-ip -i -r -t 30 -o full_test_download.json
```

### 3. 监控线路变化
定期运行并保存结果，对比不同时间的路由路径:
```bash
python route_test.py target.com -o result_$(date +%Y%m%d_%H%M%S).json
```

### 4. 限制跳数节省时间
如果只关心前几跳:
```bash
python route_test.py target.com -m 10
```
