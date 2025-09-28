"""
Driver Backup and Restore System
Provides functionality to backup current drivers before installation and
restore them if issues occur with new drivers.
"""

import asyncio
import subprocess
import logging
import shutil
from typing import Dict, List, Optional, Tuple
from pathlib import Path
from datetime import datetime
import json
import tempfile
import zipfile
import hashlib

try:
    import pythoncom
    import wmi
    WMI_AVAILABLE = True
except ImportError:
    WMI_AVAILABLE = False
    wmi = None
    pythoncom = None

class DriverBackupManager:
    """Manages driver backup and restore operations."""
    
    def __init__(self, backup_directory: Optional[Path] = None):
        self.logger = logging.getLogger(__name__)
        self.wmi_conn = None
        
        # Set backup directory
        if backup_directory:
            self.backup_dir = Path(backup_directory)
        else:
            self.backup_dir = Path.cwd() / "driver_backups"
        
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        
        # Backup metadata file
        self.metadata_file = self.backup_dir / "backup_metadata.json"
        self.metadata = self._load_metadata()
    
    async def initialize(self):
        """Initialize the backup manager."""
        try:
            if WMI_AVAILABLE:
                pythoncom.CoInitialize()
                self.wmi_conn = wmi.WMI()
                self.logger.info("Driver backup manager initialized with WMI")
            else:
                self.logger.warning("WMI not available, using alternative methods")
            return True
        except Exception as e:
            self.logger.error(f"Failed to initialize driver backup manager: {e}")
            return False
    
    def _load_metadata(self) -> Dict:
        """Load backup metadata from file."""
        try:
            if self.metadata_file.exists():
                with open(self.metadata_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
        except Exception as e:
            self.logger.error(f"Error loading backup metadata: {e}")
        
        return {
            'backups': {},
            'created': datetime.now().isoformat(),
            'version': '1.0'
        }
    
    def _save_metadata(self):
        """Save backup metadata to file."""
        try:
            with open(self.metadata_file, 'w', encoding='utf-8') as f:
                json.dump(self.metadata, f, indent=2, ensure_ascii=False)
        except Exception as e:
            self.logger.error(f"Error saving backup metadata: {e}")
    
    async def create_system_restore_point(self, description: str = "Driver Update") -> bool:
        """Create a Windows system restore point."""
        try:
            self.logger.info(f"Creating system restore point: {description}")
            
            # PowerShell command to create restore point
            powershell_script = f'''
            try {{
                # Enable system restore if not enabled
                Enable-ComputerRestore -Drive "C:\\"
                
                # Create restore point
                $result = Checkpoint-Computer -Description "{description}" -RestorePointType "MODIFY_SETTINGS"
                
                if ($result -eq $null) {{
                    Write-Output "SUCCESS: System restore point created"
                }} else {{
                    Write-Output "ERROR: Failed to create restore point"
                }}
            }} catch {{
                Write-Output "ERROR: $($_.Exception.Message)"
            }}
            '''
            
            result = await self._run_powershell_async(powershell_script, timeout=120)
            
            if result and result.returncode == 0 and "SUCCESS" in result.stdout:
                self.logger.info("System restore point created successfully")
                return True
            else:
                self.logger.warning(f"Failed to create system restore point: {result.stderr if result else 'Unknown error'}")
                return False
                
        except Exception as e:
            self.logger.error(f"Error creating system restore point: {e}")
            return False
    
    async def backup_device_drivers(self, device_ids: List[str] = None, progress_callback=None) -> Dict:
        """Backup drivers for specified devices or all devices."""
        backup_results = {
            'backup_id': datetime.now().strftime('%Y%m%d_%H%M%S'),
            'successful_backups': [],
            'failed_backups': [],
            'backup_path': None,
            'total_size_mb': 0
        }
        
        try:
            backup_id = backup_results['backup_id']
            backup_path = self.backup_dir / f"backup_{backup_id}"
            backup_path.mkdir(parents=True, exist_ok=True)
            backup_results['backup_path'] = str(backup_path)
            
            self.logger.info(f"Starting driver backup to: {backup_path}")
            
            if progress_callback:
                progress_callback("Initializing driver backup...", 0)
            
            # Get list of installed drivers
            drivers_to_backup = await self._get_installed_drivers(device_ids)
            
            if not drivers_to_backup:
                self.logger.warning("No drivers found to backup")
                return backup_results
            
            total_drivers = len(drivers_to_backup)
            self.logger.info(f"Found {total_drivers} drivers to backup")
            
            # Backup each driver
            for i, driver_info in enumerate(drivers_to_backup):
                if progress_callback:
                    progress = (i + 1) * 90 // total_drivers
                    progress_callback(f"Backing up driver {i+1}/{total_drivers}: {driver_info.get('name', 'Unknown')[:50]}...", progress)
                
                try:
                    backup_result = await self._backup_single_driver(driver_info, backup_path)
                    if backup_result['success']:
                        backup_results['successful_backups'].append(backup_result)
                        backup_results['total_size_mb'] += backup_result.get('size_mb', 0)
                    else:
                        backup_results['failed_backups'].append({
                            'driver': driver_info,
                            'error': backup_result.get('error', 'Unknown error')
                        })
                        
                except Exception as e:
                    self.logger.error(f"Error backing up driver {driver_info.get('name', 'Unknown')}: {e}")
                    backup_results['failed_backups'].append({
                        'driver': driver_info,
                        'error': str(e)
                    })
            
            # Create backup archive
            if progress_callback:
                progress_callback("Creating backup archive...", 95)
            
            archive_path = await self._create_backup_archive(backup_path, backup_id)
            if archive_path:
                backup_results['archive_path'] = str(archive_path)
                # Calculate archive size
                archive_size_mb = archive_path.stat().st_size / (1024 * 1024)
                backup_results['archive_size_mb'] = round(archive_size_mb, 2)
            
            # Update metadata
            self.metadata['backups'][backup_id] = {
                'timestamp': datetime.now().isoformat(),
                'device_count': len(backup_results['successful_backups']),
                'total_size_mb': backup_results['total_size_mb'],
                'archive_path': backup_results.get('archive_path', ''),
                'successful_count': len(backup_results['successful_backups']),
                'failed_count': len(backup_results['failed_backups'])
            }
            self._save_metadata()
            
            if progress_callback:
                progress_callback("Driver backup completed!", 100)
            
            self.logger.info(f"Driver backup completed: {len(backup_results['successful_backups'])} successful, "
                           f"{len(backup_results['failed_backups'])} failed")
            
            return backup_results
            
        except Exception as e:
            self.logger.error(f"Error during driver backup: {e}")
            backup_results['failed_backups'].append({
                'driver': {'name': 'General backup process'},
                'error': str(e)
            })
            return backup_results
    
    async def _get_installed_drivers(self, device_ids: List[str] = None) -> List[Dict]:
        """Get list of installed drivers to backup."""
        drivers = []
        
        try:
            # Use DISM to export driver information
            dism_result = subprocess.run([
                'dism', '/online', '/get-drivers', '/format:table'
            ], capture_output=True, text=True, timeout=60)
            
            if dism_result.returncode == 0:
                lines = dism_result.stdout.strip().split('\n')
                
                # Parse DISM output
                for line in lines:
                    if '.inf' in line.lower():
                        parts = line.split()
                        if len(parts) >= 4:
                            driver_info = {
                                'published_name': parts[0] if parts[0] else '',
                                'original_file_name': parts[1] if len(parts) > 1 else '',
                                'inbox': parts[2] if len(parts) > 2 else '',
                                'class_name': parts[3] if len(parts) > 3 else '',
                                'provider_name': parts[4] if len(parts) > 4 else '',
                                'date': parts[5] if len(parts) > 5 else '',
                                'version': parts[6] if len(parts) > 6 else ''
                            }
                            
                            # Filter by device IDs if specified
                            if device_ids is None or any(device_id in driver_info.get('original_file_name', '') for device_id in device_ids):
                                drivers.append(driver_info)
            
            # Also get drivers via WMI if available
            if self.wmi_conn and not drivers:
                for driver in self.wmi_conn.Win32_PnPSignedDriver():
                    if driver.InfName and driver.DeviceName:
                        driver_info = {
                            'name': driver.DeviceName,
                            'inf_name': driver.InfName,
                            'driver_version': getattr(driver, 'DriverVersion', ''),
                            'driver_date': getattr(driver, 'DriverDate', ''),
                            'manufacturer': getattr(driver, 'Manufacturer', ''),
                            'device_id': getattr(driver, 'DeviceID', ''),
                            'hardware_id': getattr(driver, 'HardwareID', '')
                        }
                        
                        # Filter by device IDs if specified
                        if device_ids is None or any(device_id in driver_info.get('device_id', '') for device_id in device_ids):
                            drivers.append(driver_info)
            
            self.logger.info(f"Found {len(drivers)} drivers for backup")
            return drivers
            
        except Exception as e:
            self.logger.error(f"Error getting installed drivers: {e}")
            return []
    
    async def _backup_single_driver(self, driver_info: Dict, backup_path: Path) -> Dict:
        """Backup a single driver."""
        result = {
            'success': False,
            'driver_info': driver_info,
            'backup_files': [],
            'size_mb': 0,
            'error': None
        }
        
        try:
            driver_name = driver_info.get('published_name') or driver_info.get('inf_name', 'unknown_driver')
            driver_backup_path = backup_path / f"driver_{driver_name}"
            driver_backup_path.mkdir(parents=True, exist_ok=True)
            
            # Export driver using DISM
            if driver_info.get('published_name'):
                export_result = subprocess.run([
                    'dism', '/online', '/export-driver',
                    f'/destination:{driver_backup_path}',
                    f'/driver:{driver_info["published_name"]}'
                ], capture_output=True, text=True, timeout=120)
                
                if export_result.returncode == 0:
                    # List exported files
                    exported_files = list(driver_backup_path.rglob('*'))
                    total_size = sum(f.stat().st_size for f in exported_files if f.is_file())
                    
                    result.update({
                        'success': True,
                        'backup_files': [str(f) for f in exported_files],
                        'size_mb': round(total_size / (1024 * 1024), 2)
                    })
                    
                    # Create driver info file
                    info_file = driver_backup_path / 'driver_info.json'
                    with open(info_file, 'w', encoding='utf-8') as f:
                        json.dump(driver_info, f, indent=2, ensure_ascii=False)
                    
                    self.logger.debug(f"Successfully backed up driver: {driver_name}")
                else:
                    result['error'] = f"DISM export failed: {export_result.stderr}"
            else:
                result['error'] = "No driver identifier available for backup"
                
        except Exception as e:
            result['error'] = str(e)
            self.logger.error(f"Error backing up driver {driver_info.get('name', 'Unknown')}: {e}")
        
        return result
    
    async def _create_backup_archive(self, backup_path: Path, backup_id: str) -> Optional[Path]:
        """Create a compressed archive of the backup."""
        try:
            archive_path = self.backup_dir / f"drivers_backup_{backup_id}.zip"
            
            with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
                for file_path in backup_path.rglob('*'):
                    if file_path.is_file():
                        arcname = file_path.relative_to(backup_path)
                        zipf.write(file_path, arcname)
            
            # Calculate checksum
            checksum = self._calculate_file_checksum(archive_path)
            
            # Create checksum file
            checksum_file = archive_path.with_suffix('.zip.sha256')
            with open(checksum_file, 'w') as f:
                f.write(f"{checksum}  {archive_path.name}\n")
            
            self.logger.info(f"Created backup archive: {archive_path}")
            return archive_path
            
        except Exception as e:
            self.logger.error(f"Error creating backup archive: {e}")
            return None
    
    def _calculate_file_checksum(self, file_path: Path) -> str:
        """Calculate SHA256 checksum of a file."""
        sha256_hash = hashlib.sha256()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                sha256_hash.update(chunk)
        return sha256_hash.hexdigest()
    
    async def restore_drivers(self, backup_id: str, progress_callback=None) -> Dict:
        """Restore drivers from a backup."""
        restore_results = {
            'successful_restores': [],
            'failed_restores': [],
            'reboot_required': False
        }
        
        try:
            if backup_id not in self.metadata['backups']:
                raise ValueError(f"Backup ID {backup_id} not found")
            
            backup_info = self.metadata['backups'][backup_id]
            archive_path = Path(backup_info.get('archive_path', ''))
            
            if not archive_path.exists():
                raise FileNotFoundError(f"Backup archive not found: {archive_path}")
            
            self.logger.info(f"Restoring drivers from backup: {backup_id}")
            
            if progress_callback:
                progress_callback("Extracting backup archive...", 0)
            
            # Extract backup archive
            with tempfile.TemporaryDirectory() as temp_dir:
                temp_path = Path(temp_dir)
                
                with zipfile.ZipFile(archive_path, 'r') as zipf:
                    zipf.extractall(temp_path)
                
                # Find driver folders
                driver_folders = [d for d in temp_path.iterdir() if d.is_dir() and d.name.startswith('driver_')]
                
                total_drivers = len(driver_folders)
                
                for i, driver_folder in enumerate(driver_folders):
                    if progress_callback:
                        progress = (i + 1) * 90 // total_drivers
                        progress_callback(f"Restoring driver {i+1}/{total_drivers}...", progress)
                    
                    try:
                        restore_result = await self._restore_single_driver(driver_folder)
                        if restore_result['success']:
                            restore_results['successful_restores'].append(restore_result)
                            if restore_result.get('reboot_required', False):
                                restore_results['reboot_required'] = True
                        else:
                            restore_results['failed_restores'].append(restore_result)
                            
                    except Exception as e:
                        self.logger.error(f"Error restoring driver from {driver_folder}: {e}")
                        restore_results['failed_restores'].append({
                            'driver_folder': str(driver_folder),
                            'error': str(e)
                        })
            
            if progress_callback:
                progress_callback("Driver restore completed!", 100)
            
            self.logger.info(f"Driver restore completed: {len(restore_results['successful_restores'])} successful, "
                           f"{len(restore_results['failed_restores'])} failed")
            
            return restore_results
            
        except Exception as e:
            self.logger.error(f"Error during driver restore: {e}")
            restore_results['failed_restores'].append({
                'error': str(e)
            })
            return restore_results
    
    async def _restore_single_driver(self, driver_folder: Path) -> Dict:
        """Restore a single driver from backup folder."""
        result = {
            'success': False,
            'driver_folder': str(driver_folder),
            'reboot_required': False,
            'error': None
        }
        
        try:
            # Look for INF files in the driver folder
            inf_files = list(driver_folder.rglob('*.inf'))
            
            if not inf_files:
                result['error'] = "No INF files found in driver backup"
                return result
            
            # Install driver using pnputil
            for inf_file in inf_files:
                install_result = subprocess.run([
                    'pnputil', '/add-driver', str(inf_file), '/install'
                ], capture_output=True, text=True, timeout=120)
                
                if install_result.returncode == 0:
                    result['success'] = True
                    result['reboot_required'] = 'reboot' in install_result.stdout.lower()
                    self.logger.info(f"Successfully restored driver: {inf_file.name}")
                    break
                else:
                    result['error'] = f"pnputil failed: {install_result.stderr}"
            
            return result
            
        except Exception as e:
            result['error'] = str(e)
            return result
    
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
    
    def list_backups(self) -> List[Dict]:
        """List available driver backups."""
        backups = []
        
        for backup_id, backup_info in self.metadata['backups'].items():
            backup_summary = {
                'backup_id': backup_id,
                'timestamp': backup_info.get('timestamp', ''),
                'device_count': backup_info.get('device_count', 0),
                'total_size_mb': backup_info.get('total_size_mb', 0),
                'successful_count': backup_info.get('successful_count', 0),
                'failed_count': backup_info.get('failed_count', 0),
                'archive_exists': Path(backup_info.get('archive_path', '')).exists() if backup_info.get('archive_path') else False
            }
            backups.append(backup_summary)
        
        # Sort by timestamp (newest first)
        backups.sort(key=lambda x: x['timestamp'], reverse=True)
        return backups
    
    def delete_backup(self, backup_id: str) -> bool:
        """Delete a driver backup."""
        try:
            if backup_id not in self.metadata['backups']:
                self.logger.warning(f"Backup ID {backup_id} not found")
                return False
            
            backup_info = self.metadata['backups'][backup_id]
            archive_path = Path(backup_info.get('archive_path', ''))
            
            # Delete archive file
            if archive_path.exists():
                archive_path.unlink()
                self.logger.info(f"Deleted backup archive: {archive_path}")
            
            # Delete checksum file
            checksum_file = archive_path.with_suffix('.zip.sha256')
            if checksum_file.exists():
                checksum_file.unlink()
            
            # Remove from metadata
            del self.metadata['backups'][backup_id]
            self._save_metadata()
            
            self.logger.info(f"Successfully deleted backup: {backup_id}")
            return True
            
        except Exception as e:
            self.logger.error(f"Error deleting backup {backup_id}: {e}")
            return False
