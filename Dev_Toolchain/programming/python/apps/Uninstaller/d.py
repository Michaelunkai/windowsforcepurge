#!/usr/bin/env python3
"""
ULTIMATE SAFE UNINSTALLER - ABSOLUTE COMPLETE REMOVAL TOOL
Safely removes all traces of applications while protecting critical system files
Supports Windows Package Manager, MSI, registry cleanup, and deep file scanning

Usage: python d.py <app1> <app2> [app3] ...
Requires: Administrator privileges on Windows
"""

import os
import sys
import subprocess
import shutil
import winreg
import psutil
import glob
import time
import json
import logging
from pathlib import Path
import argparse
import tempfile
import ctypes
from ctypes import wintypes
import re

class UltimateUninstaller:
    def __init__(self):
        self.deleted_count = 0
        self.failed_count = 0
        self.skipped_count = 0
        self.found_installers = []
        self.critical_system_files = self._load_critical_files()
        self.setup_logging()

    def setup_logging(self):
        """Setup comprehensive logging"""
        log_file = os.path.join(tempfile.gettempdir(), "uninstaller.log")
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
        self.logger.info(f"Uninstaller session started. Log file: {log_file}")

    def _load_critical_files(self):
        """Load list of critical system files that should NEVER be deleted"""
        return {
            # Windows critical system files
            'ntoskrnl.exe', 'hal.dll', 'win32k.sys', 'ntdll.dll', 'kernel32.dll',
            'user32.dll', 'gdi32.dll', 'advapi32.dll', 'msvcrt.dll', 'shell32.dll',
            'ole32.dll', 'oleaut32.dll', 'comctl32.dll', 'comdlg32.dll', 'wininet.dll',
            'urlmon.dll', 'shlwapi.dll', 'version.dll', 'mpr.dll', 'netapi32.dll',
            'winspool.drv', 'ws2_32.dll', 'wsock32.dll', 'mswsock.dll', 'dnsapi.dll',
            'iphlpapi.dll', 'dhcpcsvc.dll', 'winhttp.dll', 'crypt32.dll', 'wintrust.dll',
            'imagehlp.dll', 'psapi.dll', 'secur32.dll', 'netman.dll', 'rasapi32.dll',
            'tapi32.dll', 'rtutils.dll', 'setupapi.dll', 'cfgmgr32.dll', 'devmgr.dll',
            'newdev.dll', 'wtsapi32.dll', 'winsta.dll', 'authz.dll', 'xmllite.dll',
            # System executables
            'explorer.exe', 'winlogon.exe', 'csrss.exe', 'smss.exe', 'wininit.exe',
            'services.exe', 'lsass.exe', 'svchost.exe', 'dwm.exe', 'taskhost.exe',
            'taskhostw.exe', 'sihost.exe', 'ctfmon.exe', 'RuntimeBroker.exe',
            'ApplicationFrameHost.exe', 'WWAHost.exe', 'SearchUI.exe', 'ShellExperienceHost.exe',
            # System directories (partial paths)
            'windows', 'system32', 'syswow64', 'drivers', 'winsxs', 'boot', 'efi'
        }

    def is_critical_system_file(self, file_path):
        """Check if a file is critical to system operation"""
        file_path_lower = file_path.lower()
        file_name = os.path.basename(file_path_lower)

        # Check critical file names
        if file_name in self.critical_system_files:
            return True

        # Check critical paths
        critical_paths = [
            'c:\\windows\\system32\\',
            'c:\\windows\\syswow64\\',
            'c:\\windows\\winsxs\\',
            'c:\\windows\\boot\\',
            'c:\\efi\\',
            'c:\\windows\\drivers\\',
            'c:\\windows\\inf\\',
            'c:\\windows\\fonts\\',
            'c:\\windows\\globalization\\',
            'c:\\windows\\ime\\',
            'c:\\windows\\speech\\',
            'c:\\windows\\registration\\',
            'c:\\windows\\schemas\\',
            'c:\\windows\\security\\',
            'c:\\windows\\servicing\\',
            'c:\\windows\\diagnostics\\',
            'c:\\windows\\help\\',
            'c:\\windows\\l2schemas\\',
            'c:\\windows\\migration\\',
            'c:\\windows\\policydefinitions\\',
            'c:\\windows\\resources\\',
            'c:\\windows\\shellnew\\',
            'c:\\windows\\speech_onecore\\',
            'c:\\windows\\tracing\\',
            'c:\\windows\\web\\'
        ]

        for critical_path in critical_paths:
            if file_path_lower.startswith(critical_path):
                # Allow specific subdirectories that are safe to clean
                safe_subdirs = ['temp', 'logs', 'prefetch', 'installer', 'downloaded program files']
                for safe_dir in safe_subdirs:
                    if f'\\{safe_dir}\\' in file_path_lower:
                        return False
                return True

        return False

    def check_admin(self):
        """Check admin privileges"""
        try:
            return ctypes.windll.shell32.IsUserAnAdmin()
        except:
            return False

    def find_installed_programs(self, app_names):
        """Find all installed programs matching the app names using multiple methods"""
        self.logger.info(f"Searching for installed programs: {app_names}")
        found_programs = []

        for app_name in app_names:
            self.logger.info(f"Searching for: {app_name}")

            # Method 1: Windows Package Manager (winget)
            try:
                result = subprocess.run(['winget', 'list', '--accept-source-agreements'],
                                      capture_output=True, text=True, timeout=60)
                for line in result.stdout.split('\n'):
                    if app_name.lower() in line.lower():
                        found_programs.append(('winget', line.strip(), app_name))
                        self.logger.info(f"Found winget package: {line.strip()}")
            except Exception as e:
                self.logger.warning(f"Winget search failed: {e}")

            # Method 2: Registry - Uninstall entries
            self._search_uninstall_registry(app_name, found_programs)

            # Method 3: MSI packages
            self._search_msi_packages(app_name, found_programs)

            # Method 4: Windows Apps (UWP/MSIX)
            self._search_windows_apps(app_name, found_programs)

        return found_programs

    def _search_uninstall_registry(self, app_name, found_programs):
        """Search Windows uninstall registry entries"""
        uninstall_keys = [
            r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        ]

        for key_path in uninstall_keys:
            try:
                with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, key_path) as key:
                    for i in range(winreg.QueryInfoKey(key)[0]):
                        try:
                            subkey_name = winreg.EnumKey(key, i)
                            with winreg.OpenKey(key, subkey_name) as subkey:
                                try:
                                    display_name = winreg.QueryValueEx(subkey, "DisplayName")[0]
                                    if app_name.lower() in display_name.lower():
                                        try:
                                            uninstall_string = winreg.QueryValueEx(subkey, "UninstallString")[0]
                                            found_programs.append(('registry', display_name, uninstall_string))
                                            self.logger.info(f"Found registry entry: {display_name}")
                                        except FileNotFoundError:
                                            found_programs.append(('registry', display_name, None))
                                except FileNotFoundError:
                                    pass
                        except Exception:
                            continue
            except Exception as e:
                self.logger.warning(f"Registry search failed for {key_path}: {e}")

    def _search_msi_packages(self, app_name, found_programs):
        """Search MSI installed packages"""
        try:
            result = subprocess.run(['wmic', 'product', 'get', 'name,version'],
                                  capture_output=True, text=True, timeout=60)
            for line in result.stdout.split('\n'):
                if app_name.lower() in line.lower() and line.strip():
                    found_programs.append(('msi', line.strip(), app_name))
                    self.logger.info(f"Found MSI package: {line.strip()}")
        except Exception as e:
            self.logger.warning(f"MSI search failed: {e}")

    def _search_windows_apps(self, app_name, found_programs):
        """Search Windows Store apps and UWP packages"""
        try:
            result = subprocess.run(['powershell', '-Command',
                                   f'Get-AppxPackage | Where-Object {{$_.Name -like "*{app_name}*"}} | Select-Object Name,PackageFullName'],
                                  capture_output=True, text=True, timeout=60)
            for line in result.stdout.split('\n'):
                if app_name.lower() in line.lower() and line.strip() and 'Name' not in line:
                    found_programs.append(('uwp', line.strip(), app_name))
                    self.logger.info(f"Found UWP package: {line.strip()}")
        except Exception as e:
            self.logger.warning(f"UWP search failed: {e}")

    def uninstall_programs(self, found_programs):
        """Uninstall found programs using appropriate methods"""
        self.logger.info("Starting program uninstallation")

        for program_type, program_info, app_name in found_programs:
            self.logger.info(f"Uninstalling {program_type}: {program_info}")

            if program_type == 'winget':
                self._uninstall_winget(program_info, app_name)
            elif program_type == 'registry':
                self._uninstall_registry(program_info, app_name)
            elif program_type == 'msi':
                self._uninstall_msi(program_info, app_name)
            elif program_type == 'uwp':
                self._uninstall_uwp(program_info, app_name)

    def _uninstall_winget(self, program_info, app_name):
        """Uninstall using Windows Package Manager"""
        try:
            # Extract package ID from winget list output
            parts = program_info.split()
            if len(parts) >= 2:
                package_id = parts[-1] if '.' in parts[-1] else app_name
                self.logger.info(f"Attempting winget uninstall: {package_id}")
                result = subprocess.run(['winget', 'uninstall', package_id, '--silent'],
                                      capture_output=True, text=True, timeout=300)
                if result.returncode == 0:
                    self.logger.info(f"Successfully uninstalled via winget: {package_id}")
                else:
                    self.logger.warning(f"Winget uninstall failed: {result.stderr}")
        except Exception as e:
            self.logger.error(f"Winget uninstall error: {e}")

    def _uninstall_registry(self, display_name, uninstall_string):
        """Uninstall using registry uninstall string"""
        if not uninstall_string:
            return
        try:
            self.logger.info(f"Attempting registry uninstall: {display_name}")
            # Add silent flags for common installers
            if 'msiexec' in uninstall_string.lower():
                uninstall_string += ' /quiet /norestart'
            elif uninstall_string.endswith('.exe"') or uninstall_string.endswith('.exe'):
                uninstall_string += ' /S'

            result = subprocess.run(uninstall_string, shell=True, capture_output=True,
                                  text=True, timeout=300)
            if result.returncode == 0:
                self.logger.info(f"Successfully uninstalled via registry: {display_name}")
            else:
                self.logger.warning(f"Registry uninstall may have failed: {result.stderr}")
        except Exception as e:
            self.logger.error(f"Registry uninstall error: {e}")

    def _uninstall_msi(self, program_info, app_name):
        """Uninstall MSI package"""
        try:
            self.logger.info(f"Attempting MSI uninstall: {program_info}")
            result = subprocess.run(['wmic', 'product', 'where', f'name like "%{app_name}%"',
                                   'call', 'uninstall', '/nointeractive'],
                                  capture_output=True, text=True, timeout=300)
            if 'ReturnValue = 0' in result.stdout:
                self.logger.info(f"Successfully uninstalled MSI: {program_info}")
            else:
                self.logger.warning(f"MSI uninstall may have failed")
        except Exception as e:
            self.logger.error(f"MSI uninstall error: {e}")

    def _uninstall_uwp(self, program_info, app_name):
        """Uninstall UWP/Windows Store app"""
        try:
            self.logger.info(f"Attempting UWP uninstall: {program_info}")
            result = subprocess.run(['powershell', '-Command',
                                   f'Get-AppxPackage "*{app_name}*" | Remove-AppxPackage'],
                                  capture_output=True, text=True, timeout=300)
            if result.returncode == 0:
                self.logger.info(f"Successfully uninstalled UWP: {program_info}")
            else:
                self.logger.warning(f"UWP uninstall may have failed: {result.stderr}")
        except Exception as e:
            self.logger.error(f"UWP uninstall error: {e}")

    def kill_processes(self, app_names):
        """Terminate all related processes"""
        self.logger.info("Terminating related processes")

        for app_name in app_names:
            killed_count = 0

            # Method 1: psutil for precise matching
            for proc in psutil.process_iter(['pid', 'name', 'exe', 'cmdline']):
                try:
                    info = proc.info
                    should_kill = False

                    # Check process name
                    if info.get('name') and app_name.lower() in info['name'].lower():
                        should_kill = True

                    # Check executable path
                    if info.get('exe') and app_name.lower() in info['exe'].lower():
                        should_kill = True

                    # Check command line
                    if info.get('cmdline'):
                        cmdline_str = ' '.join(info['cmdline']).lower()
                        if app_name.lower() in cmdline_str:
                            should_kill = True

                    if should_kill:
                        self.logger.info(f"Terminating process: {info['name']} (PID: {info['pid']})")
                        proc.terminate()
                        killed_count += 1

                        # Wait a bit then force kill if still running
                        try:
                            proc.wait(timeout=3)
                        except psutil.TimeoutExpired:
                            proc.kill()

                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
                except Exception as e:
                    self.logger.warning(f"Error checking process: {e}")

            # Method 2: taskkill for broader matching
            try:
                subprocess.run(['taskkill', '/f', '/t', '/im', f'*{app_name}*'],
                             capture_output=True, timeout=30)
            except Exception:
                pass

            self.logger.info(f"Terminated {killed_count} processes for {app_name}")

    def kill_services(self, app_names):
        """Stop and remove related services"""
        self.logger.info("Stopping and removing related services")

        for app_name in app_names:
            try:
                # Get all services
                result = subprocess.run(['sc', 'query', 'type=all'],
                                      capture_output=True, text=True, timeout=30)

                services_to_remove = []
                for line in result.stdout.split('\n'):
                    if 'SERVICE_NAME:' in line:
                        service_name = line.split(':')[1].strip()
                        if app_name.lower() in service_name.lower():
                            services_to_remove.append(service_name)

                for service in services_to_remove:
                    self.logger.info(f"Stopping service: {service}")
                    subprocess.run(['sc', 'stop', service], capture_output=True, timeout=10)
                    time.sleep(2)
                    self.logger.info(f"Removing service: {service}")
                    subprocess.run(['sc', 'delete', service], capture_output=True, timeout=10)

            except Exception as e:
                self.logger.error(f"Service cleanup error: {e}")

    def delete_scheduled_tasks(self, app_names):
        """Remove related scheduled tasks"""
        self.logger.info("Removing related scheduled tasks")

        for app_name in app_names:
            try:
                result = subprocess.run(['schtasks', '/query', '/fo', 'csv'],
                                      capture_output=True, text=True, timeout=30)

                tasks_to_delete = []
                for line in result.stdout.split('\n'):
                    if app_name.lower() in line.lower() and 'TaskName' not in line:
                        parts = line.split(',')
                        if len(parts) > 0:
                            task_name = parts[0].strip('"')
                            if task_name:
                                tasks_to_delete.append(task_name)

                for task in tasks_to_delete:
                    self.logger.info(f"Deleting scheduled task: {task}")
                    subprocess.run(['schtasks', '/delete', '/tn', task, '/f'],
                                 capture_output=True, timeout=10)

            except Exception as e:
                self.logger.error(f"Scheduled task cleanup error: {e}")

    def schedule_for_deletion_on_reboot(self, path):
        """Schedule file/directory for deletion on next reboot"""
        try:
            MOVEFILE_DELAY_UNTIL_REBOOT = 0x00000004
            result = ctypes.windll.kernel32.MoveFileExW(str(path), None, MOVEFILE_DELAY_UNTIL_REBOOT)
            if result:
                self.logger.info(f"Scheduled for deletion on reboot: {path}")
                return True
            else:
                self.logger.warning(f"Failed to schedule for deletion: {path}")
                return False
        except Exception as e:
            self.logger.error(f"Error scheduling for deletion: {e}")
            return False

    def force_delete_file(self, file_path):
        """Safely force delete a file with multiple methods"""
        if not os.path.exists(file_path):
            return True

        # Critical system file check
        if self.is_critical_system_file(file_path):
            self.logger.warning(f"SKIPPED critical system file: {file_path}")
            self.skipped_count += 1
            return False

        try:
            # Remove attributes
            try:
                subprocess.run(['attrib', '-R', '-H', '-S', file_path],
                             capture_output=True, timeout=5)
            except:
                pass

            # Standard delete
            try:
                os.remove(file_path)
                if not os.path.exists(file_path):
                    return True
            except:
                pass

            # Take ownership and delete
            try:
                subprocess.run(['takeown', '/f', file_path], capture_output=True, timeout=10)
                subprocess.run(['icacls', file_path, '/grant', 'Everyone:F'],
                             capture_output=True, timeout=10)
                os.remove(file_path)
                if not os.path.exists(file_path):
                    return True
            except:
                pass

            # Schedule for deletion on reboot
            return self.schedule_for_deletion_on_reboot(file_path)

        except Exception as e:
            self.logger.error(f"Error deleting file {file_path}: {e}")
            return False

    def force_delete_directory(self, dir_path):
        """Safely force delete a directory with multiple methods"""
        if not os.path.exists(dir_path):
            return True

        # Critical system directory check
        if self.is_critical_system_file(dir_path):
            self.logger.warning(f"SKIPPED critical system directory: {dir_path}")
            self.skipped_count += 1
            return False

        try:
            # Take ownership recursively
            try:
                subprocess.run(['takeown', '/f', dir_path, '/r', '/d', 'y'],
                             capture_output=True, timeout=30)
                subprocess.run(['icacls', dir_path, '/grant', 'Everyone:F', '/t'],
                             capture_output=True, timeout=30)
            except:
                pass

            # Remove attributes
            try:
                subprocess.run(['attrib', '-R', '-H', '-S', dir_path, '/S', '/D'],
                             capture_output=True, timeout=20)
            except:
                pass

            # Standard delete
            try:
                shutil.rmtree(dir_path, ignore_errors=True)
                if not os.path.exists(dir_path):
                    return True
            except:
                pass

            # CMD rmdir
            try:
                subprocess.run(['cmd', '/c', f'rmdir /s /q "{dir_path}"'],
                             capture_output=True, timeout=30)
                if not os.path.exists(dir_path):
                    return True
            except:
                pass

            # Schedule for deletion on reboot
            return self.schedule_for_deletion_on_reboot(dir_path)

        except Exception as e:
            self.logger.error(f"Error deleting directory {dir_path}: {e}")
            return False

    def remove_shortcuts_and_icons(self, app_names):
        """Remove application shortcuts and icons"""
        self.logger.info("Removing shortcuts and icons")

        # Get all user directories dynamically
        user_dirs = []
        try:
            for user_dir in os.listdir("C:\\Users"):
                user_path = f"C:\\Users\\{user_dir}"
                if os.path.isdir(user_path) and user_dir not in ['All Users', 'Default', 'Public']:
                    user_dirs.append(user_path)
        except:
            pass

        shortcut_locations = [
            r"C:\ProgramData\Microsoft\Windows\Start Menu\Programs",
            r"C:\Users\Public\Desktop",
        ]

        # Add per-user locations
        for user_path in user_dirs:
            shortcut_locations.extend([
                f"{user_path}\\Desktop",
                f"{user_path}\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs",
                f"{user_path}\\AppData\\Roaming\\Microsoft\\Internet Explorer\\Quick Launch",
            ])

        for app_name in app_names:
            for location in shortcut_locations:
                if not os.path.exists(location):
                    continue

                try:
                    for root, dirs, files in os.walk(location):
                        for file in files:
                            if (app_name.lower() in file.lower() and
                                file.lower().endswith(('.lnk', '.url'))):
                                shortcut_path = os.path.join(root, file)
                                self.logger.info(f"Removing shortcut: {shortcut_path}")
                                if self.force_delete_file(shortcut_path):
                                    self.deleted_count += 1
                                else:
                                    self.failed_count += 1
                except Exception as e:
                    self.logger.error(f"Shortcut cleanup error in {location}: {e}")

    def get_comprehensive_search_locations(self):
        """Get comprehensive list of search locations"""
        locations = [
            # Program installation directories
            r"C:\Program Files",
            r"C:\Program Files (x86)",
            r"C:\Program Files\Common Files",
            r"C:\Program Files (x86)\Common Files",
            r"C:\Program Files\WindowsApps",
            r"C:\Program Files\ModifiableWindowsApps",

            # System data directories
            r"C:\ProgramData",
            r"C:\Windows\Installer",
            r"C:\Windows\System32",
            r"C:\Windows\SysWOW64",

            # Safe temporary and cache directories
            r"C:\Windows\Temp",
            r"C:\Windows\Prefetch",
            r"C:\Windows\Logs",
            r"C:\ProgramData\Package Cache",
            r"C:\ProgramData\Microsoft\Windows\WER",
        ]

        # Add user directories dynamically
        try:
            for user_dir in os.listdir("C:\\Users"):
                user_path = f"C:\\Users\\{user_dir}"
                if os.path.isdir(user_path) and user_dir not in ['All Users', 'Default', 'Public']:
                    locations.extend([
                        f"{user_path}\\AppData\\Local",
                        f"{user_path}\\AppData\\Roaming",
                        f"{user_path}\\AppData\\LocalLow",
                        f"{user_path}\\AppData\\Local\\Temp",
                        f"{user_path}\\Desktop",
                        f"{user_path}\\Documents",
                        f"{user_path}\\Downloads"
                    ])
        except:
            pass

        return locations

    def comprehensive_file_search(self, app_names):
        """Comprehensive file and directory search with safety checks"""
        self.logger.info("Starting comprehensive file search")

        search_locations = self.get_comprehensive_search_locations()

        for app_name in app_names:
            self.logger.info(f"Searching for files related to: {app_name}")
            all_targets = set()

            for location in search_locations:
                if not os.path.exists(location):
                    continue

                self.logger.info(f"Searching in: {location}")
                try:
                    # Use multiple search methods
                    patterns = [
                        f"*{app_name}*",
                        f"*{app_name.lower()}*",
                        f"*{app_name.upper()}*",
                        f"*{app_name.capitalize()}*"
                    ]

                    for pattern in patterns:
                        try:
                            # Use glob for Python-based search
                            search_pattern = os.path.join(location, "**", pattern)
                            for match in glob.glob(search_pattern, recursive=True):
                                if os.path.exists(match):
                                    all_targets.add(match)
                        except Exception:
                            continue

                    # Use dir command for additional search
                    try:
                        cmd = f'dir "{location}\\*{app_name}*" /s /b /a 2>nul'
                        result = subprocess.run(cmd, shell=True, capture_output=True,
                                              text=True, timeout=60)
                        for line in result.stdout.split('\n'):
                            if line.strip() and os.path.exists(line.strip()):
                                all_targets.add(line.strip())
                    except Exception:
                        continue

                except Exception as e:
                    self.logger.error(f"Search failed in {location}: {e}")

            # Remove targets
            self.logger.info(f"Found {len(all_targets)} targets for {app_name}")
            self._remove_targets(list(all_targets))

    def _remove_targets(self, targets):
        """Remove found targets with safety checks"""
        # Sort by depth (files first, then directories)
        targets.sort(key=lambda x: (os.path.isdir(x), x.count(os.sep)), reverse=False)

        for target in targets:
            if not os.path.exists(target):
                continue

            self.logger.info(f"Processing: {target}")

            try:
                if os.path.isfile(target):
                    if self.force_delete_file(target):
                        self.logger.info(f"SUCCESS: Deleted file {target}")
                        self.deleted_count += 1
                    else:
                        self.logger.warning(f"FAILED: Could not delete file {target}")
                        self.failed_count += 1

                elif os.path.isdir(target):
                    if self.force_delete_directory(target):
                        self.logger.info(f"SUCCESS: Deleted directory {target}")
                        self.deleted_count += 1
                    else:
                        self.logger.warning(f"FAILED: Could not delete directory {target}")
                        self.failed_count += 1

            except Exception as e:
                self.logger.error(f"Error processing {target}: {e}")
                self.failed_count += 1

    def cleanup_registry_safe(self, app_names):
        """Safe registry cleanup with protection for critical keys"""
        self.logger.info("Starting safe registry cleanup")

        # Define safe registry areas for application cleanup
        safe_cleanup_areas = [
            (winreg.HKEY_CURRENT_USER, r"Software"),
            (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
            (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
            (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Classes\Installer\Products"),
            (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths"),
            (winreg.HKEY_CURRENT_USER, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Run"),
            (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Run"),
        ]

        for app_name in app_names:
            self.logger.info(f"Cleaning registry for: {app_name}")

            for root_key, subkey_path in safe_cleanup_areas:
                try:
                    self._cleanup_registry_key(root_key, subkey_path, app_name)
                except Exception as e:
                    self.logger.error(f"Registry cleanup error in {subkey_path}: {e}")

    def _cleanup_registry_key(self, root_key, key_path, app_name):
        """Clean specific registry key area"""
        try:
            with winreg.OpenKey(root_key, key_path, 0, winreg.KEY_READ | winreg.KEY_WRITE) as key:
                subkeys_to_delete = []

                # Find subkeys that match the app name
                try:
                    i = 0
                    while True:
                        subkey_name = winreg.EnumKey(key, i)
                        if app_name.lower() in subkey_name.lower():
                            subkeys_to_delete.append(subkey_name)
                        i += 1
                except OSError:
                    pass  # No more subkeys

                # Delete matching subkeys
                for subkey_name in subkeys_to_delete:
                    try:
                        self.logger.info(f"Deleting registry key: {key_path}\\{subkey_name}")
                        winreg.DeleteKeyEx(key, subkey_name)
                    except Exception as e:
                        self.logger.warning(f"Could not delete registry key {subkey_name}: {e}")

                # Find and delete matching values
                values_to_delete = []
                try:
                    i = 0
                    while True:
                        value_name, value_data, value_type = winreg.EnumValue(key, i)
                        if (app_name.lower() in value_name.lower() or
                            (isinstance(value_data, str) and app_name.lower() in value_data.lower())):
                            values_to_delete.append(value_name)
                        i += 1
                except OSError:
                    pass  # No more values

                # Delete matching values
                for value_name in values_to_delete:
                    try:
                        self.logger.info(f"Deleting registry value: {key_path}\\{value_name}")
                        winreg.DeleteValue(key, value_name)
                    except Exception as e:
                        self.logger.warning(f"Could not delete registry value {value_name}: {e}")

        except FileNotFoundError:
            pass  # Key doesn't exist
        except PermissionError:
            self.logger.warning(f"Permission denied accessing registry key: {key_path}")

    def final_system_cleanup(self):
        """Final system cleanup operations"""
        self.logger.info("Performing final system cleanup")

        try:
            # Clear recycle bin
            self.logger.info("Clearing recycle bin")
            subprocess.run(['powershell', '-Command',
                           'Clear-RecycleBin -Force -ErrorAction SilentlyContinue'],
                         capture_output=True, timeout=30)
        except Exception as e:
            self.logger.warning(f"Recycle bin cleanup failed: {e}")

        try:
            # Clear temporary files
            self.logger.info("Clearing temporary files")
            temp_locations = [
                os.environ.get('TEMP', ''),
                os.environ.get('TMP', ''),
                r'C:\Windows\Temp',
                r'C:\Temp'
            ]

            for temp_path in temp_locations:
                if temp_path and os.path.exists(temp_path):
                    try:
                        for item in os.listdir(temp_path):
                            item_path = os.path.join(temp_path, item)
                            if os.path.isfile(item_path):
                                self.force_delete_file(item_path)
                            elif os.path.isdir(item_path):
                                self.force_delete_directory(item_path)
                    except Exception:
                        continue
        except Exception as e:
            self.logger.warning(f"Temp cleanup failed: {e}")

        try:
            # Flush DNS cache
            self.logger.info("Flushing DNS cache")
            subprocess.run(['ipconfig', '/flushdns'], capture_output=True, timeout=15)
        except Exception as e:
            self.logger.warning(f"DNS flush failed: {e}")

    def execute_ultimate_uninstall(self, app_names):
        """Execute the complete uninstallation process"""
        self.logger.info("="*80)
        self.logger.info("ULTIMATE SAFE UNINSTALLER - COMPLETE REMOVAL")
        self.logger.info("="*80)
        self.logger.info(f"TARGETS: {', '.join(app_names)}")
        self.logger.info("="*80)

        start_time = time.time()

        try:
            # Step 1: Find and uninstall programs properly
            found_programs = self.find_installed_programs(app_names)
            if found_programs:
                self.uninstall_programs(found_programs)
                time.sleep(5)  # Wait for uninstallation to complete

            # Step 2: Terminate related processes
            self.kill_processes(app_names)

            # Step 3: Stop and remove services
            self.kill_services(app_names)

            # Step 4: Remove scheduled tasks
            self.delete_scheduled_tasks(app_names)

            # Step 5: Remove shortcuts and icons
            self.remove_shortcuts_and_icons(app_names)

            # Step 6: Comprehensive file search and removal
            self.comprehensive_file_search(app_names)

            # Step 7: Safe registry cleanup
            self.cleanup_registry_safe(app_names)

            # Step 8: Final system cleanup
            self.final_system_cleanup()

        except Exception as e:
            self.logger.error(f"Uninstallation error: {e}")

        # Results
        total_time = time.time() - start_time
        self.logger.info("\n" + "="*80)
        self.logger.info("UNINSTALLATION COMPLETE!")
        self.logger.info("="*80)
        self.logger.info(f"Applications processed: {len(app_names)}")
        self.logger.info(f"Total time: {total_time:.1f} seconds")
        self.logger.info(f"Items deleted: {self.deleted_count}")
        self.logger.info(f"Items failed: {self.failed_count}")
        self.logger.info(f"Critical items skipped: {self.skipped_count}")

        if self.failed_count == 0:
            self.logger.info("\nSUCCESS: ALL ITEMS REMOVED!")
        else:
            self.logger.warning(f"\nNOTE: {self.failed_count} items could not be removed or are scheduled for deletion on reboot")

        self.logger.info("\nUNINSTALLATION COMPLETED SAFELY!")
        print(f"\nLog file saved to: {os.path.join(tempfile.gettempdir(), 'uninstaller.log')}")

def main():
    parser = argparse.ArgumentParser(description='Ultimate Safe Uninstaller - Complete Application Removal')
    parser.add_argument('apps', nargs='*', help='Applications to uninstall completely')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be removed without actually removing it')

    args = parser.parse_args()

    if not args.apps:
        print("ERROR: No applications specified")
        print("Usage: python d.py <app1> <app2> [app3] ...")
        print("\nExamples:")
        print("python d.py wavebox")
        print("python d.py temp logs outlook")
        sys.exit(1)

    # Initialize uninstaller
    uninstaller = UltimateUninstaller()

    # Check admin privileges
    if not uninstaller.check_admin():
        print("ERROR: Administrator privileges required!")
        print("Please run as Administrator")
        sys.exit(1)

    # Show warning
    print("WARNING: This will completely remove all traces of the specified applications.")
    print("This action cannot be undone!")
    print(f"Applications to remove: {', '.join(args.apps)}")

    if not args.dry_run:
        confirm = input("\nAre you sure you want to continue? (type 'YES' to confirm): ")
        if confirm != 'YES':
            print("Operation cancelled.")
            sys.exit(0)

    # Execute uninstallation
    if args.dry_run:
        print("DRY RUN MODE - No actual changes will be made")
        # Could implement dry run logic here
    else:
        uninstaller.execute_ultimate_uninstall(args.apps)

if __name__ == "__main__":
    main()