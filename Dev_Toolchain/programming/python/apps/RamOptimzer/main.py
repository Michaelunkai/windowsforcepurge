#!/usr/bin/env python3
"""
RAM Optimizer Pro - Main Entry Point
Continuous RAM optimization tool for Windows
"""

import sys
import os
import argparse
import time
import threading
from memory_manager import WindowsMemoryManager
import signal

def run_gui():
    """Run the GUI application with fallback options"""
    print("Starting RAM Optimizer GUI...")
    
    # Try lightweight GUI first (no external dependencies)
    try:
        from simple_ram_optimizer import LightweightRamOptimizer
        print("✅ Loading Lightweight GUI (recommended)")
        app = LightweightRamOptimizer()
        app.run()
        return
    except Exception as e:
        print(f"⚠️ Lightweight GUI failed: {e}")
    
    # Try simple tkinter GUI
    try:
        from simple_gui import SimpleRamOptimizerGUI
        print("✅ Loading Simple GUI")
        app = SimpleRamOptimizerGUI()
        app.run()
        return
    except Exception as e:
        print(f"⚠️ Simple GUI failed: {e}")
    
    # Try advanced GUI (requires matplotlib)
    try:
        from ram_optimizer_gui import RamOptimizerGUI
        print("✅ Loading Advanced GUI")
        app = RamOptimizerGUI()
        app.run()
        return
    except ImportError as e:
        print(f"⚠️ Advanced GUI failed: {e}")
        print("\n" + "="*50)
        print("GUI DEPENDENCY ISSUES DETECTED")
        print("="*50)
        print("The GUI requires additional packages that may not be available.")
        print("However, the core RAM optimization functionality works perfectly!")
        print("\n✅ WORKING ALTERNATIVES:")
        print("1. Command line: python main.py clean")
        print("2. Service mode: python main.py service")
        print("3. Batch launcher: launch.bat")
        print("4. Memory info: python main.py info")
        print("\n💡 To fix GUI issues:")
        print("- Install from python.org instead of Windows Store")
        print("- Or use command line (recommended - more reliable)")
        print("="*50)
        
        # Ask user what to do
        choice = input("\nWould you like to:\n1. Run manual cleanup now\n2. Start service mode\n3. Exit\nEnter choice (1-3): ")
        
        if choice == '1':
            run_manual_cleanup()
        elif choice == '2':
            run_service()
        else:
            print("Exiting. Use 'python main.py clean' for RAM optimization anytime!")

def run_service(interval=30, threshold=80):
    """Run as background service"""
    print(f"🚀 RAM Optimizer Service starting...")
    print(f"Check interval: {interval} seconds")
    print(f"Memory threshold: {threshold}%")
    print("Press Ctrl+C to stop\n")
    
    memory_manager = WindowsMemoryManager()
    
    def service_callback(event_type, data):
        """Callback for service events"""
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        
        if event_type == 'high_memory':
            print(f"[{timestamp}] 🔥 High memory usage detected: {data['percentage']:.1f}%")
        elif event_type == 'cleanup_performed':
            if data['status'] == 'success':
                print(f"[{timestamp}] ✅ Cleanup completed:")
                print(f"  - Processes optimized: {data['processes_cleaned']}")
                print(f"  - Memory freed: {data['memory_freed_mb']:.1f} MB")
                print(f"  - Memory usage: {data['memory_before']['percentage']:.1f}% → {data['memory_after']['percentage']:.1f}%")
            else:
                print(f"[{timestamp}] ❌ Cleanup failed: {data['status']}")
        elif event_type == 'error':
            print(f"[{timestamp}] ⚠️ Error: {data}")
    
    # Set up signal handler for graceful shutdown
    def signal_handler(signum, frame):
        print("\n🛑 Shutting down RAM Optimizer Service...")
        memory_manager.stop_auto_monitoring()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Configure and start monitoring
    memory_manager.set_auto_clean_settings(interval, threshold)
    
    if memory_manager.start_auto_monitoring(service_callback):
        print("✅ Service started successfully. Monitoring memory usage...")
        
        # Keep the service running
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            pass
    else:
        print("❌ Failed to start monitoring service")
        sys.exit(1)
    
    print("🛑 Service stopped.")

def run_manual_cleanup():
    """Run a single manual cleanup"""
    print("🚀 Performing manual RAM optimization...")
    
    memory_manager = WindowsMemoryManager()
    
    # Show memory before
    memory_before = memory_manager.get_memory_info()
    print(f"\n📊 Memory before optimization:")
    print(f"  Total: {memory_before['total']:.1f} GB")
    print(f"  Used: {memory_before['used']:.1f} GB ({memory_before['percentage']:.1f}%)")
    print(f"  Available: {memory_before['available']:.1f} GB")
    
    # Perform cleanup
    print("\n⚙️ Optimizing...")
    results = memory_manager.comprehensive_cleanup()
    
    if results['status'] == 'success':
        print("\n✅ Optimization completed successfully!")
        print(f"  Processes optimized: {results['processes_cleaned']}")
        print(f"  Memory freed: {results['memory_freed_mb']:.1f} MB")
        
        memory_after = results['memory_after']
        print(f"\n📊 Memory after optimization:")
        print(f"  Used: {memory_after['used']:.1f} GB ({memory_after['percentage']:.1f}%)")
        print(f"  Available: {memory_after['available']:.1f} GB")
        improvement = memory_before['percentage'] - memory_after['percentage']
        print(f"  🎯 Improvement: {improvement:.1f}% reduction")
        
        if results['memory_freed_mb'] > 1000:
            print(f"\n🎉 Excellent! Freed {results['memory_freed_mb']/1024:.1f} GB of RAM!")
        elif results['memory_freed_mb'] > 100:
            print(f"\n👍 Good result! Freed {results['memory_freed_mb']:.0f} MB of RAM!")
    else:
        print(f"❌ Optimization failed: {results['status']}")

def show_memory_info():
    """Show current memory information"""
    memory_manager = WindowsMemoryManager()
    
    print("📊 Current Memory Information:")
    print("=" * 40)
    
    memory_info = memory_manager.get_memory_info()
    print(f"Total Memory: {memory_info['total']:.1f} GB")
    print(f"Used Memory: {memory_info['used']:.1f} GB ({memory_info['percentage']:.1f}%)")
    print(f"Available Memory: {memory_info['available']:.1f} GB")
    print(f"Free Memory: {memory_info['free']:.1f} GB")
    
    # Memory status indicator
    if memory_info['percentage'] > 85:
        status = "🔴 CRITICAL - High memory usage!"
    elif memory_info['percentage'] > 70:
        status = "🟡 WARNING - Consider optimization"
    else:
        status = "🟢 GOOD - Memory usage is healthy"
    
    print(f"Status: {status}")
    
    print(f"\n📋 Top Memory-Using Processes:")
    print("-" * 40)
    processes = memory_manager.get_process_memory_info()
    for i, proc in enumerate(processes[:10], 1):
        print(f"{i:2d}. {proc['name']:<25} {proc['memory_mb']:>8.1f} MB (PID: {proc['pid']})")

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="🚀 RAM Optimizer Pro - Windows Memory Optimization Tool")
    parser.add_argument('mode', nargs='?', default='gui', 
                       choices=['gui', 'service', 'clean', 'info'],
                       help='Run mode: gui (default), service, clean, or info')
    parser.add_argument('--interval', type=int, default=30,
                       help='Check interval in seconds for service mode (default: 30)')
    parser.add_argument('--threshold', type=int, default=80,
                       help='Memory threshold percentage for auto-cleanup (default: 80)')
    parser.add_argument('--version', action='version', version='🚀 RAM Optimizer Pro 1.0')
    
    args = parser.parse_args()
    
    # Check if running on Windows
    if os.name != 'nt':
        print("❌ Error: This application is designed for Windows only.")
        sys.exit(1)
    
    # Check for administrator privileges for optimal functionality
    try:
        import ctypes
        if not ctypes.windll.shell32.IsUserAnAdmin():
            print("⚠️ Warning: Running without administrator privileges.")
            print("Some optimization features may be limited.")
            print("For best results, run as administrator.\n")
    except Exception:
        pass
    
    # Show welcome message
    print("🚀 RAM Optimizer Pro - Windows Memory Optimization Tool")
    print("=" * 55)
    
    # Execute based on mode
    try:
        if args.mode == 'gui':
            run_gui()
        elif args.mode == 'service':
            run_service(args.interval, args.threshold)
        elif args.mode == 'clean':
            run_manual_cleanup()
        elif args.mode == 'info':
            show_memory_info()
    except KeyboardInterrupt:
        print("\n🛑 Operation cancelled by user.")
        sys.exit(0)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 