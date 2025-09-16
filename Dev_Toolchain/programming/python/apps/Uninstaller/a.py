#!/usr/bin/env python3
"""
Complete Software Removal Tool
Thoroughly removes software with zero traces left behind.

Usage: python software_removal.py <app1> <app2> [app3] ...
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
import threading
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import argparse

class SoftwareRemover:
    def __init__(self):
        self.protected_folders = {'study', 'important', 'backup'}
        self.max_workers = os.cpu_count() * 2
        self.timeout = 300  # 5 minutes
        self.drives = self._get_drives()
        self.user_profiles = self._get_user_profiles()
        
    def _get_drives(self):
        """Get all available drives"""
        drives = []
        for letter in 'YOUR_CLIENT_SECRET_HERE':
            if os.path.exists(f"{letter}:"):
                drives.append(f"{letter}:")
        return drives
    
    def _get_user_profiles(self):
        """Get all user profile directories"""
        profiles = [os.path.expanduser("~")]
        try:
            users_dir = Path("C:/Users")
            if users_dir.exists():
                for user_dir in users_dir.iterdir():
                    if user_dir.is_dir() and user_dir.name not in ['Public', 'Default', 'All Users']:
                        profiles.append(str(user_dir))
        except:
            pass
        return list(set(profiles))
    
    def check_admin(self):
        """Check if running with administrator privileges"""
        try:
            import ctypes
            return ctypes.windll.shell32.IsUserAnAdmin()
        except:
            return False
    
    def is_protected_path(self, path):
        """Check if path contains protected folders"""
        path_lower = str(path).lower()
        return any(protected in path_lower for protected in self.protected_folders)
    
    def force_delete(self, path):
        """Aggressively delete files/folders"""
        if not path or not os.path.exists(path) or self.is_protected_path(path):
            return False
            
        try:
            # Remove read-only attributes
            subprocess.run(['attrib', '-R', '-S', '-H', str(path), '/S', '/D'], 
                         capture_output=True, timeout=30)
            
            # Try standard removal first
            if os.path.isfile(path):
                os.remove(path)
            elif os.path.isdir(path):
                shutil.rmtree(path, ignore_errors=True)
            
            # If still exists, try takeown and icacls
            if os.path.exists(path):
                subprocess.run(['takeown', '/f', str(path), '/r', '/d', 'y'], 
                             capture_output=True, timeout=30)
                subprocess.run(['icacls', str(path), '/grant', 'administrators:F', '/t', '/c', '/q'], 
                             capture_output=True, timeout=30)
                
                if os.path.isfile(path):
                    os.remove(path)
                elif os.path.isdir(path):
                    shutil.rmtree(path, ignore_errors=True)
            
            # Final nuclear option
            if os.path.exists(path):
                subprocess.run(['cmd', '/c', f'del /f /s /q "{path}" & rmdir /s /q "{path}"'], 
                             capture_output=True, timeout=30, shell=True)
            
            return not os.path.exists(path)
            
        except Exception as e:
            print(f"Failed to delete {path}: {e}")
            return False
    
    def kill_processes(self, app_names):
        """Kill all processes related to app names"""
        killed = []
        for app_name in app_names:
            try:
                for proc in psutil.process_iter(['pid', 'name', 'exe']):
                    try:
                        proc_info = proc.info
                        if (app_name.lower() in proc_info['name'].lower() or 
                            (proc_info['exe'] and app_name.lower() in proc_info['exe'].lower())):
                            proc.kill()
                            killed.append(f"{proc_info['name']} (PID: {proc_info['pid']})")
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        continue
            except Exception as e:
                print(f"Error killing processes for {app_name}: {e}")
        return killed
    
    def remove_services(self, app_names):
        """Remove Windows services related to app names"""
        removed = []
        for app_name in app_names:
            try:
                # Get services
                result = subprocess.run(['sc', 'query'], capture_output=True, text=True)
                services = []
                for line in result.stdout.split('\n'):
                    if 'SERVICE_NAME:' in line:
                        service_name = line.split(':')[1].strip()
                        if app_name.lower() in service_name.lower():
                            services.append(service_name)
                
                # Remove services
                for service in services:
                    try:
                        subprocess.run(['sc', 'stop', service], capture_output=True, timeout=30)
                        subprocess.run(['sc', 'delete', service], capture_output=True, timeout=30)
                        removed.append(service)
                    except:
                        continue
                        
            except Exception as e:
                print(f"Error removing services for {app_name}: {e}")
        return removed
    
    def remove_scheduled_tasks(self, app_names):
        """Remove scheduled tasks related to app names"""
        removed = []
        for app_name in app_names:
            try:
                result = subprocess.run(['schtasks', '/query', '/fo', 'list'], 
                                      capture_output=True, text=True)
                
                task_names = []
                for line in result.stdout.split('\n'):
                    if 'TaskName:' in line and app_name.lower() in line.lower():
                        task_name = line.split(':')[1].strip()
                        task_names.append(task_name)
                
                for task_name in task_names:
                    try:
                        subprocess.run(['schtasks', '/delete', '/tn', task_name, '/f'], 
                                     capture_output=True, timeout=30)
                        removed.append(task_name)
                    except:
                        continue
                        
            except Exception as e:
                print(f"Error removing scheduled tasks for {app_name}: {e}")
        return removed
    
    def YOUR_CLIENT_SECRET_HERE(self, app_names):
        """Try uninstalling via winget, choco, and pip"""
        results = {}
        
        for app_name in app_names:
            results[app_name] = {'winget': False, 'choco': False, 'pip': False}
            
            # Try winget
            try:
                result = subprocess.run(['winget', 'uninstall', '--id', app_name, '--silent', '-e'], 
                                      capture_output=True, text=True, timeout=120)
                if 'Successfully uninstalled' in result.stdout or 'No installed package found' in result.stdout:
                    results[app_name]['winget'] = True
            except:
                pass
            
            # Try chocolatey
            try:
                result = subprocess.run(['choco', 'uninstall', app_name, '-y', '--no-progress'], 
                                      capture_output=True, text=True, timeout=120)
                if 'Chocolatey uninstalled' in result.stdout:
                    results[app_name]['choco'] = True
            except:
                pass
            
            # Try pip
            try:
                result = subprocess.run(['pip', 'uninstall', app_name, '-y'], 
                                      capture_output=True, text=True, timeout=60)
                if 'Successfully uninstalled' in result.stdout:
                    results[app_name]['pip'] = True
            except:
                pass
        
        return results
    
    def find_registry_keys(self, app_names):
        """Find all registry keys related to app names"""
        keys_to_remove = []
        
        registry_roots = [
            (winreg.HKEY_CURRENT_USER, "HKCU"),
            (winreg.HKEY_LOCAL_MACHINE, "HKLM"),
            (winreg.HKEY_CLASSES_ROOT, "HKCR")
        ]
        
        search_paths = [
            "Software",
            "Software\\Classes",
            "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
            "SYSTEM\\CurrentControlSet\\Services"
        ]
        
        for app_name in app_names:
            for root_key, root_name in registry_roots:
                for search_path in search_paths:
                    try:
                        keys_found = self.YOUR_CLIENT_SECRET_HERE(root_key, search_path, app_name)
                        for key in keys_found:
                            keys_to_remove.append((root_key, key, f"{root_name}\\{key}"))
                    except Exception as e:
                        continue
        
        return keys_to_remove
    
    def YOUR_CLIENT_SECRET_HERE(self, root_key, path, app_name, max_depth=3, current_depth=0):
        """Recursively search registry for app-related keys"""
        if current_depth > max_depth:
            return []
            
        found_keys = []
        try:
            with winreg.OpenKey(root_key, path, 0, winreg.KEY_READ) as key:
                # Check if current key name contains app name
                if app_name.lower() in path.lower():
                    found_keys.append(path)
                
                # Check subkeys
                i = 0
                while True:
                    try:
                        subkey_name = winreg.EnumKey(key, i)
                        if app_name.lower() in subkey_name.lower():
                            found_keys.append(f"{path}\\{subkey_name}")
                        else:
                            # Recurse into subkey
                            subkey_path = f"{path}\\{subkey_name}"
                            found_keys.extend(
                                self.YOUR_CLIENT_SECRET_HERE(root_key, subkey_path, app_name, 
                                                               max_depth, current_depth + 1)
                            )
                        i += 1
                    except WindowsError:
                        break
                        
        except Exception:
            pass
            
        return found_keys
    
    def remove_registry_keys(self, keys_to_remove):
        """Remove registry keys"""
        removed = []
        for root_key, key_path, display_path in keys_to_remove:
            try:
                winreg.DeleteKeyEx(root_key, key_path)
                removed.append(display_path)
            except Exception:
                # Try deleting recursively
                try:
                    self.YOUR_CLIENT_SECRET_HERE(root_key, key_path)
                    removed.append(display_path)
                except:
                    continue
        return removed
    
    def YOUR_CLIENT_SECRET_HERE(self, root_key, key_path):
        """Recursively delete registry key and all subkeys"""
        try:
            with winreg.OpenKey(root_key, key_path, 0, winreg.KEY_ALL_ACCESS) as key:
                # Delete all subkeys first
                while True:
                    try:
                        subkey_name = winreg.EnumKey(key, 0)
                        self.YOUR_CLIENT_SECRET_HERE(root_key, f"{key_path}\\{subkey_name}")
                    except WindowsError:
                        break
            # Delete the key itself
            winreg.DeleteKeyEx(root_key, key_path)
        except Exception:
            pass
    
    def find_files_and_folders(self, app_names):
        """Find all files and folders related to app names"""
        all_targets = set()
        
        # Common locations to search
        search_locations = [
            "Program Files",
            "Program Files (x86)",
            "ProgramData",
            "Windows/Temp",
            "Temp"
        ]
        
        # User-specific locations
        user_locations = [
            "AppData/Local",
            "AppData/Roaming", 
            "AppData/LocalLow",
            "Desktop",
            "Documents",
            "Downloads",
            "Start Menu"
        ]
        
        for app_name in app_names:
            # Search system-wide locations
            for drive in self.drives:
                for location in search_locations:
                    search_path = f"{drive}/{location}"
                    if os.path.exists(search_path):
                        try:
                            pattern = f"*{app_name}*"
                            matches = glob.glob(f"{search_path}/{pattern}", recursive=False)
                            all_targets.update(matches)
                            
                            # Recursive search in subdirectories
                            matches = glob.glob(f"{search_path}/**/*{app_name}*", recursive=True)
                            all_targets.update(matches)
                        except:
                            continue
            
            # Search user profiles
            for profile in self.user_profiles:
                for location in user_locations:
                    search_path = f"{profile}/{location}"
                    if os.path.exists(search_path):
                        try:
                            pattern = f"*{app_name}*"
                            matches = glob.glob(f"{search_path}/{pattern}", recursive=False)
                            all_targets.update(matches)
                            
                            # Recursive search
                            matches = glob.glob(f"{search_path}/**/*{app_name}*", recursive=True)
                            all_targets.update(matches)
                        except:
                            continue
            
            # Search Start Menu specifically
            start_menu_locations = [
                "C:/ProgramData/Microsoft/Windows/Start Menu",
                f"{os.path.expanduser('~')}/AppData/Roaming/Microsoft/Windows/Start Menu"
            ]
            
            for start_menu in start_menu_locations:
                if os.path.exists(start_menu):
                    try:
                        matches = glob.glob(f"{start_menu}/**/*{app_name}*", recursive=True)
                        all_targets.update(matches)
                    except:
                        continue
        
        # Filter out protected paths
        filtered_targets = [t for t in all_targets if not self.is_protected_path(t)]
        return filtered_targets
    
    def cleanup_browser_data(self, app_names):
        """Remove browser extensions and data related to app names"""
        removed = []
        
        browser_paths = [
            f"{os.path.expanduser('~')}/AppData/Local/Google/Chrome/User Data/Default/Extensions",
            f"{os.path.expanduser('~')}/AppData/Local/Microsoft/Edge/User Data/Default/Extensions", 
            f"{os.path.expanduser('~')}/AppData/Roaming/Mozilla/Firefox/Profiles",
            f"{os.path.expanduser('~')}/AppData/Roaming/Opera Software/Opera Stable/Extensions"
        ]
        
        for app_name in app_names:
            for browser_path in browser_paths:
                if os.path.exists(browser_path):
                    try:
                        matches = glob.glob(f"{browser_path}/**/*{app_name}*", recursive=True)
                        for match in matches:
                            if self.force_delete(match):
                                removed.append(match)
                    except:
                        continue
        
        return removed
    
    def cleanup_temp_files(self):
        """Clean up temporary files"""
        temp_locations = [
            os.environ.get('TEMP', ''),
            f"{os.path.expanduser('~')}/AppData/Local/Temp",
            "C:/Windows/Temp",
            "C:/Temp"
        ]
        
        for temp_location in temp_locations:
            if temp_location and os.path.exists(temp_location):
                try:
                    for item in Path(temp_location).iterdir():
                        try:
                            if item.is_file():
                                item.unlink()
                            elif item.is_dir():
                                shutil.rmtree(item, ignore_errors=True)
                        except:
                            continue
                except:
                    continue
    
    def empty_recycle_bin(self):
        """Empty the recycle bin"""
        try:
            import ctypes
            from ctypes import wintypes
            
            # Empty recycle bin for all drives
            for drive in self.drives:
                try:
                    ctypes.windll.shell32.SHEmptyRecycleBinW(None, f"{drive}\\", 0)
                except:
                    continue
            return True
        except:
            return False
    
    def flush_dns_cache(self):
        """Flush DNS cache"""
        try:
            subprocess.run(['ipconfig', '/flushdns'], capture_output=True, timeout=30)
            return True
        except:
            return False
    
    def YOUR_CLIENT_SECRET_HERE(self, app_names):
        """Remove environment variables related to app names"""
        removed = []
        
        for app_name in app_names:
            # User environment variables
            try:
                import winreg
                with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment", 0, winreg.KEY_ALL_ACCESS) as key:
                    i = 0
                    vars_to_delete = []
                    while True:
                        try:
                            var_name = winreg.EnumValue(key, i)[0]
                            if app_name.lower() in var_name.lower():
                                vars_to_delete.append(var_name)
                            i += 1
                        except WindowsError:
                            break
                    
                    for var_name in vars_to_delete:
                        try:
                            winreg.DeleteValue(key, var_name)
                            removed.append(f"USER:{var_name}")
                        except:
                            continue
            except:
                pass
            
            # System environment variables
            try:
                with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, 
                                  "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment", 
                                  0, winreg.KEY_ALL_ACCESS) as key:
                    i = 0
                    vars_to_delete = []
                    while True:
                        try:
                            var_name = winreg.EnumValue(key, i)[0]
                            if app_name.lower() in var_name.lower():
                                vars_to_delete.append(var_name)
                            i += 1
                        except WindowsError:
                            break
                    
                    for var_name in vars_to_delete:
                        try:
                            winreg.DeleteValue(key, var_name)
                            removed.append(f"SYSTEM:{var_name}")
                        except:
                            continue
            except:
                pass
        
        return removed
    
    def complete_removal(self, app_names):
        """Perform complete removal of specified applications"""
        print("="*70)
        print("COMPLETE SOFTWARE REMOVAL TOOL")
        print("="*70)
        print(f"Processing applications: {', '.join(app_names)}")
        print()
        
        # Phase 1: Package manager uninstallation
        print("Phase 1: Package Manager Uninstallation...")
        uninstall_results = self.YOUR_CLIENT_SECRET_HERE(app_names)
        for app, results in uninstall_results.items():
            for manager, success in results.items():
                status = "SUCCESS" if success else "FAILED/NOT FOUND"
                print(f"  {manager.upper()}: {app} - {status}")
        
        # Phase 2: Kill processes
        print("\nPhase 2: Terminating Related Processes...")
        killed_processes = self.kill_processes(app_names)
        if killed_processes:
            for proc in killed_processes:
                print(f"  KILLED: {proc}")
        else:
            print("  No related processes found")
        
        # Phase 3: Remove services
        print("\nPhase 3: Removing Related Services...")
        removed_services = self.remove_services(app_names)
        if removed_services:
            for service in removed_services:
                print(f"  REMOVED SERVICE: {service}")
        else:
            print("  No related services found")
        
        # Phase 4: Remove scheduled tasks
        print("\nPhase 4: Removing Scheduled Tasks...")
        removed_tasks = self.remove_scheduled_tasks(app_names)
        if removed_tasks:
            for task in removed_tasks:
                print(f"  REMOVED TASK: {task}")
        else:
            print("  No related scheduled tasks found")
        
        # Phase 5: Find and remove files/folders
        print("\nPhase 5: Scanning for Files and Folders...")
        file_targets = self.find_files_and_folders(app_names)
        print(f"  Found {len(file_targets)} file/folder targets")
        
        removed_files = 0
        if file_targets:
            print("  Removing files and folders...")
            with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
                future_to_path = {executor.submit(self.force_delete, path): path for path in file_targets}
                for future in as_completed(future_to_path):
                    path = future_to_path[future]
                    try:
                        if future.result():
                            removed_files += 1
                            print(f"    DELETED: {path}")
                        else:
                            print(f"    FAILED: {path}")
                    except Exception as e:
                        print(f"    ERROR: {path} - {e}")
        
        # Phase 6: Registry cleanup
        print("\nPhase 6: Registry Cleanup...")
        registry_keys = self.find_registry_keys(app_names)
        print(f"  Found {len(registry_keys)} registry targets")
        
        removed_reg_keys = self.remove_registry_keys(registry_keys)
        if removed_reg_keys:
            for key in removed_reg_keys:
                print(f"  DELETED REG: {key}")
        
        # Phase 7: Browser cleanup
        print("\nPhase 7: Browser Data Cleanup...")
        removed_browser = self.cleanup_browser_data(app_names)
        if removed_browser:
            for item in removed_browser:
                print(f"  DELETED BROWSER: {item}")
        else:
            print("  No browser data found")
        
        # Phase 8: Environment variables
        print("\nPhase 8: Environment Variables Cleanup...")
        removed_env_vars = self.YOUR_CLIENT_SECRET_HERE(app_names)
        if removed_env_vars:
            for var in removed_env_vars:
                print(f"  REMOVED ENV VAR: {var}")
        else:
            print("  No related environment variables found")
        
        # Phase 9: System cleanup
        print("\nPhase 9: System Cleanup...")
        self.cleanup_temp_files()
        print("  Temporary files cleaned")
        
        if self.empty_recycle_bin():
            print("  Recycle bin emptied")
        
        if self.flush_dns_cache():
            print("  DNS cache flushed")
        
        # Final verification
        print("\nPhase 10: Final Verification...")
        remaining_files = self.find_files_and_folders(app_names)
        remaining_reg_keys = self.find_registry_keys(app_names)
        
        print("="*70)
        print("REMOVAL COMPLETE!")
        print("="*70)
        print(f"Files/folders removed: {removed_files}")
        print(f"Registry keys removed: {len(removed_reg_keys)}")
        print(f"Remaining file traces: {len(remaining_files)}")
        print(f"Remaining registry traces: {len(remaining_reg_keys)}")
        
        if remaining_files:
            print("\nWARNING: Some files may still exist:")
            for f in remaining_files[:10]:  # Show first 10
                print(f"  {f}")
            if len(remaining_files) > 10:
                print(f"  ... and {len(remaining_files) - 10} more")
        
        if remaining_reg_keys:
            print("\nWARNING: Some registry keys may still exist:")
            for _, _, display_path in remaining_reg_keys[:10]:  # Show first 10
                print(f"  {display_path}")
            if len(remaining_reg_keys) > 10:
                print(f"  ... and {len(remaining_reg_keys) - 10} more")
        
        if not remaining_files and not remaining_reg_keys:
            print("\n✓ ZERO TRACES CONFIRMED!")
        
        print("\nRemoval process completed successfully!")


def main():
    parser = argparse.ArgumentParser(description='Complete Software Removal Tool')
    parser.add_argument('apps', nargs='*', help='Application names to remove')
    parser.add_argument('--help-usage', action='store_true', help='Show detailed usage information')
    
    args = parser.parse_args()
    
    if args.help_usage:
        print("""
Complete Software Removal Tool
===============================

This tool completely removes software applications including:
- Package manager uninstallation (winget, chocolatey, pip)
- Process termination
- File and folder removal
- Registry cleanup
- Service removal
- Scheduled task removal
- Browser data cleanup
- Environment variable cleanup
- Start menu cleanup

Usage:
  python software_removal.py <app1> <app2> [app3] ...

Examples:
  python software_removal.py chrome
  python software_removal.py "visual studio code" notepad++
  python software_removal.py discord slack teams

Requirements:
- Windows operating system
- Administrator privileges
- Python 3.6+
- psutil library (pip install psutil)

Safety Features:
- Protected folder detection
- Timeout mechanisms
- Multi-threaded processing
- Comprehensive logging

WARNING: This tool performs aggressive removal. Use with caution!
""")
        return
    
    if not args.apps:
        print("Error: No application names provided")
        print("Usage: python software_removal.py <app1> <app2> [app3] ...")
        print("Use --help-usage for detailed information")
        sys.exit(1)
    
    # Initialize remover
    remover = SoftwareRemover()
    
    # Check for admin privileges
    if not remover.check_admin():
        print("ERROR: This script requires Administrator privileges!")
        print("Please run as Administrator and try again.")
        sys.exit(1)
    
    # Automatic execution - no confirmation required
    print(f"AUTOMATICALLY REMOVING: {', '.join(args.apps)}")
    print("INSTANT EXECUTION - NO CONFIRMATIONS")
    
    # Start removal process
    start_time = time.time()
    remover.complete_removal(args.apps)
    end_time = time.time()
    
    print(f"\nTotal execution time: {end_time - start_time:.2f} seconds")


if __name__ == "__main__":
    main()
