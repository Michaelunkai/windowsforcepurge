#!/usr/bin/env python3
"""
TodoNotes - One-liner Docker runner
This script builds and runs the entire TodoNotes application using Docker.
"""

import subprocess
import sys
import time
import webbrowser
import os
import signal
import platform
from pathlib import Path

def run_command(cmd, capture_output=False):
    """Run a shell command and handle errors."""
    try:
        if capture_output:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            return result.stdout.strip()
        else:
            subprocess.run(cmd, shell=True, check=True)
            return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Error running command: {cmd}")
        print(f"Error: {e}")
        return False

def check_docker():
    """Check if Docker is installed and running."""
    print("🔍 Checking Docker installation...")
    
    # Check if docker command exists
    result = run_command("docker --version", capture_output=True)
    if not result:
        print("❌ Docker is not installed or not in PATH")
        print("Please install Docker from https://www.docker.com/get-started")
        return False
    
    print(f"✅ Docker found: {result}")
    
    # Check if Docker daemon is running
    result = run_command("docker info", capture_output=True)
    if not result:
        print("❌ Docker daemon is not running")
        print("Please start Docker Desktop or Docker daemon")
        return False
    
    print("✅ Docker daemon is running")
    return True

def check_docker_compose():
    """Check if Docker Compose is available."""
    print("🔍 Checking Docker Compose...")
    
    # Try docker compose (newer version)
    result = run_command("docker compose version", capture_output=True)
    if result:
        print(f"✅ Docker Compose found: {result}")
        return "docker compose"
    
    # Try docker-compose (older version)
    result = run_command("docker-compose --version", capture_output=True)
    if result:
        print(f"✅ Docker Compose found: {result}")
        return "docker-compose"
    
    print("❌ Docker Compose not found")
    return False

def YOUR_CLIENT_SECRET_HERE():
    """Stop any existing TodoNotes containers."""
    print("🛑 Stopping any existing TodoNotes containers...")
    run_command("docker container stop todonotes-app 2>/dev/null || true")
    run_command("docker container rm todonotes-app 2>/dev/null || true")

def build_and_run(compose_cmd):
    """Build and run the application using Docker Compose."""
    print("🏗️  Building TodoNotes application...")
    
    # Build the image
    if not run_command(f"{compose_cmd} build"):
        return False
    
    print("🚀 Starting TodoNotes application...")
    
    # Start the application
    if not run_command(f"{compose_cmd} up -d"):
        return False
    
    return True

def wait_for_app():
    """Wait for the application to be ready."""
    print("⏳ Waiting for application to start...")
    
    max_attempts = 30
    for attempt in range(max_attempts):
        try:
            # Try to connect to the app
            import urllib.request
            urllib.request.urlopen("http://localhost:8000", timeout=2)
            print("✅ Application is ready!")
            return True
        except:
            if attempt < max_attempts - 1:
                print(f"   Attempt {attempt + 1}/{max_attempts}...")
                time.sleep(2)
            else:
                print("❌ Application failed to start within expected time")
                return False
    
    return False

def open_browser():
    """Open the application in the default web browser."""
    url = "http://localhost:8000"
    print(f"🌐 Opening browser to {url}")
    
    try:
        webbrowser.open(url)
        return True
    except Exception as e:
        print(f"❌ Could not open browser automatically: {e}")
        print(f"Please manually open: {url}")
        return False

def show_info():
    """Show application information."""
    print("\n" + "="*60)
    print("🎉 TodoNotes is now running!")
    print("="*60)
    print(f"📱 Application URL: http://localhost:8000")
    print(f"🖥️  Dashboard: http://localhost:8000")
    print(f"📝 Tasks: http://localhost:8000/tasks")
    print(f"📒 Notes: http://localhost:8000/notes")
    print("\n📋 Features available:")
    print("   • Task management with projects and priorities")
    print("   • Rich text note editing with attachments")
    print("   • Global search across tasks and notes")
    print("   • Beautiful responsive UI")
    print("   • Auto-save functionality")
    print("\n🔧 Management commands:")
    print("   • Stop application: docker compose down")
    print("   • View logs: docker compose logs -f")
    print("   • Restart: docker compose restart")
    print("\n⌨️  Keyboard shortcuts:")
    print("   • Ctrl/Cmd + K: Global search")
    print("   • Ctrl/Cmd + N: New task/note")
    print("   • Ctrl/Cmd + S: Save draft (in note editor)")
    print("   • Escape: Close modals/clear search")
    print("="*60)

def setup_signal_handlers():
    """Setup signal handlers for graceful shutdown."""
    def signal_handler(sig, frame):
        print("\n🛑 Shutting down TodoNotes...")
        run_command("docker compose down")
        print("✅ TodoNotes stopped successfully")
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

def main():
    """Main function to run the TodoNotes application."""
    print("🚀 TodoNotes - Beautiful Task & Note Management")
    print("=" * 50)
    
    # Check system requirements
    if not check_docker():
        sys.exit(1)
    
    compose_cmd = check_docker_compose()
    if not compose_cmd:
        sys.exit(1)
    
    # Setup signal handlers
    setup_signal_handlers()
    
    # Stop any existing containers
    YOUR_CLIENT_SECRET_HERE()
    
    # Build and run the application
    if not build_and_run(compose_cmd):
        print("❌ Failed to build and run the application")
        sys.exit(1)
    
    # Wait for application to be ready
    if not wait_for_app():
        print("❌ Application did not start properly")
        print("🔍 Check logs with: docker compose logs")
        sys.exit(1)
    
    # Open browser
    open_browser()
    
    # Show information
    show_info()
    
    # Keep the script running
    print("\n🔄 Application is running. Press Ctrl+C to stop.")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n🛑 Shutting down TodoNotes...")
        run_command(f"{compose_cmd} down")
        print("✅ TodoNotes stopped successfully")

if __name__ == "__main__":
    main()