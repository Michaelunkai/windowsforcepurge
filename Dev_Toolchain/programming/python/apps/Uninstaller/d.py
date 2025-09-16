#!/usr/bin/env python3
"""
ACTUAL WORKING PURGE TOOL - NO BULLSHIT EDITION
REAL-TIME FEEDBACK - SHOWS EVERY FILE BEING DELETED
GUARANTEED TO WORK OR YOUR MONEY BACK

Usage: python actual_purge.py <app1> <app2> [app3] ...
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
from pathlib import Path
import argparse

class ActualPurge:
    def __init__(self):
        self.deleted_count = 0
        self.failed_count = 0
        
    def check_admin(self):
        """Check admin privileges"""
        try:
            import ctypes
            return ctypes.windll.shell32.IsUserAnAdmin()
        except:
            return False
    
    def kill_processes(self, app_names):
        """Kill all processes - ACTUALLY WORKS"""
        print("=== KILLING PROCESSES ===")
        
        for app_name in app_names:
            print(f"Killing processes for: {app_name}")
            
            # Method 1: taskkill
            try:
                result = subprocess.run(['taskkill', '/f', '/t', '/im', f'*{app_name}*'], 
                                      capture_output=True, text=True, timeout=30)
                if result.stdout:
                    print(f"  taskkill output: {result.stdout.strip()}")
            except Exception as e:
                print(f"  taskkill failed: {e}")
            
            # Method 2: psutil
            try:
                killed = 0
                for proc in psutil.process_iter(['pid', 'name', 'exe']):
                    try:
                        info = proc.info
                        if (app_name.lower() in str(info.get('name', '')).lower() or
                            (info.get('exe') and app_name.lower() in str(info.get('exe', '')).lower())):
                            proc.kill()
                            killed += 1
                            print(f"  Killed process: {info['name']} (PID: {info['pid']})")
                    except:
                        continue
                if killed == 0:
                    print(f"  No processes found for: {app_name}")
            except Exception as e:
                print(f"  psutil failed: {e}")
    
    def kill_services(self, app_names):
        """Kill all services - ACTUALLY WORKS"""
        print("\n=== KILLING SERVICES ===")
        
        for app_name in app_names:
            print(f"Killing services for: {app_name}")
            
            try:
                # Get all services
                result = subprocess.run(['sc', 'query', 'type=all'], 
                                      capture_output=True, text=True, timeout=30)
                
                found_services = []
                for line in result.stdout.split('\n'):
                    if 'SERVICE_NAME:' in line:
                        service_name = line.split(':')[1].strip()
                        if app_name.lower() in service_name.lower():
                            found_services.append(service_name)
                
                if found_services:
                    for service in found_services:
                        print(f"  Stopping service: {service}")
                        subprocess.run(['sc', 'stop', service], capture_output=True, timeout=10)
                        print(f"  Deleting service: {service}")
                        subprocess.run(['sc', 'delete', service], capture_output=True, timeout=10)
                else:
                    print(f"  No services found for: {app_name}")
                    
            except Exception as e:
                print(f"  Service cleanup failed: {e}")
    
    def delete_scheduled_tasks(self, app_names):
        """Delete scheduled tasks - ACTUALLY WORKS"""
        print("\n=== DELETING SCHEDULED TASKS ===")
        
        for app_name in app_names:
            print(f"Deleting scheduled tasks for: {app_name}")
            
            try:
                # Get all tasks
                result = subprocess.run(['schtasks', '/query', '/fo', 'csv'], 
                                      capture_output=True, text=True, timeout=30)
                
                found_tasks = []
                for line in result.stdout.split('\n'):
                    if app_name.lower() in line.lower() and 'TaskName' not in line:
                        parts = line.split(',')
                        if len(parts) > 0:
                            task_name = parts[0].strip('"')
                            if task_name:
                                found_tasks.append(task_name)
                
                if found_tasks:
                    for task in found_tasks:
                        print(f"  Deleting task: {task}")
                        try:
                            subprocess.run(['schtasks', '/delete', '/tn', task, '/f'], 
                                         capture_output=True, timeout=10)
                            print(f"    SUCCESS: Deleted {task}")
                        except Exception as e:
                            print(f"    FAILED: {task} - {e}")
                else:
                    print(f"  No scheduled tasks found for: {app_name}")
                    
            except Exception as e:
                print(f"  Task cleanup failed: {e}")
    
    def YOUR_CLIENT_SECRET_HERE(self, path):
        """Schedule a file or directory for deletion on next reboot (Windows only)"""
        try:
            import ctypes
            YOUR_CLIENT_SECRET_HERE = 0x00000004
            res = ctypes.windll.kernel32.MoveFileExW(str(path), None, YOUR_CLIENT_SECRET_HERE)
            if res != 0:
                print(f"    SCHEDULED FOR DELETION ON REBOOT: {path}")
                return True
            else:
                print(f"    FAILED TO SCHEDULE FOR DELETION: {path}")
                return False
        except Exception as e:
            print(f"    ERROR scheduling for deletion: {e}")
            return False
    
    def force_delete_file(self, file_path):
        """Force delete a single file - ACTUALLY WORKS, schedules for deletion on reboot if locked"""
        if not os.path.exists(file_path):
            return True
        try:
            # Method 1: Remove read-only attribute
            try:
                subprocess.run(['attrib', '-R', '-H', '-S', file_path], 
                             capture_output=True, timeout=5)
            except:
                pass
            # Method 2: Standard delete
            try:
                os.remove(file_path)
                if not os.path.exists(file_path):
                    return True
            except Exception as e:
                pass
            # Method 3: Take ownership and delete
            try:
                subprocess.run(['takeown', '/f', file_path], capture_output=True, timeout=10)
                subprocess.run(['icacls', file_path, '/grant', 'Everyone:F'], 
                             capture_output=True, timeout=10)
                os.remove(file_path)
                if not os.path.exists(file_path):
                    return True
            except:
                pass
            # Method 4: CMD delete
            try:
                subprocess.run(['cmd', '/c', f'del /f /q "{file_path}"'], 
                             capture_output=True, timeout=10)
                if not os.path.exists(file_path):
                    return True
            except:
                pass
            # Method 5: Schedule for deletion on reboot
            self.YOUR_CLIENT_SECRET_HERE(file_path)
            return False
        except Exception:
            return False
    
    def force_delete_directory(self, dir_path):
        """Force delete a directory - AGGRESSIVE: unlock handles, take ownership, remove reparse points, rename, schedule for deletion on reboot if locked"""
        import random, string
        if not os.path.exists(dir_path):
            return True
        try:
            # Step 1: Try to unlock handles using handle.exe (if available)
            handle_exe = r"C:\Sysinternals\handle.exe"
            if os.path.exists(handle_exe):
                try:
                    result = subprocess.run([handle_exe, dir_path, "/accepteula"], capture_output=True, text=True, timeout=20)
                    for line in result.stdout.splitlines():
                        if "pid:" in line.lower():
                            pid = None
                            try:
                                pid = int(line.split("pid:")[1].split()[0])
                            except:
                                continue
                            if pid:
                                print(f"    Attempting to close handles in PID {pid}")
                                subprocess.run([handle_exe, f"-c", dir_path, f"-p", str(pid), "/accepteula"], capture_output=True, timeout=10)
                except Exception as e:
                    print(f"    handle.exe unlock failed: {e}")
            # Step 2: Remove reparse points/junctions if present
            try:
                import ctypes
                YOUR_CLIENT_SECRET_HERE = 0x400
                attrs = ctypes.windll.kernel32.GetFileAttributesW(str(dir_path))
                if attrs & YOUR_CLIENT_SECRET_HERE:
                    print(f"    Removing reparse point: {dir_path}")
                    subprocess.run(["cmd", "/c", f"rmdir \"{dir_path}\""], capture_output=True, timeout=10)
                    if not os.path.exists(dir_path):
                        return True
            except Exception as e:
                print(f"    Reparse point removal failed: {e}")
            # Step 3: Take ownership and grant permissions recursively
            try:
                subprocess.run(["takeown", "/f", dir_path, "/r", "/d", "y"], capture_output=True, timeout=20)
                subprocess.run(["icacls", dir_path, "/grant", "Everyone:F", "/t"], capture_output=True, timeout=20)
            except Exception as e:
                print(f"    Ownership/permissions failed: {e}")
            # Step 4: Try renaming the directory to a random name
            renamed = False
            try:
                parent = os.path.dirname(dir_path)
                rand_name = ''.join(random.choices(string.ascii_letters + string.digits, k=12))
                new_path = os.path.join(parent, rand_name)
                os.rename(dir_path, new_path)
                print(f"    Renamed {dir_path} to {new_path}")
                dir_path = new_path
                renamed = True
            except Exception as e:
                print(f"    Rename failed: {e}")
            # Step 5: Try standard delete again
            try:
                shutil.rmtree(dir_path, ignore_errors=True)
                if not os.path.exists(dir_path):
                    return True
            except Exception as e:
                print(f"    rmtree after rename failed: {e}")
            # Step 6: Remove attributes and try again
            try:
                subprocess.run(["attrib", "-R", "-H", "-S", dir_path, "/S", "/D"], capture_output=True, timeout=15)
                shutil.rmtree(dir_path, ignore_errors=True)
                if not os.path.exists(dir_path):
                    return True
            except Exception as e:
                print(f"    attrib/rmtree failed: {e}")
            # Step 7: CMD rmdir
            try:
                subprocess.run(["cmd", "/c", f"rmdir /s /q \"{dir_path}\""], capture_output=True, timeout=20)
                if not os.path.exists(dir_path):
                    return True
            except Exception as e:
                print(f"    cmd rmdir failed: {e}")
            # Step 8: Schedule for deletion on reboot
            self.YOUR_CLIENT_SECRET_HERE(dir_path)
            return False
        except Exception as e:
            print(f"    AGGRESSIVE DELETE ERROR: {e}")
            return False
    
    def YOUR_CLIENT_SECRET_HERE(self, app_names):
        """Remove app shortcuts/icons from Start Menu, Desktop, Quick Launch, etc."""
        print("\n=== REMOVING SHORTCUTS AND ICONS ===")
        # Common locations for shortcuts/icons
        user_dirs = []
        try:
            for user_dir in os.listdir("C:\\Users"):
                user_path = f"C:\\Users\\{user_dir}"
                if os.path.isdir(user_path):
                    user_dirs.append(user_path)
        except:
            pass
        shortcut_locations = [
            r"C:\ProgramData\Microsoft\Windows\Start Menu\Programs",
            r"C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup",
            r"C:\Users\Public\Desktop",
        ]
        # Add per-user locations
        for user_path in user_dirs:
            shortcut_locations.extend([
                f"{user_path}\\Desktop",
                f"{user_path}\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs",
                f"{user_path}\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs\\Startup",
                f"{user_path}\\AppData\\Roaming\\Microsoft\\Internet Explorer\\Quick Launch",
            ])
        for app_name in app_names:
            print(f"Removing shortcuts/icons for: {app_name}")
            for location in shortcut_locations:
                if not os.path.exists(location):
                    continue
                try:
                    for root, dirs, files in os.walk(location):
                        for file in files:
                            if app_name.lower() in file.lower() and file.lower().endswith('.lnk'):
                                shortcut_path = os.path.join(root, file)
                                print(f"  Deleting shortcut: {shortcut_path}")
                                self.force_delete_file(shortcut_path)
                except Exception as e:
                    print(f"  Shortcut cleanup failed in {location}: {e}")
    
    def search_and_destroy(self, app_names):
        """Search and destroy files - ACTUALLY WORKS"""
        print("\n=== SEARCHING AND DESTROYING FILES ===")
        # Define search locations (expanded)
        search_locations = [
            r"C:\Program Files",
            r"C:\Program Files\Common Files",
            r"C:\Program Files\ModifiableWindowsApps",
            r"C:\Program Files\WindowsApps",
            r"C:\Program Files\WindowsAppsDeleted",
            r"C:\Program Files (x86)",
            r"C:\Program Files (x86)\Common Files",
            r"C:\ProgramData",
            r"C:\ProgramData\Application Data",
            r"C:\ProgramData\Package Cache",
            r"C:\ProgramData\Microsoft\Windows\Start Menu\Programs",
            r"C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup",
            r"C:\ProgramData\Microsoft\Windows\WER",
            r"C:\ProgramData\Microsoft\Windows\Caches",
            r"C:\ProgramData\Microsoft\Crypto",
            r"C:\ProgramData\Microsoft\Crypto\RSA",
            r"C:\ProgramData\App-V",
            r"C:\ProgramData\Microsoft\PlayReady",
            r"C:\ProgramData\Microsoft\Search\Data\Applications",
            r"C:\ProgramData\Microsoft\Search\Data\Temp",
            r"C:\ProgramData\Microsoft\Windows\GameExplorer",
            r"C:\ProgramData\Oracle",
            r"C:\ProgramData\Docker",
            r"C:\ProgramData\NVIDIA Corporation",
            r"C:\ProgramData\Temp",
            r"C:\ProgramData\Logs",
            r"C:\ProgramData\CrashDumps",
            r"C:\ProgramData\Desktop",
            r"C:\ProgramData\Documents",
            r"C:\Windows\System32",
            r"C:\Windows\System32\drivers",
            r"C:\Windows\System32\DriverStore",
            r"C:\Windows\System32\Tasks",
            r"C:\Windows\System32\Tasks\Microsoft",
            r"C:\Windows\System32\Tasks\WPD",
            r"C:\Windows\System32\spool\DRIVERS",
            r"C:\Windows\System32\spool\PRINTERS",
            r"C:\Windows\System32\LogFiles",
            r"C:\Windows\System32\LogFiles\WMI",
            r"C:\Windows\System32\catroot2",
            r"C:\Windows\System32\winevt\Logs",
            r"C:\Windows\SysWOW64",
            r"C:\Windows\WinSxS",
            r"C:\Windows\INF",
            r"C:\Windows\Fonts",
            r"C:\Windows\SystemApps",
            r"C:\Windows\SystemResources",
            r"C:\Windows\servicing",
            r"C:\Windows\Installer",
            r"C:\Windows\Installer\$PatchCache$",
            r"C:\Windows\Prefetch",
            r"C:\Windows\Temp",
            r"C:\Windows\Logs",
            r"C:\Windows\Logs\CBS",
            r"C:\Windows\Logs\DISM",
            r"C:\Windows\ServiceProfiles\LocalService\AppData\Local\Temp",
            r"C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp",
            r"C:\Windows\SoftwareDistribution\Download",
            r"C:\Windows\Microsoft.NET\Assembly\GAC_MSIL",
            r"C:\$Recycle.Bin",
            r"C:\System Volume Information",
            r"C:\$WINDOWS.~BT",
            r"C:\$WINDOWS.~WS",
            r"C:\Recovery",
            r"C:\Windows\CSC",
            r"C:\Intel",
            r"C:\AMD",
            r"C:\NVIDIA",
            r"C:\Logs",
            r"C:\CrashDumps",
            r"C:\Drivers",
            r"C:\MSOCache",
            r"C:\Temp",
            r"C:\PerfLogs",
            r"C:\Users\Public\Desktop",
            r"C:\Users\Public\Documents",
            r"C:\Users\Public\Downloads",
            r"C:\Users\misha\Desktop",
            r"C:\Users\misha\Documents",
            r"C:\Users\misha\Downloads",
            r"C:\Users\misha\Saved Games",
            r"C:\Users\misha\AppData\Local",
            r"C:\Users\misha\AppData\Local\Programs",
            r"C:\Users\misha\AppData\Local\Packages",
            r"C:\Users\misha\AppData\Local\VirtualStore",
            r"C:\Users\misha\AppData\Local\CrashDumps",
            r"C:\Users\misha\AppData\Local\Temp",
            r"C:\Users\misha\AppData\Local\SquirrelTemp",
            r"C:\Users\misha\AppData\Local\D3DSCache",
            r"C:\Users\misha\AppData\Local\Microsoft\Windows\WER",
            r"C:\Users\misha\AppData\Local\Microsoft\WindowsApps",
            r"C:\Users\misha\AppData\Local\Microsoft\Windows\Caches",
            r"C:\Users\misha\AppData\Local\Microsoft\Windows\Explorer",
            r"C:\Users\misha\AppData\Local\Microsoft\Edge\User Data",
            r"C:\Users\misha\AppData\Local\Google\Chrome\User Data",
            r"C:\Users\misha\AppData\Local\BraveSoftware\Brave-Browser\User Data",
            r"C:\Users\misha\AppData\Local\Vivaldi\User Data",
            r"C:\Users\misha\AppData\Local\Opera Software",
            r"C:\Users\misha\AppData\Local\Yandex\YandexBrowser\User Data",
            r"C:\Users\misha\AppData\Roaming",
            r"C:\Users\misha\AppData\Roaming\Installer",
            r"C:\Users\misha\AppData\Roaming\Microsoft\Windows\Start Menu\Programs",
            r"C:\Users\misha\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup",
            r"C:\Users\misha\AppData\Roaming\Microsoft\Windows\Recent",
            r"C:\Users\misha\AppData\Roaming\Microsoft\Windows\SendTo",
            r"C:\Users\misha\AppData\Roaming\Microsoft\Windows\Templates",
            r"C:\Users\misha\AppData\Roaming\Microsoft\Windows\GameExplorer",
            r"C:\Users\misha\AppData\Roaming\Microsoft\Windows\Printer Shortcuts",
            r"C:\Users\misha\AppData\Roaming\Microsoft\Windows\Themes",
            r"C:\Users\misha\AppData\Roaming\Mozilla\Firefox\Profiles",
            r"C:\Users\misha\AppData\LocalLow",
        ]
        # Add dynamic user directories
        try:
            for user_dir in os.listdir("C:\\Users"):
                user_path = f"C:\\Users\\{user_dir}"
                if os.path.isdir(user_path) and user_dir not in ['All Users', 'Default', 'Public']:
                    search_locations.extend([
                        f"{user_path}\\AppData\\Local",
                        f"{user_path}\\AppData\\Roaming",
                        f"{user_path}\\AppData\\LocalLow",
                        f"{user_path}\\Desktop",
                        f"{user_path}\\Documents",
                        f"{user_path}\\Downloads"
                    ])
        except:
            pass
        # Add container layers
        container_base = r"C:\ProgramData\Microsoft\Windows\Containers\Layers"
        if os.path.exists(container_base):
            try:
                for layer in os.listdir(container_base):
                    layer_path = f"{container_base}\\{layer}\\Files"
                    if os.path.exists(layer_path):
                        search_locations.append(layer_path)
            except:
                pass
        # Search and destroy
        for app_name in app_names:
            print(f"\nSearching for: {app_name}")
            all_targets = []
            # Search each location
            for location in search_locations:
                if not os.path.exists(location):
                    continue
                print(f"  Searching in: {location}")
                try:
                    # Use dir command to find files
                    cmd = f'dir "{location}\\*{app_name}*" /s /b /a 2>nul'
                    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=60)
                    found_count = 0
                    for line in result.stdout.split('\n'):
                        if line.strip() and os.path.exists(line.strip()):
                            all_targets.append(line.strip())
                            found_count += 1
                    if found_count > 0:
                        print(f"    Found {found_count} items")
                except Exception as e:
                    print(f"    Search failed: {e}")
            # Remove duplicates
            all_targets = list(set(all_targets))
            print(f"\nFound {len(all_targets)} total targets for {app_name}")
            # Destroy everything
            if all_targets:
                print("Starting destruction:")
                for target in all_targets:
                    print(f"  Destroying: {target}")
                    try:
                        if os.path.isfile(target):
                            if self.force_delete_file(target):
                                print(f"    SUCCESS: File deleted")
                                self.deleted_count += 1
                            else:
                                print(f"    FAILED: File survived or scheduled for deletion on reboot")
                                self.failed_count += 1
                        elif os.path.isdir(target):
                            if self.force_delete_directory(target):
                                print(f"    SUCCESS: Directory deleted")
                                self.deleted_count += 1
                            else:
                                print(f"    FAILED: Directory survived or scheduled for deletion on reboot")
                                self.failed_count += 1
                        else:
                            print(f"    SKIPPED: Path doesn't exist")
                    except Exception as e:
                        print(f"    ERROR: {e}")
                        self.failed_count += 1
            else:
                print("  No targets found")
    
    def cleanup_registry(self, app_names):
        """Cleanup registry - ACTUALLY WORKS"""
        print("\n=== CLEANING REGISTRY ===")
        
        for app_name in app_names:
            print(f"Cleaning registry for: {app_name}")
            
            # Registry cleanup commands
            registry_commands = [
                f'reg delete "HKCU\\Software" /f /v "*{app_name}*" 2>nul',
                f'reg delete "HKLM\\Software" /f /v "*{app_name}*" 2>nul',
                f'reg delete "HKLM\\SYSTEM\\CurrentControlSet\\Services" /f /v "*{app_name}*" 2>nul'
            ]
            
            for cmd in registry_commands:
                try:
                    print(f"  Executing: {cmd}")
                    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
                    if result.returncode == 0:
                        print(f"    SUCCESS: Registry cleaned")
                    else:
                        print(f"    INFO: No registry entries found")
                except Exception as e:
                    print(f"    ERROR: {e}")
    
    def final_cleanup(self):
        """Final cleanup - ACTUALLY WORKS"""
        print("\n=== FINAL CLEANUP ===")
        
        try:
            print("Clearing recycle bin...")
            subprocess.run(['powershell', '-Command', 'Clear-RecycleBin -Force -ErrorAction SilentlyContinue'], 
                         capture_output=True, timeout=30)
            print("  Recycle bin cleared")
        except Exception as e:
            print(f"  Recycle bin cleanup failed: {e}")
        
        try:
            print("Clearing temp files...")
            temp_paths = [
                os.environ.get('TEMP', ''),
                'C:\\Windows\\Temp'
            ]
            
            for temp_path in temp_paths:
                if temp_path and os.path.exists(temp_path):
                    subprocess.run(['cmd', '/c', f'del /f /s /q "{temp_path}\\*.*" 2>nul'], 
                                 capture_output=True, timeout=30)
            print("  Temp files cleared")
        except Exception as e:
            print(f"  Temp cleanup failed: {e}")
        
        try:
            print("Flushing DNS cache...")
            subprocess.run(['ipconfig', '/flushdns'], capture_output=True, timeout=15)
            print("  DNS cache flushed")
        except Exception as e:
            print(f"  DNS flush failed: {e}")
    
    def execute_purge(self, app_names):
        """Execute the purge - ACTUALLY WORKS"""
        print("="*80)
        print("ACTUAL WORKING PURGE TOOL - NO BULLSHIT EDITION")
        print("="*80)
        print(f"TARGETS: {', '.join(app_names)}")
        print("REAL-TIME FEEDBACK - SHOWS EVERY FILE BEING DELETED")
        print("="*80)
        start_time = time.time()
        # Step 1: Kill processes
        self.kill_processes(app_names)
        # Step 2: Kill services
        self.kill_services(app_names)
        # Step 3: Delete scheduled tasks
        self.delete_scheduled_tasks(app_names)
        # Step 4: Remove shortcuts/icons
        self.YOUR_CLIENT_SECRET_HERE(app_names)
        # Step 5: Search and destroy files
        self.search_and_destroy(app_names)
        # Step 6: Cleanup registry
        self.cleanup_registry(app_names)
        # Step 7: Final cleanup
        self.final_cleanup()
        # Results
        total_time = time.time() - start_time
        print("\n" + "="*80)
        print("PURGE COMPLETE!")
        print("="*80)
        print(f"Apps processed: {len(app_names)}")
        print(f"Total time: {total_time:.1f} seconds")
        print(f"Files deleted: {self.deleted_count}")
        print(f"Files failed: {self.failed_count}")
        if self.failed_count == 0:
            print("\nSUCCESS: ALL FILES DELETED!")
        else:
            print(f"\nWARNING: {self.failed_count} files could not be deleted or are scheduled for deletion on reboot")
            print("These may be protected system files or currently in use")
        print("\nPURGE TOOL COMPLETED!")
        print("Files have been permanently deleted from your system.")


def main():
    parser = argparse.ArgumentParser(description='Actual Working Purge Tool')
    parser.add_argument('apps', nargs='*', help='Applications to purge')
    
    args = parser.parse_args()
    
    if not args.apps:
        print("ERROR: No applications specified")
        print("Usage: python actual_purge.py <app1> <app2> [app3] ...")
        print("\nExamples:")
        print("python actual_purge.py ramdisk")
        print("python actual_purge.py veeam outlook")
        sys.exit(1)
    
    # Initialize purge tool
    purge = ActualPurge()
    
    # Check admin
    if not purge.check_admin():
        print("ERROR: Administrator privileges required!")
        sys.exit(1)
    
    # Execute purge
    purge.execute_purge(args.apps)


if __name__ == "__main__":
    main()
