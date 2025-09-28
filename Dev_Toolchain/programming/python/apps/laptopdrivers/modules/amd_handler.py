"""
AMD Driver Handler Module
Handles detection, download, and installation of AMD drivers (CPU, GPU, Chipset).
"""

import asyncio
import aiohttp
import subprocess
import json
import re
import os
import tempfile
import logging
from typing import Dict, Optional, List
from pathlib import Path
import zipfile
# Remove BeautifulSoup dependency for faster parsing
# from bs4 import BeautifulSoup

class AMDDriverHandler:
    """Handles AMD driver operations."""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.amd_base_url = "https://www.amd.com"
        self.support_url = "https://www.amd.com/support"
        self.auto_detect_url = "https://www.amd.com/support/auto-detect-tool"
        
        # AMD product families
        self.cpu_families = {
            'ryzen 9': 'ryzen-9',
            'ryzen 7': 'ryzen-7', 
            'ryzen 5': 'ryzen-5',
            'ryzen 3': 'ryzen-3',
            'athlon': 'athlon',
            'a-series': 'a-series'
        }
        
        self.gpu_families = {
            'radeon rx 7000': 'radeon-rx-7000',
            'radeon rx 6000': 'radeon-rx-6000',
            'radeon rx 5000': 'radeon-rx-5000',
            'radeon rx vega': 'radeon-rx-vega',
            'radeon r9': 'radeon-r9',
            'radeon r7': 'radeon-r7',
            'radeon r5': 'radeon-r5'
        }
    
    def _identify_amd_products(self, hardware_info: Dict) -> Dict:
        """Identify AMD products from hardware info."""
        products = {}
        
        # Identify CPU
        if hardware_info.get('amd_cpu'):
            cpu_name = hardware_info['amd_cpu'].get('name', '').lower()
            for family_name, family_id in self.cpu_families.items():
                if family_name in cpu_name:
                    products['cpu_family'] = family_id
                    products['cpu_name'] = hardware_info['amd_cpu'].get('name')
                    break
        
        # Identify GPU
        if hardware_info.get('amd_gpu'):
            gpu_name = hardware_info['amd_gpu'].get('name', '').lower()
            for family_name, family_id in self.gpu_families.items():
                if family_name in gpu_name:
                    products['gpu_family'] = family_id
                    products['gpu_name'] = hardware_info['amd_gpu'].get('name')
                    break
        
        return products
    
    async def get_amd_auto_detect_tool(self) -> Optional[str]:
        """Get the AMD auto-detect tool download URL."""
        try:
            # Set a 15-second timeout
            timeout = aiohttp.ClientTimeout(total=15)
            
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(self.auto_detect_url) as response:
                    if response.status == 200:
                        # Just return the auto-detect page URL
                        return self.auto_detect_url
            
        except asyncio.TimeoutError:
            self.logger.error("AMD auto-detect tool request timed out")
        except Exception as e:
            self.logger.error(f"Error getting AMD auto-detect tool: {e}")
        
        # Return the auto-detect URL as fallback
        return self.auto_detect_url
    
    async def get_latest_amd_software(self) -> Optional[Dict]:
        """Get latest AMD Software Adrenalin Edition info."""
        try:
            # AMD Software download page
            amd_software_url = "https://www.amd.com/support/graphics/amd-radeon-rx-graphics"
            
            # Set a 30-second timeout
            timeout = aiohttp.ClientTimeout(total=30)
            
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(amd_software_url) as response:
                    if response.status == 200:
                        content = await response.text()
                        
                        # Look for version information (simplified check)
                        version_pattern = r'AMD Software[:\s]*(?:Adrenalin Edition\s*)?(\d+\.\d+(?:\.\d+)?)'
                        version_match = re.search(version_pattern, content, re.IGNORECASE)
                        
                        if version_match:
                            version = version_match.group(1)
                            
                            # Return basic info without trying to find exact download link
                            return {
                                'name': f'AMD Software Adrenalin Edition {version}',
                                'version': version,
                                'download_url': amd_software_url,  # Use the main page URL
                                'type': 'amd_software'
                            }
                        else:
                            # Return generic info if version not found
                            return {
                                'name': 'AMD Software Adrenalin Edition',
                                'version': 'Latest',
                                'download_url': amd_software_url,
                                'type': 'amd_software'
                            }
            
        except asyncio.TimeoutError:
            self.logger.error("AMD Software info request timed out")
        except Exception as e:
            self.logger.error(f"Error getting AMD Software info: {e}")
        
        return None
    
    async def get_chipset_drivers(self, hardware_info: Dict) -> Optional[Dict]:
        """Get AMD chipset drivers for the system."""
        try:
            # AMD chipset download page
            chipset_url = "https://www.amd.com/support/chipsets"
            
            # Set a 20-second timeout
            timeout = aiohttp.ClientTimeout(total=20)
            
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(chipset_url) as response:
                    if response.status == 200:
                        content = await response.text()
                        
                        # Look for latest chipset driver version (more flexible pattern)
                        version_pattern = r'AMD Chipset[^0-9]*(\d+\.\d+(?:\.\d+)*(?:\.\d+)?)'
                        version_match = re.search(version_pattern, content, re.IGNORECASE)
                        
                        if version_match:
                            version = version_match.group(1)
                            
                            return {
                                'name': f'AMD Chipset Software {version}',
                                'version': version,
                                'download_url': chipset_url,  # Use main page URL
                                'type': 'chipset'
                            }
                        else:
                            # Return generic info
                            return {
                                'name': 'AMD Chipset Software',
                                'version': 'Latest',
                                'download_url': chipset_url,
                                'type': 'chipset'
                            }
            
        except asyncio.TimeoutError:
            self.logger.error("AMD chipset drivers request timed out")
        except Exception as e:
            self.logger.error(f"Error getting AMD chipset drivers: {e}")
        
        return None
    
    async def check_for_updates(self, hardware_info: Dict) -> Optional[Dict]:
        """Check for AMD driver updates."""
        try:
            updates = {}
            
            # Get installed software info
            installed_software = hardware_info.get('installed_software', {})
            
            # For speed, provide known AMD software without web scraping
            if hardware_info.get('amd_gpu') or hardware_info.get('amd_cpu'):
                # Check current AMD Software version
                amd_software_current = 'Not Installed'
                for software_name, software_info in installed_software.items():
                    if 'amd software' in software_name.lower() or 'adrenalin' in software_name.lower():
                        amd_software_current = software_info.get('version', 'Unknown')
                        break
                
                updates['amd_software'] = {
                    'name': 'AMD Software Adrenalin Edition',
                    'version': '24.2.1',
                    'download_url': 'https://www.amd.com/support/graphics/amd-radeon-rx-graphics',
                    'type': 'amd_software',
                    'current_version': amd_software_current,
                    'latest_version': '24.2.1',
                    'update_available': amd_software_current in ['Not Installed', 'Unknown'],
                    'component': 'AMD Graphics Software',
                    'category': 'amd'
                }
            
            # Check for chipset drivers (for CPU)
            if hardware_info.get('amd_cpu'):
                # Check current chipset version
                chipset_current = 'Not Installed'
                for software_name, software_info in installed_software.items():
                    if 'amd chipset' in software_name.lower() or 'chipset software' in software_name.lower():
                        chipset_current = software_info.get('version', 'Unknown')
                        break
                
                updates['chipset'] = {
                    'name': 'AMD Chipset Software',
                    'version': '6.12.0.87',
                    'download_url': 'https://www.amd.com/support/chipsets',
                    'type': 'chipset',
                    'current_version': chipset_current,
                    'latest_version': '6.12.0.87',
                    'update_available': chipset_current in ['Not Installed', 'Unknown'],
                    'component': 'AMD Chipset Drivers',
                    'category': 'amd'
                }
            
            # Always provide auto-detect tool
            updates['auto_detect'] = {
                'name': 'AMD Auto-Detect and Install Tool',
                'version': 'Latest',
                'download_url': 'https://www.amd.com/support/auto-detect-tool',
                'type': 'auto_detect',
                'current_version': 'Not Installed',
                'latest_version': 'Latest',
                'update_available': True,
                'component': 'AMD Auto-Detect Tool',
                'category': 'amd'
            }
            
            if updates:
                self.logger.info(f"Found AMD updates: {list(updates.keys())}")
                return updates
            
        except Exception as e:
            self.logger.error(f"Error checking for AMD updates: {e}")
        
        return None
    
    async def download_driver(self, driver_info: Dict, download_path: Path) -> Optional[Path]:
        """Download AMD driver."""
        try:
            download_url = driver_info.get('download_url')
            if not download_url:
                self.logger.error("No download URL available for AMD driver")
                return None
            
            # Create download directory
            download_path.mkdir(parents=True, exist_ok=True)
            
            # Generate filename
            driver_type = driver_info.get('type', 'amd_driver')
            version = driver_info.get('version', 'latest')
            filename = f"amd_{driver_type}_{version}.exe"
            file_path = download_path / filename
            
            self.logger.info(f"Downloading AMD driver to: {file_path}")
            
            async with aiohttp.ClientSession() as session:
                async with session.get(download_url) as response:
                    if response.status == 200:
                        total_size = int(response.headers.get('content-length', 0))
                        downloaded = 0
                        
                        with open(file_path, 'wb') as f:
                            async for chunk in response.content.iter_chunked(8192):
                                f.write(chunk)
                                downloaded += len(chunk)
                                
                                if total_size > 0:
                                    progress = (downloaded / total_size) * 100
                                    if downloaded % (1024 * 1024) == 0:  # Log every MB
                                        self.logger.info(f"Downloaded {progress:.1f}%")
                        
                        self.logger.info(f"AMD driver downloaded successfully: {file_path}")
                        return file_path
                    else:
                        self.logger.error(f"AMD driver download failed: {response.status}")
                        return None
            
        except Exception as e:
            self.logger.error(f"Error downloading AMD driver: {e}")
            return None
    
    async def install_driver(self, driver_info: Dict) -> bool:
        """Install AMD driver."""
        try:
            # Create temporary directory for download
            with tempfile.TemporaryDirectory() as temp_dir:
                temp_path = Path(temp_dir)
                
                # Download driver
                driver_file = await self.download_driver(driver_info, temp_path)
                if not driver_file:
                    return False
                
                driver_type = driver_info.get('type', 'unknown')
                self.logger.info(f"Starting AMD {driver_type} installation...")
                
                # Prepare installation command based on driver type
                if driver_type == 'amd_software':
                    # AMD Software Adrenalin Edition
                    install_cmd = [
                        str(driver_file),
                        '/S',  # Silent install
                        '/v/qn'  # Quiet, no UI
                    ]
                elif driver_type == 'chipset':
                    # AMD Chipset Software
                    install_cmd = [
                        str(driver_file),
                        '/S'  # Silent install
                    ]
                elif driver_type == 'auto_detect':
                    # Auto-detect tool - run normally as it needs user interaction
                    install_cmd = [str(driver_file)]
                else:
                    # Generic installation
                    install_cmd = [
                        str(driver_file),
                        '/S'
                    ]
                
                # Run installation
                process = subprocess.Popen(
                    install_cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )
                
                # Wait for installation to complete
                try:
                    timeout = 3600 if driver_type == 'amd_software' else 1800  # Longer timeout for full AMD Software
                    stdout, stderr = process.communicate(timeout=timeout)
                    
                    if process.returncode == 0:
                        self.logger.info(f"AMD {driver_type} installation completed successfully")
                        return True
                    else:
                        self.logger.error(f"AMD {driver_type} installation failed: {stderr}")
                        return False
                        
                except subprocess.TimeoutExpired:
                    process.kill()
                    self.logger.error(f"AMD {driver_type} installation timed out")
                    return False
        
        except Exception as e:
            self.logger.error(f"Error installing AMD driver: {e}")
            return False
    
    async def get_current_amd_versions(self) -> Dict[str, str]:
        """Get currently installed AMD software versions."""
        try:
            versions = {}
            
            # Try to get AMD Software version
            try:
                result = subprocess.run([
                    'reg', 'query', 
                    'HKEY_LOCAL_MACHINE\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall',
                    '/s', '/f', 'AMD Software'
                ], capture_output=True, text=True, timeout=30)
                
                if result.returncode == 0:
                    # Parse registry output for version
                    version_match = re.search(r'DisplayVersion\s+REG_SZ\s+(\d+\.\d+\.\d+)', result.stdout)
                    if version_match:
                        versions['amd_software'] = version_match.group(1)
            except Exception:
                pass
            
            # Try to get chipset version
            try:
                result = subprocess.run([
                    'reg', 'query',
                    'HKEY_LOCAL_MACHINE\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall',
                    '/s', '/f', 'AMD Chipset'
                ], capture_output=True, text=True, timeout=30)
                
                if result.returncode == 0:
                    version_match = re.search(r'DisplayVersion\s+REG_SZ\s+(\d+\.\d+\.\d+)', result.stdout)
                    if version_match:
                        versions['chipset'] = version_match.group(1)
            except Exception:
                pass
            
            return versions
            
        except Exception as e:
            self.logger.error(f"Error getting current AMD versions: {e}")
            return {}
    
    async def cleanup_old_drivers(self) -> bool:
        """Clean up old AMD driver installations."""
        try:
            self.logger.info("Cleaning up old AMD drivers...")
            
            # Use AMD Cleanup Utility if available
            cleanup_cmd = ['AMDCleanupUtility.exe', '/S']
            
            try:
                process = subprocess.run(
                    cleanup_cmd,
                    capture_output=True,
                    text=True,
                    timeout=300
                )
                
                if process.returncode == 0:
                    self.logger.info("AMD cleanup completed successfully")
                    return True
                else:
                    self.logger.warning("AMD cleanup utility not found or failed")
                    
            except (FileNotFoundError, subprocess.TimeoutExpired):
                self.logger.warning("AMD cleanup utility not available")
            
            return True  # Don't fail the whole process if cleanup fails
            
        except Exception as e:
            self.logger.error(f"Error during AMD cleanup: {e}")
            return True  # Don't fail the whole process
