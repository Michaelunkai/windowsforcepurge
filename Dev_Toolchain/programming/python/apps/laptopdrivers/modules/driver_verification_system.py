"""
Driver Verification and Safety System
Provides digital signature verification, compatibility checking, and safety
validation to ensure only legitimate and compatible drivers are installed.
"""

import asyncio
import subprocess
import logging
import hashlib
import tempfile
from typing import Dict, List, Optional, Tuple, Set
from pathlib import Path
from datetime import datetime
import json
import winreg
import re
import os

try:
    import pythoncom
    import wmi
    WMI_AVAILABLE = True
except ImportError:
    WMI_AVAILABLE = False
    wmi = None
    pythoncom = None

class DriverVerificationSystem:
    """Comprehensive driver verification and safety system."""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.wmi_conn = None
        
        # Known trusted publishers
        self.trusted_publishers = {
            'Microsoft Corporation',
            'Microsoft Windows',
            'NVIDIA Corporation',
            'Advanced Micro Devices, Inc.',
            'Intel Corporation',
            'Realtek Semiconductor Corp.',
            'Qualcomm Atheros Communications Inc.',
            'Broadcom Corporation',
            'ASUSTeK Computer Inc.',
            'ASUS',
            'Dell Inc.',
            'Hewlett-Packard Company',
            'Lenovo',
            'Logitech',
            'Creative Technology Ltd'
        }
        
        # Known malicious signatures to avoid
        self.blacklisted_signatures = {
            # Placeholder for known bad signatures
            'untrusted_publisher_example'
        }
        
        # Minimum driver date (drivers older than this are considered too old)
        self.min_driver_date = datetime(2018, 1, 1)
        
        # OS compatibility matrix
        self.os_compatibility = {
            'Windows 10': ['10.0'],
            'Windows 11': ['10.0', '11.0']
        }
    
    async def initialize(self):
        """Initialize the driver verification system."""
        try:
            if WMI_AVAILABLE:
                pythoncom.CoInitialize()
                self.wmi_conn = wmi.WMI()
                self.logger.info("Driver verification system initialized")
            else:
                self.logger.warning("WMI not available, using alternative methods")
            return True
        except Exception as e:
            self.logger.error(f"Failed to initialize driver verification system: {e}")
            return False
    
    async def verify_driver_package(self, driver_path: Path, device_hardware_id: str = None) -> Dict:
        """Comprehensive verification of a driver package."""
        verification_result = {
            'is_safe': False,
            'is_compatible': False,
            'signature_valid': False,
            'publisher_trusted': False,
            'version_acceptable': False,
            'hardware_compatible': False,
            'os_compatible': False,
            'details': {},
            'warnings': [],
            'errors': [],
            'recommendation': 'DO_NOT_INSTALL'
        }
        
        try:
            self.logger.info(f"Verifying driver package: {driver_path}")
            
            # Check if path exists and is accessible
            if not driver_path.exists():
                verification_result['errors'].append(f"Driver package not found: {driver_path}")
                return verification_result
            
            # Verify digital signature
            signature_result = await self._verify_digital_signature(driver_path)
            verification_result['signature_valid'] = signature_result['valid']
            verification_result['details']['signature'] = signature_result
            
            if not signature_result['valid']:
                verification_result['errors'].append("Driver package has invalid or missing digital signature")
            else:
                # Check publisher trust
                publisher = signature_result.get('publisher', '')
                verification_result['publisher_trusted'] = self._is_publisher_trusted(publisher)
                verification_result['details']['publisher'] = publisher
                
                if not verification_result['publisher_trusted']:
                    verification_result['warnings'].append(f"Publisher not in trusted list: {publisher}")
            
            # Verify driver version and date
            version_result = await self._verify_driver_version(driver_path)
            verification_result['version_acceptable'] = version_result['acceptable']
            verification_result['details']['version'] = version_result
            
            if not version_result['acceptable']:
                verification_result['warnings'].append(f"Driver version may be outdated: {version_result.get('version', 'Unknown')}")
            
            # Check OS compatibility
            os_result = await self._verify_os_compatibility(driver_path)
            verification_result['os_compatible'] = os_result['compatible']
            verification_result['details']['os_compatibility'] = os_result
            
            if not os_result['compatible']:
                verification_result['errors'].append(f"Driver not compatible with current OS: {os_result.get('current_os', 'Unknown')}")
            
            # Check hardware compatibility if hardware ID provided
            if device_hardware_id:
                hw_result = await self._verify_hardware_compatibility(driver_path, device_hardware_id)
                verification_result['hardware_compatible'] = hw_result['compatible']
                verification_result['details']['hardware_compatibility'] = hw_result
                
                if not hw_result['compatible']:
                    verification_result['warnings'].append("Driver may not be compatible with detected hardware")
            else:
                verification_result['hardware_compatible'] = True  # Assume compatible if no hardware ID
            
            # Scan for malware indicators
            malware_result = await self._scan_for_malware_indicators(driver_path)
            verification_result['details']['malware_scan'] = malware_result
            
            if malware_result['suspicious']:
                verification_result['errors'].append("Driver package contains suspicious indicators")
            
            # Calculate overall safety and compatibility
            verification_result['is_safe'] = (
                verification_result['signature_valid'] and
                verification_result['publisher_trusted'] and
                not malware_result['suspicious']
            )
            
            verification_result['is_compatible'] = (
                verification_result['version_acceptable'] and
                verification_result['os_compatible'] and
                verification_result['hardware_compatible']
            )
            
            # Determine recommendation
            if verification_result['is_safe'] and verification_result['is_compatible']:
                verification_result['recommendation'] = 'SAFE_TO_INSTALL'
            elif verification_result['is_safe'] and not verification_result['is_compatible']:
                verification_result['recommendation'] = 'COMPATIBLE_ISSUES'
            elif not verification_result['is_safe'] and verification_result['is_compatible']:
                verification_result['recommendation'] = 'SECURITY_RISK'
            else:
                verification_result['recommendation'] = 'DO_NOT_INSTALL'
            
            return verification_result
            
        except Exception as e:
            self.logger.error(f"Error during driver verification: {e}")
            verification_result['errors'].append(f"Verification error: {str(e)}")
            return verification_result
    
    async def _verify_digital_signature(self, driver_path: Path) -> Dict:
        """Verify the digital signature of a driver package."""
        signature_result = {
            'valid': False,
            'publisher': '',
            'signed_date': '',
            'certificate_chain': [],
            'signature_algorithm': '',
            'error': None
        }
        
        try:
            # Use PowerShell to verify signature
            powershell_script = f'''
            try {{
                $signature = Get-AuthenticodeSignature -FilePath "{driver_path}"
                
                $result = @{{
                    Status = $signature.Status.ToString()
                    SignerCertificate = if ($signature.SignerCertificate) {{
                        @{{
                            Subject = $signature.SignerCertificate.Subject
                            Issuer = $signature.SignerCertificate.Issuer
                            NotBefore = $signature.SignerCertificate.NotBefore.ToString()
                            NotAfter = $signature.SignerCertificate.NotAfter.ToString()
                            Thumbprint = $signature.SignerCertificate.Thumbprint
                        }}
                    }} else {{ $null }}
                    TimeStamperCertificate = if ($signature.TimeStamperCertificate) {{
                        @{{
                            Subject = $signature.TimeStamperCertificate.Subject
                            NotBefore = $signature.TimeStamperCertificate.NotBefore.ToString()
                            NotAfter = $signature.TimeStamperCertificate.NotAfter.ToString()
                        }}
                    }} else {{ $null }}
                }}
                
                return $result | ConvertTo-Json -Depth 3
            }} catch {{
                return @{{ Error = $_.Exception.Message }} | ConvertTo-Json
            }}
            '''
            
            result = await self._run_powershell_async(powershell_script, timeout=30)
            
            if result and result.returncode == 0:
                try:
                    signature_data = json.loads(result.stdout)
                    
                    if signature_data.get('Error'):
                        signature_result['error'] = signature_data['Error']
                    else:
                        status = signature_data.get('Status', 'Unknown')
                        signature_result['valid'] = status == 'Valid'
                        
                        signer_cert = signature_data.get('SignerCertificate')
                        if signer_cert:
                            signature_result['publisher'] = self._extract_common_name(signer_cert.get('Subject', ''))
                            signature_result['signed_date'] = signer_cert.get('NotBefore', '')
                            signature_result['certificate_chain'].append({
                                'subject': signer_cert.get('Subject', ''),
                                'issuer': signer_cert.get('Issuer', ''),
                                'thumbprint': signer_cert.get('Thumbprint', '')
                            })
                        
                        timestamp_cert = signature_data.get('TimeStamperCertificate')
                        if timestamp_cert:
                            signature_result['certificate_chain'].append({
                                'subject': timestamp_cert.get('Subject', ''),
                                'type': 'Timestamp'
                            })
                
                except json.JSONDecodeError as e:
                    signature_result['error'] = f"Failed to parse signature data: {e}"
            else:
                signature_result['error'] = "Failed to verify signature"
            
            # Additional verification for INF files
            if driver_path.suffix.lower() == '.inf':
                inf_verification = await self._verify_inf_signature(driver_path)
                signature_result.update(inf_verification)
            
            return signature_result
            
        except Exception as e:
            signature_result['error'] = str(e)
            return signature_result
    
    def _extract_common_name(self, subject: str) -> str:
        """Extract common name from certificate subject."""
        try:
            cn_match = re.search(r'CN=([^,]+)', subject)
            if cn_match:
                return cn_match.group(1).strip()
        except Exception:
            pass
        return subject
    
    async def _verify_inf_signature(self, inf_path: Path) -> Dict:
        """Verify INF file signature using Windows verification."""
        inf_result = {
            'inf_valid': False,
            'cat_file_found': False,
            'cat_file_valid': False
        }
        
        try:
            # Look for associated catalog file
            cat_files = list(inf_path.parent.glob('*.cat'))
            
            if cat_files:
                inf_result['cat_file_found'] = True
                
                # Verify catalog file
                for cat_file in cat_files:
                    verify_result = subprocess.run([
                        'signtool', 'verify', '/pa', str(cat_file)
                    ], capture_output=True, text=True, timeout=30)
                    
                    if verify_result.returncode == 0:
                        inf_result['cat_file_valid'] = True
                        break
            
            # Verify INF file with pnputil
            pnputil_result = subprocess.run([
                'pnputil', '/verify-driver', str(inf_path)
            ], capture_output=True, text=True, timeout=30)
            
            inf_result['inf_valid'] = pnputil_result.returncode == 0
            
            return inf_result
            
        except Exception as e:
            self.logger.debug(f"INF signature verification error: {e}")
            return inf_result
    
    def _is_publisher_trusted(self, publisher: str) -> bool:
        """Check if publisher is in the trusted list."""
        if not publisher:
            return False
        
        # Check against blacklist first
        if publisher.lower() in [p.lower() for p in self.blacklisted_signatures]:
            return False
        
        # Check against trusted publishers
        return any(trusted.lower() in publisher.lower() or publisher.lower() in trusted.lower() 
                  for trusted in self.trusted_publishers)
    
    async def _verify_driver_version(self, driver_path: Path) -> Dict:
        """Verify driver version and date acceptability."""
        version_result = {
            'acceptable': False,
            'version': '',
            'date': '',
            'too_old': False,
            'error': None
        }
        
        try:
            if driver_path.suffix.lower() == '.inf':
                # Parse INF file for version information
                version_info = await self._parse_inf_version(driver_path)
                version_result.update(version_info)
            else:
                # Get file version for executable drivers
                version_info = await self._get_file_version(driver_path)
                version_result.update(version_info)
            
            # Check if date is acceptable
            if version_result['date']:
                try:
                    driver_date = datetime.strptime(version_result['date'], '%Y-%m-%d')
                    version_result['too_old'] = driver_date < self.min_driver_date
                    version_result['acceptable'] = not version_result['too_old']
                except ValueError:
                    version_result['acceptable'] = True  # Assume acceptable if can't parse date
            else:
                version_result['acceptable'] = True  # Assume acceptable if no date
            
            return version_result
            
        except Exception as e:
            version_result['error'] = str(e)
            return version_result
    
    async def _parse_inf_version(self, inf_path: Path) -> Dict:
        """Parse version information from INF file."""
        version_info = {
            'version': '',
            'date': '',
            'provider': '',
            'class': ''
        }
        
        try:
            with open(inf_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # Extract version information
            version_match = re.search(r'DriverVer\s*=\s*([^,]+),([^,\n]+)', content, re.IGNORECASE)
            if version_match:
                date_str = version_match.group(1).strip()
                version_str = version_match.group(2).strip()
                
                # Convert date format (MM/DD/YYYY to YYYY-MM-DD)
                try:
                    if '/' in date_str:
                        parts = date_str.split('/')
                        if len(parts) == 3:
                            version_info['date'] = f"{parts[2]}-{parts[0].zfill(2)}-{parts[1].zfill(2)}"
                    else:
                        version_info['date'] = date_str
                except Exception:
                    version_info['date'] = date_str
                
                version_info['version'] = version_str
            
            # Extract provider
            provider_match = re.search(r'Provider\s*=\s*([^\n]+)', content, re.IGNORECASE)
            if provider_match:
                version_info['provider'] = provider_match.group(1).strip().strip('"')
            
            # Extract class
            class_match = re.search(r'Class\s*=\s*([^\n]+)', content, re.IGNORECASE)
            if class_match:
                version_info['class'] = class_match.group(1).strip().strip('"')
            
            return version_info
            
        except Exception as e:
            self.logger.debug(f"Error parsing INF version: {e}")
            return version_info
    
    async def _get_file_version(self, file_path: Path) -> Dict:
        """Get version information from executable file."""
        version_info = {
            'version': '',
            'date': '',
            'description': '',
            'company': ''
        }
        
        try:
            # Use PowerShell to get file version
            powershell_script = f'''
            try {{
                $file = Get-Item "{file_path}"
                $version = $file.VersionInfo
                
                $result = @{{
                    FileVersion = $version.FileVersion
                    ProductVersion = $version.ProductVersion
                    CompanyName = $version.CompanyName
                    FileDescription = $version.FileDescription
                    LastWriteTime = $file.LastWriteTime.ToString("yyyy-MM-dd")
                }}
                
                return $result | ConvertTo-Json
            }} catch {{
                return @{{ Error = $_.Exception.Message }} | ConvertTo-Json
            }}
            '''
            
            result = await self._run_powershell_async(powershell_script, timeout=15)
            
            if result and result.returncode == 0:
                try:
                    version_data = json.loads(result.stdout)
                    
                    version_info['version'] = version_data.get('FileVersion') or version_data.get('ProductVersion', '')
                    version_info['date'] = version_data.get('LastWriteTime', '')
                    version_info['description'] = version_data.get('FileDescription', '')
                    version_info['company'] = version_data.get('CompanyName', '')
                    
                except json.JSONDecodeError:
                    pass
            
            return version_info
            
        except Exception as e:
            self.logger.debug(f"Error getting file version: {e}")
            return version_info
    
    async def _verify_os_compatibility(self, driver_path: Path) -> Dict:
        """Verify OS compatibility of the driver."""
        os_result = {
            'compatible': False,
            'supported_os': [],
            'current_os': '',
            'architecture_match': False
        }
        
        try:
            # Get current OS information
            if self.wmi_conn:
                for os_info in self.wmi_conn.Win32_OperatingSystem():
                    os_result['current_os'] = f"{os_info.Caption} {os_info.Version}"
                    break
            
            if not os_result['current_os']:
                import platform
                os_result['current_os'] = f"{platform.system()} {platform.release()}"
            
            # Check architecture
            import platform
            current_arch = platform.machine().lower()
            
            if driver_path.suffix.lower() == '.inf':
                # Parse INF for architecture and OS support
                os_support = await self._parse_inf_os_support(driver_path)
                os_result.update(os_support)
                
                # Check if current architecture is supported
                supported_archs = os_result.get('supported_architectures', [])
                os_result['architecture_match'] = (
                    not supported_archs or  # No specific arch requirement
                    any(arch.lower() in current_arch for arch in supported_archs) or
                    ('x64' in supported_archs and current_arch in ['amd64', 'x86_64']) or
                    ('x86' in supported_archs and current_arch in ['i386', 'i686'])
                )
            else:
                # For executable drivers, assume compatibility with current OS
                os_result['architecture_match'] = True
                os_result['supported_os'] = [os_result['current_os']]
            
            # Determine overall compatibility
            os_result['compatible'] = (
                os_result['architecture_match'] and
                (not os_result['supported_os'] or  # No specific OS requirement
                 any('windows' in supported_os.lower() for supported_os in os_result['supported_os']))
            )
            
            return os_result
            
        except Exception as e:
            self.logger.debug(f"Error verifying OS compatibility: {e}")
            os_result['compatible'] = True  # Assume compatible if can't verify
            return os_result
    
    async def _parse_inf_os_support(self, inf_path: Path) -> Dict:
        """Parse OS support information from INF file."""
        os_support = {
            'supported_os': [],
            'supported_architectures': [],
            'target_os_version': ''
        }
        
        try:
            with open(inf_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # Look for TargetOSVersion
            target_os_match = re.search(r'TargetOSVersion\s*=\s*([^\n]+)', content, re.IGNORECASE)
            if target_os_match:
                os_support['target_os_version'] = target_os_match.group(1).strip()
            
            # Look for architecture specifications
            arch_patterns = [
                r'\.NT(x86|amd64|arm64|x64)',
                r'Architecture\s*=\s*([^\n]+)'
            ]
            
            for pattern in arch_patterns:
                matches = re.findall(pattern, content, re.IGNORECASE)
                for match in matches:
                    if isinstance(match, tuple):
                        os_support['supported_architectures'].extend(match)
                    else:
                        os_support['supported_architectures'].append(match)
            
            # Remove duplicates and clean up
            os_support['supported_architectures'] = list(set(
                arch.strip() for arch in os_support['supported_architectures'] if arch.strip()
            ))
            
            # Default OS support assumption for Windows drivers
            if not os_support['supported_os']:
                os_support['supported_os'] = ['Windows 10', 'Windows 11']
            
            return os_support
            
        except Exception as e:
            self.logger.debug(f"Error parsing INF OS support: {e}")
            return os_support
    
    async def _verify_hardware_compatibility(self, driver_path: Path, hardware_id: str) -> Dict:
        """Verify hardware compatibility of the driver."""
        hw_result = {
            'compatible': False,
            'supported_hardware_ids': [],
            'exact_match': False,
            'partial_match': False
        }
        
        try:
            if driver_path.suffix.lower() == '.inf':
                # Parse INF for hardware ID support
                hw_support = await self._parse_inf_hardware_support(driver_path)
                hw_result['supported_hardware_ids'] = hw_support
                
                # Check for exact match
                hw_result['exact_match'] = hardware_id.upper() in [hid.upper() for hid in hw_support]
                
                # Check for partial match (vendor/device ID)
                if not hw_result['exact_match'] and hardware_id:
                    hardware_id_upper = hardware_id.upper()
                    for supported_id in hw_support:
                        supported_id_upper = supported_id.upper()
                        
                        # Extract VEN and DEV IDs
                        hw_ven_match = re.search(r'VEN_([0-9A-F]{4})', hardware_id_upper)
                        hw_dev_match = re.search(r'DEV_([0-9A-F]{4})', hardware_id_upper)
                        sup_ven_match = re.search(r'VEN_([0-9A-F]{4})', supported_id_upper)
                        sup_dev_match = re.search(r'DEV_([0-9A-F]{4})', supported_id_upper)
                        
                        if (hw_ven_match and sup_ven_match and 
                            hw_ven_match.group(1) == sup_ven_match.group(1)):
                            if (hw_dev_match and sup_dev_match and 
                                hw_dev_match.group(1) == sup_dev_match.group(1)):
                                hw_result['partial_match'] = True
                                break
                
                hw_result['compatible'] = hw_result['exact_match'] or hw_result['partial_match']
            else:
                # For non-INF drivers, assume compatible
                hw_result['compatible'] = True
            
            return hw_result
            
        except Exception as e:
            self.logger.debug(f"Error verifying hardware compatibility: {e}")
            hw_result['compatible'] = True  # Assume compatible if can't verify
            return hw_result
    
    async def _parse_inf_hardware_support(self, inf_path: Path) -> List[str]:
        """Parse hardware IDs from INF file."""
        hardware_ids = []
        
        try:
            with open(inf_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # Look for hardware ID patterns
            hardware_patterns = [
                r'%([^%]+)%\s*=\s*[^,]+,\s*([^,\n]+)',  # Device installation sections
                r'HardwareIDs\s*=\s*([^\n]+)',          # Explicit hardware ID lists
                r'(PCI\\VEN_[0-9A-F]{4}&DEV_[0-9A-F]{4}[^\s,]*)',  # PCI hardware IDs
                r'(USB\\VID_[0-9A-F]{4}&PID_[0-9A-F]{4}[^\s,]*)'   # USB hardware IDs
            ]
            
            for pattern in hardware_patterns:
                matches = re.findall(pattern, content, re.IGNORECASE)
                for match in matches:
                    if isinstance(match, tuple):
                        for part in match:
                            if part and ('VEN_' in part.upper() or 'VID_' in part.upper()):
                                hardware_ids.append(part.strip().strip('"'))
                    else:
                        if match and ('VEN_' in match.upper() or 'VID_' in match.upper()):
                            hardware_ids.append(match.strip().strip('"'))
            
            # Remove duplicates
            hardware_ids = list(set(hardware_ids))
            
            return hardware_ids
            
        except Exception as e:
            self.logger.debug(f"Error parsing INF hardware support: {e}")
            return []
    
    async def _scan_for_malware_indicators(self, driver_path: Path) -> Dict:
        """Scan driver for malware indicators."""
        malware_result = {
            'suspicious': False,
            'indicators': [],
            'file_hash': '',
            'file_size': 0
        }
        
        try:
            # Calculate file hash
            malware_result['file_hash'] = self._calculate_file_hash(driver_path)
            malware_result['file_size'] = driver_path.stat().st_size
            
            # Check file size (extremely large or small drivers are suspicious)
            if malware_result['file_size'] > 100 * 1024 * 1024:  # > 100MB
                malware_result['indicators'].append("Unusually large file size")
            elif malware_result['file_size'] < 1024:  # < 1KB
                malware_result['indicators'].append("Unusually small file size")
            
            # Check for suspicious strings (if text-based)
            if driver_path.suffix.lower() in ['.inf', '.txt', '.reg']:
                suspicious_strings = await self._scan_for_suspicious_strings(driver_path)
                malware_result['indicators'].extend(suspicious_strings)
            
            # Check file entropy (packed/encrypted files have high entropy)
            entropy = await self._calculate_file_entropy(driver_path)
            if entropy > 7.5:  # High entropy threshold
                malware_result['indicators'].append("High file entropy (possibly packed/encrypted)")
            
            malware_result['suspicious'] = len(malware_result['indicators']) > 0
            
            return malware_result
            
        except Exception as e:
            self.logger.debug(f"Error scanning for malware indicators: {e}")
            return malware_result
    
    def _calculate_file_hash(self, file_path: Path) -> str:
        """Calculate SHA256 hash of file."""
        try:
            sha256_hash = hashlib.sha256()
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    sha256_hash.update(chunk)
            return sha256_hash.hexdigest()
        except Exception:
            return ""
    
    async def _scan_for_suspicious_strings(self, file_path: Path) -> List[str]:
        """Scan file for suspicious strings."""
        suspicious_indicators = []
        
        try:
            # Suspicious strings to look for
            suspicious_patterns = [
                r'\\\\[^\\]+\\[Cc]\$',  # Admin shares
                r'net\s+user\s+\w+\s+/add',  # User creation
                r'reg\s+add\s+.*\\run',  # Registry run keys
                r'powershell\s+-e\s+',  # Encoded PowerShell
                r'\\\\?\\pipe\\',  # Named pipes
                r'SeDebugPrivilege',  # Debug privilege
                r'\\\\deviceharddisk',  # Direct disk access
            ]
            
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            for pattern in suspicious_patterns:
                if re.search(pattern, content, re.IGNORECASE):
                    suspicious_indicators.append(f"Suspicious pattern found: {pattern}")
            
            return suspicious_indicators
            
        except Exception:
            return []
    
    async def _calculate_file_entropy(self, file_path: Path) -> float:
        """Calculate Shannon entropy of file."""
        try:
            import math
            from collections import Counter
            
            with open(file_path, 'rb') as f:
                data = f.read()
            
            if not data:
                return 0.0
            
            # Count byte frequencies
            byte_counts = Counter(data)
            data_len = len(data)
            
            # Calculate entropy
            entropy = 0.0
            for count in byte_counts.values():
                probability = count / data_len
                entropy -= probability * math.log2(probability)
            
            return entropy
            
        except Exception:
            return 0.0
    
    async def _run_powershell_async(self, script: str, timeout: int = 60) -> Optional[subprocess.CompletedProcess]:
        """Run PowerShell script asynchronously."""
        try:
            with tempfile.NamedTemporaryFile(mode='w', suffix='.ps1', delete=False) as f:
                f.write(script)
                script_path = f.name
            
            try:
                process = await asyncio.create_subprocess_exec(
                    'powershell', '-ExecutionPolicy', 'Bypass', '-File', script_path,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=timeout)
                
                return subprocess.CompletedProcess(
                    args=['powershell', '-File', script_path],
                    returncode=process.returncode,
                    stdout=stdout.decode('utf-8', errors='ignore'),
                    stderr=stderr.decode('utf-8', errors='ignore')
                )
                
            finally:
                try:
                    Path(script_path).unlink()
                except Exception:
                    pass
                    
        except Exception as e:
            self.logger.error(f"Error running PowerShell script: {e}")
            return None
    
    def generate_verification_report(self, verification_result: Dict) -> str:
        """Generate a human-readable verification report."""
        report_lines = []
        
        report_lines.append("=== DRIVER VERIFICATION REPORT ===")
        report_lines.append(f"Overall Recommendation: {verification_result['recommendation']}")
        report_lines.append(f"Safe to Install: {'✅ YES' if verification_result['is_safe'] else '❌ NO'}")
        report_lines.append(f"Compatible: {'✅ YES' if verification_result['is_compatible'] else '❌ NO'}")
        report_lines.append("")
        
        # Security checks
        report_lines.append("🔒 SECURITY VERIFICATION:")
        report_lines.append(f"  Digital Signature: {'✅ Valid' if verification_result['signature_valid'] else '❌ Invalid'}")
        report_lines.append(f"  Trusted Publisher: {'✅ Yes' if verification_result['publisher_trusted'] else '❌ No'}")
        
        publisher = verification_result['details'].get('signature', {}).get('publisher', '')
        if publisher:
            report_lines.append(f"  Publisher: {publisher}")
        
        report_lines.append("")
        
        # Compatibility checks
        report_lines.append("🔧 COMPATIBILITY VERIFICATION:")
        report_lines.append(f"  Version Acceptable: {'✅ Yes' if verification_result['version_acceptable'] else '❌ No'}")
        report_lines.append(f"  OS Compatible: {'✅ Yes' if verification_result['os_compatible'] else '❌ No'}")
        report_lines.append(f"  Hardware Compatible: {'✅ Yes' if verification_result['hardware_compatible'] else '❌ No'}")
        
        version_details = verification_result['details'].get('version', {})
        if version_details.get('version'):
            report_lines.append(f"  Driver Version: {version_details['version']}")
        if version_details.get('date'):
            report_lines.append(f"  Driver Date: {version_details['date']}")
        
        report_lines.append("")
        
        # Warnings and errors
        if verification_result['warnings']:
            report_lines.append("⚠️  WARNINGS:")
            for warning in verification_result['warnings']:
                report_lines.append(f"  • {warning}")
            report_lines.append("")
        
        if verification_result['errors']:
            report_lines.append("❌ ERRORS:")
            for error in verification_result['errors']:
                report_lines.append(f"  • {error}")
            report_lines.append("")
        
        report_lines.append("=== END OF REPORT ===")
        
        return "\n".join(report_lines)
