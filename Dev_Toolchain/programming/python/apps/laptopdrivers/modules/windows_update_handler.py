"""
Windows Update Driver Handler Module
Leverages Windows Update API and PowerShell cmdlets to find and install 
device drivers from Microsoft's driver catalog.
"""

import asyncio
import subprocess
import logging
import json
import re
from typing import Dict, List, Optional, Tuple
from datetime import datetime
import tempfile
from pathlib import Path

class WindowsUpdateHandler:
    """Handles Windows Update driver operations."""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.powershell_available = self._check_powershell_availability()
        self.windows_update_available = self._check_windows_update_module()
    
    def _check_powershell_availability(self) -> bool:
        """Check if PowerShell is available."""
        try:
            result = subprocess.run(
                ['powershell', '-Command', 'Get-Host | Select-Object Version'],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                self.logger.info("PowerShell is available for Windows Update operations")
                return True
        except Exception as e:
            self.logger.warning(f"PowerShell not available: {e}")
        return False
    
    def _check_windows_update_module(self) -> bool:
        """Check if Windows Update PowerShell module is available."""
        try:
            if not self.powershell_available:
                return False
            
            result = subprocess.run([
                'powershell', '-Command',
                'Get-Module -ListAvailable -Name PSWindowsUpdate, WindowsUpdateProvider'
            ], capture_output=True, text=True, timeout=15)
            
            if result.returncode == 0 and result.stdout.strip():
                self.logger.info("Windows Update PowerShell modules are available")
                return True
            else:
                # Try to install PSWindowsUpdate module
                self.logger.info("Attempting to install PSWindowsUpdate module...")
                install_result = subprocess.run([
                    'powershell', '-Command',
                    'Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser'
                ], capture_output=True, text=True, timeout=60)
                
                if install_result.returncode == 0:
                    self.logger.info("PSWindowsUpdate module installed successfully")
                    return True
                
        except Exception as e:
            self.logger.warning(f"Windows Update module not available: {e}")
        
        return False
    
    async def scan_for_driver_updates(self, hardware_info: Optional[Dict] = None) -> List[Dict]:
        """Scan Windows Update for available driver updates."""
        driver_updates = []
        
        try:
            if not self.powershell_available:
                self.logger.error("PowerShell not available for Windows Update scanning")
                return []
            
            self.logger.info("Scanning Windows Update for driver updates...")
            
            # Use Windows Update API to scan for drivers
            powershell_script = '''
            try {
                # Import required modules
                if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
                    Import-Module PSWindowsUpdate -Force
                    $updates = Get-WUList -Category "Drivers" -MicrosoftUpdate
                } else {
                    # Fallback to native Windows Update API
                    $Session = New-Object -ComObject Microsoft.Update.Session
                    $Searcher = $Session.CreateUpdateSearcher()
                    $SearchResult = $Searcher.Search("IsInstalled=0 and Type='Driver'")
                    $updates = $SearchResult.Updates
                }
                
                $driverList = @()
                foreach ($update in $updates) {
                    $driverInfo = @{
                        Title = $update.Title
                        Description = $update.Description
                        Size = if ($update.MaxDownloadSize) { $update.MaxDownloadSize } else { 0 }
                        IsDownloaded = if ($update.IsDownloaded) { $update.IsDownloaded } else { $false }
                        RebootRequired = if ($update.RebootRequired) { $update.RebootRequired } else { $false }
                        Categories = if ($update.Categories) { ($update.Categories | ForEach-Object { $_.Name }) -join ", " } else { "Drivers" }
                        UpdateID = if ($update.Identity) { $update.Identity.UpdateID } else { [System.Guid]::NewGuid().ToString() }
                        Severity = if ($update.MsrcSeverity) { $update.MsrcSeverity } else { "Important" }
                        LastDeploymentChangeTime = if ($update.LastDeploymentChangeTime) { $update.LastDeploymentChangeTime.ToString() } else { "" }
                    }
                    $driverList += $driverInfo
                }
                
                return $driverList | ConvertTo-Json -Depth 3
            } catch {
                Write-Error "Error scanning for updates: $($_.Exception.Message)"
                return "[]"
            }
            '''
            
            result = await self._run_powershell_async(powershell_script, timeout=120)
            
            if result and result.returncode == 0:
                try:
                    updates_data = json.loads(result.stdout)
                    if not isinstance(updates_data, list):
                        updates_data = [updates_data] if updates_data else []
                    
                    for update in updates_data:
                        driver_update = {
                            'name': update.get('Title', 'Unknown Driver Update'),
                            'description': update.get('Description', ''),
                            'size_bytes': update.get('Size', 0),
                            'size_mb': round(update.get('Size', 0) / (1024 * 1024), 2),
                            'is_downloaded': update.get('IsDownloaded', False),
                            'reboot_required': update.get('RebootRequired', False),
                            'categories': update.get('Categories', 'Drivers'),
                            'update_id': update.get('UpdateID', ''),
                            'severity': update.get('Severity', 'Important'),
                            'release_date': update.get('LastDeploymentChangeTime', ''),
                            'source': 'Windows Update',
                            'install_method': 'windows_update'
                        }
                        driver_updates.append(driver_update)
                    
                    self.logger.info(f"Found {len(driver_updates)} driver updates from Windows Update")
                    
                except json.JSONDecodeError as e:
                    self.logger.error(f"Failed to parse Windows Update results: {e}")
                    # Fallback: try alternative method
                    driver_updates = await self._scan_with_alternative_method()
            else:
                self.logger.warning("Windows Update scan failed, trying alternative method")
                driver_updates = await self._scan_with_alternative_method()
            
            return driver_updates
            
        except Exception as e:
            self.logger.error(f"Error scanning Windows Update for drivers: {e}")
            return []
    
    async def _scan_with_alternative_method(self) -> List[Dict]:
        """Alternative method to scan for driver updates using pnputil."""
        driver_updates = []
        
        try:
            self.logger.info("Using alternative method to scan for driver updates...")
            
            # Use pnputil to scan for device driver updates
            result = subprocess.run([
                'pnputil', '/scan-devices'
            ], capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                # Parse pnputil output for devices needing drivers
                lines = result.stdout.split('\n')
                for line in lines:
                    if 'driver' in line.lower() and ('missing' in line.lower() or 'update' in line.lower()):
                        driver_update = {
                            'name': f"Device Driver Update - {line.strip()}",
                            'description': 'Driver update available via Windows Update',
                            'size_bytes': 0,
                            'size_mb': 0,
                            'is_downloaded': False,
                            'reboot_required': True,
                            'categories': 'Drivers',
                            'update_id': '',
                            'severity': 'Important',
                            'release_date': '',
                            'source': 'Windows Update (pnputil)',
                            'install_method': 'pnputil'
                        }
                        driver_updates.append(driver_update)
            
            # Also check Windows Update via dism
            dism_result = subprocess.run([
                'dism', '/online', '/get-drivers'
            ], capture_output=True, text=True, timeout=60)
            
            if dism_result.returncode == 0:
                self.logger.info("Successfully retrieved driver information via DISM")
                # Additional processing could be added here
            
            return driver_updates
            
        except Exception as e:
            self.logger.error(f"Alternative driver scan method failed: {e}")
            return []
    
    async def install_driver_updates(self, updates: List[Dict], progress_callback=None) -> Dict:
        """Install driver updates from Windows Update."""
        install_results = {
            'successful': [],
            'failed': [],
            'skipped': [],
            'reboot_required': False
        }
        
        try:
            if not updates:
                self.logger.info("No driver updates to install")
                return install_results
            
            self.logger.info(f"Installing {len(updates)} driver updates from Windows Update...")
            
            if progress_callback:
                progress_callback("Preparing driver installation...", 0)
            
            # Create PowerShell script for batch driver installation
            update_ids = [update.get('update_id', '') for update in updates if update.get('update_id')]
            
            if not update_ids:
                # Fallback to installing all available driver updates
                powershell_script = '''
                try {
                    if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
                        Import-Module PSWindowsUpdate -Force
                        $results = Install-WindowsUpdate -Category "Drivers" -AcceptAll -AutoReboot:$false
                        return $results | ConvertTo-Json -Depth 2
                    } else {
                        # Use native Windows Update API
                        $Session = New-Object -ComObject Microsoft.Update.Session
                        $Searcher = $Session.CreateUpdateSearcher()
                        $SearchResult = $Searcher.Search("IsInstalled=0 and Type='Driver'")
                        
                        if ($SearchResult.Updates.Count -gt 0) {
                            $Downloader = $Session.CreateUpdateDownloader()
                            $Downloader.Updates = $SearchResult.Updates
                            $DownloadResult = $Downloader.Download()
                            
                            $Installer = $Session.CreateUpdateInstaller()
                            $Installer.Updates = $SearchResult.Updates
                            $InstallResult = $Installer.Install()
                            
                            return @{
                                ResultCode = $InstallResult.ResultCode
                                RebootRequired = $InstallResult.RebootRequired
                                HResult = $InstallResult.HResult
                            } | ConvertTo-Json
                        }
                    }
                } catch {
                    return @{ Error = $_.Exception.Message } | ConvertTo-Json
                }
                '''
            else:
                # Install specific updates by ID
                update_ids_str = "', '".join(update_ids)
                powershell_script = f'''
                try {{
                    if (Get-Module -ListAvailable -Name PSWindowsUpdate) {{
                        Import-Module PSWindowsUpdate -Force
                        $updateIds = @('{update_ids_str}')
                        $results = @()
                        foreach ($id in $updateIds) {{
                            $result = Install-WindowsUpdate -UpdateID $id -AcceptAll -AutoReboot:$false
                            $results += $result
                        }}
                        return $results | ConvertTo-Json -Depth 2
                    }}
                }} catch {{
                    return @{{ Error = $_.Exception.Message }} | ConvertTo-Json
                }}
                '''
            
            if progress_callback:
                progress_callback("Installing driver updates (this may take several minutes)...", 25)
            
            # Execute the installation
            result = await self._run_powershell_async(powershell_script, timeout=1800)  # 30 minutes
            
            if result and result.returncode == 0:
                try:
                    results_data = json.loads(result.stdout)
                    if not isinstance(results_data, list):
                        results_data = [results_data] if results_data else []
                    
                    for i, (update, result_data) in enumerate(zip(updates, results_data)):
                        if progress_callback:
                            progress = 25 + (i + 1) * 60 // len(updates)
                            progress_callback(f"Processing installation results ({i+1}/{len(updates)})...", progress)
                        
                        if result_data.get('Error'):
                            install_results['failed'].append({
                                'update': update,
                                'error': result_data['Error']
                            })
                        else:
                            result_code = result_data.get('ResultCode', 2)  # 2 = Succeeded
                            if result_code == 2:
                                install_results['successful'].append(update)
                                if result_data.get('RebootRequired', False):
                                    install_results['reboot_required'] = True
                            else:
                                install_results['failed'].append({
                                    'update': update,
                                    'error': f'Installation failed with code: {result_code}'
                                })
                    
                    if progress_callback:
                        progress_callback("Driver installation completed!", 100)
                    
                except json.JSONDecodeError as e:
                    self.logger.error(f"Failed to parse installation results: {e}")
                    # Mark all as failed
                    for update in updates:
                        install_results['failed'].append({
                            'update': update,
                            'error': 'Failed to parse installation results'
                        })
            else:
                self.logger.error("Driver installation command failed")
                for update in updates:
                    install_results['failed'].append({
                        'update': update,
                        'error': 'Installation command failed'
                    })
            
            # Log summary
            self.logger.info(f"Driver installation complete: "
                           f"{len(install_results['successful'])} successful, "
                           f"{len(install_results['failed'])} failed, "
                           f"reboot required: {install_results['reboot_required']}")
            
            return install_results
            
        except Exception as e:
            self.logger.error(f"Error installing driver updates: {e}")
            for update in updates:
                install_results['failed'].append({
                    'update': update,
                    'error': str(e)
                })
            return install_results
    
    async def _run_powershell_async(self, script: str, timeout: int = 60) -> Optional[subprocess.CompletedProcess]:
        """Run PowerShell script asynchronously."""
        try:
            # Create temporary script file
            with tempfile.NamedTemporaryFile(mode='w', suffix='.ps1', delete=False) as f:
                f.write(script)
                script_path = f.name
            
            try:
                # Run PowerShell with execution policy bypass
                process = await asyncio.create_subprocess_exec(
                    'powershell', '-ExecutionPolicy', 'Bypass', '-File', script_path,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=timeout)
                
                result = subprocess.CompletedProcess(
                    args=['powershell', '-File', script_path],
                    returncode=process.returncode,
                    stdout=stdout.decode('utf-8', errors='ignore'),
                    stderr=stderr.decode('utf-8', errors='ignore')
                )
                
                return result
                
            finally:
                # Clean up temporary file
                try:
                    Path(script_path).unlink()
                except Exception:
                    pass
                    
        except asyncio.TimeoutError:
            self.logger.error(f"PowerShell script timed out after {timeout} seconds")
            return None
        except Exception as e:
            self.logger.error(f"Error running PowerShell script: {e}")
            return None
    
    async def check_windows_update_service(self) -> bool:
        """Check if Windows Update service is running and available."""
        try:
            result = subprocess.run([
                'powershell', '-Command',
                'Get-Service -Name wuauserv | Select-Object Status'
            ], capture_output=True, text=True, timeout=10)
            
            if result.returncode == 0 and 'Running' in result.stdout:
                self.logger.info("Windows Update service is running")
                return True
            else:
                self.logger.warning("Windows Update service is not running")
                # Try to start the service
                start_result = subprocess.run([
                    'powershell', '-Command',
                    'Start-Service -Name wuauserv'
                ], capture_output=True, text=True, timeout=30)
                
                if start_result.returncode == 0:
                    self.logger.info("Successfully started Windows Update service")
                    return True
                
        except Exception as e:
            self.logger.error(f"Error checking Windows Update service: {e}")
        
        return False
    
    async def get_driver_installation_history(self) -> List[Dict]:
        """Get history of driver installations from Windows Update."""
        history = []
        
        try:
            powershell_script = '''
            try {
                $events = Get-WinEvent -FilterHashtable @{LogName="System"; ID=7045} -MaxEvents 100 | 
                    Where-Object { $_.Message -match "driver" -or $_.Message -match "Driver" }
                
                $driverHistory = @()
                foreach ($event in $events) {
                    $driverInfo = @{
                        TimeCreated = $event.TimeCreated.ToString()
                        Message = $event.Message
                        LevelDisplayName = $event.LevelDisplayName
                        Id = $event.Id
                    }
                    $driverHistory += $driverInfo
                }
                
                return $driverHistory | ConvertTo-Json -Depth 2
            } catch {
                return "[]"
            }
            '''
            
            result = await self._run_powershell_async(powershell_script, timeout=30)
            
            if result and result.returncode == 0:
                try:
                    history_data = json.loads(result.stdout)
                    if not isinstance(history_data, list):
                        history_data = [history_data] if history_data else []
                    
                    for event in history_data:
                        history.append({
                            'timestamp': event.get('TimeCreated', ''),
                            'message': event.get('Message', ''),
                            'level': event.get('LevelDisplayName', ''),
                            'event_id': event.get('Id', 0)
                        })
                        
                except json.JSONDecodeError:
                    pass
            
            return history
            
        except Exception as e:
            self.logger.error(f"Error getting driver installation history: {e}")
            return []
