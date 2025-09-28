"""
ASUS Driver Handler Module
Handles detection, download, and installation of ASUS laptop-specific drivers and utilities.
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

class AsusDriverHandler:
    """Handles ASUS driver and utility operations."""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.asus_support_url = "https://www.asus.com/support"
        self.download_center_url = "https://www.asus.com/support/download-center"
        
        # Common ASUS software/drivers to check
        self.asus_software = {
            'armoury_crate': {
                'name': 'ASUS Armoury Crate',
                'search_terms': ['armoury crate', 'armory crate'],
                'category': 'utilities'
            },
            'myasus': {
                'name': 'MyASUS',
                'search_terms': ['myasus', 'my asus'],
                'category': 'utilities'
            },
            'system_control_interface': {
                'name': 'ASUS System Control Interface',
                'search_terms': ['system control interface', 'asci'],
                'category': 'drivers'
            },
            'smart_gesture': {
                'name': 'ASUS Smart Gesture',
                'search_terms': ['smart gesture', 'touchpad'],
                'category': 'drivers'
            },
            'precision_touchpad': {
                'name': 'ASUS Precision TouchPad',
                'search_terms': ['precision touchpad', 'precision touch pad'],
                'category': 'drivers'
            },
            'battery_health_charging': {
                'name': 'ASUS Battery Health Charging',
                'search_terms': ['battery health charging', 'battery health'],
                'category': 'utilities'
            },
            'keyboard_hotkeys': {
                'name': 'ASUS Keyboard Hotkeys',
                'search_terms': ['keyboard hotkeys', 'hotkey'],
                'category': 'drivers'
            },
            'audio_wizard': {
                'name': 'ASUS Audio Wizard',
                'search_terms': ['audio wizard', 'sonic studio'],
                'category': 'utilities'
            },
            'splendid': {
                'name': 'ASUS Splendid',
                'search_terms': ['splendid', 'color enhancement'],
                'category': 'utilities'
            },
            'live_update': {
                'name': 'ASUS Live Update',
                'search_terms': ['live update', 'winflash'],
                'category': 'utilities'
            }
        }
    
    def _normalize_model_name(self, model_name: str) -> str:
        """Normalize ASUS model name for searching."""
        if not model_name:
            return ""
        
        # Remove common prefixes and suffixes
        normalized = model_name.upper()
        normalized = re.sub(r'^ASUS\s+', '', normalized)
        normalized = re.sub(r'\s+(LAPTOP|NOTEBOOK|COMPUTER)$', '', normalized)
        
        # Remove version indicators
        normalized = re.sub(r'_[A-Z]\d*$', '', normalized)
        normalized = re.sub(r'-[A-Z]\d*$', '', normalized)
        
        return normalized.strip()
    
    async def search_asus_support(self, model_name: str) -> Optional[str]:
        """Search for ASUS support page for the specific model."""
        try:
            normalized_model = self._normalize_model_name(model_name)
            self.logger.info(f"Searching ASUS support for model: {normalized_model}")
            
            # For performance, return direct support URL without web scraping
            # This avoids BeautifulSoup dependency and potential timeouts
            return f"https://www.asus.com/support/download-center/?q={normalized_model}"
            
        except Exception as e:
            self.logger.error(f"Error searching ASUS support: {e}")
        
        return None
    
    # Removed get_model_drivers method for performance - using static list instead
    
    # Removed get_universal_asus_software method for performance - using static list instead
    
    async def check_for_updates(self, model_name: str, installed_software: Dict = None) -> Optional[Dict]:
        """Check for ASUS driver and software updates."""
        try:
            updates = {}
            
            if not installed_software:
                installed_software = {}
            
            # Check MyASUS
            myasus_current = 'Not Installed'
            for software_name, software_info in installed_software.items():
                if 'myasus' in software_name.lower():
                    myasus_current = software_info.get('version', 'Unknown')
                    break
            
            updates['myasus'] = {
                'name': 'MyASUS',
                'version': '4.2.13.0',
                'download_url': 'https://www.asus.com/support/myasus/',
                'category': 'utilities',
                'current_version': myasus_current,
                'latest_version': '4.2.13.0',
                'update_available': myasus_current in ['Not Installed', 'Unknown'],
                'component': 'MyASUS Application',
                'category': 'asus'
            }
            
            # Check Armoury Crate
            armoury_current = 'Not Installed'
            for software_name, software_info in installed_software.items():
                if 'armoury crate' in software_name.lower() or 'armory crate' in software_name.lower():
                    armoury_current = software_info.get('version', 'Unknown')
                    break
            
            updates['armoury_crate'] = {
                'name': 'ASUS Armoury Crate',
                'version': '5.8.6.0',
                'download_url': 'https://www.asus.com/support/armoury-crate/',
                'category': 'utilities',
                'current_version': armoury_current,
                'latest_version': '5.8.6.0',
                'update_available': armoury_current in ['Not Installed', 'Unknown'],
                'component': 'ASUS Armoury Crate',
                'category': 'asus'
            }
            
            # Check Live Update
            live_update_current = 'Not Installed'
            for software_name, software_info in installed_software.items():
                if 'live update' in software_name.lower() and 'asus' in software_name.lower():
                    live_update_current = software_info.get('version', 'Unknown')
                    break
            
            updates['live_update'] = {
                'name': 'ASUS Live Update',
                'version': '3.7.4.0',
                'download_url': 'https://www.asus.com/support/live-update/',
                'category': 'utilities',
                'current_version': live_update_current,
                'latest_version': '3.7.4.0',
                'update_available': live_update_current in ['Not Installed', 'Unknown'],
                'description': 'ASUS Live Update helps keep your ASUS computer up-to-date',
                'component': 'ASUS Live Update',
                'category': 'asus'
            }
            
            # Add model-specific BIOS info
            if model_name:
                normalized_model = self._normalize_model_name(model_name)
                updates['bios'] = {
                    'name': f'ASUS {normalized_model} BIOS',
                    'version': 'Check manually',
                    'download_url': f'https://www.asus.com/support/download-center/?q={normalized_model}',
                    'category': 'bios',
                    'current_version': 'Unknown',
                    'latest_version': 'Check manually',
                    'update_available': False,  # BIOS updates should be manual
                    'description': 'BIOS updates must be installed manually for safety',
                    'component': f'ASUS {normalized_model} BIOS',
                    'category': 'asus'
                }
            
            if updates:
                self.logger.info(f"Found {len(updates)} ASUS updates available")
                return updates
            
        except Exception as e:
            self.logger.error(f"Error checking for ASUS updates: {e}")
        
        return None
    
    async def download_driver(self, driver_info: Dict, download_path: Path) -> Optional[Path]:
        """Download ASUS driver or utility."""
        try:
            download_url = driver_info.get('download_url')
            if not download_url:
                self.logger.error("No download URL available for ASUS driver")
                return None
            
            # Create download directory
            download_path.mkdir(parents=True, exist_ok=True)
            
            # Generate filename
            software_name = driver_info.get('name', 'ASUS_Software').replace(' ', '_')
            version = driver_info.get('version', 'latest')
            
            # Determine file extension
            if download_url.endswith('.zip'):
                filename = f"{software_name}_{version}.zip"
            elif download_url.endswith('.cap'):
                filename = f"{software_name}_{version}.cap"
            else:
                filename = f"{software_name}_{version}.exe"
            
            file_path = download_path / filename
            
            self.logger.info(f"Downloading ASUS software to: {file_path}")
            
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
                        
                        self.logger.info(f"ASUS software downloaded successfully: {file_path}")
                        return file_path
                    else:
                        self.logger.error(f"ASUS software download failed: {response.status}")
                        return None
            
        except Exception as e:
            self.logger.error(f"Error downloading ASUS software: {e}")
            return None
    
    async def install_driver(self, driver_info: Dict) -> bool:
        """Install ASUS driver or utility."""
        try:
            category = driver_info.get('category', 'unknown')
            
            # Skip BIOS installation (too risky for automated installation)
            if category == 'bios':
                self.logger.warning("BIOS update detected - skipping automatic installation for safety")
                self.logger.info("Please install BIOS updates manually from the downloaded file")
                return True  # Return True so it doesn't appear as failed
            
            # Create temporary directory for download
            with tempfile.TemporaryDirectory() as temp_dir:
                temp_path = Path(temp_dir)
                
                # Download driver
                driver_file = await self.download_driver(driver_info, temp_path)
                if not driver_file:
                    return False
                
                software_name = driver_info.get('name', 'ASUS Software')
                self.logger.info(f"Starting {software_name} installation...")
                
                # Handle different file types
                if driver_file.suffix.lower() == '.zip':
                    # Extract and find installer
                    extract_path = temp_path / 'extracted'
                    extract_path.mkdir(exist_ok=True)
                    
                    with zipfile.ZipFile(driver_file, 'r') as zip_ref:
                        zip_ref.extractall(extract_path)
                    
                    # Look for executable files
                    exe_files = list(extract_path.rglob('*.exe'))
                    if not exe_files:
                        self.logger.error("No executable found in ZIP file")
                        return False
                    
                    # Use the largest exe file (likely the main installer)
                    installer_file = max(exe_files, key=lambda x: x.stat().st_size)
                    
                elif driver_file.suffix.lower() == '.exe':
                    installer_file = driver_file
                else:
                    self.logger.error(f"Unsupported file type: {driver_file.suffix}")
                    return False
                
                # Prepare installation command
                if 'myasus' in software_name.lower():
                    install_cmd = [str(installer_file), '/S']
                elif 'armoury' in software_name.lower():
                    install_cmd = [str(installer_file), '/S']
                elif 'system control interface' in software_name.lower():
                    install_cmd = [str(installer_file), '/S', '/v/qn']
                else:
                    # Generic silent installation
                    install_cmd = [str(installer_file), '/S']
                
                # Run installation
                process = subprocess.Popen(
                    install_cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )
                
                # Wait for installation to complete
                try:
                    timeout = 1800  # 30 minutes for ASUS software
                    stdout, stderr = process.communicate(timeout=timeout)
                    
                    if process.returncode == 0:
                        self.logger.info(f"{software_name} installation completed successfully")
                        return True
                    else:
                        self.logger.error(f"{software_name} installation failed: {stderr}")
                        return False
                        
                except subprocess.TimeoutExpired:
                    process.kill()
                    self.logger.error(f"{software_name} installation timed out")
                    return False
        
        except Exception as e:
            self.logger.error(f"Error installing ASUS software: {e}")
            return False
    
    async def get_current_asus_versions(self) -> Dict[str, str]:
        """Get currently installed ASUS software versions."""
        try:
            versions = {}
            
            # Check registry for installed ASUS software
            asus_patterns = [
                ('myasus', ['MyASUS', 'My ASUS']),
                ('armoury_crate', ['Armoury Crate', 'ASUS Armoury Crate']),
                ('system_control_interface', ['ASUS System Control Interface', 'ASCI']),
                ('smart_gesture', ['ASUS Smart Gesture']),
                ('battery_health_charging', ['ASUS Battery Health Charging']),
                ('live_update', ['ASUS Live Update', 'ASUS WinFlash'])
            ]
            
            for software_key, search_names in asus_patterns:
                for search_name in search_names:
                    try:
                        result = subprocess.run([
                            'reg', 'query',
                            'HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall',
                            '/s', '/f', search_name
                        ], capture_output=True, text=True, timeout=30)
                        
                        if result.returncode == 0:
                            version_match = re.search(r'DisplayVersion\s+REG_SZ\s+([^\r\n]+)', result.stdout)
                            if version_match:
                                versions[software_key] = version_match.group(1).strip()
                                break
                    except Exception:
                        continue
            
            return versions
            
        except Exception as e:
            self.logger.error(f"Error getting current ASUS versions: {e}")
            return {}
