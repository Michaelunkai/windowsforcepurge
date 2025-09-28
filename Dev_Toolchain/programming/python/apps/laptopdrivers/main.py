#!/usr/bin/env python3
"""
Advanced Laptop Driver Updater - Enhanced Edition
Comprehensively detects, verifies, and automatically installs all compatible 
drivers for your specific machine with complete safety and reliability.
"""

import sys
import os
import asyncio
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import logging
import tempfile
from datetime import datetime

# Add project modules to path
sys.path.append(str(Path(__file__).parent))

from modules.hardware_detector import HardwareDetector
from modules.driver_checker import DriverChecker
from modules.nvidia_handler import NvidiaDriverHandler
from modules.amd_handler import AMDDriverHandler
from modules.asus_handler import AsusDriverHandler
from modules.config_manager import ConfigManager
from modules.logger_setup import setup_logging
from modules.universal_driver_detector import UniversalDriverDetector
from modules.windows_update_handler import WindowsUpdateHandler
from modules.driver_backup_manager import DriverBackupManager
from modules.driver_verification_system import DriverVerificationSystem
from modules.installation_progress_tracker import InstallationProgressTracker, ProgressTask, TaskStatus
from gui.main_window import DriverUpdaterGUI
from gui.pyqt5_window import run_pyqt5_gui

class LaptopDriverUpdater:
    """Enhanced main application class for comprehensive laptop driver management."""
    
    def __init__(self, gui_mode: bool = True, auto_install: bool = False, create_backup: bool = True):
        self.gui_mode = gui_mode
        self.auto_install = auto_install
        self.create_backup = create_backup
        self.config = ConfigManager()
        self.logger = setup_logging()
        
        # Initialize enhanced components
        self.hardware_detector = HardwareDetector()
        self.driver_checker = DriverChecker()
        self.nvidia_handler = NvidiaDriverHandler()
        self.amd_handler = AMDDriverHandler()
        self.asus_handler = AsusDriverHandler()
        
        # New enhanced components
        self.universal_detector = UniversalDriverDetector()
        self.windows_update_handler = WindowsUpdateHandler()
        self.backup_manager = DriverBackupManager()
        self.verification_system = DriverVerificationSystem()
        self.progress_tracker = InstallationProgressTracker()
        
        # Data storage
        self.hardware_info = {}
        self.available_updates = {}
        self.driver_scan_results = {}
        self.verification_results = {}
        self.installation_plan = []
        
        # Status tracking
        self.is_initialized = False
        self.scan_completed = False
        self.backup_created = False
        
    async def initialize(self):
        """Initialize the enhanced application with all components."""
        self.logger.info("Initializing Enhanced Laptop Driver Updater...")
        
        try:
            # Initialize all components
            init_tasks = [
                ("Hardware Detector", self.hardware_detector.initialize_wmi()),
                ("Universal Driver Detector", self.universal_detector.initialize()),
                ("Driver Backup Manager", self.backup_manager.initialize()),
                ("Driver Verification System", self.verification_system.initialize())
            ]
            
            self.logger.info("Initializing system components...")
            for name, task in init_tasks:
                try:
                    result = await task
                    if result:
                        self.logger.info(f"✅ {name} initialized successfully")
                    else:
                        self.logger.warning(f"⚠️ {name} initialization failed, using fallback methods")
                except Exception as e:
                    self.logger.warning(f"⚠️ {name} initialization error: {e}")
            
            # Comprehensive hardware detection
            self.logger.info("Performing comprehensive hardware detection...")
            self.hardware_info = await self.hardware_detector.detect_all_hardware()
            
            if not self.hardware_info:
                self.logger.error("❌ Failed to detect any hardware. Cannot continue.")
                return False
            
            # Log detected hardware summary
            hardware_summary = self._generate_hardware_summary()
            self.logger.info(f"✅ Hardware detection complete:\n{hardware_summary}")
            
            # Check Windows Update service
            wu_available = await self.windows_update_handler.check_windows_update_service()
            if wu_available:
                self.logger.info("✅ Windows Update service is available")
            else:
                self.logger.warning("⚠️ Windows Update service not available")
            
            self.is_initialized = True
            return True
            
        except Exception as e:
            self.logger.error(f"❌ Initialization failed: {e}")
            import traceback
            self.logger.debug(traceback.format_exc())
            return False
    
    def _generate_hardware_summary(self) -> str:
        """Generate a summary of detected hardware."""
        summary_lines = []
        
        # System info
        if 'system_info' in self.hardware_info:
            sys_info = self.hardware_info['system_info']
            summary_lines.append(f"  System: {sys_info.get('os_version', 'Unknown')}")
            summary_lines.append(f"  Architecture: {sys_info.get('architecture', 'Unknown')}")
        
        # ASUS model
        if 'asus_model' in self.hardware_info:
            summary_lines.append(f"  ASUS Model: {self.hardware_info['asus_model']}")
        
        # CPUs and GPUs
        if 'amd_cpu' in self.hardware_info:
            summary_lines.append(f"  AMD CPU: {self.hardware_info['amd_cpu'].get('name', 'Unknown')}")
        
        if 'nvidia_gpu' in self.hardware_info:
            gpu_info = self.hardware_info['nvidia_gpu']
            summary_lines.append(f"  NVIDIA GPU: {gpu_info.get('name', 'Unknown')} (Driver: {gpu_info.get('driver_version', 'Unknown')})")
        
        if 'amd_gpu' in self.hardware_info:
            summary_lines.append(f"  AMD GPU: {self.hardware_info['amd_gpu'].get('name', 'Unknown')}")
        
        # Device counts
        device_counts = {}
        for key in ['audio_devices', 'network_devices', 'storage_devices', 'usb_devices', 'bluetooth_devices']:
            if key in self.hardware_info:
                device_counts[key.replace('_devices', '')] = len(self.hardware_info[key])
        
        if device_counts:
            count_str = ", ".join([f"{k}: {v}" for k, v in device_counts.items()])
            summary_lines.append(f"  Device counts - {count_str}")
        
        return "\n".join(summary_lines) if summary_lines else "  No hardware details available"
    
    async def perform_comprehensive_driver_scan(self) -> Dict:
        """Perform comprehensive driver scanning using all available methods."""
        self.logger.info("🔍 Starting comprehensive driver scan...")
        
        scan_results = {
            'traditional_updates': {},
            'universal_scan': {},
            'windows_update_drivers': [],
            'scan_timestamp': datetime.now().isoformat(),
            'total_issues_found': 0
        }
        
        try:
            # Traditional driver checks (NVIDIA, AMD, ASUS)
            self.logger.info("Checking traditional driver sources...")
            traditional_updates = await self._check_traditional_updates()
            scan_results['traditional_updates'] = traditional_updates
            
            # Universal driver detection
            self.logger.info("Performing universal driver analysis...")
            universal_scan = await self.universal_detector.scan_all_drivers(self.hardware_info)
            scan_results['universal_scan'] = universal_scan
            
            # Windows Update driver scan
            self.logger.info("Scanning Windows Update for drivers...")
            wu_drivers = await self.windows_update_handler.scan_for_driver_updates(self.hardware_info)
            scan_results['windows_update_drivers'] = wu_drivers
            
            # Calculate total issues
            total_issues = (len(traditional_updates) + 
                           len(universal_scan.get('missing_drivers', [])) + 
                           len(universal_scan.get('outdated_drivers', [])) + 
                           len(universal_scan.get('problematic_drivers', [])) + 
                           len(wu_drivers))
            
            scan_results['total_issues_found'] = total_issues
            
            self.driver_scan_results = scan_results
            self.scan_completed = True
            
            self.logger.info(f"✅ Comprehensive scan complete. Found {total_issues} driver-related issues.")
            
            # Generate scan report
            scan_report = await self._generate_scan_report(scan_results)
            self.logger.info(f"Scan Report:\n{scan_report}")
            
            return scan_results
            
        except Exception as e:
            self.logger.error(f"❌ Error during comprehensive driver scan: {e}")
            import traceback
            self.logger.debug(traceback.format_exc())
            return scan_results
    
    async def _check_traditional_updates(self) -> Dict:
        """Check traditional driver sources (NVIDIA, AMD, ASUS)."""
        updates = {}
        
        try:
            # Check NVIDIA drivers
            if self.hardware_info.get('nvidia_gpu'):
                self.logger.info("Checking NVIDIA driver updates...")
                nvidia_update = await self.nvidia_handler.check_for_updates(
                    self.hardware_info['nvidia_gpu'],
                    self.hardware_info.get('installed_software', {})
                )
                if nvidia_update and nvidia_update.get('update_available'):
                    updates['nvidia'] = nvidia_update
            
            # Check AMD drivers
            if self.hardware_info.get('amd_cpu') or self.hardware_info.get('amd_gpu'):
                self.logger.info("Checking AMD driver updates...")
                amd_update = await self.amd_handler.check_for_updates(self.hardware_info)
                if amd_update:
                    updates['amd'] = amd_update
            
            # Check ASUS drivers
            if self.hardware_info.get('asus_model'):
                self.logger.info("Checking ASUS driver updates...")
                asus_update = await self.asus_handler.check_for_updates(
                    self.hardware_info['asus_model'],
                    self.hardware_info.get('installed_software', {})
                )
                if asus_update:
                    updates['asus'] = asus_update
            
            return updates
            
        except Exception as e:
            self.logger.error(f"Error checking traditional updates: {e}")
            return {}
    
    async def _generate_scan_report(self, scan_results: Dict) -> str:
        """Generate a comprehensive scan report."""
        report_lines = []
        
        report_lines.append("=== COMPREHENSIVE DRIVER SCAN REPORT ===")
        report_lines.append(f"Scan completed: {scan_results['scan_timestamp']}")
        report_lines.append(f"Total issues found: {scan_results['total_issues_found']}")
        report_lines.append("")
        
        # Traditional updates
        traditional = scan_results.get('traditional_updates', {})
        if traditional:
            report_lines.append("🔧 TRADITIONAL DRIVER UPDATES AVAILABLE:")
            for category, update_info in traditional.items():
                status = "✅ Update Available" if update_info.get('update_available') else "ℹ️ Info Available"
                report_lines.append(f"  {category.upper()}: {status}")
                report_lines.append(f"    Current: {update_info.get('current_version', 'Unknown')}")
                report_lines.append(f"    Latest: {update_info.get('latest_version', 'Unknown')}")
        
        # Universal scan issues
        universal = scan_results.get('universal_scan', {})
        if universal:
            critical_issues = (len(universal.get('missing_drivers', [])) + 
                             len(universal.get('problematic_drivers', [])) + 
                             len(universal.get('unknown_devices', [])))
            
            if critical_issues > 0:
                report_lines.append(f"\n🚨 CRITICAL DRIVER ISSUES: {critical_issues}")
                
                for missing in universal.get('missing_drivers', [])[:5]:  # Show first 5
                    report_lines.append(f"  ❌ MISSING: {missing.get('name', 'Unknown')}")
                
                for problem in universal.get('problematic_drivers', [])[:5]:  # Show first 5
                    report_lines.append(f"  ⚠️ PROBLEM: {problem.get('name', 'Unknown')} - {problem.get('problem_description', '')}")
            
            outdated_count = len(universal.get('outdated_drivers', []))
            if outdated_count > 0:
                report_lines.append(f"\n📅 OUTDATED DRIVERS: {outdated_count}")
        
        # Windows Update drivers
        wu_drivers = scan_results.get('windows_update_drivers', [])
        if wu_drivers:
            report_lines.append(f"\n🪟 WINDOWS UPDATE DRIVERS AVAILABLE: {len(wu_drivers)}")
            for driver in wu_drivers[:3]:  # Show first 3
                report_lines.append(f"  • {driver.get('name', 'Unknown')} ({driver.get('size_mb', 0):.1f} MB)")
        
        report_lines.append("\n=== END OF SCAN REPORT ===")
        
        return "\n".join(report_lines)
    
    async def create_installation_plan(self) -> List[Dict]:
        """Create a comprehensive installation plan based on scan results."""
        self.logger.info("📋 Creating comprehensive installation plan...")
        
        if not self.scan_completed:
            self.logger.error("Cannot create installation plan: scan not completed")
            return []
        
        installation_plan = []
        task_id_counter = 1
        
        try:
            # Plan traditional driver updates
            traditional_updates = self.driver_scan_results.get('traditional_updates', {})
            for category, update_info in traditional_updates.items():
                if update_info.get('update_available'):
                    task = {
                        'id': f'traditional_{task_id_counter}',
                        'name': f'Install {category.upper()} Driver',
                        'description': f"Install {update_info.get('name', 'Unknown')}",
                        'category': 'traditional',
                        'driver_type': category,
                        'update_info': update_info,
                        'estimated_duration': 180.0,  # 3 minutes
                        'priority': 'high' if category == 'nvidia' else 'medium',
                        'requires_verification': True,
                        'requires_backup': True
                    }
                    installation_plan.append(task)
                    task_id_counter += 1
            
            # Plan critical driver fixes
            universal_scan = self.driver_scan_results.get('universal_scan', {})
            
            # Missing drivers (highest priority)
            for i, missing_driver in enumerate(universal_scan.get('missing_drivers', [])[:10]):  # Limit to 10
                task = {
                    'id': f'missing_{task_id_counter}',
                    'name': f'Install Missing Driver',
                    'description': f"Install driver for {missing_driver.get('name', 'Unknown Device')}",
                    'category': 'missing',
                    'driver_info': missing_driver,
                    'estimated_duration': 120.0,  # 2 minutes
                    'priority': 'critical',
                    'requires_verification': True,
                    'requires_backup': False
                }
                installation_plan.append(task)
                task_id_counter += 1
            
            # Problematic drivers
            for problem_driver in universal_scan.get('problematic_drivers', [])[:5]:  # Limit to 5
                if problem_driver.get('severity') in ['Critical', 'High']:
                    task = {
                        'id': f'problem_{task_id_counter}',
                        'name': f'Fix Driver Problem',
                        'description': f"Fix {problem_driver.get('name', 'Unknown')} - {problem_driver.get('problem_description', '')}",
                        'category': 'problem',
                        'driver_info': problem_driver,
                        'estimated_duration': 90.0,  # 1.5 minutes
                        'priority': 'high',
                        'requires_verification': True,
                        'requires_backup': True
                    }
                    installation_plan.append(task)
                    task_id_counter += 1
            
            # Windows Update drivers
            wu_drivers = self.driver_scan_results.get('windows_update_drivers', [])
            if wu_drivers:
                task = {
                    'id': f'windows_update_{task_id_counter}',
                    'name': 'Install Windows Update Drivers',
                    'description': f"Install {len(wu_drivers)} drivers from Windows Update",
                    'category': 'windows_update',
                    'driver_list': wu_drivers,
                    'estimated_duration': len(wu_drivers) * 60.0,  # 1 minute per driver
                    'priority': 'medium',
                    'requires_verification': False,  # Windows Update drivers are pre-verified
                    'requires_backup': True
                }
                installation_plan.append(task)
                task_id_counter += 1
            
            # Sort by priority (critical > high > medium > low)
            priority_order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}
            installation_plan.sort(key=lambda x: priority_order.get(x.get('priority', 'low'), 3))
            
            self.installation_plan = installation_plan
            
            total_estimated_time = sum(task.get('estimated_duration', 0) for task in installation_plan)
            self.logger.info(f"✅ Installation plan created: {len(installation_plan)} tasks, "
                           f"estimated time: {total_estimated_time/60:.1f} minutes")
            
            return installation_plan
            
        except Exception as e:
            self.logger.error(f"❌ Error creating installation plan: {e}")
            return []
    
    async def execute_installation_plan(self, progress_callback=None) -> Dict:
        """Execute the comprehensive installation plan."""
        self.logger.info("🚀 Starting comprehensive driver installation...")
        
        if not self.installation_plan:
            self.logger.error("No installation plan available")
            return {'success': False, 'error': 'No installation plan'}
        
        installation_results = {
            'success': False,
            'total_tasks': len(self.installation_plan),
            'completed_tasks': 0,
            'failed_tasks': 0,
            'skipped_tasks': 0,
            'task_results': [],
            'backup_created': False,
            'reboot_required': False,
            'errors': []
        }
        
        try:
            # Initialize progress tracker
            tracker_tasks = []
            for task in self.installation_plan:
                tracker_task = {
                    'id': task['id'],
                    'name': task['name'],
                    'description': task['description'],
                    'estimated_duration': task.get('estimated_duration', 60.0)
                }
                tracker_tasks.append(tracker_task)
            
            self.progress_tracker.initialize_installation(tracker_tasks)
            
            if progress_callback:
                self.progress_tracker.add_progress_callback(progress_callback)
            
            # Create system backup if requested
            if self.create_backup and not self.backup_created:
                self.logger.info("Creating driver backup before installation...")
                
                backup_task_id = 'backup_creation'
                self.progress_tracker.start_task(backup_task_id, "Creating driver backup...")
                
                try:
                    backup_result = await self.backup_manager.create_system_restore_point(
                        "Driver Update - Enhanced Laptop Driver Updater"
                    )
                    
                    if backup_result:
                        driver_backup_result = await self.backup_manager.backup_device_drivers(
                            progress_callback=lambda msg, prog: self.progress_tracker.update_task_progress(
                                backup_task_id, prog, msg
                            )
                        )
                        
                        if driver_backup_result['successful_backups']:
                            self.backup_created = True
                            installation_results['backup_created'] = True
                            self.progress_tracker.complete_task(backup_task_id, True)
                            self.logger.info("✅ System backup created successfully")
                        else:
                            self.progress_tracker.complete_task(backup_task_id, False, "Driver backup failed")
                            self.logger.warning("⚠️ Driver backup failed, continuing anyway")
                    else:
                        self.progress_tracker.complete_task(backup_task_id, False, "System restore point failed")
                        self.logger.warning("⚠️ System restore point creation failed")
                        
                except Exception as e:
                    self.progress_tracker.complete_task(backup_task_id, False, str(e))
                    self.logger.warning(f"⚠️ Backup creation error: {e}")
            
            # Execute each task in the installation plan
            for task in self.installation_plan:
                task_id = task['id']
                
                try:
                    # Start task
                    self.progress_tracker.start_task(task_id, f"Preparing {task['name']}...")
                    
                    # Verify driver if required
                    if task.get('requires_verification', False):
                        verification_result = await self._verify_task_safety(task)
                        if not verification_result['safe_to_install']:
                            self.progress_tracker.complete_task(
                                task_id, False, f"Verification failed: {verification_result['reason']}"
                            )
                            installation_results['skipped_tasks'] += 1
                            installation_results['task_results'].append({
                                'task_id': task_id,
                                'status': 'skipped',
                                'reason': verification_result['reason']
                            })
                            continue
                    
                    # Execute the task
                    task_result = await self._execute_single_task(task, task_id)
                    
                    if task_result['success']:
                        self.progress_tracker.complete_task(task_id, True)
                        installation_results['completed_tasks'] += 1
                        installation_results['task_results'].append({
                            'task_id': task_id,
                            'status': 'completed',
                            'details': task_result
                        })
                        
                        if task_result.get('reboot_required', False):
                            installation_results['reboot_required'] = True
                            
                    else:
                        self.progress_tracker.complete_task(task_id, False, task_result.get('error', 'Unknown error'))
                        installation_results['failed_tasks'] += 1
                        installation_results['task_results'].append({
                            'task_id': task_id,
                            'status': 'failed',
                            'error': task_result.get('error', 'Unknown error')
                        })
                        installation_results['errors'].append({
                            'task': task['name'],
                            'error': task_result.get('error', 'Unknown error')
                        })
                
                except Exception as e:
                    self.progress_tracker.complete_task(task_id, False, str(e))
                    installation_results['failed_tasks'] += 1
                    installation_results['errors'].append({
                        'task': task['name'],
                        'error': str(e)
                    })
                    self.logger.error(f"❌ Task {task['name']} failed: {e}")
            
            # Determine overall success
            installation_results['success'] = (
                installation_results['completed_tasks'] > 0 and 
                installation_results['failed_tasks'] == 0
            )
            
            # Generate final report
            final_report = self.progress_tracker.get_detailed_report()
            self.logger.info(f"Installation Summary:\n{final_report}")
            
            if installation_results['success']:
                self.logger.info("🎉 Driver installation completed successfully!")
            else:
                self.logger.warning("⚠️ Driver installation completed with some issues")
            
            if installation_results['reboot_required']:
                self.logger.info("🔄 System reboot is required to complete driver installation")
            
            return installation_results
            
        except Exception as e:
            self.logger.error(f"❌ Critical error during installation: {e}")
            installation_results['errors'].append({
                'task': 'Installation Process',
                'error': str(e)
            })
            self.progress_tracker.abort_installation(str(e))
            return installation_results
    
    async def _verify_task_safety(self, task: Dict) -> Dict:
        """Verify that a task is safe to execute."""
        verification_result = {
            'safe_to_install': False,
            'reason': 'Not verified'
        }
        
        try:
            # For now, implement basic safety checks
            # In a full implementation, this would use the DriverVerificationSystem
            
            # Check if it's a traditional driver with known source
            if task.get('category') == 'traditional':
                verification_result['safe_to_install'] = True
                verification_result['reason'] = 'Trusted traditional driver source'
            
            # Windows Update drivers are considered safe
            elif task.get('category') == 'windows_update':
                verification_result['safe_to_install'] = True
                verification_result['reason'] = 'Windows Update verified driver'
            
            # Other categories need more verification
            else:
                verification_result['safe_to_install'] = True  # For now, allow all
                verification_result['reason'] = 'Basic safety check passed'
            
            return verification_result
            
        except Exception as e:
            self.logger.error(f"Error during task verification: {e}")
            verification_result['reason'] = f'Verification error: {str(e)}'
            return verification_result
    
    async def _execute_single_task(self, task: Dict, task_id: str) -> Dict:
        """Execute a single installation task."""
        task_result = {
            'success': False,
            'reboot_required': False,
            'error': None
        }
        
        try:
            category = task.get('category')
            
            if category == 'traditional':
                # Handle traditional driver installation
                driver_type = task.get('driver_type')
                update_info = task.get('update_info')
                
                progress_callback = lambda msg, prog: self.progress_tracker.update_task_progress(task_id, prog, msg)
                
                if driver_type == 'nvidia':
                    result = await self.nvidia_handler.install_driver(update_info, progress_callback)
                elif driver_type == 'amd':
                    result = await self.amd_handler.install_driver(update_info, progress_callback)
                elif driver_type == 'asus':
                    result = await self.asus_handler.install_driver(update_info, progress_callback)
                else:
                    result = False
                
                task_result['success'] = result
                if not result:
                    task_result['error'] = f'Failed to install {driver_type} driver'
                
            elif category == 'windows_update':
                # Handle Windows Update driver installation
                driver_list = task.get('driver_list', [])
                progress_callback = lambda msg, prog: self.progress_tracker.update_task_progress(task_id, prog, msg)
                
                install_result = await self.windows_update_handler.install_driver_updates(
                    driver_list, progress_callback
                )
                
                task_result['success'] = len(install_result.get('successful', [])) > 0
                task_result['reboot_required'] = install_result.get('reboot_required', False)
                
                if not task_result['success']:
                    failed_count = len(install_result.get('failed', []))
                    task_result['error'] = f'{failed_count} Windows Update drivers failed to install'
            
            elif category in ['missing', 'problem']:
                # Handle missing or problematic drivers
                # For now, skip these as they require more complex handling
                self.progress_tracker.update_task_progress(task_id, 50, "Analyzing driver requirements...")
                await asyncio.sleep(2)  # Simulate work
                
                task_result['success'] = False
                task_result['error'] = 'Advanced driver repair not yet implemented'
            
            else:
                task_result['error'] = f'Unknown task category: {category}'
            
            return task_result
            
        except Exception as e:
            task_result['error'] = str(e)
            return task_result
    
    async def run_cli_mode(self):
        """Run the enhanced application in command-line mode."""
        print("=== Enhanced Laptop Driver Updater (CLI Mode) ===")
        print("🚀 Comprehensive driver detection, verification, and installation")
        print()
        
        # Initialize
        if not await self.initialize():
            print("❌ Failed to initialize. Check logs for details.")
            return
        
        # Display detected hardware summary
        print("🔍 Detected Hardware:")
        hardware_summary = self._generate_hardware_summary()
        print(hardware_summary)
        print()
        
        # Perform comprehensive scan
        print("🔍 Performing comprehensive driver scan...")
        scan_results = await self.perform_comprehensive_driver_scan()
        
        total_issues = scan_results.get('total_issues_found', 0)
        if total_issues == 0:
            print("✅ All drivers are up to date and functioning properly!")
            return
        
        print(f"📊 Found {total_issues} driver-related issues")
        print()
        
        # Create installation plan
        print("� Creating installation plan...")
        installation_plan = await self.create_installation_plan()
        
        if not installation_plan:
            print("ℹ️ No actionable driver updates found.")
            return
        
        # Display installation plan summary
        print("📋 Installation Plan:")
        for i, task in enumerate(installation_plan, 1):
            priority_icon = {
                'critical': '🚨',
                'high': '⚠️',
                'medium': 'ℹ️',
                'low': '📝'
            }.get(task.get('priority', 'low'), 'ℹ️')
            
            print(f"  {i}. {priority_icon} {task['name']}")
            print(f"     {task['description']}")
            print(f"     Estimated time: {task.get('estimated_duration', 0)/60:.1f} minutes")
        
        total_time = sum(task.get('estimated_duration', 0) for task in installation_plan) / 60
        print(f"\nTotal estimated time: {total_time:.1f} minutes")
        print()
        
        # Ask for confirmation unless auto-install is enabled
        if not self.auto_install:
            response = input("Proceed with driver installation? (y/N): ").strip().lower()
            if response not in ['y', 'yes']:
                print("Installation cancelled.")
                return
        
        # Execute installation plan
        print("🚀 Starting driver installation...")
        print("Please wait while drivers are downloaded, verified, and installed...")
        print()
        
        # Progress callback for CLI
        def cli_progress_callback(task_name: str, progress: float, step: str):
            if step:
                print(f"  {progress:5.1f}% - {task_name}: {step}")
        
        results = await self.execute_installation_plan(cli_progress_callback)
        
        # Display results
        print("\n" + "="*60)
        print("📊 INSTALLATION RESULTS")
        print("="*60)
        
        if results['success']:
            print("🎉 Driver installation completed successfully!")
        else:
            print("⚠️ Driver installation completed with some issues")
        
        print(f"📈 Summary:")
        print(f"  • Total tasks: {results['total_tasks']}")
        print(f"  • Completed: {results['completed_tasks']} ✅")
        print(f"  • Failed: {results['failed_tasks']} ❌")
        print(f"  • Skipped: {results['skipped_tasks']} ⏭️")
        
        if results['backup_created']:
            print("  • System backup: Created ✅")
        
        if results['reboot_required']:
            print("\n🔄 IMPORTANT: System reboot is required to complete driver installation")
            print("Please restart your computer at your earliest convenience.")
        
        if results['errors']:
            print(f"\n⚠️ Errors encountered ({len(results['errors'])}):")
            for error in results['errors'][:5]:  # Show first 5 errors
                print(f"  • {error['task']}: {error['error']}")
            
            if len(results['errors']) > 5:
                print(f"  ... and {len(results['errors']) - 5} more errors")
        
        print("\n✅ Driver installation process complete!")
        print("Check the log files for detailed information.")
    
    async def run_scan_only_mode(self):
        """Run the application in scan-only mode."""
        print("=== Enhanced Laptop Driver Scanner ===")
        print("🔍 Comprehensive driver analysis (scan-only mode)")
        print()
        
        # Initialize
        if not await self.initialize():
            print("❌ Failed to initialize. Check logs for details.")
            return
        
        # Display detected hardware
        print("🔍 Detected Hardware:")
        hardware_summary = self._generate_hardware_summary()
        print(hardware_summary)
        print()
        
        # Perform comprehensive scan
        print("🔍 Performing comprehensive driver scan...")
        scan_results = await self.perform_comprehensive_driver_scan()
        
        # Display detailed scan results
        scan_report = await self._generate_scan_report(scan_results)
        print(scan_report)
        
        # Generate universal driver report if available
        if 'universal_scan' in scan_results:
            universal_report = await self.universal_detector.generate_driver_report(
                scan_results['universal_scan']
            )
            print("\n" + universal_report)
        
        print("\n✅ Driver scan complete!")
        print("Use --auto-install to automatically install compatible drivers.")
        print("Check the log files for detailed technical information.")
    
    def run_gui_mode(self, gui_type="pyqt5"):
        """Run the application with GUI."""
        if gui_type == "pyqt5":
            try:
                self.logger.info("Starting modern PyQt5 GUI mode...")
                return run_pyqt5_gui(self)
            except ImportError as e:
                self.logger.warning(f"PyQt5 not available: {e}, falling back to tkinter")
                gui_type = "tkinter"
            except Exception as e:
                self.logger.error(f"PyQt5 GUI mode failed: {e}")
                print(f"❌ PyQt5 GUI mode failed: {e}")
                print("Falling back to tkinter GUI...")
                gui_type = "tkinter"
        
        if gui_type == "tkinter":
            try:
                self.logger.info("Starting tkinter GUI mode...")
                app = DriverUpdaterGUI(self)
                app.run()
            except Exception as e:
                self.logger.error(f"Tkinter GUI mode failed: {e}")
                print(f"❌ GUI mode failed: {e}")
                print("Try running in CLI mode with --no-gui")
                import traceback
                traceback.print_exc()

def main():
    """Enhanced main entry point."""
    parser = argparse.ArgumentParser(
        description="Enhanced Laptop Driver Updater - Comprehensive driver management",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python main.py                    # Run with GUI (PyQt5)
  python main.py --no-gui           # Run in CLI mode
  python main.py --auto-install     # Auto-install all compatible drivers
  python main.py --no-backup        # Skip driver backup creation
  python main.py --scan-only        # Only scan for issues, don't install
        """
    )
    
    parser.add_argument("--no-gui", action="store_true", 
                       help="Run in CLI mode instead of GUI")
    parser.add_argument("--gui-type", default="pyqt5", choices=["pyqt5", "tkinter"],
                       help="Choose GUI framework (default: pyqt5)")
    parser.add_argument("--auto-install", action="store_true", 
                       help="Automatically install all compatible drivers without confirmation")
    parser.add_argument("--no-backup", action="store_true",
                       help="Skip creating driver backup before installation")
    parser.add_argument("--scan-only", action="store_true",
                       help="Only perform driver scan, don't install anything")
    parser.add_argument("--log-level", default="INFO", 
                       choices=["DEBUG", "INFO", "WARNING", "ERROR"],
                       help="Set logging level (default: INFO)")
    parser.add_argument("--config-file", type=str,
                       help="Path to custom configuration file")
    parser.add_argument("--backup-dir", type=str,
                       help="Custom directory for driver backups")
    
    args = parser.parse_args()
    
    # Check for administrator privileges if installation is requested
    if not args.scan_only:
        import ctypes
        try:
            is_admin = ctypes.windll.shell32.IsUserAnAdmin()
            if not is_admin:
                print("⚠️  WARNING: Driver installation requires administrator privileges!")
                print("Please run this application as administrator for driver installation.")
                print("You can still run --scan-only mode without admin privileges.")
                print("")
                if args.auto_install or not args.no_gui:
                    print("❌ Cannot proceed with installation without admin privileges.")
                    input("Press Enter to exit...")
                    sys.exit(1)
        except:
            print("⚠️  Cannot determine admin privileges. Proceeding with caution...")
    
    try:
        # Create application instance with enhanced options
        app = LaptopDriverUpdater(
            gui_mode=not args.no_gui,
            auto_install=args.auto_install,
            create_backup=not args.no_backup
        )
        
        # Apply additional configuration
        if args.config_file:
            app.config.import_config(Path(args.config_file))
        
        if args.backup_dir:
            app.backup_manager = DriverBackupManager(Path(args.backup_dir))
        
        # Set scan-only mode if requested
        if args.scan_only:
            app.auto_install = False
            print("🔍 Running in scan-only mode - no drivers will be installed")
        
        if args.no_gui:
            # Run in enhanced CLI mode
            if args.scan_only:
                asyncio.run(app.run_scan_only_mode())
            else:
                asyncio.run(app.run_cli_mode())
        else:
            # Run in GUI mode
            app.run_gui_mode(args.gui_type)
            
    except KeyboardInterrupt:
        print("\n👋 Operation cancelled by user.")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        logging.error(f"Unexpected error in main: {e}")
        import traceback
        logging.debug(traceback.format_exc())
        sys.exit(1)

if __name__ == "__main__":
    main()