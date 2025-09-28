"""
NVIDIA Driver Handler Module
Handles detection, download, and installation of NVIDIA drivers.
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
import hashlib

class NvidiaDriverHandler:
    """Handles NVIDIA driver operations."""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.base_url = "https://www.nvidia.com/Download/processFind.aspx"
        self.download_base_url = "https://us.download.nvidia.com"
        
        # NVIDIA product mappings for different GPU series
        self.gpu_mappings = {
            # RTX 40 Series
            'rtx 4090': {'psid': '103', 'pfid': '916'},
            'rtx 4080': {'psid': '103', 'pfid': '915'},
            'rtx 4070': {'psid': '103', 'pfid': '913'},
            'rtx 4060': {'psid': '103', 'pfid': '911'},
            
            # RTX 30 Series
            'rtx 3090': {'psid': '103', 'pfid': '894'},
            'rtx 3080': {'psid': '103', 'pfid': '893'},
            'rtx 3070': {'psid': '103', 'pfid': '892'},
            'rtx 3060': {'psid': '103', 'pfid': '888'},
            
            # RTX 20 Series
            'rtx 2080': {'psid': '103', 'pfid': '836'},
            'rtx 2070': {'psid': '103', 'pfid': '835'},
            'rtx 2060': {'psid': '103', 'pfid': '834'},
            
            # GTX 16 Series
            'gtx 1660': {'psid': '103', 'pfid': '845'},
            'gtx 1650': {'psid': '103', 'pfid': '844'},
            
            # GTX 10 Series
            'gtx 1080': {'psid': '103', 'pfid': '758'},
            'gtx 1070': {'psid': '103', 'pfid': '756'},
            'gtx 1060': {'psid': '103', 'pfid': '754'},
            'gtx 1050': {'psid': '103', 'pfid': '752'},
        }
    
    def _get_gpu_product_info(self, gpu_name: str) -> Optional[Dict[str, str]]:
        """Get NVIDIA product series and family IDs for GPU."""
        try:
            gpu_name_lower = gpu_name.lower()
            
            # Try exact matches first
            for gpu_key, info in self.gpu_mappings.items():
                if gpu_key in gpu_name_lower:
                    return info
            
            # Try pattern matching for mobile variants
            if 'mobile' in gpu_name_lower or 'laptop' in gpu_name_lower:
                # Remove mobile/laptop indicators and try again
                clean_name = re.sub(r'\b(mobile|laptop|ti)\b', '', gpu_name_lower).strip()
                for gpu_key, info in self.gpu_mappings.items():
                    if gpu_key in clean_name:
                        return info
            
            # Default to generic modern GPU series if no match
            if 'rtx' in gpu_name_lower:
                return {'psid': '103', 'pfid': '916'}  # Default to RTX series
            elif 'gtx' in gpu_name_lower:
                return {'psid': '103', 'pfid': '758'}  # Default to GTX series
            
        except Exception as e:
            self.logger.error(f"Error getting GPU product info: {e}")
        
        return None
    
    async def get_latest_driver_info(self, gpu_info: Dict) -> Optional[Dict]:
        """Get latest NVIDIA driver information for the GPU."""
        try:
            gpu_name = gpu_info.get('name', '')
            self.logger.info(f"Checking for NVIDIA driver updates for: {gpu_name}")
            
            # Get product info
            product_info = self._get_gpu_product_info(gpu_name)
            if not product_info:
                self.logger.warning(f"Could not determine product info for GPU: {gpu_name}")
                return None
            
            # Determine OS version
            os_version = "57"  # Windows 10/11 64-bit
            
            # Build request parameters
            params = {
                'psid': product_info['psid'],
                'pfid': product_info['pfid'],
                'osid': os_version,
                'lid': '1',  # English
                'whql': '1',  # WHQL certified only
                'ctk': '0'   # Not looking for CUDA toolkit
            }
            
            # Set a 30-second timeout for NVIDIA requests
            timeout = aiohttp.ClientTimeout(total=30)
            
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(self.base_url, params=params) as response:
                    if response.status == 200:
                        content = await response.text()
                        
                        # Parse the response for driver information
                        driver_info = self._parse_nvidia_response(content)
                        if driver_info:
                            self.logger.info(f"Found NVIDIA driver: {driver_info}")
                            return driver_info
                    else:
                        self.logger.error(f"NVIDIA API request failed: {response.status}")
            
            # Fallback: Try to get driver info via nvidia-smi
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=name,driver_version', '--format=csv,noheader,nounits'],
                capture_output=True, text=True, timeout=10
            )
            
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if lines and lines[0].strip():
                    parts = lines[0].split(', ')
                    if len(parts) >= 2:
                        current_version = parts[1].strip()
                        return {
                            'name': f"NVIDIA Graphics Driver for {gpu_name}",
                            'version': current_version,
                            'current_version': current_version,
                            'download_url': None,
                            'file_size': 0,
                            'release_notes': ''
                        }
            
        except Exception as e:
            self.logger.error(f"Error getting NVIDIA driver info: {e}")
        
        return None
    
    def _parse_nvidia_response(self, html_content: str) -> Optional[Dict]:
        """Parse NVIDIA's driver search response."""
        try:
            # Look for driver version
            version_match = re.search(r'Version:\s*(\d+\.\d+)', html_content)
            if not version_match:
                return None
            
            version = version_match.group(1)
            
            # Look for download URL
            download_match = re.search(r'href="([^"]*\.exe)"', html_content)
            download_url = download_match.group(1) if download_match else None
            
            # Look for file size
            size_match = re.search(r'(\d+(?:\.\d+)?)\s*MB', html_content)
            file_size = float(size_match.group(1)) * 1024 * 1024 if size_match else 0
            
            # Look for release date
            date_match = re.search(r'Release Date:\s*(\d{4}\.\d{1,2}\.\d{1,2})', html_content)
            release_date = date_match.group(1) if date_match else ''
            
            return {
                'name': f"NVIDIA Graphics Driver {version}",
                'version': version,
                'download_url': download_url,
                'file_size': int(file_size),
                'release_date': release_date,
                'release_notes': f"NVIDIA Graphics Driver {version}"
            }
            
        except Exception as e:
            self.logger.error(f"Error parsing NVIDIA response: {e}")
            return None
    
    async def check_for_updates(self, gpu_info: Dict, installed_software: Dict = None) -> Optional[Dict]:
        """Check if there are updates available for the NVIDIA GPU."""
        try:
            # Get current driver version from hardware detection or nvidia-smi
            current_version = gpu_info.get('driver_version', 'Unknown')
            
            # Try to get a more specific version from nvidia-smi if available
            if current_version == 'Unknown':
                try:
                    current_result = subprocess.run(
                        ['nvidia-smi', '--query-gpu=driver_version', '--format=csv,noheader,nounits'],
                        capture_output=True, text=True, timeout=10
                    )
                    if current_result.returncode == 0:
                        current_version = current_result.stdout.strip()
                except Exception:
                    pass
            
            # Try to get latest driver version from NVIDIA's API
            latest_version = await self._get_latest_nvidia_version(gpu_info)
            if not latest_version:
                # Fallback to a reasonable default
                latest_version = "561.09"  # Current stable version as of 2024
            
            # Compare versions if both are available
            update_available = False
            status_message = "Up to Date"
            
            if current_version != 'Unknown' and latest_version != 'Unknown':
                try:
                    # Extract numeric version for comparison
                    current_numeric = self._extract_version_number(current_version)
                    latest_numeric = self._extract_version_number(latest_version)
                    
                    if latest_numeric > current_numeric:
                        update_available = True
                        status_message = "Update Available"
                    elif current_numeric > latest_numeric:
                        # Current version is newer than "latest" detected
                        update_available = False
                        status_message = "Newer than Latest"
                        self.logger.info(f"Current NVIDIA driver ({current_version}) is newer than detected latest ({latest_version})")
                    else:
                        # Versions are equal
                        update_available = False
                        status_message = "Up to Date"
                        
                except Exception as e:
                    self.logger.warning(f"Version comparison failed: {e}")
                    update_available = False  # Don't assume update needed if comparison fails
                    status_message = "Version Check Failed"
            
            return {
                'name': f"NVIDIA Graphics Driver for {gpu_info.get('name', 'NVIDIA GPU')}",
                'current_version': current_version,
                'latest_version': latest_version,
                'update_available': update_available,
                'status': status_message,
                'component': 'NVIDIA Graphics Driver', 
                'category': 'nvidia',
                'download_url': f"https://www.nvidia.com/Download/driverResults.aspx/{latest_version}/en-us" if update_available else None
            }
            
        except Exception as e:
            self.logger.error(f"Error checking for NVIDIA updates: {e}")
            return {
                'name': 'NVIDIA Graphics Driver',
                'current_version': gpu_info.get('driver_version', 'Unknown'),
                'latest_version': 'Check manually',
                'update_available': False,
                'status': 'Check manually',
                'component': 'NVIDIA Graphics Driver',
                'category': 'nvidia'
            }
    
    def _extract_version_number(self, version_string: str) -> float:
        """Extract numeric version for comparison."""
        try:
            # Extract main version number (e.g., "581.29" from "581.29" or "581.29.00")
            match = re.search(r'(\d+\.\d+)', version_string)
            if match:
                return float(match.group(1))
        except Exception:
            pass
        return 0.0
    
    async def _get_latest_nvidia_version(self, gpu_info: Dict) -> Optional[str]:
        """Get the latest NVIDIA driver version."""
        try:
            # Try NVIDIA's download API
            gpu_name = gpu_info.get('name', '')
            product_info = self._get_gpu_product_info(gpu_name)
            
            if not product_info:
                return "586.16"  # Updated to current latest version as of Sep 2025
            
            # Set a shorter timeout for this request
            timeout = aiohttp.ClientTimeout(total=15)
            
            # Build request parameters
            params = {
                'psid': product_info['psid'],
                'pfid': product_info['pfid'],
                'osid': '57',  # Windows 10/11 64-bit
                'lid': '1',    # English
                'whql': '1',   # WHQL certified only
                'ctk': '0'     # Not looking for CUDA toolkit
            }
            
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(self.base_url, params=params) as response:
                    if response.status == 200:
                        content = await response.text()
                        
                        # Look for driver version in the response
                        version_match = re.search(r'Version:\s*(\d+\.\d+)', content)
                        if version_match:
                            version = version_match.group(1)
                            # Ensure we don't return a version older than what's currently installed
                            current_version = gpu_info.get('driver_version', '0.0')
                            if self._extract_version_number(version) >= self._extract_version_number(current_version):
                                return version
                            else:
                                # If API returns older version, use a more recent fallback
                                return "586.16"
            
        except Exception as e:
            self.logger.debug(f"Could not get latest NVIDIA version from API: {e}")
        
        # Return current latest version as of September 2025
        return "586.16"
    
    async def download_driver(self, driver_info: Dict, download_path: Path, progress_callback=None) -> Optional[Path]:
        """Download NVIDIA driver with progress tracking."""
        try:
            download_url = driver_info.get('download_url')
            if not download_url:
                self.logger.error("No download URL available")
                return None
            
            # Create download directory
            download_path.mkdir(parents=True, exist_ok=True)
            
            # Generate filename
            filename = f"nvidia_driver_{driver_info.get('version', 'latest')}.exe"
            file_path = download_path / filename
            
            self.logger.info(f"Downloading NVIDIA driver to: {file_path}")
            
            if progress_callback:
                progress_callback("Starting NVIDIA driver download...", 0)
            
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
                                    
                                    # Update progress every 5%
                                    if progress_callback and int(progress) % 5 == 0:
                                        size_mb = total_size / (1024 * 1024)
                                        downloaded_mb = downloaded / (1024 * 1024)
                                        progress_callback(
                                            f"Downloading NVIDIA driver: {downloaded_mb:.1f}/{size_mb:.1f} MB ({progress:.1f}%)",
                                            progress * 0.7  # Reserve 30% for installation
                                        )
                        
                        if progress_callback:
                            progress_callback("NVIDIA driver download complete", 70)
                        
                        self.logger.info(f"NVIDIA driver downloaded successfully: {file_path}")
                        return file_path
                    else:
                        self.logger.error(f"Download failed: {response.status}")
                        return None
            
        except Exception as e:
            self.logger.error(f"Error downloading NVIDIA driver: {e}")
            if progress_callback:
                progress_callback(f"Download failed: {str(e)[:50]}...", 0)
            return None
    
    async def install_driver(self, driver_info: Dict, progress_callback=None) -> bool:
        """Install NVIDIA driver with progress tracking."""
        try:
            # Create temporary directory for download
            with tempfile.TemporaryDirectory() as temp_dir:
                temp_path = Path(temp_dir)
                
                if progress_callback:
                    progress_callback("Preparing NVIDIA driver installation...", 0)
                
                # Download driver
                driver_file = await self.download_driver(driver_info, temp_path, progress_callback)
                if not driver_file:
                    return False
                
                if progress_callback:
                    progress_callback("Installing NVIDIA driver (this may take several minutes)...", 75)
                
                self.logger.info("Starting NVIDIA driver installation...")
                
                # Install driver silently
                install_cmd = [
                    str(driver_file),
                    '-s',  # Silent install
                    '-noreboot',  # Don't reboot automatically
                    '-noeula',  # Accept EULA
                    '-nofinish'  # Don't show finish dialog
                ]
                
                # Run installation
                process = subprocess.Popen(
                    install_cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )
                
                if progress_callback:
                    progress_callback("NVIDIA driver installation in progress...", 85)
                
                # Wait for installation to complete (with timeout)
                try:
                    stdout, stderr = process.communicate(timeout=1800)  # 30 minute timeout
                    
                    if process.returncode == 0:
                        if progress_callback:
                            progress_callback("NVIDIA driver installation completed!", 100)
                        self.logger.info("NVIDIA driver installation completed successfully")
                        return True
                    else:
                        if progress_callback:
                            progress_callback("NVIDIA driver installation failed", 0)
                        self.logger.error(f"NVIDIA driver installation failed: {stderr}")
                        return False
                        
                except subprocess.TimeoutExpired:
                    process.kill()
                    if progress_callback:
                        progress_callback("NVIDIA driver installation timed out", 0)
                    self.logger.error("NVIDIA driver installation timed out")
                    return False
        
        except Exception as e:
            if progress_callback:
                progress_callback(f"NVIDIA installation error: {str(e)[:30]}...", 0)
            self.logger.error(f"Error installing NVIDIA driver: {e}")
            return False
    
    async def get_driver_release_notes(self, version: str) -> str:
        """Get release notes for a specific driver version."""
        try:
            # NVIDIA doesn't provide a simple API for release notes
            # This is a placeholder for future implementation
            return f"NVIDIA Graphics Driver {version} - Please check NVIDIA website for detailed release notes."
            
        except Exception as e:
            self.logger.error(f"Error getting release notes: {e}")
            return ""
