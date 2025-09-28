"""
Enhanced Hardware Detection Module
Comprehensive detection of all hardware components including ASUS laptop model, 
AMD CPU, NVIDIA GPU, chipsets, audio devices, network adapters, storage controllers, and more.
"""

import asyncio
import subprocess
import json
import re
import logging
from typing import Dict, Optional, List, Set, Tuple
import psutil
import winreg
import platform
import uuid
from pathlib import Path

# Handle WMI import with proper COM initialization
try:
    import pythoncom
    import wmi
    WMI_AVAILABLE = True
except ImportError:
    WMI_AVAILABLE = False
    wmi = None
    pythoncom = None

class HardwareDetector:
    """Comprehensive hardware detection for all system components."""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.wmi_conn = None
        
        # Hardware vendor IDs for better identification
        self.vendor_ids = {
            '1022': 'AMD',
            '10DE': 'NVIDIA',
            '8086': 'Intel',
            '1002': 'AMD/ATI',
            '10EC': 'Realtek',
            '1106': 'VIA',
            '14E4': 'Broadcom',
            '168C': 'Qualcomm Atheros',
            '1969': 'Qualcomm Atheros',
            '15B3': 'Mellanox',
            '1D6B': 'Linux Foundation',
            '0B05': 'ASUS',
            '1043': 'ASUS',
            '1458': 'Gigabyte',
            '1462': 'MSI',
            '1849': 'ASRock'
        }
        
        # Device class GUIDs for Windows device enumeration
        self.device_classes = {
            'Display': '{4d36e968-e325-11ce-bfc1-08002be10318}',
            'Audio': '{4d36e96c-e325-11ce-bfc1-08002be10318}',
            'Network': '{4d36e972-e325-11ce-bfc1-08002be10318}',
            'Storage': '{4d36e967-e325-11ce-bfc1-08002be10318}',
            'USB': '{36fc9e60-c465-11cf-8056-444553540000}',
            'Bluetooth': '{e0cbf06c-cd8b-4647-bb8a-263b43f0f974}',
            'System': '{4d36e97d-e325-11ce-bfc1-08002be10318}',
            'Processor': '{50127dc3-0f36-415e-a6cc-4cb3be910b65}',
            'Memory': '{5099944a-f6b9-4057-a056-8c550228544c}'
        }
        
    async def initialize_wmi(self):
        """Initialize WMI connection."""
        try:
            if not WMI_AVAILABLE:
                self.logger.warning("WMI not available, using alternative methods")
                return False
            
            # Initialize COM for the current thread
            pythoncom.CoInitialize()
            self.wmi_conn = wmi.WMI()
            self.logger.debug("WMI connection initialized successfully")
            return True
        except Exception as e:
            self.logger.error(f"Failed to initialize WMI: {e}")
            return False
    
    async def detect_asus_model(self) -> Optional[str]:
        """Detect ASUS laptop model."""
        try:
            # Try WMI first
            if not self.wmi_conn:
                await self.initialize_wmi()
            
            if self.wmi_conn:
                for system in self.wmi_conn.Win32_ComputerSystem():
                    manufacturer = system.Manufacturer.lower() if system.Manufacturer else ""
                    model = system.Model if system.Model else ""
                    
                    if "asus" in manufacturer and model:
                        self.logger.info(f"Detected ASUS model: {model}")
                        return model
            
            # Try registry as backup
            try:
                with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, 
                                   r"SYSTEM\CurrentControlSet\Control\SystemInformation") as key:
                    manufacturer = winreg.QueryValueEx(key, "SystemManufacturer")[0]
                    model = winreg.QueryValueEx(key, "SystemProductName")[0]
                    
                    if "asus" in manufacturer.lower():
                        self.logger.info(f"Detected ASUS model from registry: {model}")
                        return model
            except Exception:
                pass
            
            # Try WMIC command
            result = subprocess.run(
                ['wmic', 'computersystem', 'get', 'manufacturer,model', '/format:csv'],
                capture_output=True, text=True, timeout=10
            )
            
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                for line in lines[1:]:  # Skip header
                    if line.strip():
                        parts = line.split(',')
                        if len(parts) >= 3:
                            manufacturer = parts[1].lower() if parts[1] else ""
                            model = parts[2] if parts[2] else ""
                            
                            if "asus" in manufacturer and model:
                                self.logger.info(f"Detected ASUS model via WMIC: {model}")
                                return model
            
        except Exception as e:
            self.logger.error(f"Error detecting ASUS model: {e}")
        
        return None
    
    async def detect_nvidia_gpu(self) -> Optional[Dict]:
        """Detect NVIDIA GPU information."""
        try:
            # Try nvidia-smi first
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=name,driver_version,uuid', '--format=csv,noheader,nounits'],
                capture_output=True, text=True, timeout=10
            )
            
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if lines and lines[0].strip():
                    parts = lines[0].split(', ')
                    if len(parts) >= 2:
                        gpu_info = {
                            'name': parts[0].strip(),
                            'driver_version': parts[1].strip(),
                            'uuid': parts[2].strip() if len(parts) > 2 else None
                        }
                        self.logger.info(f"Detected NVIDIA GPU: {gpu_info['name']}, Driver: {gpu_info['driver_version']}")
                        return gpu_info
            
            # Try WMI as backup
            if self.wmi_conn:
                for gpu in self.wmi_conn.Win32_VideoController():
                    if gpu.Name and "nvidia" in gpu.Name.lower():
                        gpu_info = {
                            'name': gpu.Name,
                            'driver_version': gpu.DriverVersion if gpu.DriverVersion else "Unknown",
                            'device_id': gpu.DeviceID if gpu.DeviceID else None
                        }
                        self.logger.info(f"Detected NVIDIA GPU via WMI: {gpu_info['name']}")
                        return gpu_info
            
            # Try WMIC
            result = subprocess.run(
                ['wmic', 'path', 'win32_videocontroller', 'get', 'name,driverversion', '/format:csv'],
                capture_output=True, text=True, timeout=10
            )
            
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                for line in lines[1:]:  # Skip header
                    if line.strip():
                        parts = line.split(',')
                        if len(parts) >= 3:
                            name = parts[2] if len(parts) > 2 else ""
                            driver_version = parts[1] if len(parts) > 1 else ""
                            
                            if name and "nvidia" in name.lower():
                                gpu_info = {
                                    'name': name,
                                    'driver_version': driver_version or "Unknown"
                                }
                                self.logger.info(f"Detected NVIDIA GPU via WMIC: {gpu_info['name']}")
                                return gpu_info
            
        except Exception as e:
            self.logger.error(f"Error detecting NVIDIA GPU: {e}")
        
        return None
    
    async def detect_amd_cpu(self) -> Optional[Dict]:
        """Detect AMD CPU information."""
        try:
            # Try WMI first
            if self.wmi_conn:
                for processor in self.wmi_conn.Win32_Processor():
                    if processor.Name and "amd" in processor.Name.lower():
                        cpu_info = {
                            'name': processor.Name,
                            'family': getattr(processor, 'Family', 'Unknown') if hasattr(processor, 'Family') else "Unknown",
                            'model': getattr(processor, 'Model', 'Unknown') if hasattr(processor, 'Model') else "Unknown",
                            'stepping': getattr(processor, 'Stepping', 'Unknown') if hasattr(processor, 'Stepping') else "Unknown",
                            'cores': getattr(processor, 'NumberOfCores', 0) if hasattr(processor, 'NumberOfCores') else 0,
                            'threads': getattr(processor, 'NumberOfLogicalProcessors', 0) if hasattr(processor, 'NumberOfLogicalProcessors') else 0
                        }
                        self.logger.info(f"Detected AMD CPU: {cpu_info['name']}")
                        return cpu_info
            
            # Try WMIC
            try:
                result = subprocess.run(
                    ['wmic', 'cpu', 'get', 'name,family,model,stepping,numberofcores,numberoflogicalprocessors', '/format:csv'],
                    capture_output=True, text=True, timeout=10
                )
                
                if result.returncode == 0:
                    lines = result.stdout.strip().split('\n')
                    for line in lines[1:]:  # Skip header
                        if line.strip():
                            parts = line.split(',')
                            if len(parts) >= 7:
                                name = parts[5] if len(parts) > 5 else ""
                                
                                if name and "amd" in name.lower():
                                    cpu_info = {
                                        'name': name.strip(),
                                        'family': parts[1].strip() if len(parts) > 1 and parts[1].strip() else "Unknown",
                                        'model': parts[2].strip() if len(parts) > 2 and parts[2].strip() else "Unknown",
                                        'cores': int(parts[3]) if len(parts) > 3 and parts[3].strip().isdigit() else 0,
                                        'threads': int(parts[4]) if len(parts) > 4 and parts[4].strip().isdigit() else 0
                                    }
                                    self.logger.info(f"Detected AMD CPU via WMIC: {cpu_info['name']}")
                                    return cpu_info
            except Exception as wmic_error:
                self.logger.warning(f"WMIC CPU detection failed: {wmic_error}")
            
            # Use registry as backup
            try:
                with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, 
                                   r"HARDWARE\DESCRIPTION\System\CentralProcessor\0") as key:
                    cpu_name = winreg.QueryValueEx(key, "ProcessorNameString")[0]
                
                if cpu_name and "amd" in cpu_name.lower():
                    cpu_info = {
                        'name': cpu_name.strip(),
                        'cores': psutil.cpu_count(logical=False) or 0,
                        'threads': psutil.cpu_count(logical=True) or 0
                    }
                    self.logger.info(f"Detected AMD CPU via registry: {cpu_info['name']}")
                    return cpu_info
            except Exception as reg_error:
                self.logger.warning(f"Registry CPU detection failed: {reg_error}")
            
        except Exception as e:
            self.logger.error(f"Error detecting AMD CPU: {e}")
        
        return None
    
    async def detect_amd_gpu(self) -> Optional[Dict]:
        """Detect AMD GPU information."""
        try:
            # Try WMI first
            if self.wmi_conn:
                for gpu in self.wmi_conn.Win32_VideoController():
                    if gpu.Name and ("amd" in gpu.Name.lower() or "radeon" in gpu.Name.lower()):
                        gpu_info = {
                            'name': gpu.Name,
                            'driver_version': gpu.DriverVersion if gpu.DriverVersion else "Unknown",
                            'device_id': gpu.DeviceID if gpu.DeviceID else None
                        }
                        self.logger.info(f"Detected AMD GPU via WMI: {gpu_info['name']}")
                        return gpu_info
            
            # Try WMIC
            result = subprocess.run(
                ['wmic', 'path', 'win32_videocontroller', 'get', 'name,driverversion', '/format:csv'],
                capture_output=True, text=True, timeout=10
            )
            
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                for line in lines[1:]:  # Skip header
                    if line.strip():
                        parts = line.split(',')
                        if len(parts) >= 3:
                            name = parts[2] if len(parts) > 2 else ""
                            driver_version = parts[1] if len(parts) > 1 else ""
                            
                            if name and ("amd" in name.lower() or "radeon" in name.lower()):
                                gpu_info = {
                                    'name': name,
                                    'driver_version': driver_version or "Unknown"
                                }
                                self.logger.info(f"Detected AMD GPU via WMIC: {gpu_info['name']}")
                                return gpu_info
            
        except Exception as e:
            self.logger.error(f"Error detecting AMD GPU: {e}")
        
        return None
    
    async def detect_installed_software(self) -> Dict:
        """Detect installed software versions from Windows registry."""
        software_info = {}
        
        try:
            # Common software registry locations
            registry_paths = [
                (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
                (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
                (winreg.HKEY_CURRENT_USER, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")
            ]
            
            software_patterns = {
                'ASUS Armoury Crate': ['armoury crate', 'armory crate'],
                'MyASUS': ['myasus', 'my asus'],
                'ASUS System Control Interface': ['asus system control', 'asci'],
                'ASUS Smart Gesture': ['smart gesture'],
                'AMD Software': ['amd software', 'amd adrenalin', 'radeon software'],
                'AMD Chipset Software': ['amd chipset', 'chipset software'],
                'NVIDIA GeForce Experience': ['geforce experience', 'nvidia geforce'],
                'NVIDIA Graphics Driver': ['nvidia graphics driver', 'nvidia display driver']
            }
            
            for hkey, reg_path in registry_paths:
                try:
                    with winreg.OpenKey(hkey, reg_path) as key:
                        for i in range(winreg.QueryInfoKey(key)[0]):  # Number of subkeys
                            try:
                                subkey_name = winreg.EnumKey(key, i)
                                with winreg.OpenKey(key, subkey_name) as subkey:
                                    try:
                                        display_name = winreg.QueryValueEx(subkey, "DisplayName")[0]
                                        display_version = winreg.QueryValueEx(subkey, "DisplayVersion")[0]
                                        
                                        # Check if this matches any software we're looking for
                                        for software_name, patterns in software_patterns.items():
                                            if any(pattern.lower() in display_name.lower() for pattern in patterns):
                                                if software_name not in software_info:
                                                    software_info[software_name] = {
                                                        'name': display_name,
                                                        'version': display_version,
                                                        'registry_key': subkey_name
                                                    }
                                                    self.logger.info(f"Found installed software: {display_name} v{display_version}")
                                                break
                                    except FileNotFoundError:
                                        continue
                            except Exception:
                                continue
                except Exception as e:
                    self.logger.debug(f"Could not access registry path {reg_path}: {e}")
                    continue
            
        except Exception as e:
            self.logger.error(f"Error detecting installed software: {e}")
        
        return software_info
    
    async def detect_system_info(self) -> Dict:
        """Detect general system information."""
        try:
            system_info = {
                'os_version': '',
                'architecture': '',
                'bios_version': '',
                'motherboard': ''
            }
            
            # Get OS info
            if self.wmi_conn:
                for os in self.wmi_conn.Win32_OperatingSystem():
                    system_info['os_version'] = f"{os.Caption} {os.Version}" if os.Caption and os.Version else "Unknown"
                    system_info['architecture'] = os.OSArchitecture if os.OSArchitecture else "Unknown"
                    break
                
                # Get BIOS info
                for bios in self.wmi_conn.Win32_BIOS():
                    system_info['bios_version'] = bios.SMBIOSBIOSVersion if bios.SMBIOSBIOSVersion else "Unknown"
                    break
                
                # Get motherboard info
                for board in self.wmi_conn.Win32_BaseBoard():
                    system_info['motherboard'] = f"{board.Manufacturer} {board.Product}" if board.Manufacturer and board.Product else "Unknown"
                    break
            
            return system_info
            
        except Exception as e:
            self.logger.error(f"Error detecting system info: {e}")
            return {}
    
    async def detect_pci_devices(self) -> List[Dict]:
        """Detect all PCI devices on the system."""
        devices = []
        try:
            # Try WMI first
            if self.wmi_conn:
                for device in self.wmi_conn.Win32_PnPEntity():
                    if device.HardwareID and device.DeviceID:
                        device_info = {
                            'name': device.Name or 'Unknown Device',
                            'device_id': device.DeviceID,
                            'hardware_id': device.HardwareID[0] if isinstance(device.HardwareID, list) else device.HardwareID,
                            'vendor': 'Unknown',
                            'status': device.Status or 'Unknown',
                            'problem_code': getattr(device, 'ConfigManagerErrorCode', 0),
                            'driver_date': getattr(device, 'DriverDate', None),
                            'driver_version': getattr(device, 'DriverVersion', None)
                        }
                        
                        # Extract vendor from hardware ID
                        if device_info['hardware_id']:
                            vendor_match = re.search(r'VEN_([0-9A-F]{4})', device_info['hardware_id'])
                            if vendor_match:
                                vendor_id = vendor_match.group(1)
                                device_info['vendor'] = self.vendor_ids.get(vendor_id, f'Vendor_{vendor_id}')
                        
                        devices.append(device_info)
            
            # Fallback to registry enumeration
            if not devices:
                devices = await self._enumerate_devices_from_registry()
            
            self.logger.info(f"Detected {len(devices)} PCI/hardware devices")
            return devices
            
        except Exception as e:
            self.logger.error(f"Error detecting PCI devices: {e}")
            return []
    
    async def _enumerate_devices_from_registry(self) -> List[Dict]:
        """Enumerate devices from Windows registry."""
        devices = []
        try:
            with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE,
                               r"SYSTEM\CurrentControlSet\Enum") as enum_key:
                for i in range(winreg.QueryInfoKey(enum_key)[0]):
                    try:
                        bus_name = winreg.EnumKey(enum_key, i)
                        with winreg.OpenKey(enum_key, bus_name) as bus_key:
                            for j in range(winreg.QueryInfoKey(bus_key)[0]):
                                try:
                                    device_name = winreg.EnumKey(bus_key, j)
                                    with winreg.OpenKey(bus_key, device_name) as device_key:
                                        for k in range(winreg.QueryInfoKey(device_key)[0]):
                                            try:
                                                instance_name = winreg.EnumKey(device_key, k)
                                                device_info = await self._get_device_info_from_registry(
                                                    f"{bus_name}\\{device_name}\\{instance_name}"
                                                )
                                                if device_info:
                                                    devices.append(device_info)
                                            except Exception:
                                                continue
                                except Exception:
                                    continue
                    except Exception:
                        continue
        except Exception as e:
            self.logger.error(f"Error enumerating devices from registry: {e}")
        
        return devices
    
    async def _get_device_info_from_registry(self, device_path: str) -> Optional[Dict]:
        """Get device information from registry path."""
        try:
            with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE,
                               f"SYSTEM\\CurrentControlSet\\Enum\\{device_path}") as key:
                device_info = {
                    'name': 'Unknown Device',
                    'device_id': device_path,
                    'hardware_id': '',
                    'vendor': 'Unknown',
                    'status': 'Unknown',
                    'problem_code': 0
                }
                
                try:
                    device_info['name'] = winreg.QueryValueEx(key, "DeviceDesc")[0]
                    if device_info['name'].startswith('@'):
                        # Handle indirect string references
                        device_info['name'] = device_info['name'].split(';')[-1] if ';' in device_info['name'] else device_info['name']
                except FileNotFoundError:
                    pass
                
                try:
                    hardware_ids = winreg.QueryValueEx(key, "HardwareID")[0]
                    if isinstance(hardware_ids, list):
                        device_info['hardware_id'] = hardware_ids[0]
                    else:
                        device_info['hardware_id'] = hardware_ids
                except FileNotFoundError:
                    pass
                
                # Extract vendor from hardware ID
                if device_info['hardware_id']:
                    vendor_match = re.search(r'VEN_([0-9A-F]{4})', device_info['hardware_id'])
                    if vendor_match:
                        vendor_id = vendor_match.group(1)
                        device_info['vendor'] = self.vendor_ids.get(vendor_id, f'Vendor_{vendor_id}')
                
                return device_info
                
        except Exception:
            return None
    
    async def detect_chipset(self) -> Optional[Dict]:
        """Detect system chipset information."""
        try:
            chipset_info = {
                'name': 'Unknown Chipset',
                'vendor': 'Unknown',
                'driver_version': 'Unknown'
            }
            
            if self.wmi_conn:
                # Check motherboard information
                for board in self.wmi_conn.Win32_BaseBoard():
                    if board.Manufacturer and board.Product:
                        chipset_info['name'] = f"{board.Manufacturer} {board.Product}"
                        
                        # Determine vendor
                        manufacturer_lower = board.Manufacturer.lower()
                        if 'intel' in manufacturer_lower:
                            chipset_info['vendor'] = 'Intel'
                        elif 'amd' in manufacturer_lower:
                            chipset_info['vendor'] = 'AMD'
                        elif 'asus' in manufacturer_lower:
                            chipset_info['vendor'] = 'ASUS'
                        else:
                            chipset_info['vendor'] = board.Manufacturer
                        break
                
                # Try to get chipset driver version from system devices
                for device in self.wmi_conn.Win32_SystemDriver():
                    if device.Name and ('chipset' in device.Name.lower() or 'pci' in device.Name.lower()):
                        if hasattr(device, 'Version') and device.Version:
                            chipset_info['driver_version'] = device.Version
                            break
            
            self.logger.info(f"Detected chipset: {chipset_info}")
            return chipset_info
            
        except Exception as e:
            self.logger.error(f"Error detecting chipset: {e}")
            return None
    
    async def detect_audio_devices(self) -> List[Dict]:
        """Detect audio devices and their drivers."""
        audio_devices = []
        try:
            if self.wmi_conn:
                for device in self.wmi_conn.Win32_SoundDevice():
                    if device.Name:
                        audio_info = {
                            'name': device.Name,
                            'manufacturer': getattr(device, 'Manufacturer', 'Unknown'),
                            'device_id': getattr(device, 'DeviceID', ''),
                            'status': getattr(device, 'Status', 'Unknown'),
                            'driver_version': 'Unknown'
                        }
                        
                        # Try to get driver version
                        if hasattr(device, 'DriverVersion') and device.DriverVersion:
                            audio_info['driver_version'] = device.DriverVersion
                        
                        audio_devices.append(audio_info)
            
            # Also check audio controllers via PnP devices
            if self.wmi_conn:
                for device in self.wmi_conn.Win32_PnPEntity():
                    if (device.Name and device.HardwareID and 
                        any(keyword in device.Name.lower() for keyword in ['audio', 'sound', 'speaker', 'microphone'])):
                        
                        # Avoid duplicates
                        if not any(existing['name'] == device.Name for existing in audio_devices):
                            audio_info = {
                                'name': device.Name,
                                'manufacturer': getattr(device, 'Manufacturer', 'Unknown'),
                                'device_id': getattr(device, 'DeviceID', ''),
                                'hardware_id': device.HardwareID[0] if isinstance(device.HardwareID, list) else device.HardwareID,
                                'status': getattr(device, 'Status', 'Unknown'),
                                'driver_version': getattr(device, 'DriverVersion', 'Unknown')
                            }
                            audio_devices.append(audio_info)
            
            self.logger.info(f"Detected {len(audio_devices)} audio devices")
            return audio_devices
            
        except Exception as e:
            self.logger.error(f"Error detecting audio devices: {e}")
            return []
    
    async def detect_network_devices(self) -> List[Dict]:
        """Detect network adapters and their drivers."""
        network_devices = []
        try:
            if self.wmi_conn:
                for adapter in self.wmi_conn.Win32_NetworkAdapter():
                    # Skip virtual and software adapters
                    if (adapter.Name and adapter.HardwareID and 
                        not any(keyword in adapter.Name.lower() for keyword in 
                               ['virtual', 'loopback', 'tunnel', 'teredo', 'isatap', 'miniport'])):
                        
                        network_info = {
                            'name': adapter.Name,
                            'manufacturer': getattr(adapter, 'Manufacturer', 'Unknown'),
                            'device_id': getattr(adapter, 'DeviceID', ''),
                            'hardware_id': adapter.HardwareID[0] if isinstance(adapter.HardwareID, list) else adapter.HardwareID,
                            'mac_address': getattr(adapter, 'MACAddress', ''),
                            'status': getattr(adapter, 'NetConnectionStatus', 'Unknown'),
                            'adapter_type': getattr(adapter, 'AdapterType', 'Unknown'),
                            'driver_version': 'Unknown'
                        }
                        
                        # Determine network type
                        name_lower = adapter.Name.lower()
                        if 'wifi' in name_lower or 'wireless' in name_lower or '802.11' in name_lower:
                            network_info['type'] = 'WiFi'
                        elif 'ethernet' in name_lower or 'lan' in name_lower:
                            network_info['type'] = 'Ethernet'
                        elif 'bluetooth' in name_lower:
                            network_info['type'] = 'Bluetooth'
                        else:
                            network_info['type'] = 'Other'
                        
                        network_devices.append(network_info)
            
            self.logger.info(f"Detected {len(network_devices)} network devices")
            return network_devices
            
        except Exception as e:
            self.logger.error(f"Error detecting network devices: {e}")
            return []
    
    async def detect_storage_devices(self) -> List[Dict]:
        """Detect storage devices and controllers."""
        storage_devices = []
        try:
            if self.wmi_conn:
                # Detect disk drives
                for disk in self.wmi_conn.Win32_DiskDrive():
                    if disk.Model:
                        storage_info = {
                            'name': disk.Model,
                            'type': 'Disk Drive',
                            'interface': getattr(disk, 'InterfaceType', 'Unknown'),
                            'size': getattr(disk, 'Size', 0),
                            'manufacturer': getattr(disk, 'Manufacturer', 'Unknown'),
                            'serial_number': getattr(disk, 'SerialNumber', '').strip() if getattr(disk, 'SerialNumber', '') else '',
                            'firmware_revision': getattr(disk, 'FirmwareRevision', 'Unknown')
                        }
                        
                        # Convert size to GB
                        if storage_info['size']:
                            try:
                                storage_info['size_gb'] = int(int(storage_info['size']) / (1024**3))
                            except:
                                storage_info['size_gb'] = 0
                        
                        storage_devices.append(storage_info)
                
                # Detect storage controllers
                for controller in self.wmi_conn.Win32_SCSIController():
                    if controller.Name:
                        controller_info = {
                            'name': controller.Name,
                            'type': 'Storage Controller',
                            'manufacturer': getattr(controller, 'Manufacturer', 'Unknown'),
                            'hardware_id': getattr(controller, 'HardwareID', ''),
                            'driver_version': getattr(controller, 'DriverVersion', 'Unknown')
                        }
                        storage_devices.append(controller_info)
            
            self.logger.info(f"Detected {len(storage_devices)} storage devices")
            return storage_devices
            
        except Exception as e:
            self.logger.error(f"Error detecting storage devices: {e}")
            return []
    
    async def detect_usb_devices(self) -> List[Dict]:
        """Detect USB devices and controllers."""
        usb_devices = []
        try:
            if self.wmi_conn:
                for device in self.wmi_conn.Win32_USBHub():
                    if device.Name:
                        usb_info = {
                            'name': device.Name,
                            'device_id': getattr(device, 'DeviceID', ''),
                            'description': getattr(device, 'Description', ''),
                            'status': getattr(device, 'Status', 'Unknown')
                        }
                        usb_devices.append(usb_info)
                
                # Also check USB controllers
                for controller in self.wmi_conn.Win32_USBController():
                    if controller.Name:
                        controller_info = {
                            'name': controller.Name,
                            'type': 'USB Controller',
                            'manufacturer': getattr(controller, 'Manufacturer', 'Unknown'),
                            'device_id': getattr(controller, 'DeviceID', ''),
                            'status': getattr(controller, 'Status', 'Unknown')
                        }
                        usb_devices.append(controller_info)
            
            self.logger.info(f"Detected {len(usb_devices)} USB devices")
            return usb_devices
            
        except Exception as e:
            self.logger.error(f"Error detecting USB devices: {e}")
            return []
    
    async def detect_bluetooth_devices(self) -> List[Dict]:
        """Detect Bluetooth devices and adapters."""
        bluetooth_devices = []
        try:
            if self.wmi_conn:
                for device in self.wmi_conn.Win32_PnPEntity():
                    if (device.Name and device.HardwareID and
                        'bluetooth' in device.Name.lower()):
                        
                        bluetooth_info = {
                            'name': device.Name,
                            'manufacturer': getattr(device, 'Manufacturer', 'Unknown'),
                            'device_id': getattr(device, 'DeviceID', ''),
                            'hardware_id': device.HardwareID[0] if isinstance(device.HardwareID, list) else device.HardwareID,
                            'status': getattr(device, 'Status', 'Unknown'),
                            'driver_version': getattr(device, 'DriverVersion', 'Unknown')
                        }
                        bluetooth_devices.append(bluetooth_info)
            
            self.logger.info(f"Detected {len(bluetooth_devices)} Bluetooth devices")
            return bluetooth_devices
            
        except Exception as e:
            self.logger.error(f"Error detecting Bluetooth devices: {e}")
            return []
    
    async def detect_all_hardware(self) -> Dict:
        """Detect all hardware components comprehensively."""
        self.logger.info("Starting comprehensive hardware detection...")
        
        # Initialize WMI
        await self.initialize_wmi()
        
        hardware_info = {}
        
        # Detect all components concurrently
        tasks = [
            ('asus_model', self.detect_asus_model()),
            ('nvidia_gpu', self.detect_nvidia_gpu()),
            ('amd_cpu', self.detect_amd_cpu()),
            ('amd_gpu', self.detect_amd_gpu()),
            ('system_info', self.detect_system_info()),
            ('installed_software', self.detect_installed_software()),
            ('chipset', self.detect_chipset()),
            ('audio_devices', self.detect_audio_devices()),
            ('network_devices', self.detect_network_devices()),
            ('storage_devices', self.detect_storage_devices()),
            ('usb_devices', self.detect_usb_devices()),
            ('bluetooth_devices', self.detect_bluetooth_devices()),
            ('pci_devices', self.detect_pci_devices())
        ]
        
        results = await asyncio.gather(*[task[1] for task in tasks], return_exceptions=True)
        
        for i, (key, _) in enumerate(tasks):
            if not isinstance(results[i], Exception) and results[i]:
                hardware_info[key] = results[i]
        
        # Add system summary
        hardware_info['detection_summary'] = {
            'total_components': len(hardware_info),
            'detection_timestamp': asyncio.get_event_loop().time(),
            'system_uuid': str(uuid.uuid4()),
            'os_info': platform.system() + ' ' + platform.release(),
            'python_version': platform.python_version()
        }
        
        self.logger.info(f"Comprehensive hardware detection complete. Found: {list(hardware_info.keys())}")
        return hardware_info
