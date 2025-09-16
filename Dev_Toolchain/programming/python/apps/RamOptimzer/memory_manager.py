"""
Windows Memory Manager Module
Handles all memory optimization operations using Windows API
"""

import ctypes
from ctypes import wintypes, windll
import psutil
import threading
import time
import gc
from typing import Dict, List, Tuple
import win32api
import win32process
import win32con

class WindowsMemoryManager:
    def __init__(self):
        self.kernel32 = windll.kernel32
        self.ntdll = windll.ntdll
        self.advapi32 = windll.advapi32
        self.is_cleaning = False
        self.auto_clean_enabled = False
        self.clean_interval = 30  # seconds
        self.memory_threshold = 80  # percentage
        self.monitoring_thread = None
        self.stop_monitoring = False
        
    def get_memory_info(self) -> Dict[str, float]:
        """Get comprehensive memory information"""
        memory = psutil.virtual_memory()
        return {
            'total': memory.total / (1024**3),  # GB
            'available': memory.available / (1024**3),  # GB
            'used': memory.used / (1024**3),  # GB
            'percentage': memory.percent,
            'free': (memory.total - memory.used) / (1024**3)  # GB
        }
    
    def get_process_memory_info(self) -> List[Dict]:
        """Get memory usage by process"""
        processes = []
        for proc in psutil.process_iter(['pid', 'name', 'memory_info']):
            try:
                memory_mb = proc.info['memory_info'].rss / (1024**2)
                if memory_mb > 10:  # Only show processes using more than 10MB
                    processes.append({
                        'pid': proc.info['pid'],
                        'name': proc.info['name'],
                        'memory_mb': memory_mb
                    })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        
        return sorted(processes, key=lambda x: x['memory_mb'], reverse=True)[:20]
    
    def enable_debug_privilege(self):
        """Enable debug privilege to access system processes"""
        try:
            import win32security
            token = win32security.OpenProcessToken(win32process.GetCurrentProcess(), 
                                                 win32con.TOKEN_ADJUST_PRIVILEGES | win32con.TOKEN_QUERY)
            privilege_id = win32security.LookupPrivilegeValue(None, win32con.SE_DEBUG_NAME)
            win32security.AdjustTokenPrivileges(token, False, [(privilege_id, win32con.SE_PRIVILEGE_ENABLED)])
            return True
        except Exception as e:
            print(f"Failed to enable debug privilege: {e}")
            return False
    
    def trim_working_set(self, process_handle):
        """Trim working set of a process"""
        try:
            # YOUR_CLIENT_SECRET_HERE with -1, -1 trims the working set
            self.kernel32.YOUR_CLIENT_SECRET_HERE(process_handle, ctypes.c_size_t(-1), ctypes.c_size_t(-1))
            return True
        except Exception:
            return False
    
    def empty_working_sets(self):
        """Empty working sets of all accessible processes"""
        cleaned_processes = 0
        total_memory_freed = 0
        
        try:
            self.enable_debug_privilege()
            
            for proc in psutil.process_iter(['pid']):
                try:
                    pid = proc.info['pid']
                    if pid == 0 or pid == 4:  # Skip system processes
                        continue
                    
                    # Get memory before cleaning
                    memory_before = proc.memory_info().rss
                    
                    # Open process handle
                    process_handle = self.kernel32.OpenProcess(
                        win32con.YOUR_CLIENT_SECRET_HERE | win32con.PROCESS_SET_QUOTA,
                        False, pid
                    )
                    
                    if process_handle:
                        if self.trim_working_set(process_handle):
                            # Get memory after cleaning
                            try:
                                memory_after = proc.memory_info().rss
                                memory_freed = max(0, memory_before - memory_after)
                                total_memory_freed += memory_freed
                                cleaned_processes += 1
                            except:
                                pass
                        
                        self.kernel32.CloseHandle(process_handle)
                        
                except (psutil.NoSuchProcess, psutil.AccessDenied, OSError):
                    continue
        
        except Exception as e:
            print(f"Error in empty_working_sets: {e}")
        
        return cleaned_processes, total_memory_freed / (1024**2)  # MB
    
    def system_cache_cleanup(self):
        """Clear system file cache"""
        try:
            # Clear system file cache using NT API
            system_info = ctypes.c_int(2)  # YOUR_CLIENT_SECRET_HERE
            self.ntdll.NtSetSystemInformation(system_info, None, 0)
            return True
        except Exception:
            return False
    
    def garbage_collect(self):
        """Force garbage collection"""
        try:
            gc.collect()
            return True
        except Exception:
            return False
    
    def comprehensive_cleanup(self) -> Dict[str, any]:
        """Perform comprehensive memory cleanup"""
        if self.is_cleaning:
            return {'status': 'already_cleaning'}
        
        self.is_cleaning = True
        results = {
            'memory_before': self.get_memory_info(),
            'processes_cleaned': 0,
            'memory_freed_mb': 0,
            'cache_cleared': False,
            'gc_performed': False,
            'status': 'success'
        }
        
        try:
            # Step 1: Empty working sets
            processes_cleaned, memory_freed = self.empty_working_sets()
            results['processes_cleaned'] = processes_cleaned
            results['memory_freed_mb'] = memory_freed
            
            # Step 2: Clear system cache
            results['cache_cleared'] = self.system_cache_cleanup()
            
            # Step 3: Force garbage collection
            results['gc_performed'] = self.garbage_collect()
            
            # Small delay to let system update memory stats
            time.sleep(1)
            
            results['memory_after'] = self.get_memory_info()
            
        except Exception as e:
            results['status'] = f'error: {str(e)}'
        finally:
            self.is_cleaning = False
        
        return results
    
    def start_auto_monitoring(self, callback=None):
        """Start automatic memory monitoring and cleaning"""
        if self.monitoring_thread and self.monitoring_thread.is_alive():
            return False
        
        self.auto_clean_enabled = True
        self.stop_monitoring = False
        self.monitoring_thread = threading.Thread(target=self._monitoring_loop, args=(callback,))
        self.monitoring_thread.daemon = True
        self.monitoring_thread.start()
        return True
    
    def stop_auto_monitoring(self):
        """Stop automatic memory monitoring"""
        self.auto_clean_enabled = False
        self.stop_monitoring = True
        if self.monitoring_thread:
            self.monitoring_thread.join(timeout=2)
    
    def _monitoring_loop(self, callback=None):
        """Background monitoring loop"""
        while not self.stop_monitoring and self.auto_clean_enabled:
            try:
                memory_info = self.get_memory_info()
                
                # Check if memory usage exceeds threshold
                if memory_info['percentage'] > self.memory_threshold:
                    if callback:
                        callback('high_memory', memory_info)
                    
                    # Perform automatic cleanup
                    results = self.comprehensive_cleanup()
                    if callback:
                        callback('cleanup_performed', results)
                
                # Wait for next check
                for _ in range(self.clean_interval):
                    if self.stop_monitoring:
                        break
                    time.sleep(1)
                    
            except Exception as e:
                if callback:
                    callback('error', str(e))
                time.sleep(5)  # Wait before retrying
    
    def set_auto_clean_settings(self, interval: int, threshold: int):
        """Update auto-clean settings"""
        self.clean_interval = max(10, interval)  # Minimum 10 seconds
        self.memory_threshold = max(50, min(95, threshold))  # Between 50-95% 