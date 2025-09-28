"""
Driver Version Checker Module
Checks current installed driver versions and compares with latest available versions.
"""

import asyncio
import subprocess
import json
import re
import logging
from typing import Dict, Optional, List, Tuple
from pathlib import Path
import winreg
from packaging import version

class DriverChecker:
    """Checks and compares driver versions."""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
    
    async def get_current_nvidia_version(self) -> Optional[str]:
        """Get currently installed NVIDIA driver version."""
        try:
            # Try nvidia-smi first (most reliable)
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=driver_version', '--format=csv,noheader,nounits'],
                capture_output=True, text=True, timeout=10
            )
            
            if result.returncode == 0:
                version_str = result.stdout.strip()
                if version_str:
                    self.logger.info(f"Current NVIDIA driver version: {version_str}")
                    return version_str
            
            # Try registry lookup
            try:
                with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE,
                                   r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall") as key:
                    for i in range(winreg.QueryInfoKey(key)[0]):
                        try:
                            subkey_name = winreg.EnumKey(key, i)
                            with winreg.OpenKey(key, subkey_name) as subkey:
                                try:
                                    display_name = winreg.QueryValueEx(subkey, "DisplayName")[0]
                                    if "nvidia graphics driver" in display_name.lower():
                                        display_version = winreg.QueryValueEx(subkey, "DisplayVersion")[0]
                                        self.logger.info(f"Found NVIDIA driver in registry: {display_version}")
                                        return display_version
                                except FileNotFoundError:
                                    continue
                        except OSError:
                            continue
            except Exception as e:
                self.logger.warning(f"Registry lookup failed: {e}")
            
            # Try WMIC as last resort
            result = subprocess.run(
                ['wmic', 'path', 'win32_systemdriver', 'where', 'name like "%nvidia%"', 
                 'get', 'version', '/format:csv'],
                capture_output=True, text=True, timeout=10
            )
            
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                for line in lines[1:]:  # Skip header
                    if line.strip():
                        parts = line.split(',')
                        if len(parts) >= 2 and parts[1]:
                            version_str = parts[1]
                            self.logger.info(f"Found NVIDIA driver via WMIC: {version_str}")
                            return version_str
            
        except Exception as e:
            self.logger.error(f"Error getting NVIDIA driver version: {e}")
        
        return None
    
    async def get_current_amd_version(self) -> Optional[Dict[str, str]]:
        """Get currently installed AMD driver versions."""
        try:
            amd_versions = {}
            
            # Check AMD display driver
            try:
                with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE,
                                   r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall") as key:
                    for i in range(winreg.QueryInfoKey(key)[0]):
                        try:
                            subkey_name = winreg.EnumKey(key, i)
                            with winreg.OpenKey(key, subkey_name) as subkey:
                                try:
                                    display_name = winreg.QueryValueEx(subkey, "DisplayName")[0]
                                    display_version = winreg.QueryValueEx(subkey, "DisplayVersion")[0]
                                    
                                    if "amd" in display_name.lower():
                                        if "software" in display_name.lower() or "adrenalin" in display_name.lower():
                                            amd_versions['amd_software'] = display_version
                                        elif "chipset" in display_name.lower():
                                            amd_versions['amd_chipset'] = display_version
                                        elif "display" in display_name.lower() or "graphics" in display_name.lower():
                                            amd_versions['amd_display'] = display_version
                                            
                                except FileNotFoundError:
                                    continue
                        except OSError:
                            continue
            except Exception as e:
                self.logger.warning(f"AMD registry lookup failed: {e}")
            
            # Try to get AMD driver info from device manager via WMIC
            result = subprocess.run(
                ['wmic', 'path', 'win32_pnpsigneddriver', 'where', 
                 'devicename like "%AMD%" or devicename like "%Radeon%"',
                 'get', 'devicename,driverversion', '/format:csv'],
                capture_output=True, text=True, timeout=15
            )
            
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                for line in lines[1:]:  # Skip header
                    if line.strip():
                        parts = line.split(',')
                        if len(parts) >= 3:
                            device_name = parts[1] if len(parts) > 1 else ""
                            driver_version = parts[2] if len(parts) > 2 else ""
                            
                            if device_name and driver_version:
                                if "display" in device_name.lower() or "graphics" in device_name.lower():
                                    amd_versions['amd_display_device'] = driver_version
                                elif "audio" in device_name.lower():
                                    amd_versions['amd_audio'] = driver_version
            
            if amd_versions:
                self.logger.info(f"Found AMD driver versions: {amd_versions}")
                return amd_versions
            
        except Exception as e:
            self.logger.error(f"Error getting AMD driver versions: {e}")
        
        return None
    
    async def get_current_asus_versions(self, asus_model: str) -> Optional[Dict[str, str]]:
        """Get currently installed ASUS-specific software versions."""
        try:
            asus_versions = {}
            
            # Common ASUS software to check
            asus_software_patterns = [
                "asus",
                "armoury crate",
                "myasus",
                "asus system control interface",
                "asus live update",
                "asus smart gesture",
                "asus precision touchpad",
                "asus battery health charging",
                "asus keyboard hotkeys",
                "asus wireless console",
                "asus splendid",
                "asus audio wizard",
                "asus gaming center"
            ]
            
            try:
                with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE,
                                   r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall") as key:
                    for i in range(winreg.QueryInfoKey(key)[0]):
                        try:
                            subkey_name = winreg.EnumKey(key, i)
                            with winreg.OpenKey(key, subkey_name) as subkey:
                                try:
                                    display_name = winreg.QueryValueEx(subkey, "DisplayName")[0]
                                    display_version = winreg.QueryValueEx(subkey, "DisplayVersion")[0]
                                    
                                    display_name_lower = display_name.lower()
                                    
                                    for pattern in asus_software_patterns:
                                        if pattern in display_name_lower:
                                            # Clean up the key name
                                            key_name = pattern.replace(" ", "_")
                                            asus_versions[key_name] = display_version
                                            break
                                            
                                except FileNotFoundError:
                                    continue
                        except OSError:
                            continue
            except Exception as e:
                self.logger.warning(f"ASUS registry lookup failed: {e}")
            
            # Check for BIOS version
            try:
                result = subprocess.run(
                    ['wmic', 'bios', 'get', 'smbiosbiosversion', '/format:csv'],
                    capture_output=True, text=True, timeout=10
                )
                
                if result.returncode == 0:
                    lines = result.stdout.strip().split('\n')
                    for line in lines[1:]:  # Skip header
                        if line.strip():
                            parts = line.split(',')
                            if len(parts) >= 2 and parts[1]:
                                asus_versions['bios'] = parts[1]
                                break
            except Exception as e:
                self.logger.warning(f"BIOS version lookup failed: {e}")
            
            if asus_versions:
                self.logger.info(f"Found ASUS software versions: {asus_versions}")
                return asus_versions
            
        except Exception as e:
            self.logger.error(f"Error getting ASUS software versions: {e}")
        
        return None
    
    def compare_versions(self, current: str, latest: str) -> bool:
        """Compare two version strings. Returns True if latest is newer."""
        try:
            # Clean version strings
            current_clean = re.sub(r'[^\d\.]', '', current)
            latest_clean = re.sub(r'[^\d\.]', '', latest)
            
            if not current_clean or not latest_clean:
                return False
            
            # Use packaging library for proper version comparison
            return version.parse(latest_clean) > version.parse(current_clean)
            
        except Exception as e:
            self.logger.error(f"Error comparing versions {current} vs {latest}: {e}")
            # Fallback to string comparison
            return latest != current
    
    async def check_driver_updates_needed(self, hardware_info: Dict, available_versions: Dict) -> Dict:
        """Check which drivers need updates based on hardware and available versions."""
        updates_needed = {}
        
        try:
            # Check NVIDIA updates
            if hardware_info.get('nvidia_gpu') and available_versions.get('nvidia'):
                current_nvidia = await self.get_current_nvidia_version()
                if current_nvidia:
                    latest_nvidia = available_versions['nvidia'].get('version')
                    if latest_nvidia and self.compare_versions(current_nvidia, latest_nvidia):
                        updates_needed['nvidia'] = {
                            'current_version': current_nvidia,
                            'latest_version': latest_nvidia,
                            'update_available': True
                        }
                        self.logger.info(f"NVIDIA update available: {current_nvidia} -> {latest_nvidia}")
                    else:
                        updates_needed['nvidia'] = {
                            'current_version': current_nvidia,
                            'latest_version': latest_nvidia or current_nvidia,
                            'update_available': False
                        }
            
            # Check AMD updates
            if (hardware_info.get('amd_cpu') or hardware_info.get('amd_gpu')) and available_versions.get('amd'):
                current_amd = await self.get_current_amd_version()
                if current_amd:
                    amd_updates = {}
                    for component, current_ver in current_amd.items():
                        latest_ver = available_versions['amd'].get(component, {}).get('version')
                        if latest_ver and self.compare_versions(current_ver, latest_ver):
                            amd_updates[component] = {
                                'current_version': current_ver,
                                'latest_version': latest_ver,
                                'update_available': True
                            }
                        else:
                            amd_updates[component] = {
                                'current_version': current_ver,
                                'latest_version': latest_ver or current_ver,
                                'update_available': False
                            }
                    
                    if any(update['update_available'] for update in amd_updates.values()):
                        updates_needed['amd'] = amd_updates
                        self.logger.info(f"AMD updates available: {amd_updates}")
            
            # Check ASUS updates
            if hardware_info.get('asus_model') and available_versions.get('asus'):
                current_asus = await self.get_current_asus_versions(hardware_info['asus_model'])
                if current_asus:
                    asus_updates = {}
                    for component, current_ver in current_asus.items():
                        latest_ver = available_versions['asus'].get(component, {}).get('version')
                        if latest_ver and self.compare_versions(current_ver, latest_ver):
                            asus_updates[component] = {
                                'current_version': current_ver,
                                'latest_version': latest_ver,
                                'update_available': True
                            }
                        else:
                            asus_updates[component] = {
                                'current_version': current_ver,
                                'latest_version': latest_ver or current_ver,
                                'update_available': False
                            }
                    
                    if any(update['update_available'] for update in asus_updates.values()):
                        updates_needed['asus'] = asus_updates
                        self.logger.info(f"ASUS updates available: {asus_updates}")
            
            return updates_needed
            
        except Exception as e:
            self.logger.error(f"Error checking for driver updates: {e}")
            return {}
