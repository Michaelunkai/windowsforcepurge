"""
Universal Driver Detection Module
Comprehensive driver scanning for all hardware components using Windows APIs,
Device Manager queries, and registry analysis to find missing or outdated drivers.
"""

import asyncio
import subprocess
import logging
import winreg
import re
from typing import Dict, List, Optional, Tuple, Set
from pathlib import Path
from datetime import datetime, timedelta
import json

try:
    import pythoncom
    import wmi
    WMI_AVAILABLE = True
except ImportError:
    WMI_AVAILABLE = False
    wmi = None
    pythoncom = None

class UniversalDriverDetector:
    """Universal driver detection and analysis system."""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.wmi_conn = None
        
        # Driver problem codes that indicate driver issues
        self.problem_codes = {
            1: "Device not configured correctly",
            3: "Driver for this device might be corrupted",
            10: "Device cannot start",
            18: "Device drivers for this device need to be reinstalled",
            19: "Registry might be corrupted",
            21: "System is shutting down",
            22: "Device has been disabled",
            24: "Device not present, not working, or doesn't have all drivers installed",
            28: "Device drivers are not installed",
            31: "Device is not working properly",
            37: "Windows cannot initialize device driver",
            39: "Windows cannot load device driver",
            40: "Windows cannot access device",
            41: "Windows successfully loaded device driver but cannot find hardware device",
            43: "Windows has stopped this device because it has reported problems",
            45: "Currently, hardware device is not connected to computer",
            47: "Windows cannot use this hardware device because it has been prepared for safe removal",
            48: "Device driver software was blocked from starting",
            49: "Windows cannot start new hardware devices"
        }
        
        # Known driver update sources
        self.driver_sources = {
            'windows_update': 'Windows Update',
            'manufacturer_website': 'Manufacturer Website',
            'driver_store': 'Windows Driver Store',
            'third_party': 'Third-party Driver Database'
        }
        
        # Critical device classes that should always have proper drivers
        self.critical_device_classes = {
            'Display',
            'Audio',
            'Network',
            'Storage',
            'USB',
            'Bluetooth',
            'System',
            'Processor'
        }
    
    async def initialize(self):
        """Initialize the universal driver detector."""
        try:
            if WMI_AVAILABLE:
                pythoncom.CoInitialize()
                self.wmi_conn = wmi.WMI()
                self.logger.info("Universal driver detector initialized with WMI")
            else:
                self.logger.warning("WMI not available, using alternative methods")
            return True
        except Exception as e:
            self.logger.error(f"Failed to initialize universal driver detector: {e}")
            return False
    
    async def scan_all_drivers(self, hardware_info: Dict) -> Dict:
        """Perform comprehensive driver scan for all hardware."""
        self.logger.info("Starting comprehensive driver scan...")
        
        driver_status = {
            'missing_drivers': [],
            'outdated_drivers': [],
            'problematic_drivers': [],
            'up_to_date_drivers': [],
            'unknown_devices': [],
            'scan_summary': {
                'total_devices_scanned': 0,
                'devices_needing_attention': 0,
                'critical_issues': 0,
                'scan_timestamp': datetime.now().isoformat()
            }
        }
        
        try:
            # Scan for devices with problems
            problem_devices = await self._detect_problem_devices()
            driver_status['problematic_drivers'].extend(problem_devices)
            
            # Scan for unknown devices
            unknown_devices = await self._detect_unknown_devices()
            driver_status['unknown_devices'].extend(unknown_devices)
            
            # Scan for missing drivers
            missing_drivers = await self._detect_missing_drivers()
            driver_status['missing_drivers'].extend(missing_drivers)
            
            # Scan for outdated drivers
            outdated_drivers = await self._detect_outdated_drivers(hardware_info)
            driver_status['outdated_drivers'].extend(outdated_drivers)
            
            # Scan for up-to-date drivers
            updated_drivers = await self._detect_updated_drivers()
            driver_status['up_to_date_drivers'].extend(updated_drivers)
            
            # Calculate summary statistics
            total_devices = (len(driver_status['missing_drivers']) + 
                           len(driver_status['outdated_drivers']) + 
                           len(driver_status['problematic_drivers']) + 
                           len(driver_status['up_to_date_drivers']) + 
                           len(driver_status['unknown_devices']))
            
            critical_issues = (len(driver_status['missing_drivers']) + 
                             len(driver_status['problematic_drivers']) + 
                             len(driver_status['unknown_devices']))
            
            devices_needing_attention = (len(driver_status['missing_drivers']) + 
                                       len(driver_status['outdated_drivers']) + 
                                       len(driver_status['problematic_drivers']))
            
            driver_status['scan_summary'].update({
                'total_devices_scanned': total_devices,
                'devices_needing_attention': devices_needing_attention,
                'critical_issues': critical_issues
            })
            
            self.logger.info(f"Driver scan complete: {total_devices} devices scanned, "
                           f"{devices_needing_attention} need attention, {critical_issues} critical issues")
            
            return driver_status
            
        except Exception as e:
            self.logger.error(f"Error during comprehensive driver scan: {e}")
            return driver_status
    
    async def _detect_problem_devices(self) -> List[Dict]:
        """Detect devices with driver problems."""
        problem_devices = []
        
        try:
            if self.wmi_conn:
                for device in self.wmi_conn.Win32_PnPEntity():
                    problem_code = getattr(device, 'ConfigManagerErrorCode', 0)
                    
                    if problem_code and problem_code != 0:
                        problem_info = {
                            'name': device.Name or 'Unknown Device',
                            'device_id': device.DeviceID or '',
                            'hardware_id': device.HardwareID[0] if device.HardwareID else '',
                            'problem_code': problem_code,
                            'problem_description': self.problem_codes.get(problem_code, f'Unknown problem (Code: {problem_code})'),
                            'status': device.Status or 'Unknown',
                            'driver_version': getattr(device, 'DriverVersion', 'Unknown'),
                            'driver_date': getattr(device, 'DriverDate', None),
                            'severity': self._determine_problem_severity(problem_code),
                            'recommended_action': self._get_recommended_action(problem_code)
                        }
                        problem_devices.append(problem_info)
            
            self.logger.info(f"Found {len(problem_devices)} devices with driver problems")
            return problem_devices
            
        except Exception as e:
            self.logger.error(f"Error detecting problem devices: {e}")
            return []
    
    def _determine_problem_severity(self, problem_code: int) -> str:
        """Determine the severity of a device problem."""
        critical_codes = {3, 10, 18, 24, 28, 37, 39, 40, 43}
        high_codes = {1, 19, 22, 31, 41, 48, 49}
        
        if problem_code in critical_codes:
            return 'Critical'
        elif problem_code in high_codes:
            return 'High'
        else:
            return 'Medium'
    
    def _get_recommended_action(self, problem_code: int) -> str:
        """Get recommended action for a problem code."""
        actions = {
            1: "Update device driver or check device configuration",
            3: "Reinstall device driver",
            10: "Update or reinstall device driver",
            18: "Reinstall device drivers",
            19: "Clean boot and reinstall driver",
            22: "Enable device in Device Manager",
            24: "Install missing device drivers",
            28: "Install device drivers",
            31: "Update device driver",
            37: "Reinstall device driver",
            39: "Reinstall device driver",
            40: "Update device driver or check hardware connection",
            41: "Check hardware connection and update driver",
            43: "Update or rollback device driver",
            48: "Update device driver or check driver signature",
            49: "Update device driver"
        }
        return actions.get(problem_code, "Update device driver")
    
    async def _detect_unknown_devices(self) -> List[Dict]:
        """Detect unknown devices without proper drivers."""
        unknown_devices = []
        
        try:
            if self.wmi_conn:
                for device in self.wmi_conn.Win32_PnPEntity():
                    if (device.Name and 
                        ('unknown' in device.Name.lower() or 
                         device.Name.lower().startswith('unknown device') or
                         not getattr(device, 'DriverVersion', None))):
                        
                        unknown_info = {
                            'name': device.Name,
                            'device_id': device.DeviceID or '',
                            'hardware_id': device.HardwareID[0] if device.HardwareID else '',
                            'status': device.Status or 'Unknown',
                            'manufacturer': getattr(device, 'Manufacturer', 'Unknown'),
                            'driver_version': getattr(device, 'DriverVersion', None),
                            'driver_date': getattr(device, 'DriverDate', None),
                            'needs_driver': True,
                            'priority': 'High' if any(cls in (device.Name or '') for cls in self.critical_device_classes) else 'Medium'
                        }
                        
                        # Try to identify device type from hardware ID
                        if unknown_info['hardware_id']:
                            unknown_info['device_type'] = self._identify_device_type(unknown_info['hardware_id'])
                        
                        unknown_devices.append(unknown_info)
            
            self.logger.info(f"Found {len(unknown_devices)} unknown devices")
            return unknown_devices
            
        except Exception as e:
            self.logger.error(f"Error detecting unknown devices: {e}")
            return []
    
    def _identify_device_type(self, hardware_id: str) -> str:
        """Identify device type from hardware ID."""
        hardware_id_lower = hardware_id.lower()
        
        if 'ven_10de' in hardware_id_lower:
            return 'NVIDIA Device'
        elif 'ven_1002' in hardware_id_lower:
            return 'AMD/ATI Device'
        elif 'ven_8086' in hardware_id_lower:
            return 'Intel Device'
        elif 'ven_10ec' in hardware_id_lower:
            return 'Realtek Device'
        elif 'ven_14e4' in hardware_id_lower:
            return 'Broadcom Device'
        elif 'ven_168c' in hardware_id_lower:
            return 'Qualcomm Atheros Device'
        elif 'usb\\' in hardware_id_lower:
            return 'USB Device'
        elif 'pci\\' in hardware_id_lower:
            return 'PCI Device'
        elif 'acpi\\' in hardware_id_lower:
            return 'ACPI Device'
        else:
            return 'Unknown Device Type'
    
    async def _detect_missing_drivers(self) -> List[Dict]:
        """Detect devices that are missing drivers entirely."""
        missing_drivers = []
        
        try:
            # Check Device Manager for devices without drivers
            result = subprocess.run([
                'powershell', '-Command',
                "Get-WmiObject Win32_SystemDriver | Where-Object {$_.State -eq 'Stopped' -and $_.StartMode -eq 'Auto'} | Select-Object Name, PathName, State, Status"
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0 and result.stdout:
                lines = result.stdout.strip().split('\n')
                for line in lines[3:]:  # Skip headers
                    if line.strip():
                        missing_info = {
                            'name': 'Missing System Driver',
                            'description': line.strip(),
                            'status': 'Driver Missing',
                            'severity': 'High',
                            'recommended_action': 'Install missing driver'
                        }
                        missing_drivers.append(missing_info)
            
            # Also check for devices that failed to start
            if self.wmi_conn:
                for device in self.wmi_conn.Win32_PnPEntity():
                    if (device.Status == 'Error' or 
                        getattr(device, 'ConfigManagerErrorCode', 0) in [28, 24, 37, 39]):
                        
                        missing_info = {
                            'name': device.Name or 'Unknown Device',
                            'device_id': device.DeviceID or '',
                            'hardware_id': device.HardwareID[0] if device.HardwareID else '',
                            'status': 'Driver Missing or Failed',
                            'severity': 'Critical',
                            'recommended_action': 'Install or reinstall device driver'
                        }
                        missing_drivers.append(missing_info)
            
            self.logger.info(f"Found {len(missing_drivers)} devices with missing drivers")
            return missing_drivers
            
        except Exception as e:
            self.logger.error(f"Error detecting missing drivers: {e}")
            return []
    
    async def _detect_outdated_drivers(self, hardware_info: Dict) -> List[Dict]:
        """Detect drivers that have newer versions available."""
        outdated_drivers = []
        
        try:
            # Check driver dates - drivers older than 2 years might be outdated
            cutoff_date = datetime.now() - timedelta(days=730)  # 2 years
            
            if self.wmi_conn:
                for device in self.wmi_conn.Win32_PnPEntity():
                    if device.DriverDate and device.DriverVersion:
                        try:
                            # Parse WMI date format (YYYYMMDDHHMMSS.ffffff+UUU)
                            date_str = device.DriverDate.split('.')[0]
                            driver_date = datetime.strptime(date_str, '%Y%m%d%H%M%S')
                            
                            if driver_date < cutoff_date:
                                outdated_info = {
                                    'name': device.Name or 'Unknown Device',
                                    'device_id': device.DeviceID or '',
                                    'hardware_id': device.HardwareID[0] if device.HardwareID else '',
                                    'current_version': device.DriverVersion,
                                    'driver_date': driver_date.strftime('%Y-%m-%d'),
                                    'days_old': (datetime.now() - driver_date).days,
                                    'status': 'Potentially Outdated',
                                    'severity': 'Medium',
                                    'recommended_action': 'Check for driver updates'
                                }
                                
                                # Higher priority for critical devices
                                if any(keyword in (device.Name or '').lower() 
                                      for keyword in ['display', 'graphics', 'audio', 'network', 'ethernet', 'wifi']):
                                    outdated_info['severity'] = 'High'
                                
                                outdated_drivers.append(outdated_info)
                                
                        except (ValueError, AttributeError) as e:
                            self.logger.debug(f"Could not parse driver date for {device.Name}: {e}")
                            continue
            
            self.logger.info(f"Found {len(outdated_drivers)} potentially outdated drivers")
            return outdated_drivers
            
        except Exception as e:
            self.logger.error(f"Error detecting outdated drivers: {e}")
            return []
    
    async def _detect_updated_drivers(self) -> List[Dict]:
        """Detect drivers that are up to date."""
        updated_drivers = []
        
        try:
            recent_cutoff = datetime.now() - timedelta(days=365)  # 1 year
            
            if self.wmi_conn:
                for device in self.wmi_conn.Win32_PnPEntity():
                    if (device.DriverDate and device.DriverVersion and 
                        getattr(device, 'ConfigManagerErrorCode', 0) == 0):
                        
                        try:
                            date_str = device.DriverDate.split('.')[0]
                            driver_date = datetime.strptime(date_str, '%Y%m%d%H%M%S')
                            
                            if driver_date >= recent_cutoff:
                                updated_info = {
                                    'name': device.Name or 'Unknown Device',
                                    'device_id': device.DeviceID or '',
                                    'current_version': device.DriverVersion,
                                    'driver_date': driver_date.strftime('%Y-%m-%d'),
                                    'status': 'Up to Date',
                                    'manufacturer': getattr(device, 'Manufacturer', 'Unknown')
                                }
                                updated_drivers.append(updated_info)
                                
                        except (ValueError, AttributeError):
                            continue
            
            self.logger.info(f"Found {len(updated_drivers)} up-to-date drivers")
            return updated_drivers
            
        except Exception as e:
            self.logger.error(f"Error detecting updated drivers: {e}")
            return []
    
    async def find_driver_solutions(self, device_info: Dict) -> List[Dict]:
        """Find potential driver solutions for a device."""
        solutions = []
        
        try:
            hardware_id = device_info.get('hardware_id', '')
            device_name = device_info.get('name', '')
            
            # Extract vendor and device IDs
            vendor_match = re.search(r'VEN_([0-9A-F]{4})', hardware_id)
            device_match = re.search(r'DEV_([0-9A-F]{4})', hardware_id)
            
            if vendor_match and device_match:
                vendor_id = vendor_match.group(1)
                device_id = device_match.group(1)
                
                # Check Windows Update
                solutions.append({
                    'source': 'Windows Update',
                    'method': 'automatic',
                    'description': 'Search Windows Update for compatible drivers',
                    'reliability': 'High',
                    'command': f'pnputil /scan-devices /instanceid "{device_info.get("device_id", "")}"'
                })
                
                # Check manufacturer websites based on vendor ID
                vendor_info = self._get_vendor_info(vendor_id)
                if vendor_info:
                    solutions.append({
                        'source': vendor_info['name'],
                        'method': 'manual',
                        'description': f'Download from {vendor_info["name"]} official website',
                        'url': vendor_info.get('support_url', ''),
                        'reliability': 'High'
                    })
                
                # Generic driver databases
                solutions.append({
                    'source': 'Generic Driver Database',
                    'method': 'manual',
                    'description': 'Search third-party driver databases',
                    'reliability': 'Medium',
                    'warning': 'Verify driver authenticity before installation'
                })
            
            return solutions
            
        except Exception as e:
            self.logger.error(f"Error finding driver solutions: {e}")
            return []
    
    def _get_vendor_info(self, vendor_id: str) -> Optional[Dict]:
        """Get vendor information from vendor ID."""
        vendors = {
            '1022': {'name': 'AMD', 'support_url': 'https://www.amd.com/support'},
            '10DE': {'name': 'NVIDIA', 'support_url': 'https://www.nvidia.com/drivers'},
            '8086': {'name': 'Intel', 'support_url': 'https://www.intel.com/content/www/us/en/support'},
            '1002': {'name': 'AMD', 'support_url': 'https://www.amd.com/support'},
            '10EC': {'name': 'Realtek', 'support_url': 'https://www.realtek.com/downloads'},
            '14E4': {'name': 'Broadcom', 'support_url': 'https://www.broadcom.com/support'},
            '168C': {'name': 'Qualcomm Atheros', 'support_url': 'https://www.qualcomm.com/support'},
            '1043': {'name': 'ASUS', 'support_url': 'https://www.asus.com/support'}
        }
        
        return vendors.get(vendor_id.upper())
    
    async def generate_driver_report(self, scan_results: Dict) -> str:
        """Generate a comprehensive driver status report."""
        report_lines = []
        
        report_lines.append("=== COMPREHENSIVE DRIVER STATUS REPORT ===")
        report_lines.append(f"Scan completed: {scan_results['scan_summary']['scan_timestamp']}")
        report_lines.append(f"Total devices scanned: {scan_results['scan_summary']['total_devices_scanned']}")
        report_lines.append(f"Devices needing attention: {scan_results['scan_summary']['devices_needing_attention']}")
        report_lines.append(f"Critical issues: {scan_results['scan_summary']['critical_issues']}")
        report_lines.append("")
        
        # Critical Issues Section
        if scan_results['missing_drivers'] or scan_results['problematic_drivers'] or scan_results['unknown_devices']:
            report_lines.append("🚨 CRITICAL ISSUES REQUIRING IMMEDIATE ATTENTION:")
            
            for device in scan_results['missing_drivers']:
                report_lines.append(f"  ❌ MISSING DRIVER: {device['name']}")
                report_lines.append(f"     Action: {device['recommended_action']}")
            
            for device in scan_results['problematic_drivers']:
                report_lines.append(f"  ⚠️  PROBLEM DEVICE: {device['name']}")
                report_lines.append(f"     Issue: {device['problem_description']}")
                report_lines.append(f"     Severity: {device['severity']}")
                report_lines.append(f"     Action: {device['recommended_action']}")
            
            for device in scan_results['unknown_devices']:
                report_lines.append(f"  ❓ UNKNOWN DEVICE: {device['name']}")
                report_lines.append(f"     Type: {device.get('device_type', 'Unknown')}")
                report_lines.append(f"     Priority: {device['priority']}")
            
            report_lines.append("")
        
        # Outdated Drivers Section
        if scan_results['outdated_drivers']:
            report_lines.append("📅 OUTDATED DRIVERS:")
            for driver in scan_results['outdated_drivers']:
                report_lines.append(f"  🔄 {driver['name']}")
                report_lines.append(f"     Version: {driver['current_version']}")
                report_lines.append(f"     Date: {driver['driver_date']} ({driver['days_old']} days old)")
                report_lines.append(f"     Severity: {driver['severity']}")
            report_lines.append("")
        
        # Up-to-date Drivers Section
        if scan_results['up_to_date_drivers']:
            report_lines.append("✅ UP-TO-DATE DRIVERS:")
            for driver in scan_results['up_to_date_drivers'][:10]:  # Show first 10
                report_lines.append(f"  ✓ {driver['name']} - {driver['current_version']}")
            
            if len(scan_results['up_to_date_drivers']) > 10:
                report_lines.append(f"  ... and {len(scan_results['up_to_date_drivers']) - 10} more")
            report_lines.append("")
        
        report_lines.append("=== END OF REPORT ===")
        
        return "\n".join(report_lines)
