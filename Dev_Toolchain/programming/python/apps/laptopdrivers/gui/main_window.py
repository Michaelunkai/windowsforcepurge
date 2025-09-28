"""
GUI Main Window for Laptop Driver Updater
Modern tkinter-based interface with progress tracking and detailed information.
"""

import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import asyncio
import threading
import datetime
from typing import Dict, Optional
import logging
from pathlib import Path

class DriverUpdaterGUI:
    """Main GUI window for the laptop driver updater."""
    
    def __init__(self, driver_updater):
        self.driver_updater = driver_updater
        self.logger = logging.getLogger(__name__)
        
        # GUI state
        self.root = None
        self.hardware_info = {}
        self.available_updates = {}
        self.selected_updates = set()
        self.is_scanning = False
        self.is_installing = False
        
        # GUI components
        self.progress_var = None
        self.status_var = None
        self.log_text = None
        self.hardware_tree = None
        self.updates_tree = None
        self.progress_label = None
        self.current_task_var = None
        self.overall_progress_var = None
        
    def create_gui(self):
        """Create the main GUI window."""
        self.root = tk.Tk()
        self.root.title("Laptop Driver Updater")
        self.root.geometry("1000x700")
        self.root.minsize(800, 600)
        
        # Configure style
        style = ttk.Style()
        style.theme_use('clam')
        
        # Create main notebook for tabs
        notebook = ttk.Notebook(self.root)
        notebook.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # Create tabs
        self._create_hardware_tab(notebook)
        self._create_updates_tab(notebook)
        self._create_logs_tab(notebook)
        
        # Create status bar
        self._create_status_bar()
        
        # Start hardware detection automatically after a short delay
        self.root.after(1000, self._start_hardware_detection)
    
    def _create_hardware_tab(self, parent):
        """Create the hardware information tab."""
        hardware_frame = ttk.Frame(parent)
        parent.add(hardware_frame, text="Hardware Info")
        
        # Title
        title_label = ttk.Label(hardware_frame, text="Detected Hardware", 
                               font=('Arial', 14, 'bold'))
        title_label.pack(pady=10)
        
        # Hardware tree
        tree_frame = ttk.Frame(hardware_frame)
        tree_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        # Treeview for hardware info
        columns = ('Component', 'Details')
        self.hardware_tree = ttk.Treeview(tree_frame, columns=columns, show='tree headings')
        
        # Configure columns
        self.hardware_tree.heading('#0', text='Category')
        self.hardware_tree.heading('Component', text='Component')
        self.hardware_tree.heading('Details', text='Details')
        
        self.hardware_tree.column('#0', width=150)
        self.hardware_tree.column('Component', width=300)
        self.hardware_tree.column('Details', width=400)
        
        # Scrollbars
        v_scroll = ttk.Scrollbar(tree_frame, orient=tk.VERTICAL, command=self.hardware_tree.yview)
        h_scroll = ttk.Scrollbar(tree_frame, orient=tk.HORIZONTAL, command=self.hardware_tree.xview)
        self.hardware_tree.configure(yscrollcommand=v_scroll.set, xscrollcommand=h_scroll.set)
        
        # Pack treeview and scrollbars
        self.hardware_tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        v_scroll.pack(side=tk.RIGHT, fill=tk.Y)
        h_scroll.pack(side=tk.BOTTOM, fill=tk.X)
        
        # Refresh button
        refresh_btn = ttk.Button(hardware_frame, text="Refresh Hardware Info", 
                                command=self._start_hardware_detection)
        refresh_btn.pack(pady=10)
    
    def _create_updates_tab(self, parent):
        """Create the driver updates tab."""
        updates_frame = ttk.Frame(parent)
        parent.add(updates_frame, text="Driver Updates")
        
        # Title and scan button
        top_frame = ttk.Frame(updates_frame)
        top_frame.pack(fill=tk.X, padx=10, pady=10)
        
        title_label = ttk.Label(top_frame, text="Available Driver Updates", 
                               font=('Arial', 14, 'bold'))
        title_label.pack(side=tk.LEFT)
        
        scan_btn = ttk.Button(top_frame, text="Scan for Updates", 
                             command=self._start_update_scan)
        scan_btn.pack(side=tk.RIGHT)
        
        # Updates tree
        tree_frame = ttk.Frame(updates_frame)
        tree_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        columns = ('Component', 'Current Version', 'Latest Version', 'Status')
        self.updates_tree = ttk.Treeview(tree_frame, columns=columns, show='tree headings')
        
        # Configure columns
        self.updates_tree.heading('#0', text='Category')
        self.updates_tree.heading('Component', text='Component')
        self.updates_tree.heading('Current Version', text='Current Version')
        self.updates_tree.heading('Latest Version', text='Latest Version')
        self.updates_tree.heading('Status', text='Status')
        
        self.updates_tree.column('#0', width=100)
        self.updates_tree.column('Component', width=250)
        self.updates_tree.column('Current Version', width=150)
        self.updates_tree.column('Latest Version', width=150)
        self.updates_tree.column('Status', width=100)
        
        # Scrollbars for updates tree
        v_scroll2 = ttk.Scrollbar(tree_frame, orient=tk.VERTICAL, command=self.updates_tree.yview)
        h_scroll2 = ttk.Scrollbar(tree_frame, orient=tk.HORIZONTAL, command=self.updates_tree.xview)
        self.updates_tree.configure(yscrollcommand=v_scroll2.set, xscrollcommand=h_scroll2.set)
        
        # Pack updates tree and scrollbars
        self.updates_tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        v_scroll2.pack(side=tk.RIGHT, fill=tk.Y)
        h_scroll2.pack(side=tk.BOTTOM, fill=tk.X)
        
        # Bottom frame for buttons
        bottom_frame = ttk.Frame(updates_frame)
        bottom_frame.pack(fill=tk.X, padx=10, pady=10)
        
        # Selection buttons
        select_all_btn = ttk.Button(bottom_frame, text="Select All", 
                                   command=self._select_all_updates)
        select_all_btn.pack(side=tk.LEFT, padx=5)
        
        select_none_btn = ttk.Button(bottom_frame, text="Select None", 
                                    command=self._select_no_updates)
        select_none_btn.pack(side=tk.LEFT, padx=5)
        
        # Install button
        install_btn = ttk.Button(bottom_frame, text="Install Selected Updates", 
                                command=self._start_installation, 
                                style='Accent.TButton')
        install_btn.pack(side=tk.RIGHT, padx=5)
    
    def _create_logs_tab(self, parent):
        """Create the logs tab."""
        logs_frame = ttk.Frame(parent)
        parent.add(logs_frame, text="Logs")
        
        # Title
        title_label = ttk.Label(logs_frame, text="Application Logs", 
                               font=('Arial', 14, 'bold'))
        title_label.pack(pady=10)
        
        # Log text area
        self.log_text = scrolledtext.ScrolledText(logs_frame, wrap=tk.WORD, 
                                                 height=25, font=('Consolas', 9))
        self.log_text.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        # Clear logs button
        clear_btn = ttk.Button(logs_frame, text="Clear Logs", 
                              command=self._clear_logs)
        clear_btn.pack(pady=10)
    
    def _create_status_bar(self):
        """Create the status bar at the bottom."""
        status_frame = ttk.Frame(self.root)
        status_frame.pack(fill=tk.X, side=tk.BOTTOM)
        
        # Current task label
        self.current_task_var = tk.StringVar(value="Ready")
        task_label = ttk.Label(status_frame, textvariable=self.current_task_var, font=('Arial', 9, 'bold'))
        task_label.pack(side=tk.LEFT, padx=10, pady=5)
        
        # Status label (detailed info)
        self.status_var = tk.StringVar(value="")
        status_label = ttk.Label(status_frame, textvariable=self.status_var, font=('Arial', 8))
        status_label.pack(side=tk.LEFT, padx=(0, 10), pady=5)
        
        # Progress info frame
        progress_frame = ttk.Frame(status_frame)
        progress_frame.pack(side=tk.RIGHT, padx=10, pady=5)
        
        # Progress label
        self.progress_label = ttk.Label(progress_frame, text="", font=('Arial', 8))
        self.progress_label.pack(side=tk.TOP)
        
        # Overall progress bar
        self.overall_progress_var = tk.DoubleVar()
        overall_progress_bar = ttk.Progressbar(progress_frame, variable=self.overall_progress_var, 
                                              mode='determinate', length=250)
        overall_progress_bar.pack(side=tk.TOP, pady=(2, 0))
        
        # Current task progress bar
        self.progress_var = tk.DoubleVar()
        current_progress_bar = ttk.Progressbar(progress_frame, variable=self.progress_var, 
                                              mode='determinate', length=250)
        current_progress_bar.pack(side=tk.TOP, pady=(2, 0))
    
    def _update_hardware_tree(self):
        """Update the hardware information tree."""
        # Clear existing items
        for item in self.hardware_tree.get_children():
            self.hardware_tree.delete(item)
        
        if not self.hardware_info:
            self.hardware_tree.insert('', 'end', text='No hardware detected', 
                                     values=('', 'Hardware detection failed'))
            return
        
        # Add ASUS laptop info
        if self.hardware_info.get('asus_model'):
            asus_node = self.hardware_tree.insert('', 'end', text='ASUS Laptop')
            self.hardware_tree.insert(asus_node, 'end', text='', 
                                     values=('Model', self.hardware_info['asus_model']))
        
        # Add NVIDIA GPU info
        if self.hardware_info.get('nvidia_gpu'):
            nvidia_node = self.hardware_tree.insert('', 'end', text='NVIDIA GPU')
            gpu_info = self.hardware_info['nvidia_gpu']
            self.hardware_tree.insert(nvidia_node, 'end', text='', 
                                     values=('Name', gpu_info.get('name', 'Unknown')))
            self.hardware_tree.insert(nvidia_node, 'end', text='', 
                                     values=('Driver Version', gpu_info.get('driver_version', 'Unknown')))
        
        # Add AMD CPU info
        if self.hardware_info.get('amd_cpu'):
            amd_cpu_node = self.hardware_tree.insert('', 'end', text='AMD CPU')
            cpu_info = self.hardware_info['amd_cpu']
            self.hardware_tree.insert(amd_cpu_node, 'end', text='', 
                                     values=('Name', cpu_info.get('name', 'Unknown')))
            self.hardware_tree.insert(amd_cpu_node, 'end', text='', 
                                     values=('Cores', str(cpu_info.get('cores', 'Unknown'))))
            self.hardware_tree.insert(amd_cpu_node, 'end', text='', 
                                     values=('Threads', str(cpu_info.get('threads', 'Unknown'))))
        
        # Add AMD GPU info
        if self.hardware_info.get('amd_gpu'):
            amd_gpu_node = self.hardware_tree.insert('', 'end', text='AMD GPU')
            gpu_info = self.hardware_info['amd_gpu']
            self.hardware_tree.insert(amd_gpu_node, 'end', text='', 
                                     values=('Name', gpu_info.get('name', 'Unknown')))
            self.hardware_tree.insert(amd_gpu_node, 'end', text='', 
                                     values=('Driver Version', gpu_info.get('driver_version', 'Unknown')))
        
        # Add system info
        if self.hardware_info.get('system_info'):
            system_node = self.hardware_tree.insert('', 'end', text='System Info')
            sys_info = self.hardware_info['system_info']
            for key, value in sys_info.items():
                if value:
                    self.hardware_tree.insert(system_node, 'end', text='', 
                                             values=(key.replace('_', ' ').title(), value))
        
        # Expand all nodes
        for item in self.hardware_tree.get_children():
            self.hardware_tree.item(item, open=True)
    
    def _update_updates_tree(self):
        """Update the driver updates tree."""
        # Clear existing items
        for item in self.updates_tree.get_children():
            self.updates_tree.delete(item)
        
        if not self.available_updates:
            self.updates_tree.insert('', 'end', text='No updates', 
                                    values=('No updates available', '', '', ''))
            return
        
        # Add updates by category
        for category, updates in self.available_updates.items():
            category_node = self.updates_tree.insert('', 'end', text=category.upper())
            
            if isinstance(updates, dict):
                if 'name' in updates:  # Single update
                    status = "Update Available" if updates.get('update_available', False) else "Up to Date"
                    self.updates_tree.insert(category_node, 'end', text='', 
                                           values=(updates.get('name', 'Unknown'),
                                                  updates.get('current_version', 'Unknown'),
                                                  updates.get('latest_version', 'Unknown'),
                                                  status))
                else:  # Multiple updates
                    for component, update_info in updates.items():
                        if isinstance(update_info, dict):
                            status = "Update Available" if update_info.get('update_available', False) else "Up to Date"
                            self.updates_tree.insert(category_node, 'end', text='', 
                                                   values=(update_info.get('name', component),
                                                          update_info.get('current_version', 'Unknown'),
                                                          update_info.get('latest_version', 'Unknown'),
                                                          status))
        
        # Expand all nodes
        for item in self.updates_tree.get_children():
            self.updates_tree.item(item, open=True)
    
    def _log_message(self, message: str, level: str = "INFO"):
        """Add a message to the log text area."""
        if self.log_text:
            timestamp = datetime.datetime.now().strftime("%H:%M:%S")
            log_entry = f"[{timestamp}] {level}: {message}\n"
            self.log_text.insert(tk.END, log_entry)
            self.log_text.see(tk.END)
    
    def _clear_logs(self):
        """Clear the log text area."""
        if self.log_text:
            self.log_text.delete(1.0, tk.END)
    
    def _update_progress(self, status_text: str, current_progress: float, overall_progress: float):
        """Update progress bars and status text."""
        self.status_var.set(status_text)
        self.progress_var.set(current_progress)
        self.overall_progress_var.set(overall_progress)
        
        # Update progress label
        if self.progress_label:
            self.progress_label.config(text=f"Overall: {overall_progress:.0f}% | Current: {current_progress:.0f}%")
        
        # Log the progress
        self._log_message(status_text, "PROGRESS")
        
        # Force GUI update
        self.root.update_idletasks()
    
    def _select_all_updates(self):
        """Select all available updates."""
        self.selected_updates = set(self.available_updates.keys())
    
    def _select_no_updates(self):
        """Deselect all updates."""
        self.selected_updates.clear()
    
    def _start_hardware_detection(self):
        """Start hardware detection in a separate thread."""
        if self.is_scanning:
            return
        
        self.is_scanning = True
        self.current_task_var.set("🔍 Detecting Hardware")
        self.status_var.set("Initializing hardware detection...")
        self.progress_var.set(0)
        self.overall_progress_var.set(0)
        if self.progress_label:
            self.progress_label.config(text="Starting hardware scan...")
        
        def detection_worker():
            try:
                # Update progress
                self.root.after(0, lambda: self._update_progress("Detecting ASUS laptop model...", 10, 10))
                
                # Run hardware detection with progress updates
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                
                # Initialize WMI first
                detector = self.driver_updater.hardware_detector
                self.root.after(0, lambda: self._update_progress("Initializing hardware detection...", 5, 5))
                loop.run_until_complete(detector.initialize_wmi())
                
                # Detect hardware step by step with progress updates
                self.root.after(0, lambda: self._update_progress("🏢 Detecting ASUS laptop model...", 10, 20))
                asus_model = loop.run_until_complete(detector.detect_asus_model())
                if asus_model:
                    self.root.after(0, lambda model=asus_model: self._update_progress(f"✅ Found ASUS: {model[:30]}...", 100, 20))
                else:
                    self.root.after(0, lambda: self._update_progress("⚠️ ASUS model not detected", 100, 20))
                
                self.root.after(0, lambda: self._update_progress("🎮 Detecting NVIDIA GPU...", 10, 40))
                nvidia_gpu = loop.run_until_complete(detector.detect_nvidia_gpu())
                if nvidia_gpu:
                    gpu_name = nvidia_gpu.get('name', 'Unknown')
                    self.root.after(0, lambda name=gpu_name: self._update_progress(f"✅ Found NVIDIA: {name[:25]}...", 100, 40))
                else:
                    self.root.after(0, lambda: self._update_progress("⚠️ NVIDIA GPU not detected", 100, 40))
                
                self.root.after(0, lambda: self._update_progress("🔴 Detecting AMD CPU...", 10, 60))
                amd_cpu = loop.run_until_complete(detector.detect_amd_cpu())
                if amd_cpu:
                    cpu_name = amd_cpu.get('name', 'Unknown')
                    self.root.after(0, lambda name=cpu_name: self._update_progress(f"✅ Found AMD CPU: {name[:25]}...", 100, 60))
                else:
                    self.root.after(0, lambda: self._update_progress("⚠️ AMD CPU not detected", 100, 60))
                
                self.root.after(0, lambda: self._update_progress("🔴 Detecting AMD GPU...", 10, 80))
                amd_gpu = loop.run_until_complete(detector.detect_amd_gpu())
                if amd_gpu:
                    gpu_name = amd_gpu.get('name', 'Unknown')
                    self.root.after(0, lambda name=gpu_name: self._update_progress(f"✅ Found AMD GPU: {name[:25]}...", 100, 80))
                else:
                    self.root.after(0, lambda: self._update_progress("⚠️ AMD GPU not detected", 100, 80))
                
                self.root.after(0, lambda: self._update_progress("💻 Getting system information...", 10, 90))
                system_info = loop.run_until_complete(detector.detect_system_info())
                self.root.after(0, lambda: self._update_progress("✅ System info collected", 100, 90))
                
                # Compile results
                hardware_info = {}
                if asus_model:
                    hardware_info['asus_model'] = asus_model
                if nvidia_gpu:
                    hardware_info['nvidia_gpu'] = nvidia_gpu
                if amd_cpu:
                    hardware_info['amd_cpu'] = amd_cpu
                if amd_gpu:
                    hardware_info['amd_gpu'] = amd_gpu
                if system_info:
                    hardware_info['system_info'] = system_info
                
                # Ensure we have at least some hardware detected
                if not hardware_info:
                    raise Exception("No hardware components were detected")
                
                self.driver_updater.hardware_info = hardware_info
                
                self.root.after(0, lambda: self._update_progress("Hardware detection complete!", 100, 100))
                
                # Update GUI in main thread
                self.root.after(0, self._hardware_detection_complete)
                
            except Exception as e:
                self.logger.error(f"Hardware detection failed: {e}")
                # Add a small delay to ensure GUI is ready
                self.root.after(100, lambda: self._hardware_detection_failed(str(e)))
            finally:
                self.is_scanning = False
        
        thread = threading.Thread(target=detection_worker, daemon=True)
        thread.start()
    
    def _hardware_detection_complete(self):
        """Called when hardware detection is complete."""
        self.hardware_info = self.driver_updater.hardware_info
        self._update_hardware_tree()
        self.current_task_var.set("✅ Hardware Detection Complete")
        self.status_var.set(f"Found {len(self.hardware_info)} hardware components")
        self.progress_var.set(100)
        self.overall_progress_var.set(100)
        if self.progress_label:
            self.progress_label.config(text="Hardware scan completed successfully")
        self._log_message("Hardware detection completed successfully")
    
    def _hardware_detection_failed(self, error: str):
        """Called when hardware detection fails."""
        self.current_task_var.set("❌ Hardware Detection Failed")
        self.status_var.set("Some hardware may not have been detected")
        self.progress_var.set(0)
        self.overall_progress_var.set(0)
        if self.progress_label:
            self.progress_label.config(text="Hardware detection encountered errors")
        self._log_message(f"Hardware detection failed: {error}", "ERROR")
        
        # Still try to update the tree with whatever was detected
        if hasattr(self.driver_updater, 'hardware_info') and self.driver_updater.hardware_info:
            self._update_hardware_tree()
        
        messagebox.showwarning("Warning", f"Hardware detection had issues:\n{error}\n\nSome hardware may not have been detected, but you can still try scanning for updates.")
    
    def _start_update_scan(self):
        """Start scanning for updates in a separate thread."""
        if self.is_scanning or not self.hardware_info:
            if not self.hardware_info:
                messagebox.showwarning("Warning", "Please detect hardware first")
            return
        
        self.is_scanning = True
        self.current_task_var.set("📦 Scanning for Updates")
        self.status_var.set("Initializing driver scan...")
        self.progress_var.set(0)
        self.overall_progress_var.set(0)
        
        def scan_worker():
            try:
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                
                updates = {}
                total_steps = 0
                current_step = 0
                
                # Count expected steps
                if self.hardware_info.get('nvidia_gpu'):
                    total_steps += 1
                if self.hardware_info.get('amd_cpu') or self.hardware_info.get('amd_gpu'):
                    total_steps += 1
                if self.hardware_info.get('asus_model'):
                    total_steps += 1
                
                # Check NVIDIA drivers
                if self.hardware_info.get('nvidia_gpu'):
                    current_step += 1
                    progress = (current_step / total_steps) * 100
                    self.root.after(0, lambda: self._update_progress(
                        "🎮 Scanning NVIDIA drivers...", 
                        0, progress
                    ))
                    
                    try:
                        nvidia_update = loop.run_until_complete(
                            asyncio.wait_for(
                                self.driver_updater.nvidia_handler.check_for_updates(
                                    self.hardware_info['nvidia_gpu']
                                ),
                                timeout=45.0  # 45 second timeout
                            )
                        )
                        if nvidia_update:
                            updates['nvidia'] = nvidia_update
                            self.root.after(0, lambda: self._update_progress(
                                f"✅ Found NVIDIA update: {nvidia_update.get('name', 'Unknown')}", 
                                100, progress
                            ))
                        else:
                            self.root.after(0, lambda: self._update_progress(
                                "✅ NVIDIA drivers up to date", 
                                100, progress
                            ))
                    except asyncio.TimeoutError:
                        self.root.after(0, lambda: self._update_progress(
                            "⏰ NVIDIA scan timed out (continuing...)", 
                            100, progress
                        ))
                        self.logger.warning("NVIDIA driver scan timed out")
                    except Exception as e:
                        self.root.after(0, lambda: self._update_progress(
                            f"❌ NVIDIA scan failed: {str(e)[:50]}...", 
                            100, progress
                        ))
                
                # Check AMD drivers
                if self.hardware_info.get('amd_cpu') or self.hardware_info.get('amd_gpu'):
                    current_step += 1
                    progress = (current_step / total_steps) * 100
                    self.root.after(0, lambda: self._update_progress(
                        "🔴 Scanning AMD drivers...", 
                        0, progress
                    ))
                    
                    try:
                        # Add timeout for AMD scanning
                        amd_update = loop.run_until_complete(
                            asyncio.wait_for(
                                self.driver_updater.amd_handler.check_for_updates(
                                    self.hardware_info
                                ),
                                timeout=60.0  # 60 second timeout
                            )
                        )
                        if amd_update:
                            updates['amd'] = amd_update
                            amd_count = len(amd_update) if isinstance(amd_update, dict) else 1
                            self.root.after(0, lambda: self._update_progress(
                                f"✅ Found {amd_count} AMD updates", 
                                100, progress
                            ))
                        else:
                            self.root.after(0, lambda: self._update_progress(
                                "✅ AMD drivers up to date", 
                                100, progress
                            ))
                    except asyncio.TimeoutError:
                        self.root.after(0, lambda: self._update_progress(
                            "⏰ AMD scan timed out (continuing...)", 
                            100, progress
                        ))
                        self.logger.warning("AMD driver scan timed out")
                    except Exception as e:
                        self.root.after(0, lambda: self._update_progress(
                            f"❌ AMD scan failed: {str(e)[:50]}...", 
                            100, progress
                        ))
                
                # Check ASUS drivers
                if self.hardware_info.get('asus_model'):
                    current_step += 1
                    progress = (current_step / total_steps) * 100
                    self.root.after(0, lambda: self._update_progress(
                        "🏢 Scanning ASUS utilities...", 
                        0, progress
                    ))
                    
                    try:
                        asus_update = loop.run_until_complete(
                            asyncio.wait_for(
                                self.driver_updater.asus_handler.check_for_updates(
                                    self.hardware_info['asus_model']
                                ),
                                timeout=45.0  # 45 second timeout
                            )
                        )
                        if asus_update:
                            updates['asus'] = asus_update
                            asus_count = len(asus_update) if isinstance(asus_update, dict) else 1
                            self.root.after(0, lambda: self._update_progress(
                                f"✅ Found {asus_count} ASUS updates", 
                                100, progress
                            ))
                        else:
                            self.root.after(0, lambda: self._update_progress(
                                "✅ ASUS software up to date", 
                                100, progress
                            ))
                    except asyncio.TimeoutError:
                        self.root.after(0, lambda: self._update_progress(
                            "⏰ ASUS scan timed out (continuing...)", 
                            100, progress
                        ))
                        self.logger.warning("ASUS driver scan timed out")
                    except Exception as e:
                        self.root.after(0, lambda: self._update_progress(
                            f"❌ ASUS scan failed: {str(e)[:50]}...", 
                            100, progress
                        ))
                
                self.available_updates = updates
                self.root.after(0, lambda: self._update_progress("Scan complete!", 100, 100))
                
                # Update GUI in main thread
                self.root.after(0, self._update_scan_complete)
                
            except Exception as e:
                self.logger.error(f"Update scan failed: {e}")
                self.root.after(0, lambda: self._update_scan_failed(str(e)))
            finally:
                self.is_scanning = False
        
        thread = threading.Thread(target=scan_worker, daemon=True)
        thread.start()
    
    def _update_scan_complete(self):
        """Called when update scan is complete."""
        self._update_updates_tree()
        self.current_task_var.set("✅ Driver Scan Complete")
        self.status_var.set(f"Found {len(self.available_updates)} update categories")
        self.progress_var.set(100)
        self.overall_progress_var.set(100)
        if self.progress_label:
            self.progress_label.config(text=f"Scan completed - {len(self.available_updates)} categories found")
        self._log_message(f"Update scan completed - found {len(self.available_updates)} categories")
    
    def _update_scan_failed(self, error: str):
        """Called when update scan fails."""
        self.status_var.set("Update scan failed")
        self.progress_var.set(0)
        self._log_message(f"Update scan failed: {error}", "ERROR")
        messagebox.showerror("Error", f"Update scan failed:\n{error}")
    
    def _start_installation(self):
        """Start installing selected updates."""
        if self.is_installing or not self.available_updates:
            return
        
        if not self.selected_updates:
            # If no specific selection, install all available updates
            self.selected_updates = set(self.available_updates.keys())
        
        if not self.selected_updates:
            messagebox.showinfo("Info", "No updates selected for installation")
            return
        
        # Confirm installation
        result = messagebox.askyesno(
            "Confirm Installation",
            f"Install {len(self.selected_updates)} driver categories?\n\n"
            "This may take several minutes and require a restart."
        )
        
        if not result:
            return
        
        self.is_installing = True
        self.current_task_var.set("🚀 Installing Drivers")
        self.status_var.set("Preparing for installation...")
        self.progress_var.set(0)
        self.overall_progress_var.set(0)
        
        def install_worker():
            try:
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                
                results = {}
                total_updates = len(self.selected_updates)
                current_update = 0
                
                for category in self.selected_updates:
                    current_update += 1
                    overall_progress = ((current_update - 1) / total_updates) * 100
                    
                    if category not in self.available_updates:
                        continue
                    
                    update_info = self.available_updates[category]
                    driver_name = update_info.get('name', category.upper()) if isinstance(update_info, dict) else category.upper()
                    
                    self.root.after(0, lambda cat=category, name=driver_name, prog=overall_progress: 
                                  self._update_progress(f"📥 Downloading {name}...", 0, prog))
                    
                    try:
                        if category == 'nvidia':
                            def nvidia_progress(message, progress):
                                self.root.after(0, lambda: self._update_progress(f"🎮 {message}", progress, overall_progress + (progress * 0.8 / 100)))
                            
                            result = loop.run_until_complete(
                                self.driver_updater.nvidia_handler.install_driver(update_info, nvidia_progress)
                            )
                        elif category == 'amd':
                            self.root.after(0, lambda: self._update_progress("🔴 Installing AMD drivers...", 25, overall_progress + 5))
                            result = loop.run_until_complete(
                                self.driver_updater.amd_handler.install_driver(update_info)
                            )
                        elif category == 'asus':
                            self.root.after(0, lambda: self._update_progress("🏢 Installing ASUS utilities...", 25, overall_progress + 5))
                            result = loop.run_until_complete(
                                self.driver_updater.asus_handler.install_driver(update_info)
                            )
                        else:
                            result = False
                        
                        results[category] = result
                        
                        if result:
                            self.root.after(0, lambda cat=category: self._update_progress(
                                f"✅ {cat.upper()} installation complete", 100, 
                                (current_update / total_updates) * 100
                            ))
                        else:
                            self.root.after(0, lambda cat=category: self._update_progress(
                                f"❌ {cat.upper()} installation failed", 100,
                                (current_update / total_updates) * 100
                            ))
                            
                    except Exception as e:
                        self.root.after(0, lambda cat=category, err=str(e): self._update_progress(
                            f"❌ {cat.upper()} error: {err[:30]}...", 100,
                            (current_update / total_updates) * 100
                        ))
                        results[category] = False
                
                self.root.after(0, lambda: self._update_progress("Installation complete!", 100, 100))
                
                # Update GUI in main thread
                self.root.after(0, lambda: self._installation_complete(results))
                
            except Exception as e:
                self.logger.error(f"Installation failed: {e}")
                self.root.after(0, lambda: self._installation_failed(str(e)))
            finally:
                self.is_installing = False
        
        thread = threading.Thread(target=install_worker, daemon=True)
        thread.start()
    
    def _installation_complete(self, results: Dict):
        """Called when installation is complete."""
        success_count = sum(1 for success in results.values() if success)
        total_count = len(results)
        
        self.current_task_var.set("🎉 Installation Complete!")
        self.status_var.set(f"Installed {success_count}/{total_count} driver categories successfully")
        self.progress_var.set(100)
        self.overall_progress_var.set(100)
        if self.progress_label:
            self.progress_label.config(text=f"Installation finished - {success_count}/{total_count} successful")
        self._log_message(f"Installation completed: {success_count}/{total_count} successful")
        
        # Show results
        message = f"🎉 Installation Results:\n\n"
        for category, success in results.items():
            status = "✅ Success" if success else "❌ Failed"
            message += f"{category.upper()}: {status}\n"
        
        if success_count > 0:
            message += "\n🔄 Please restart your computer to complete the installation."
        else:
            message += "\n⚠️ No drivers were successfully installed. Check the logs for details."
        
        messagebox.showinfo("Installation Complete", message)
    
    def _installation_failed(self, error: str):
        """Called when installation fails."""
        self.status_var.set("Installation failed")
        self.progress_var.set(0)
        self._log_message(f"Installation failed: {error}", "ERROR")
        messagebox.showerror("Error", f"Installation failed:\n{error}")
    
    def run(self):
        """Run the GUI application."""
        try:
            print("🚀 Starting GUI application...")
            self.create_gui()
            print("✅ GUI initialized successfully")
            print("🔍 Hardware detection will start automatically in 1 second...")
            self.root.mainloop()
        except Exception as e:
            self.logger.error(f"GUI error: {e}")
            print(f"❌ GUI error: {e}")
            import traceback
            traceback.print_exc()
            raise
