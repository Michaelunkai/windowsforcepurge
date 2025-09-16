#!/usr/bin/env python3
"""
Comprehensive Laptop Hardware Diagnostics Tool
Checks all major hardware components and reports their status
"""

import os
import sys
import subprocess
import json
import time
import platform
from datetime import datetime
from pathlib import Path

class Colors:
    """Terminal color codes for better readability"""
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    END = '\033[0m'

class HardwareDiagnostics:
    def __init__(self):
        self.system = platform.system()
        self.results = {}
        self.issues_found = []
        self.scores = {}  # Store component scores
        self.component_details = {}  # Store detailed diagnostics

    def print_header(self):
        """Print diagnostic tool header"""
        print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*60}")
        print(f"  LAPTOP HARDWARE DIAGNOSTICS TOOL")
        print(f"{'='*60}{Colors.END}")
        print(f"{Colors.BLUE}System: {self.system}")
        print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"{'='*60}{Colors.END}\n")
    
    def run_command(self, command, shell=True):
        """Safely run system commands"""
        try:
            result = subprocess.run(command, shell=shell, capture_output=True, text=True, timeout=30)
            return result.stdout.strip(), result.stderr.strip(), result.returncode
        except subprocess.TimeoutExpired:
            return "", "Command timed out", 1
        except Exception as e:
            return "", str(e), 1
    
    def check_cpu(self):
        """Check CPU status and temperature"""
        print(f"{Colors.BOLD}{Colors.YELLOW}🔧 CPU DIAGNOSTICS{Colors.END}")
        print("-" * 40)
        
        cpu_info = {}
        score = 100  # Start with perfect score
        
        if self.system == "Linux":
            # CPU info
            stdout, _, _ = self.run_command("lscpu")
            if stdout:
                for line in stdout.split('\n'):
                    if 'Model name:' in line:
                        cpu_info['model'] = line.split(':')[1].strip()
                    elif 'CPU(s):' in line and 'NUMA' not in line:
                        cpu_info['cores'] = line.split(':')[1].strip()
            
            # CPU temperature
            temp_paths = ['/sys/class/thermal/thermal_zone*/temp']
            stdout, _, _ = self.run_command(f"cat {' '.join(temp_paths)} 2>/dev/null || echo 'N/A'")
            if stdout and stdout != 'N/A':
                temps = [int(temp)/1000 for temp in stdout.split() if temp.isdigit()]
                if temps:
                    avg_temp = sum(temps) / len(temps)
                    cpu_info['temperature'] = f"{avg_temp:.1f}°C"
                    if avg_temp > 80:
                        score -= 20
                        self.issues_found.append(f"CPU temperature high: {avg_temp:.1f}°C")
            
            # CPU usage
            stdout, _, _ = self.run_command("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1")
            if stdout:
                try:
                    cpu_usage = float(stdout)
                    cpu_info['usage'] = f"{cpu_usage:.1f}%"
                    if cpu_usage > 90:
                        score -= 30
                        self.issues_found.append(f"High CPU usage: {cpu_usage:.1f}%")
                except:
                    pass
        
        elif self.system == "Darwin":  # macOS
            # CPU info
            stdout, _, _ = self.run_command("sysctl -n machdep.cpu.brand_string")
            if stdout:
                cpu_info['model'] = stdout
            
            stdout, _, _ = self.run_command("sysctl -n hw.ncpu")
            if stdout:
                cpu_info['cores'] = stdout
            
            # CPU temperature (requires additional tools on macOS)
            stdout, _, _ = self.run_command("sysctl -n machdep.xcpm.cpu_thermal_state 2>/dev/null")
            if stdout and stdout.isdigit():
                thermal_state = int(stdout)
                if thermal_state > 0:
                    self.issues_found.append(f"CPU thermal throttling detected (state: {thermal_state})")
        
        elif self.system == "Windows":
            # CPU info using wmic
            stdout, _, _ = self.run_command('wmic cpu get name /value')
            if stdout:
                for line in stdout.split('\n'):
                    if 'Name=' in line:
                        cpu_info['model'] = line.split('=')[1].strip()
            
            stdout, _, _ = self.run_command('wmic cpu get NumberOfCores /value')
            if stdout:
                for line in stdout.split('\n'):
                    if 'NumberOfCores=' in line:
                        cpu_info['cores'] = line.split('=')[1].strip()
        
        # Display results
        for key, value in cpu_info.items():
            status = f"{Colors.GREEN}✓{Colors.END}" if value else f"{Colors.RED}✗{Colors.END}"
            print(f"{status} {key.capitalize()}: {value}")
        
        self.scores['cpu'] = max(0, score)
        self.results['cpu'] = cpu_info
        print(f"CPU Score: {self.scores['cpu']}/100")
        print()
    
    def check_memory(self):
        """Check RAM status"""
        print(f"{Colors.BOLD}{Colors.YELLOW}💾 MEMORY DIAGNOSTICS{Colors.END}")
        print("-" * 40)
        
        memory_info = {}
        score = 100  # Start with perfect score
        
        if self.system == "Linux":
            stdout, _, _ = self.run_command("free -h")
            if stdout:
                lines = stdout.split('\n')
                for line in lines:
                    if 'Mem:' in line:
                        parts = line.split()
                        memory_info['total'] = parts[1]
                        memory_info['used'] = parts[2]
                        memory_info['available'] = parts[6] if len(parts) > 6 else parts[3]
                        
                        # Calculate usage percentage
                        try:
                            used_val = float(parts[2].replace('G', '').replace('M', ''))
                            total_val = float(parts[1].replace('G', '').replace('M', ''))
                            usage_pct = (used_val / total_val) * 100
                            memory_info['usage_percent'] = f"{usage_pct:.1f}%"
                            
                            if usage_pct > 90:
                                score -= 40
                                self.issues_found.append(f"High memory usage: {usage_pct:.1f}%")
                            elif usage_pct > 80:
                                score -= 20
                            elif usage_pct > 70:
                                score -= 10
                        except:
                            pass
            
            # Check for memory errors in dmesg
            stdout, _, _ = self.run_command("dmesg | grep -i 'memory error\\|ecc\\|uncorrectable' | tail -5")
            if stdout:
                self.issues_found.append("Memory errors found in system log")
        
        elif self.system == "Darwin":  # macOS
            stdout, _, _ = self.run_command("vm_stat")
            if stdout:
                # Parse vm_stat output for memory info
                for line in stdout.split('\n'):
                    if 'Pages free:' in line:
                        free_pages = int(line.split()[-1].replace('.', ''))
                        memory_info['free_pages'] = str(free_pages)
        
        elif self.system == "Windows":
            stdout, _, _ = self.run_command('wmic OS get TotalVisibleMemorySize,FreePhysicalMemory /value')
            if stdout:
                total_mem = free_mem = 0
                for line in stdout.split('\n'):
                    if 'TotalVisibleMemorySize=' in line:
                        total_mem = int(line.split('=')[1]) / 1024 / 1024  # Convert to GB
                    elif 'FreePhysicalMemory=' in line:
                        free_mem = int(line.split('=')[1]) / 1024 / 1024
                
                if total_mem > 0:
                    memory_info['total'] = f"{total_mem:.1f}GB"
                    memory_info['used'] = f"{total_mem - free_mem:.1f}GB"
                    usage_pct = ((total_mem - free_mem) / total_mem) * 100
                    memory_info['usage_percent'] = f"{usage_pct:.1f}%"
                    
                    if usage_pct > 90:
                        score -= 40
                        self.issues_found.append(f"High memory usage: {usage_pct:.1f}%")
        
        # Display results
        for key, value in memory_info.items():
            status = f"{Colors.GREEN}✓{Colors.END}"
            print(f"{status} {key.replace('_', ' ').title()}: {value}")
        
        self.scores['memory'] = max(0, score)
        self.results['memory'] = memory_info
        print(f"Memory Score: {self.scores['memory']}/100")
        print()
    
    def check_storage(self):
        """Check storage devices"""
        print(f"{Colors.BOLD}{Colors.YELLOW}💽 STORAGE DIAGNOSTICS{Colors.END}")
        print("-" * 40)
        
        storage_info = {}
        
        if self.system == "Linux":
            # Disk usage
            stdout, _, _ = self.run_command("df -h")
            if stdout:
                print(f"{Colors.CYAN}Disk Usage:{Colors.END}")
                lines = stdout.split('\n')[1:]  # Skip header
                for line in lines:
                    if line and not line.startswith('tmpfs') and not line.startswith('udev'):
                        parts = line.split()
                        if len(parts) >= 5:
                            filesystem = parts[0]
                            size = parts[1]
                            used = parts[2]
                            usage_pct = parts[4].replace('%', '')
                            mount = parts[5] if len(parts) > 5 else ''
                            
                            try:
                                usage_num = int(usage_pct)
                                if usage_num > 90:
                                    status = f"{Colors.RED}⚠{Colors.END}"
                                    self.issues_found.append(f"Low disk space on {mount}: {usage_pct}% used")
                                elif usage_num > 80:
                                    status = f"{Colors.YELLOW}⚠{Colors.END}"
                                else:
                                    status = f"{Colors.GREEN}✓{Colors.END}"
                                
                                print(f"{status} {mount}: {used}/{size} ({usage_pct}% used)")
                            except:
                                pass
            
            # SMART status
            stdout, _, _ = self.run_command("lsblk -d -o NAME,ROTA")
            if stdout:
                drives = []
                for line in stdout.split('\n')[1:]:
                    parts = line.split()
                    if len(parts) >= 2:
                        drives.append(parts[0])
                
                for drive in drives:
                    stdout, _, _ = self.run_command(f"smartctl -H /dev/{drive} 2>/dev/null")
                    if "PASSED" in stdout:
                        print(f"{Colors.GREEN}✓{Colors.END} {drive}: SMART status OK")
                    elif "FAILED" in stdout:
                        print(f"{Colors.RED}✗{Colors.END} {drive}: SMART status FAILED")
                        self.issues_found.append(f"SMART failure on drive {drive}")
        
        elif self.system == "Darwin":  # macOS
            stdout, _, _ = self.run_command("df -h")
            if stdout:
                print(f"{Colors.CYAN}Disk Usage:{Colors.END}")
                lines = stdout.split('\n')[1:]
                for line in lines:
                    if '/dev/disk' in line:
                        parts = line.split()
                        if len(parts) >= 5:
                            usage_pct = parts[4].replace('%', '')
                            mount = parts[8] if len(parts) > 8 else parts[5]
                            try:
                                usage_num = int(usage_pct)
                                if usage_num > 90:
                                    status = f"{Colors.RED}⚠{Colors.END}"
                                    self.issues_found.append(f"Low disk space on {mount}: {usage_pct}% used")
                                else:
                                    status = f"{Colors.GREEN}✓{Colors.END}"
                                print(f"{status} {mount}: {usage_pct}% used")
                            except:
                                pass
        
        elif self.system == "Windows":
            stdout, _, _ = self.run_command('wmic logicaldisk get size,freespace,caption /value')
            if stdout:
                drives = {}
                current_drive = None
                for line in stdout.split('\n'):
                    if 'Caption=' in line:
                        current_drive = line.split('=')[1].strip()
                        drives[current_drive] = {}
                    elif 'FreeSpace=' in line and current_drive:
                        drives[current_drive]['free'] = int(line.split('=')[1]) if line.split('=')[1] else 0
                    elif 'Size=' in line and current_drive:
                        drives[current_drive]['size'] = int(line.split('=')[1]) if line.split('=')[1] else 0
                
                for drive, info in drives.items():
                    if info.get('size', 0) > 0:
                        free_gb = info['free'] / (1024**3)
                        size_gb = info['size'] / (1024**3)
                        used_pct = ((size_gb - free_gb) / size_gb) * 100
                        
                        if used_pct > 90:
                            status = f"{Colors.RED}⚠{Colors.END}"
                            self.issues_found.append(f"Low disk space on {drive}: {used_pct:.1f}% used")
                        else:
                            status = f"{Colors.GREEN}✓{Colors.END}"
                        
                        print(f"{status} {drive}: {used_pct:.1f}% used ({size_gb:.1f}GB total)")
        
        self.results['storage'] = storage_info
        print()
    
    def check_battery(self):
        """Check battery status"""
        print(f"{Colors.BOLD}{Colors.YELLOW}🔋 BATTERY DIAGNOSTICS{Colors.END}")
        print("-" * 40)
        
        battery_info = {}
        score = 100  # Start with perfect score
        
        if self.system == "Linux":
            # Check if battery exists
            battery_path = "/sys/class/power_supply/BAT0"
            if os.path.exists(battery_path):
                # Battery capacity
                try:
                    with open(f"{battery_path}/capacity", 'r') as f:
                        capacity = f.read().strip()
                        battery_info['capacity'] = f"{capacity}%"
                except:
                    pass
                
                # Battery status
                try:
                    with open(f"{battery_path}/status", 'r') as f:
                        status = f.read().strip()
                        battery_info['status'] = status
                except:
                    pass
                
                # Battery health
                try:
                    with open(f"{battery_path}/charge_full", 'r') as f:
                        full = int(f.read().strip())
                    with open(f"{battery_path}/charge_full_design", 'r') as f:
                        design = int(f.read().strip())
                    
                    health = (full / design) * 100
                    battery_info['health'] = f"{health:.1f}%"
                    
                    if health < 80:
                        score -= 20
                        self.issues_found.append(f"Battery health degraded: {health:.1f}%")
                except:
                    pass
            else:
                battery_info['status'] = "No battery detected"
        
        elif self.system == "Darwin":  # macOS
            stdout, _, _ = self.run_command("pmset -g batt")
            if stdout:
                for line in stdout.split('\n'):
                    if '%' in line and 'InternalBattery' in line:
                        parts = line.split()
                        for part in parts:
                            if '%' in part:
                                battery_info['capacity'] = part
                                break
            
            # Battery cycle count
            stdout, _, _ = self.run_command("system_profiler SPPowerDataType | grep 'Cycle Count'")
            if stdout:
                cycle_count = stdout.split(':')[-1].strip()
                battery_info['cycle_count'] = cycle_count
                
                try:
                    cycles = int(cycle_count)
                    if cycles > 1000:
                        self.issues_found.append(f"High battery cycle count: {cycles}")
                except:
                    pass
        
        elif self.system == "Windows":
            stdout, _, _ = self.run_command('wmic path Win32_Battery get YOUR_CLIENT_SECRET_HERE /value')
            if stdout:
                for line in stdout.split('\n'):
                    if 'YOUR_CLIENT_SECRET_HERE=' in line:
                        charge = line.split('=')[1].strip()
                        if charge:
                            battery_info['capacity'] = f"{charge}%"
        
        # Display results
        if battery_info:
            for key, value in battery_info.items():
                status = f"{Colors.GREEN}✓{Colors.END}"
                print(f"{status} {key.replace('_', ' ').title()}: {value}")
        else:
            print(f"{Colors.YELLOW}⚠{Colors.END} No battery information available")
        
        self.scores['battery'] = max(0, score)
        self.results['battery'] = battery_info
        print(f"Battery Score: {self.scores['battery']}/100")
        print()
    
    def check_network(self):
        """Check network interfaces"""
        print(f"{Colors.BOLD}{Colors.YELLOW}🌐 NETWORK DIAGNOSTICS{Colors.END}")
        print("-" * 40)
        
        network_info = {}
        
        if self.system == "Linux":
            stdout, _, _ = self.run_command("ip addr show")
            if stdout:
                interfaces = []
                current_interface = None
                for line in stdout.split('\n'):
                    if ': ' in line and not line.startswith(' '):
                        parts = line.split(': ')
                        if len(parts) >= 2:
                            current_interface = parts[1].split('@')[0]
                            interfaces.append(current_interface)
                    elif 'inet ' in line and current_interface:
                        ip = line.strip().split()[1]
                        network_info[current_interface] = ip
                
                for interface, ip in network_info.items():
                    if interface != 'lo':  # Skip loopback
                        print(f"{Colors.GREEN}✓{Colors.END} {interface}: {ip}")
            
            # Check connectivity
            stdout, _, returncode = self.run_command("ping -c 1 8.8.8.8")
            if returncode == 0:
                print(f"{Colors.GREEN}✓{Colors.END} Internet connectivity: OK")
            else:
                print(f"{Colors.RED}✗{Colors.END} Internet connectivity: FAILED")
                self.issues_found.append("No internet connectivity")
        
        elif self.system == "Darwin":  # macOS
            stdout, _, _ = self.run_command("ifconfig")
            if stdout:
                current_interface = None
                for line in stdout.split('\n'):
                    if line and not line.startswith('\t') and not line.startswith(' '):
                        current_interface = line.split(':')[0]
                    elif 'inet ' in line and current_interface:
                        ip = line.strip().split()[1]
                        if current_interface != 'lo0':
                            network_info[current_interface] = ip
                            print(f"{Colors.GREEN}✓{Colors.END} {current_interface}: {ip}")
        
        elif self.system == "Windows":
            stdout, _, _ = self.run_command('ipconfig')
            if stdout:
                for line in stdout.split('\n'):
                    if 'IPv4 Address' in line:
                        ip = line.split(':')[-1].strip()
                        print(f"{Colors.GREEN}✓{Colors.END} Network: {ip}")
        
        self.results['network'] = network_info
        print()
    
    def YOUR_CLIENT_SECRET_HERE(self):
        """Check system temperature sensors"""
        print(f"{Colors.BOLD}{Colors.YELLOW}🌡️ TEMPERATURE SENSORS{Colors.END}")
        print("-" * 40)
        
        temp_info = {}
        
        if self.system == "Linux":
            # Check lm-sensors
            stdout, _, _ = self.run_command("sensors 2>/dev/null")
            if stdout:
                current_sensor = None
                for line in stdout.split('\n'):
                    if line and not line.startswith(' ') and ':' not in line:
                        current_sensor = line.strip()
                    elif '°C' in line:
                        parts = line.split(':')
                        if len(parts) >= 2:
                            temp_name = parts[0].strip()
                            temp_value = parts[1].strip().split()[0]
                            try:
                                temp_num = float(temp_value.replace('+', '').replace('°C', ''))
                                if temp_num > 80:
                                    self.issues_found.append(f"High temperature: {temp_name} = {temp_num}°C")
                                elif temp_num > 70:
                                    pass
                                else:
                                    pass
                                
                                print(f"{Colors.GREEN}✓{Colors.END} {temp_name}: {temp_value}")
                                temp_info[temp_name] = temp_value
                            except:
                                pass
            else:
                print(f"{Colors.YELLOW}⚠{Colors.END} Temperature sensors not available (install lm-sensors)")
        
        elif self.system == "Darwin":  # macOS
            print(f"{Colors.YELLOW}⚠{Colors.END} Temperature monitoring requires additional tools on macOS")
        
        elif self.system == "Windows":
            print(f"{Colors.YELLOW}⚠{Colors.END} Temperature monitoring requires additional tools on Windows")
        
        self.results['temperature'] = temp_info
        print()
    
    def check_usb_devices(self):
        """Check USB devices"""
        print(f"{Colors.BOLD}{Colors.YELLOW}🔌 USB DEVICES{Colors.END}")
        print("-" * 40)
        
        usb_info = {}
        
        if self.system == "Linux":
            stdout, _, _ = self.run_command("lsusb")
            if stdout:
                devices = []
                for line in stdout.split('\n'):
                    if line:
                        parts = line.split()
                        if len(parts) >= 6:
                            device_info = ' '.join(parts[6:])
                            devices.append(device_info)
                            print(f"{Colors.GREEN}✓{Colors.END} {device_info}")
                usb_info['devices'] = devices
        
        elif self.system == "Darwin":  # macOS
            stdout, _, _ = self.run_command("system_profiler SPUSBDataType")
            if stdout:
                print(f"{Colors.GREEN}✓{Colors.END} USB devices detected (run 'system_profiler SPUSBDataType' for details)")
        
        elif self.system == "Windows":
            stdout, _, _ = self.run_command('wmic path Win32_USBHub get Name /value')
            if stdout:
                devices = []
                for line in stdout.split('\n'):
                    if 'Name=' in line and line.split('=')[1].strip():
                        device = line.split('=')[1].strip()
                        devices.append(device)
                        print(f"{Colors.GREEN}✓{Colors.END} {device}")
                usb_info['devices'] = devices
        
        self.results['usb'] = usb_info
        print()
    
    def check_gpu(self):
        """Enhanced GPU diagnostics"""
        print(f"{Colors.BOLD}{Colors.YELLOW}🎮 GPU DIAGNOSTICS{Colors.END}")
        print("-" * 40)
        
        gpu_info = {}
        score = 100  # Start with perfect score
        
        if self.system == "Linux":
            # Check for NVIDIA GPU
            stdout, _, _ = self.run_command("nvidia-smi")
            if stdout:
                for line in stdout.split('\n'):
                    if 'NVIDIA' in line:
                        gpu_info['model'] = line.strip()
                    if '%' in line and 'W' in line:  # GPU utilization and power
                        parts = line.split()
                        for part in parts:
                            if '%' in part:
                                usage = int(part.replace('%', ''))
                                gpu_info['usage'] = f"{usage}%"
                                if usage > 90:
                                    score -= 20
                                    self.issues_found.append(f"High GPU usage: {usage}%")
            else:
                # Try lspci for any GPU
                stdout, _, _ = self.run_command("lspci | grep -i 'vga\|3d'")
                if stdout:
                    gpu_info['model'] = stdout.split(':')[-1].strip()
        
        elif self.system == "Windows":
            stdout, _, _ = self.run_command('wmic path win32_VideoController get name,driverversion,videoprocessor')
            if stdout:
                lines = stdout.split('\n')
                if len(lines) > 1:
                    gpu_info['model'] = lines[1].strip()
                    
            # Check GPU temperature using nvidia-smi if available
            stdout, _, _ = self.run_command('nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader')
            if stdout and stdout.strip().isdigit():
                temp = int(stdout.strip())
                gpu_info['temperature'] = f"{temp}°C"
                if temp > 85:
                    score -= 30
                    self.issues_found.append(f"High GPU temperature: {temp}°C")
                elif temp > 75:
                    score -= 15
            
            # Check GPU driver date
            stdout, _, _ = self.run_command('wmic path win32_VideoController get DriverDate,DriverVersion')
            if stdout:
                gpu_info['driver_version'] = stdout.split('\n')[1].strip() if len(stdout.split('\n')) > 1 else "Unknown"
            
            # Check GPU memory
            stdout, _, _ = self.run_command('wmic path win32_VideoController get AdapterRAM')
            if stdout:
                try:
                    vram = int(stdout.split('\n')[1]) / (1024**3)
                    gpu_info['memory'] = f"{vram:.1f}GB"
                except:
                    pass

        self.scores['gpu'] = max(0, score)
        self.results['gpu'] = gpu_info
        
        # Display results
        for key, value in gpu_info.items():
            status = f"{Colors.GREEN}✓{Colors.END}"
            print(f"{status} {key.capitalize()}: {value}")
        print(f"GPU Score: {self.scores['gpu']}/100")
        print()

    def YOUR_CLIENT_SECRET_HERE(self, component, metrics):
        """Calculate a score from 0-100 for a component based on metrics"""
        score = 100
        if component == 'cpu':
            if 'temperature' in metrics and metrics['temperature']:
                temp = float(metrics['temperature'].replace('°C', ''))
                if temp > 85: score -= 40
                elif temp > 75: score -= 20
                elif temp > 65: score -= 10
            
            if 'usage_percent' in metrics and metrics['usage_percent']:
                usage = float(metrics['usage_percent'].replace('%', ''))
                if usage > 90: score -= 30
                elif usage > 80: score -= 15
        
        elif component == 'memory':
            if 'usage_percent' in metrics and metrics['usage_percent']:
                usage = float(metrics['usage_percent'].replace('%', ''))
                if usage > 90: score -= 40
                elif usage > 80: score -= 20
                elif usage > 70: score -= 10
        
        elif component == 'battery':
            if 'health' in metrics and metrics['health']:
                health = float(metrics['health'].replace('%', ''))
                score = health  # Direct mapping of battery health to score
            
            if 'capacity' in metrics and metrics['capacity']:
                capacity = float(metrics['capacity'].replace('%', ''))
                if capacity < 20: score -= 20
        
        return max(0, int(score))

    def print_summary(self):
        """Print diagnostic summary"""
        print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*60}")
        print(f"  DIAGNOSTIC SUMMARY")
        print(f"{'='*60}{Colors.END}")
        
        if self.issues_found:
            print(f"\n{Colors.RED}{Colors.BOLD}⚠ ISSUES FOUND ({len(self.issues_found)}):{Colors.END}")
            for i, issue in enumerate(self.issues_found, 1):
                print(f"{Colors.RED}{i:2d}. {issue}{Colors.END}")
        else:
            print(f"\n{Colors.GREEN}{Colors.BOLD}✓ NO CRITICAL ISSUES FOUND{Colors.END}")
            print(f"{Colors.GREEN}All hardware components appear to be functioning normally.{Colors.END}")
        
        print(f"\n{Colors.BLUE}Components checked: CPU, Memory, Storage, Battery, Network, Temperature, USB")
        print(f"Total checks completed: {len(self.results)}{Colors.END}")
        print(f"\n{Colors.CYAN}{'='*60}{Colors.END}")
    
    def check_disk_health(self):
        """Detailed disk health check"""
        print(f"{Colors.BOLD}{Colors.YELLOW}💿 DISK HEALTH DIAGNOSTICS{Colors.END}")
        print("-" * 40)
        
        disk_health = {}
        score = 100
        
        if self.system == "Windows":
            # Check disk errors using wmic and chkdsk
            stdout, _, _ = self.run_command('wmic diskdrive get status')
            if stdout and 'OK' not in stdout.upper():
                self.issues_found.append("Disk status reports problems")
                score -= 30
            
            stdout, _, _ = self.run_command('chkdsk')
            if stdout and any(x in stdout.lower() for x in ['bad', 'error', 'corrupt']):
                self.issues_found.append("Disk errors detected - run 'chkdsk /f' to fix")
                score -= 30

        elif self.system == "Linux":
            # Check disk errors in system logs
            stdout, _, _ = self.run_command("dmesg | grep -i 'error\\|bad\\|failed' | grep -i 'sd[a-z]\\|nvme'")
            if stdout:
                self.issues_found.append("Disk errors found in system logs")
                score -= 30
            
            # Check SMART status if available
            stdout, _, _ = self.run_command("which smartctl")
            if stdout:
                drives_stdout, _, _ = self.run_command("lsblk -d -n -o NAME")
                if drives_stdout:
                    for drive in drives_stdout.split('\n'):
                        smart_out, _, _ = self.run_command(f"smartctl -H /dev/{drive}")
                        if smart_out and "FAILED" in smart_out:
                            self.issues_found.append(f"SMART health check failed for /dev/{drive}")
                            score -= 40

        self.scores['disk'] = max(0, score)
        self.results['disk_health'] = disk_health
        if score < 100:
            print(f"{Colors.RED}⚠ Disk health issues detected{Colors.END}")
        else:
            print(f"{Colors.GREEN}✓ Disk health check passed{Colors.END}")
        print(f"Disk Health Score: {self.scores['disk']}/100")
        print()

    def run_diagnostics(self):
        """Enhanced diagnostics with more checks"""
        self.print_header()
        
        try:
            self.check_cpu()
            self.check_memory()
            self.check_gpu()
            self.check_disk_health()  # Move this before storage check
            self.check_storage()
            self.check_battery()
            self.check_network()
            self.YOUR_CLIENT_SECRET_HERE()
            self.check_usb_devices()
            
            # Calculate scores for main components
            self.scores['cpu'] = self.YOUR_CLIENT_SECRET_HERE('cpu', self.results['cpu'])
            self.scores['memory'] = self.YOUR_CLIENT_SECRET_HERE('memory', self.results['memory'])
            self.scores['battery'] = self.YOUR_CLIENT_SECRET_HERE('battery', self.results['battery'])
            
            self.print_summary()
            self.print_detailed_report()  # Add detailed report
            self.print_scores()
            
        except Exception as e:
            print(f"\n{Colors.RED}Error during diagnostics: {str(e)}{Colors.END}")
            sys.exit(1)

    def print_detailed_report(self):
        """Print detailed diagnostic report"""
        print(f"\n{Colors.BOLD}{Colors.CYAN}DETAILED DIAGNOSTIC REPORT{Colors.END}")
        print("-" * 60)
        
        if self.issues_found:
            print(f"\n{Colors.RED}Critical Issues:{Colors.END}")
            for issue in self.issues_found:
                print(f"❌ {issue}")
            
            print(f"\n{Colors.YELLOW}Recommended Actions:{Colors.END}")
            for issue in self.issues_found:
                if "temperature" in issue.lower():
                    print("• Clean dust from fans and heat sinks")
                    print("• Check if thermal paste needs replacement")
                elif "memory" in issue.lower():
                    print("• Run memory diagnostic tools (memtest86+)")
                    print("• Check if memory modules are properly seated")
                elif "disk" in issue.lower():
                    print("• Backup important data immediately")
                    print("• Run disk check utilities")
                elif "battery" in issue.lower():
                    print("• Consider battery replacement")
                    print("• Check for battery recalls")
        else:
            print(f"\n{Colors.GREEN}✓ All hardware components are functioning within normal parameters{Colors.END}")
        
        print("\nSystem Information:")
        print(f"• OS: {platform.system()} {platform.release()}")
        print(f"• Machine: {platform.machine()}")
        print(f"• Processor: {self.results.get('cpu', {}).get('model', 'Unknown')}")
        print(f"• Memory: {self.results.get('memory', {}).get('total', 'Unknown')}")
        print(f"• GPU: {self.results.get('gpu', {}).get('model', 'Unknown')}")

    def print_scores(self):
        """Print component scores"""
        print(f"\n{Colors.BOLD}{Colors.CYAN}COMPONENT SCORES{Colors.END}")
        print("-" * 40)
        
        components = ['cpu', 'gpu', 'memory', 'battery']
        for component in components:
            if component in self.scores:
                score = self.scores[component]
                if score >= 80:
                    color = Colors.GREEN
                elif score >= 60:
                    color = Colors.YELLOW
                else:
                    color = Colors.RED
                
                print(f"{component.upper()}: {color}{score}/100{Colors.END}")
        
        print()

def check_admin_privileges():
    """Check if program is running with admin/root privileges"""
    try:
        if platform.system() == "Windows":
            import ctypes
            return ctypes.windll.shell32.IsUserAnAdmin() != 0
        else:
            return os.geteuid() == 0
    except:
        return False

def main():
    """Main function"""
    if len(sys.argv) > 1 and sys.argv[1] in ['-h', '--help']:
        print("Laptop Hardware Diagnostics Tool")
        print("Usage: python3 hardware_diagnostics.py")
        print("\nThis tool checks:")
        print("- CPU status and temperature")
        print("- Memory usage and errors")
        print("- Storage space and SMART status")
        print("- Battery health and status")
        print("- Network connectivity")
        print("- Temperature sensors")
        print("- USB devices")
        return
    
    # Check if running as admin/root for some checks
    if not check_admin_privileges() and platform.system() == "Linux":
        print(f"{Colors.YELLOW}Note: Some checks require root privileges for full functionality.{Colors.END}")
        print(f"{Colors.YELLOW}Run with 'sudo python3 hardware_diagnostics.py' for complete diagnostics.{Colors.END}\n")
    
    diagnostics = HardwareDiagnostics()
    diagnostics.run_diagnostics()

if __name__ == "__main__":
    main()