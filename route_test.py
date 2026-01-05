#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
去程路由测试脚本
功能：
- 追踪去程路由
- 识别ASN、地区
- 识别线路级别（骨干网、CN2、9929等）
- 测量延迟
- 集成iperf3带宽测试
"""

import subprocess
import re
import json
import sys
import time
import ipaddress
from typing import List, Dict, Optional, Tuple
import argparse
import socket

try:
    import requests
except ImportError:
    print("请安装 requests 库: pip install requests")
    sys.exit(1)


class ASNResolver:
    """ASN解析器，用于查询IP的ASN和地理位置信息"""
    
    def __init__(self):
        self.cache = {}
        
    def query_ip_info(self, ip: str) -> Dict:
        """查询IP的ASN和地理信息"""
        if ip in self.cache:
            return self.cache[ip]
        
        # 跳过私有IP
        try:
            ip_obj = ipaddress.ip_address(ip)
            if ip_obj.is_private or ip_obj.is_loopback:
                return {
                    'asn': 'N/A',
                    'as_name': 'Private/Local',
                    'country': 'N/A',
                    'city': 'N/A',
                    'isp': 'N/A'
                }
        except:
            pass
        
        info = {
            'asn': 'Unknown',
            'as_name': 'Unknown',
            'country': 'Unknown',
            'city': 'Unknown',
            'isp': 'Unknown'
        }
        
        try:
            # 使用ip-api.com获取基本信息
            response = requests.get(
                f'http://ip-api.com/json/{ip}?fields=status,country,countryCode,city,isp,as,org',
                timeout=5
            )
            
            if response.status_code == 200:
                data = response.json()
                if data.get('status') == 'success':
                    as_info = data.get('as', '')
                    if as_info:
                        # 解析 "AS15169 Google LLC" 格式
                        match = re.match(r'AS(\d+)\s+(.*)', as_info)
                        if match:
                            info['asn'] = match.group(1)
                            info['as_name'] = match.group(2)
                    
                    info['country'] = data.get('country', 'Unknown')
                    info['city'] = data.get('city', 'Unknown')
                    info['isp'] = data.get('isp', data.get('org', 'Unknown'))
            
            # 短暂延迟避免API限流
            time.sleep(0.2)
            
        except Exception as e:
            print(f"查询IP {ip} 信息失败: {e}", file=sys.stderr)
        
        self.cache[ip] = info
        return info


class RouteAnalyzer:
    """路由分析器，识别线路级别"""
    
    # CN2线路特征ASN
    CN2_ASNS = {
        '4809',  # 中国电信CN2
        '4134',  # 中国电信骨干网（部分CN2）
    }
    
    # AS4837（联通9929）
    AS9929_ASNS = {
        '9929',  # 联通A网
        '4837',  # 联通骨干网
    }
    
    # 中国移动
    CMCC_ASNS = {
        '9808',  # 中国移动
        '56040', # 中国移动国际
        '58453', # 中国移动
    }
    
    # 中国电信骨干网
    CT_BACKBONE_ASNS = {
        '4134',  # 中国电信骨干网
        '4812',  # 中国电信
    }
    
    # 中国联通骨干网
    CU_BACKBONE_ASNS = {
        '4808',  # 中国联通
        '4837',  # 中国联通
        '10099', # 中国联通
    }
    
    @staticmethod
    def identify_route_type(hops: List[Dict]) -> Dict:
        """识别路由类型和线路级别"""
        cn2_count = 0
        as9929_count = 0
        cmcc_count = 0
        ct_backbone_count = 0
        cu_backbone_count = 0
        
        asn_list = []
        
        for hop in hops:
            asn = hop.get('asn', '')
            if asn and asn != 'N/A' and asn != 'Unknown':
                asn_list.append(asn)
                
                if asn in RouteAnalyzer.CN2_ASNS:
                    cn2_count += 1
                if asn in RouteAnalyzer.AS9929_ASNS:
                    as9929_count += 1
                if asn in RouteAnalyzer.CMCC_ASNS:
                    cmcc_count += 1
                if asn in RouteAnalyzer.CT_BACKBONE_ASNS:
                    ct_backbone_count += 1
                if asn in RouteAnalyzer.CU_BACKBONE_ASNS:
                    cu_backbone_count += 1
        
        # 判断线路类型
        route_type = "国际线路"
        route_level = "未知"
        
        if cn2_count > 0:
            route_type = "CN2线路"
            if '4809' in asn_list:
                route_level = "CN2 GIA/GT"
            else:
                route_level = "CN2"
        elif as9929_count > 0:
            route_type = "联通线路"
            if '9929' in asn_list:
                route_level = "AS9929(联通A网)"
            else:
                route_level = "联通普通线路"
        elif cmcc_count > 0:
            route_type = "移动线路"
            route_level = "移动骨干网"
        elif ct_backbone_count > 0:
            route_type = "电信线路"
            route_level = "电信163骨干网"
        elif cu_backbone_count > 0:
            route_type = "联通线路"
            route_level = "联通169骨干网"
        
        return {
            'route_type': route_type,
            'route_level': route_level,
            'asn_path': ' -> '.join(asn_list) if asn_list else 'N/A',
            'cn2_hops': cn2_count,
            'as9929_hops': as9929_count,
            'cmcc_hops': cmcc_count,
        }


class RouteTracer:
    """路由追踪器"""
    
    def __init__(self, target: str, max_hops: int = 30):
        self.target = target
        self.max_hops = max_hops
        self.asn_resolver = ASNResolver()
        
    def traceroute(self) -> List[Dict]:
        """执行traceroute并解析结果"""
        print(f"\n正在追踪到 {self.target} 的路由...\n")
        
        hops = []
        
        # Windows使用tracert，Linux/Mac使用traceroute
        if sys.platform == 'win32':
            cmd = ['tracert', '-d', '-h', str(self.max_hops), self.target]
        else:
            cmd = ['traceroute', '-n', '-m', str(self.max_hops), self.target]
        
        try:
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding='utf-8',
                errors='ignore'
            )
            
            hop_num = 0
            for line in process.stdout:
                line = line.strip()
                if not line:
                    continue
                
                # 解析tracert/traceroute输出
                hop_info = self._parse_hop_line(line, hop_num)
                if hop_info:
                    hop_num = hop_info['hop']
                    
                    # 查询ASN信息
                    if hop_info['ip'] and hop_info['ip'] != '*':
                        ip_info = self.asn_resolver.query_ip_info(hop_info['ip'])
                        hop_info.update(ip_info)
                    else:
                        hop_info.update({
                            'asn': 'N/A',
                            'as_name': 'N/A',
                            'country': 'N/A',
                            'city': 'N/A',
                            'isp': 'N/A'
                        })
                    
                    hops.append(hop_info)
                    self._print_hop(hop_info)
            
            process.wait()
            
        except FileNotFoundError:
            print(f"错误: 未找到traceroute命令")
            return []
        except Exception as e:
            print(f"执行traceroute时出错: {e}")
            return []
        
        return hops
    
    def _parse_hop_line(self, line: str, current_hop: int) -> Optional[Dict]:
        """解析traceroute输出行"""
        # Windows tracert格式: "  1    <1 ms    <1 ms    <1 ms  192.168.1.1"
        # Linux traceroute格式: " 1  192.168.1.1  0.123 ms  0.234 ms  0.345 ms"
        
        if sys.platform == 'win32':
            # Windows tracert
            match = re.match(r'\s*(\d+)\s+(?:(<?\d+)\s*ms\s*)?(?:(<?\d+)\s*ms\s*)?(?:(<?\d+)\s*ms\s*)?([\d\.]+|\*)', line)
            if match:
                hop_num = int(match.group(1))
                ip = match.group(5) if match.group(5) != '*' else '*'
                
                # 提取延迟
                rtts = [match.group(2), match.group(3), match.group(4)]
                rtts = [r.replace('<', '') for r in rtts if r]
                avg_rtt = sum(int(r) for r in rtts) / len(rtts) if rtts else 0
                
                return {
                    'hop': hop_num,
                    'ip': ip,
                    'rtt': f"{avg_rtt:.1f}" if avg_rtt > 0 else '*'
                }
        else:
            # Linux/Mac traceroute
            match = re.match(r'\s*(\d+)\s+([\d\.]+|\*)\s+([\d\.]+)\s*ms', line)
            if match:
                return {
                    'hop': int(match.group(1)),
                    'ip': match.group(2) if match.group(2) != '*' else '*',
                    'rtt': match.group(3)
                }
        
        return None
    
    def _print_hop(self, hop: Dict):
        """打印单个跳点信息"""
        hop_num = hop['hop']
        ip = hop.get('ip', '*')
        rtt = hop.get('rtt', '*')
        asn = hop.get('asn', 'N/A')
        as_name = hop.get('as_name', 'N/A')
        country = hop.get('country', 'N/A')
        city = hop.get('city', 'N/A')
        
        print(f"{hop_num:2d}  {ip:15s}  {rtt:>6s} ms  "
              f"AS{asn:8s}  {country:12s}  {city:15s}  {as_name}")


class IperfTester:
    """iperf3带宽测试器"""
    
    @staticmethod
    def test_bandwidth(server: str, port: int = 5201, duration: int = 10, 
                      reverse: bool = False) -> Optional[Dict]:
        """执行iperf3测试"""
        print(f"\n正在进行iperf3带宽测试 ({server}:{port})...")
        
        cmd = ['iperf3', '-c', server, '-p', str(port), '-t', str(duration), '-J']
        
        if reverse:
            cmd.append('-R')
            print("测试方向: 下行 (服务器 -> 客户端)")
        else:
            print("测试方向: 上行 (客户端 -> 服务器)")
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=duration + 10
            )
            
            if result.returncode == 0:
                data = json.loads(result.stdout)
                
                # 提取结果
                end = data.get('end', {})
                sum_sent = end.get('sum_sent', {})
                sum_received = end.get('sum_received', {})
                
                return {
                    'sent_mbps': sum_sent.get('bits_per_second', 0) / 1_000_000,
                    'received_mbps': sum_received.get('bits_per_second', 0) / 1_000_000,
                    'sent_bytes': sum_sent.get('bytes', 0),
                    'received_bytes': sum_received.get('bytes', 0),
                }
            else:
                print(f"iperf3测试失败: {result.stderr}")
                return None
                
        except FileNotFoundError:
            print("错误: 未安装iperf3，请先安装 iperf3")
            return None
        except subprocess.TimeoutExpired:
            print("iperf3测试超时")
            return None
        except Exception as e:
            print(f"iperf3测试出错: {e}")
            return None


def main():
    parser = argparse.ArgumentParser(
        description='去程路由测试工具 - 支持ASN/地区识别、线路分析、iperf3测试'
    )
    parser.add_argument('target', help='目标主机IP或域名')
    parser.add_argument('-m', '--max-hops', type=int, default=30, 
                       help='最大跳数 (默认: 30)')
    parser.add_argument('-i', '--iperf', action='store_true',
                       help='执行iperf3带宽测试')
    parser.add_argument('-p', '--port', type=int, default=5201,
                       help='iperf3端口 (默认: 5201)')
    parser.add_argument('-t', '--time', type=int, default=10,
                       help='iperf3测试时长(秒) (默认: 10)')
    parser.add_argument('-r', '--reverse', action='store_true',
                       help='iperf3反向测试(下行)')
    parser.add_argument('-o', '--output', help='保存结果到JSON文件')
    
    args = parser.parse_args()
    
    # 解析目标主机
    target_ip = args.target
    try:
        # 如果是域名，先解析
        if not re.match(r'^\d+\.\d+\.\d+\.\d+$', args.target):
            target_ip = socket.gethostbyname(args.target)
            print(f"域名 {args.target} 解析为: {target_ip}")
    except socket.gaierror:
        print(f"无法解析域名: {args.target}")
        return 1
    
    # 执行路由追踪
    tracer = RouteTracer(target_ip, args.max_hops)
    hops = tracer.traceroute()
    
    if not hops:
        print("路由追踪失败")
        return 1
    
    # 分析路由
    print("\n" + "="*80)
    print("路由分析结果")
    print("="*80)
    
    route_analysis = RouteAnalyzer.identify_route_type(hops)
    print(f"线路类型: {route_analysis['route_type']}")
    print(f"线路级别: {route_analysis['route_level']}")
    print(f"ASN路径: {route_analysis['asn_path']}")
    print(f"总跳数: {len(hops)}")
    
    if route_analysis['cn2_hops'] > 0:
        print(f"CN2节点数: {route_analysis['cn2_hops']}")
    if route_analysis['as9929_hops'] > 0:
        print(f"AS9929节点数: {route_analysis['as9929_hops']}")
    
    # iperf3测试
    iperf_result = None
    if args.iperf:
        iperf_result = IperfTester.test_bandwidth(
            args.target, 
            args.port, 
            args.time,
            args.reverse
        )
        
        if iperf_result:
            print("\n" + "="*80)
            print("iperf3带宽测试结果")
            print("="*80)
            if args.reverse:
                print(f"下行带宽: {iperf_result['received_mbps']:.2f} Mbps")
                print(f"接收数据: {iperf_result['received_bytes'] / 1024 / 1024:.2f} MB")
            else:
                print(f"上行带宽: {iperf_result['sent_mbps']:.2f} Mbps")
                print(f"发送数据: {iperf_result['sent_bytes'] / 1024 / 1024:.2f} MB")
    
    # 保存结果
    if args.output:
        result = {
            'target': args.target,
            'target_ip': target_ip,
            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
            'hops': hops,
            'route_analysis': route_analysis,
            'iperf_result': iperf_result
        }
        
        with open(args.output, 'w', encoding='utf-8') as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        
        print(f"\n结果已保存到: {args.output}")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
