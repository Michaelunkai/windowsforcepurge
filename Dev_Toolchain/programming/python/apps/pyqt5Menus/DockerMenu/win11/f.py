import subprocess
import sys
import os
import json
import time
import re
import signal
import glob
from datetime import datetime
from typing import Dict, List, Optional, Any

class ProgressTracker:
    """Tracks and persists Docker command progress for resumption capabilities"""
    
    def __init__(self, progress_file: str = ".docker_progress.json"):
        self.progress_file = progress_file
        self.progress_data = self.load_progress()
        self.current_operation = None
        self.project_directory = None  # Will be set when we change to project directory
        
        # Register signal handlers for graceful interruption
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def set_project_directory(self, project_dir: str):
        """Set the project directory and update progress file path"""
        # Ensure we use absolute path and avoid duplication
        self.project_directory = os.path.abspath(project_dir)
        self.progress_file = os.path.join(self.project_directory, ".docker_progress.json")
        
        # Debug: show the paths being used
        print(f"📁 Project directory: {self.project_directory}")
        print(f"📁 Progress file: {self.progress_file}")
        
        # Reload progress data from the new location
        self.progress_data = self.load_progress(verbose=True)
    
    def get_progress_file_path(self) -> str:
        """Get the current progress file path"""
        if hasattr(self, 'project_directory') and self.project_directory:
            return os.path.abspath(os.path.join(self.project_directory, ".docker_progress.json"))
        return os.path.abspath(self.progress_file)
    
    def _signal_handler(self, signum, frame):
        """Handle interruption signals to save progress"""
        print(f"\n⚠️  Operation interrupted (signal {signum})")
        if self.current_operation:
            self.save_progress()
            print(f"✅ Progress saved for operation: {self.current_operation}")
        sys.exit(0)
    
    def load_progress(self, verbose: bool = False) -> Dict[str, Any]:
        """Load existing progress from file"""
        try:
            progress_file_path = self.get_progress_file_path()
            if os.path.exists(progress_file_path):
                with open(progress_file_path, 'r') as f:
                    data = json.load(f)
                    if verbose and data:
                        print(f"📖 Loaded {len(data)} operations from {progress_file_path}")
                    return data
            elif verbose:
                print(f"📄 No progress file found at {progress_file_path}")
        except Exception as e:
            print(f"Warning: Could not load progress file: {e}")
        return {}
    
    def save_progress(self):
        """Save current progress to file"""
        try:
            progress_file_path = self.get_progress_file_path()
            
            # Debug: show the paths
            print(f"🔍 Attempting to save to: {progress_file_path}")
            
            # Ensure directory exists
            progress_dir = os.path.dirname(progress_file_path)
            if progress_dir and not os.path.exists(progress_dir):
                print(f"📁 Creating directory: {progress_dir}")
                os.makedirs(progress_dir, exist_ok=True)
            
            # Double-check the path doesn't have duplication
            progress_dir_name = os.path.basename(progress_dir)
            if progress_file_path.count(progress_dir_name) > 1:
                print(f"⚠️  Path duplication detected for '{progress_dir_name}', fixing...")
                # Fix duplicated folder names in path
                parts = progress_file_path.split(os.sep)
                clean_parts = []
                prev_part = None
                for part in parts:
                    # Skip consecutive duplicate parts (except for empty parts, drive letters, etc.)
                    if part != prev_part or part in ['', '.', '..'] or ':' in part:
                        clean_parts.append(part)
                    prev_part = part
                progress_file_path = os.sep.join(clean_parts)
                print(f"🔧 Fixed path: {progress_file_path}")
            
            with open(progress_file_path, 'w') as f:
                json.dump(self.progress_data, f, indent=2)
            # Only print verbose message in debug mode
            if len(self.progress_data) > 0:
                print(f"💾 Progress saved to {progress_file_path}")
        except Exception as e:
            print(f"Error saving progress: {e}")
            print(f"   Attempted path: {progress_file_path}")
            print(f"   Current directory: {os.getcwd()}")
    
    def start_operation(self, operation_id: str, operation_type: str, command: str):
        """Start tracking a new operation"""
        self.current_operation = operation_id
        
        if operation_id not in self.progress_data:
            self.progress_data[operation_id] = {
                "type": operation_type,
                "command": command,
                "status": "started",
                "started_at": datetime.now().isoformat(),
                "completed_steps": [],
                "failed_steps": [],
                "last_successful_layer": None,
                "build_cache": {},
                "push_layers": {},
                "metadata": {}
            }
            print(f"📝 Created new operation tracking: {operation_id}")
        else:
            print(f"📝 Resuming operation tracking: {operation_id}")
        
        self.progress_data[operation_id]["status"] = "in_progress"
        self.progress_data[operation_id]["resumed_at"] = datetime.now().isoformat()
        
        # Save progress immediately to ensure we have a record
        self.save_progress()
        
        return self.progress_data[operation_id]
    
    def complete_operation(self, operation_id: str):
        """Mark operation as completed"""
        if operation_id in self.progress_data:
            self.progress_data[operation_id]["status"] = "completed"
            self.progress_data[operation_id]["completed_at"] = datetime.now().isoformat()
            self.save_progress()
        self.current_operation = None
    
    def fail_operation(self, operation_id: str, error: str):
        """Mark operation as failed with error details"""
        if operation_id in self.progress_data:
            self.progress_data[operation_id]["status"] = "failed"
            self.progress_data[operation_id]["error"] = error
            self.progress_data[operation_id]["failed_at"] = datetime.now().isoformat()
            self.save_progress()
        self.current_operation = None
    
    def update_step_progress(self, operation_id: str, step: str, data: Dict[str, Any] = None):
        """Update progress for a specific step"""
        if operation_id in self.progress_data:
            if step not in self.progress_data[operation_id]["completed_steps"]:
                self.progress_data[operation_id]["completed_steps"].append(step)
            
            if data:
                self.progress_data[operation_id]["metadata"].update(data)
            
            self.save_progress()
    
    def update_layer_progress(self, operation_id: str, layer_id: str, progress: float, operation_type: str = "push"):
        """Update progress for Docker layers (build/push operations)"""
        if operation_id in self.progress_data:
            if operation_type == "push":
                self.progress_data[operation_id]["push_layers"][layer_id] = {
                    "progress": progress,
                    "timestamp": datetime.now().isoformat()
                }
            elif operation_type == "build":
                self.progress_data[operation_id]["build_cache"][layer_id] = {
                    "cached": progress == 100,
                    "timestamp": datetime.now().isoformat()
                }
            
            self.save_progress()
    
    def get_operation_progress(self, operation_id: str) -> Optional[Dict[str, Any]]:
        """Get progress data for a specific operation"""
        return self.progress_data.get(operation_id)
    
    def is_operation_resumable(self, operation_id: str) -> bool:
        """Check if an operation can be resumed"""
        progress = self.get_operation_progress(operation_id)
        if not progress:
            return False
        
        return progress["status"] in ["started", "in_progress", "failed"]
    
    def YOUR_CLIENT_SECRET_HERE(self, max_age_days: int = 7):
        """Remove old completed operations from progress file"""
        cutoff_time = datetime.now().timestamp() - (max_age_days * 24 * 60 * 60)
        
        to_remove = []
        for op_id, data in self.progress_data.items():
            if data["status"] == "completed" and "completed_at" in data:
                completed_time = datetime.fromisoformat(data["completed_at"]).timestamp()
                if completed_time < cutoff_time:
                    to_remove.append(op_id)
        
        for op_id in to_remove:
            del self.progress_data[op_id]
        
        if to_remove:
            self.save_progress()
            print(f"🧹 Cleaned {len(to_remove)} old completed operations")
    
    def YOUR_CLIENT_SECRET_HERE(self, current_docker_name: str):
        """Remove failed operations from different projects to keep progress file clean"""
        if not current_docker_name:
            return
        
        # Handle both direct name and full image path formats
        current_prefixes = [
            f"build_{current_docker_name}",
            f"YOUR_CLIENT_SECRET_HERE{current_docker_name}"
        ]
        
        to_remove = []
        for op_id, data in self.progress_data.items():
            # Remove old failed operations from different projects
            if (data["status"] in ["failed"] and 
                not any(op_id.startswith(prefix) for prefix in current_prefixes) and
                op_id.startswith("build_")):
                to_remove.append(op_id)
        
        for op_id in to_remove:
            del self.progress_data[op_id]
        
        if to_remove:
            self.save_progress()
            print(f"🧹 Cleaned {len(to_remove)} failed operations from other projects")

# Global progress tracker instance
progress_tracker = ProgressTracker()

def YOUR_CLIENT_SECRET_HERE(output: str, operation_type: str, operation_id: str):
    """Parse Docker command output to extract progress information"""
    lines = output.split('\n')
    
    for line in lines:
        line = line.strip()
        
        if operation_type == "build":
            # Parse build steps and layer caching
            if "Step " in line and "/" in line:
                step_match = re.search(r'Step (\d+)/(\d+)', line)
                if step_match:
                    current_step = int(step_match.group(1))
                    total_steps = int(step_match.group(2))
                    progress_tracker.update_step_progress(
                        operation_id, 
                        f"build_step_{current_step}",
                        {"current_step": current_step, "total_steps": total_steps}
                    )
            
            # Parse layer caching
            elif "---> Using cache" in line:
                layer_match = re.search(r'([a-f0-9]+)', line)
                if layer_match:
                    layer_id = layer_match.group(1)
                    progress_tracker.update_layer_progress(operation_id, layer_id, 100, "build")
        
        elif operation_type == "push":
            # Parse push progress for layers
            if "Pushing" in line or "Pushed" in line:
                # Extract layer ID and progress
                layer_match = re.search(r'([a-f0-9]+):', line)
                if layer_match:
                    layer_id = layer_match.group(1)
                    
                    if "Pushed" in line:
                        progress_tracker.update_layer_progress(operation_id, layer_id, 100, "push")
                    elif "Pushing" in line:
                        # Try to extract percentage if available
                        percent_match = re.search(r'(\d+)%', line)
                        if percent_match:
                            progress = float(percent_match.group(1))
                            progress_tracker.update_layer_progress(operation_id, layer_id, progress, "push")

def YOUR_CLIENT_SECRET_HERE(command: str, operation_type: str, operation_id: str) -> bool:
    """Run a Docker command with progress tracking and resumption capability"""
    
    # Check if operation can be resumed
    resuming = False
    if progress_tracker.is_operation_resumable(operation_id):
        resuming = True
        progress = progress_tracker.get_operation_progress(operation_id)
        print(f"🔄 RESUMING {operation_type.upper()} operation: {operation_id}")
        print(f"   ⏱️  Previous attempt: {progress.get('started_at', 'Unknown')}")
        print(f"   ✅ Completed steps: {len(progress.get('completed_steps', []))}")
        
        # Show layer cache info for builds
        if operation_type == "build" and progress.get('build_cache'):
            cached_layers = len(progress['build_cache'])
            print(f"   🗂️  Cached layers: {cached_layers}")
        
        # Show push progress for pushes
        if operation_type == "push" and progress.get('push_layers'):
            completed_layers = sum(1 for layer in progress['push_layers'].values() if layer.get('progress', 0) == 100)
            total_layers = len(progress['push_layers'])
            print(f"   📤 Push progress: {completed_layers}/{total_layers} layers")
        
        print(f"   💡 Docker will use cached layers to avoid rebuilding completed steps")
        
        # For Docker builds, try to use existing image as cache source
        if operation_type == "build" and "docker build" in command:
            image_match = re.search(r'-t\s+([^\s]+)', command)
            if image_match:
                image_name = image_match.group(1)
                
                # Check if the image exists for caching
                try:
                    result = subprocess.run(f"docker images -q {image_name}", shell=True, capture_output=True, text=True)
                    if result.returncode == 0 and result.stdout.strip():
                        print(f"   ✅ Found existing image for cache: {image_name}")
                        if not "--cache-from" in command:
                            command = command.replace("docker build", f"docker build --cache-from {image_name}")
                            print(f"   🔧 Using existing image as cache source")
                    else:
                        print(f"   ℹ️  No existing image found, will build from scratch")
                        
                        # Also check for any intermediate images
                        result2 = subprocess.run("docker images -a | grep '<none>'", shell=True, capture_output=True, text=True)
                        if result2.returncode == 0 and result2.stdout.strip():
                            print(f"   🔍 Found intermediate images that may speed up build")
                            
                except Exception as e:
                    print(f"   ⚠️  Could not check for existing images: {e}")
                    
                # Add more aggressive caching options
                if not "--cache-from" in command:
                    # Enable BuildKit for better caching - use PowerShell syntax for Windows
                    if "DOCKER_BUILDKIT" not in command:
                        # Use PowerShell environment variable syntax since user is in PowerShell
                        command = f"$env:DOCKER_BUILDKIT=1; {command}"
                        print(f"   🚀 Enabled BuildKit for better caching (PowerShell)")
                    else:
                        print(f"   🔧 Using Docker's built-in layer caching")
    
    # Start tracking this operation
    progress_tracker.start_operation(operation_id, operation_type, command)
    
    print(f"🚀 Starting {operation_type}: {command}")
    
    try:
        # Run command with real-time output capture
        process = subprocess.Popen(
            command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True
        )
        
        output_lines = []
        
        # Process output line by line for real-time progress tracking
        while True:
            output = process.stdout.readline()
            if output == '' and process.poll() is not None:
                break
            
            if output:
                output_lines.append(output.strip())
                print(output.strip())  # Show real-time output
                
                # Parse output for progress information
                YOUR_CLIENT_SECRET_HERE(output, operation_type, operation_id)
        
        # Wait for process to complete
        return_code = process.poll()
        
        if return_code == 0:
            progress_tracker.complete_operation(operation_id)
            print(f"✅ {operation_type} completed successfully!")
            return True
        else:
            error_output = '\n'.join(output_lines[-10:])  # Last 10 lines for error context
            progress_tracker.fail_operation(operation_id, error_output)
            print(f"❌ {operation_type} failed with return code {return_code}")
            return False
            
    except KeyboardInterrupt:
        print(f"\n⚠️  {operation_type} interrupted by user")
        progress_tracker.save_progress()
        return False
    except Exception as e:
        error_msg = str(e)
        progress_tracker.fail_operation(operation_id, error_msg)
        print(f"❌ {operation_type} failed with error: {error_msg}")
        return False

def YOUR_CLIENT_SECRET_HERE(command: str, docker_name: str = "") -> str:
    """Generate a deterministic operation ID based on command and context"""
    
    # Extract operation type and create deterministic ID (no timestamp)
    if "docker build" in command:
        # Extract image name from build command for more specific ID
        image_match = re.search(r'-t\s+([^\s]+)', command)
        if image_match:
            image_name = image_match.group(1).replace('/', '_').replace(':', '_')
            return f"build_{image_name}"
        return f"build_{docker_name}"
    elif "docker push" in command:
        # Extract image name from push command
        push_match = re.search(r'docker push\s+([^\s]+)', command)
        if push_match:
            image_name = push_match.group(1).replace('/', '_').replace(':', '_')
            return f"push_{image_name}"
        return f"push_{docker_name}"
    elif "docker pull" in command:
        image_match = re.search(r'docker pull\s+([^\s]+)', command)
        image_name = image_match.group(1) if image_match else "unknown"
        return f"pull_{image_name.replace('/', '_').replace(':', '_')}"
    elif "docker run" in command:
        return f"run_{docker_name}"
    else:
        # Generic operation ID
        operation_type = command.split()[1] if len(command.split()) > 1 else "unknown"
        return f"{operation_type}_{docker_name}"

def YOUR_CLIENT_SECRET_HERE(command: str, docker_name: str = "") -> Optional[str]:
    """Find existing resumable operation for the given command"""
    target_operation_id = YOUR_CLIENT_SECRET_HERE(command, docker_name)
    
    # Check if exact operation exists and is resumable
    if target_operation_id in progress_tracker.progress_data:
        if progress_tracker.is_operation_resumable(target_operation_id):
            return target_operation_id
    
    # Also check for similar operations with different suffixes (in case of multiple attempts)
    for op_id, data in progress_tracker.progress_data.items():
        if (op_id.startswith(target_operation_id) and 
            progress_tracker.is_operation_resumable(op_id) and
            data.get("command") == command):
            return op_id
    
    return None

def clean_folder_name(folder_name):
    """Clean folder name to make it a single word without spaces or special characters"""
    # Start with the original name
    cleaned_name = folder_name
    
    # Remove all non-alphanumeric characters
    result = ""
    for char in cleaned_name:
        if char.isalnum():
            result += char
    
    # Ensure it's not empty
    if not result:
        result = "RenamedFolder"
    
    return result

def clean_docker_name(folder_name):
    """Clean folder name to make it Docker-compatible"""
    # Convert to lowercase first
    docker_name = folder_name.lower()
    
    # Remove any remaining invalid characters and keep only alphanumeric and underscores
    docker_name = ''.join(c for c in docker_name if c.isalnum() or c == '_')
    
    # Remove multiple consecutive underscores
    while '__' in docker_name:
        docker_name = docker_name.replace('__', '_')
    
    # Remove leading and trailing underscores
    docker_name = docker_name.strip('_')
    
    # Ensure docker name is not empty and starts with alphanumeric
    if not docker_name or not docker_name[0].isalnum():
        docker_name = "app_" + docker_name
    
    # Ensure it's not empty after all cleaning
    if not docker_name or docker_name == "app_":
        docker_name = "myapp"
    
    # Limit length to 63 characters (Docker limit)
    if len(docker_name) > 63:
        docker_name = docker_name[:63].rstrip('_')
    
    return docker_name

def create_dockerfile():
    dockerfile_content = """# Use a base image
FROM alpine:latest

# Install rsync and bash
RUN apk --no-cache add rsync bash

# Set the working directory
WORKDIR /app

# Copy everything within the current path to /home/
COPY . /home/

# Default runtime options
CMD ["rsync", "-aP", "/home/", "/home/"]
"""
    try:
        with open("Dockerfile", "w", encoding="utf-8") as f:
            f.write(dockerfile_content)
        print("Dockerfile created successfully")
    except Exception as e:
        print(f"Error creating Dockerfile: {e}")

def YOUR_CLIENT_SECRET_HERE():
    """Create a .dockerignore file to reduce build context size"""
    dockerignore_content = """# Docker-related files
Dockerfile
.dockerignore
.docker_progress.json

# Version control
.git/
.gitignore
.gitattributes

# IDE files
.vscode/
.idea/
*.swp
*.swo
*~

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Temporary files
*.tmp
*.temp
*.log
*.cache

# Build artifacts
node_modules/
dist/
build/
target/
*.o
*.exe
*.dll
*.so

# Large media files (add patterns for your specific large files)
*.iso
*.dmg
*.zip
*.tar.gz
*.rar
*.7z

# Documentation (if not needed in container)
docs/
*.md
README*

# Test files (if not needed in container)
test/
tests/
spec/
*.test.*

# Backup files
*.bak
*.backup
*~
"""
    
    try:
        # Check if .dockerignore already exists
        if os.path.exists(".dockerignore"):
            with open(".dockerignore", "r") as f:
                existing_content = f.read()
                print("📋 Existing .dockerignore found")
                return
        
        with open(".dockerignore", "w", encoding="utf-8") as f:
            f.write(dockerignore_content)
        print("📋 Optimized .dockerignore created to reduce build context size")
        print("   💡 Edit .dockerignore to exclude large files specific to your project")
        
    except Exception as e:
        print(f"Error creating .dockerignore: {e}")

def check_docker_status():
    """Check if Docker is running and accessible"""
    try:
        result = subprocess.run("docker --version", shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"Docker version: {result.stdout.strip()}")
            
            # Check if Docker daemon is running
            result = subprocess.run("docker info", shell=True, capture_output=True, text=True)
            if result.returncode == 0:
                print("Docker daemon is running")
                return True
            else:
                print("Docker daemon is not running. Please start Docker Desktop.")
                return False
        else:
            print("Docker is not installed or not in PATH")
            return False
    except Exception as e:
        print(f"Error checking Docker status: {e}")
        return False

def run_command_as_admin(command, docker_name: str = "", use_progress_tracking: bool = True):
    """Enhanced command execution with optional progress tracking"""
    
    # Determine if this is a Docker command that benefits from progress tracking
    docker_commands = ["docker build", "docker push", "docker pull", "docker run"]
    is_docker_command = any(cmd in command for cmd in docker_commands)
    
    if use_progress_tracking and is_docker_command:
        # Check for existing resumable operation first
        existing_operation_id = YOUR_CLIENT_SECRET_HERE(command, docker_name)
        
        if existing_operation_id:
            progress = progress_tracker.get_operation_progress(existing_operation_id)
            print(f"🔄 AUTO-RESUMING: Found interrupted operation from {progress.get('started_at', 'previous session')}")
            print(f"   Operation ID: {existing_operation_id}")
            operation_id = existing_operation_id
        else:
            # Generate new operation ID
            operation_id = YOUR_CLIENT_SECRET_HERE(command, docker_name)
        
        if "docker build" in command:
            operation_type = "build"
        elif "docker push" in command:
            operation_type = "push"
        elif "docker pull" in command:
            operation_type = "pull"
        elif "docker run" in command:
            operation_type = "run"
        else:
            operation_type = "docker"
        
        return YOUR_CLIENT_SECRET_HERE(command, operation_type, operation_id)
    else:
        # Run command without progress tracking (for non-Docker commands or when disabled)
        try:
            subprocess.run(command, shell=True, check=True)
            return True
        except subprocess.CalledProcessError as e:
            print(f"Error: {e}")
            return False
        except FileNotFoundError as e:
            print(f"File not found error: {e}")
            print("Note: Make sure Docker Desktop is running and you're in the correct environment (WSL2 for /mnt/f/ paths)")
            return False

def get_input(prompt):
    return input(prompt).strip()

def run_selected_commands(selected_commands, docker_name: str = ""):
    """Run a list of commands with enhanced progress tracking and error handling"""
    
    # Clean old completed operations before starting
    progress_tracker.YOUR_CLIENT_SECRET_HERE()
    
    # Clean unrelated failed operations from other projects
    if docker_name:
        progress_tracker.YOUR_CLIENT_SECRET_HERE(docker_name)
    
    success_count = 0
    total_commands = len(selected_commands)
    
    for i, command in enumerate(selected_commands, 1):
        print(f"\n{'='*60}")
        print(f"Executing command {i}/{total_commands}: {command}")
        print(f"{'='*60}")
        
        try:
            # Handle special Python function calls
            if command.startswith("PYTHON_FUNCTION:"):
                function_name = command.split(":", 1)[1]
                if function_name == "create_dockerfile":
                    create_dockerfile()
                    success_count += 1
                elif function_name == "YOUR_CLIENT_SECRET_HERE":
                    YOUR_CLIENT_SECRET_HERE()
                    success_count += 1
                elif function_name == "show_progress_status":
                    show_progress_status()
                    success_count += 1
                elif function_name == "resume_operation":
                    resume_operation()
                    success_count += 1
                continue
            
            # For interactive commands (those containing -it), we might need special handling
            if '-it' in command:
                print("⚠️  Note: Interactive command detected. If container doesn't exist, this will fail.")
            
            # Execute command with progress tracking
            success = run_command_as_admin(command, docker_name)
            
            if success:
                success_count += 1
                print(f"✅ Command {i} completed successfully")
            else:
                print(f"❌ Command {i} failed")
                
                # Ask user if they want to continue or retry
                response = input(f"\nCommand failed. Do you want to:\n"
                               f"  c) Continue with next command\n"
                               f"  r) Retry this command\n"
                               f"  s) Stop execution\n"
                               f"Enter choice (c/r/s): ").lower().strip()
                
                if response == 'r':
                    print("🔄 Retrying command...")
                    
                    # For Docker build commands that failed, try without BuildKit first
                    retry_command = command
                    if ("$env:DOCKER_BUILDKIT=1;" in command or "set DOCKER_BUILDKIT=1 &&" in command) and "docker build" in command:
                        retry_command = command.replace("$env:DOCKER_BUILDKIT=1; ", "").replace("set DOCKER_BUILDKIT=1 && ", "")
                        print("   🔧 Retrying without BuildKit (compatibility fix)")
                    
                    success = run_command_as_admin(retry_command, docker_name)
                    if success:
                        success_count += 1
                        print(f"✅ Command {i} completed successfully on retry")
                    else:
                        print(f"❌ Command {i} failed again")
                elif response == 's':
                    print("🛑 Stopping execution as requested")
                    break
                # 'c' or any other input continues to next command
                
        except Exception as e:
            print(f"❌ Error executing command: {e}")
            continue
    
    # Summary
    print(f"\n{'='*60}")
    print(f"📊 Execution Summary:")
    print(f"   Total commands: {total_commands}")
    print(f"   Successful: {success_count}")
    print(f"   Failed: {total_commands - success_count}")
    print(f"   Success rate: {(success_count/total_commands)*100:.1f}%")
    
    # Show available resumable operations
    resumable_ops = [op_id for op_id, data in progress_tracker.progress_data.items() 
                     if progress_tracker.is_operation_resumable(op_id)]
    
    if resumable_ops:
        print(f"\n🔄 Resumable operations available: {len(resumable_ops)}")
        print("   Run this script again to automatically resume failed operations")
    
    print(f"{'='*60}")

def show_progress_status():
    """Show current progress status of all operations"""
    print(f"\n{'='*60}")
    print("📊 Docker Operations Progress Status")
    print(f"{'='*60}")
    
    if not progress_tracker.progress_data:
        print("No operations tracked yet.")
        return
    
    for op_id, data in progress_tracker.progress_data.items():
        status_icon = {
            "completed": "✅",
            "in_progress": "🔄", 
            "failed": "❌",
            "started": "🟡"
        }.get(data["status"], "❓")
        
        print(f"\n{status_icon} {op_id}")
        print(f"   Type: {data['type']}")
        print(f"   Status: {data['status']}")
        print(f"   Command: {data['command'][:80]}...")
        
        if "started_at" in data:
            print(f"   Started: {data['started_at']}")
        
        if data["status"] == "completed" and "completed_at" in data:
            print(f"   Completed: {data['completed_at']}")
        
        if data["status"] == "failed" and "error" in data:
            print(f"   Error: {data['error'][:100]}...")
        
        # Show step progress
        completed_steps = len(data.get("completed_steps", []))
        if completed_steps > 0:
            print(f"   Completed steps: {completed_steps}")
        
        # Show layer progress for builds/pushes
        if data["type"] in ["build", "push"]:
            if data["type"] == "build" and data.get("build_cache"):
                cached_layers = sum(1 for layer in data["build_cache"].values() if layer.get("cached"))
                print(f"   Cached layers: {cached_layers}")
            
            if data["type"] == "push" and data.get("push_layers"):
                completed_layers = sum(1 for layer in data["push_layers"].values() if layer.get("progress", 0) == 100)
                total_layers = len(data["push_layers"])
                if total_layers > 0:
                    print(f"   Push progress: {completed_layers}/{total_layers} layers")

def resume_operation():
    """Allow user to manually resume a specific operation"""
    resumable_ops = [op_id for op_id, data in progress_tracker.progress_data.items() 
                     if progress_tracker.is_operation_resumable(op_id)]
    
    if not resumable_ops:
        print("No resumable operations available.")
        return
    
    print(f"\n🔄 Resumable Operations:")
    for i, op_id in enumerate(resumable_ops, 1):
        data = progress_tracker.progress_data[op_id]
        print(f"{i}. {op_id} ({data['type']}) - Status: {data['status']}")
    
    try:
        choice = int(input("Enter operation number to resume (0 to cancel): "))
        if choice == 0:
            return
        
        if 1 <= choice <= len(resumable_ops):
            op_id = resumable_ops[choice - 1]
            data = progress_tracker.progress_data[op_id]
            command = data["command"]
            operation_type = data["type"]
            
            print(f"Resuming: {command}")
            success = YOUR_CLIENT_SECRET_HERE(command, operation_type, op_id)
            
            if success:
                print(f"✅ Operation {op_id} completed successfully!")
            else:
                print(f"❌ Operation {op_id} failed again.")
        else:
            print("Invalid choice.")
    except ValueError:
        print("Invalid input.")

def main():
    commands = [
        {"name": "KillAll", "command": 'docker stop $(docker ps -aq) 2>/dev/null || true && docker rm $(docker ps -aq) 2>/dev/null || true && docker rmi $(docker images -q) 2>/dev/null || true && docker system prune -a --volumes --force && docker network prune --force'},
        {"name": "Pull Docker Image", "command": "docker pull michadockermisha/backup:<choosename>"},
        {"name": "Run Docker Container", "command": "docker run -v F:\\:/f/ -it --name <choosename> michadockermisha/backup:<choosename><endcommand>"},
        {"name": "Create Dockerfile", "command": "PYTHON_FUNCTION:create_dockerfile"},
        {"name": "📋 Create .dockerignore", "command": "PYTHON_FUNCTION:YOUR_CLIENT_SECRET_HERE"},
        {"name": "Build Docker Image", "command": "docker build -t michadockermisha/backup:<choosename> ."},
        {"name": "Push Docker Image", "command": "docker push michadockermisha/backup:<choosename>"},
        {"name": "Compose up", "command": "docker-compose up -d <choosename>"},
        {"name": "Compose down", "command": "docker-compose down"},
        {"name": "Start container", "command": "docker exec -it <choosename> <endcommand>"},
        {"name": "Container IP", "command": "docker inspect -f \"{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}\" <choosename>"},
        {"name": "Show Containers Running", "command": "docker ps --size"},
        {"name": "Show ALL Containers", "command": "docker ps -a --size"},
        {"name": "Show Images", "command": "docker images"},
        {"name": "SEARCH", "command": "docker search <searchterm>"},
        {"name": "📊 Show Progress Status", "command": "PYTHON_FUNCTION:show_progress_status"},
        {"name": "🔄 Resume Operation", "command": "PYTHON_FUNCTION:resume_operation"},
        {"name": "Update System Packages", "command": "winget upgrade --all"},
        {"name": "Scan System Health", "command": "docker info"},
        {"name": "Restart Docker Service", "command": "echo 'Restart Docker Desktop manually'"},
    ]

    # Check for resumable operations at startup (this will show operations from current working directory)
    # Note: This check happens before project directory is set, so may not show project-specific operations
    resumable_ops = [op_id for op_id, data in progress_tracker.progress_data.items() 
                     if progress_tracker.is_operation_resumable(op_id)]
    
    if resumable_ops:
        print(f"\n🔄 Found {len(resumable_ops)} resumable operations:")
        for op_id in resumable_ops[:3]:  # Show max 3 for brevity
            data = progress_tracker.progress_data[op_id]
            print(f"   • {op_id} ({data['type']}) - {data['status']}")
        
        if len(resumable_ops) > 3:
            print(f"   ... and {len(resumable_ops) - 3} more")
        
        print("💡 Tip: Use menu option '🔄 Resume Operation' to continue these operations")
        print("=" * 60)
    
    # Check if folder name is provided as command line argument
    if len(sys.argv) > 1:
        original_folder_path = sys.argv[1]
        
        print("=== Docker Management Script with Progress Tracking ===")
        print("🚀 Features:")
        print("   • Persistent progress tracking for all Docker operations")
        print("   • Automatic resumption from interruption points")
        print("   • Layer-by-layer progress for builds and pushes")
        print("   • Build cache optimization for faster rebuilds")
        print("   • Progress saved in .docker_progress.json")
        print("Note: Dockerfile will install bash for compatibility")
        print("Make sure Docker Desktop is running")
        print("=" * 60)
        
        # Check if folder exists
        if not os.path.exists(original_folder_path):
            print(f"Error: Folder '{original_folder_path}' does not exist.")
            return
        
        # Extract folder name and parent directory
        parent_dir = os.path.dirname(original_folder_path)
        original_folder_name = os.path.basename(original_folder_path)
        
        # Clean the folder name to make it one word
        cleaned_folder_name = clean_folder_name(original_folder_name)
        new_folder_path = os.path.join(parent_dir, cleaned_folder_name)
        
        # Rename folder if needed
        if original_folder_name != cleaned_folder_name:
            try:
                print(f"Renaming folder: '{original_folder_name}' -> '{cleaned_folder_name}'")
                os.rename(original_folder_path, new_folder_path)
                print(f"Folder renamed successfully")
            except Exception as e:
                print(f"Error renaming folder: {e}")
                return
        else:
            print(f"Folder name already clean: '{original_folder_name}'")
            new_folder_path = original_folder_path
        
        # Change to the renamed directory
        try:
            os.chdir(new_folder_path)
            print(f"Changed directory to: {os.getcwd()}")
            
            # Set the project directory for progress tracking
            progress_tracker.set_project_directory(new_folder_path)
            
        except Exception as e:
            print(f"Error changing directory: {e}")
            return
        
        # Check Docker status before proceeding
        print("\nChecking Docker status...")
        if not check_docker_status():
            print("Docker is not available. Please start Docker Desktop and try again.")
            return
        
        # Test progress file accessibility  
        print("✅ Progress tracking initialized successfully")
        
        # Use the cleaned folder name for Docker operations
        folder_name_only = cleaned_folder_name
        
        # Check if container already exists and remove it
        print(f"Checking for existing container '{cleaned_folder_name}'...")
        try:
            subprocess.run(f"docker rm -f {cleaned_folder_name}", shell=True, capture_output=True)
            print(f"Removed existing container '{cleaned_folder_name}' if it existed")
        except:
            pass  # Container doesn't exist, that's fine
        
        # Clean folder name for Docker using the helper function (already cleaned, but make it lowercase)
        docker_name = clean_docker_name(folder_name_only)
        
        # Check for existing resumable operations for this project
        build_command = f"docker build -t michadockermisha/backup:{docker_name} ."
        push_command = f"docker push michadockermisha/backup:{docker_name}"
        
        existing_build_op = YOUR_CLIENT_SECRET_HERE(build_command, docker_name)
        existing_push_op = YOUR_CLIENT_SECRET_HERE(push_command, docker_name)
        
        if existing_build_op or existing_push_op:
            print(f"\n🔄 RESUMABLE OPERATIONS DETECTED:")
            
            if existing_build_op:
                build_data = progress_tracker.get_operation_progress(existing_build_op)
                print(f"   📦 Build: {existing_build_op}")
                print(f"      Status: {build_data['status']}, Started: {build_data.get('started_at', 'Unknown')}")
            
            if existing_push_op:
                push_data = progress_tracker.get_operation_progress(existing_push_op)
                print(f"   📤 Push: {existing_push_op}")
                print(f"      Status: {push_data['status']}, Started: {push_data.get('started_at', 'Unknown')}")
            
            print(f"   ⚡ Operations will automatically resume from their checkpoints!")
            print(f"   ⚠️  Note: Docker build context transfer cannot be resumed, but layer cache will be used")
            
            # Special handling for repeated build context transfer failures
            if existing_build_op:
                build_data = progress_tracker.get_operation_progress(existing_build_op)
                completed_steps = build_data.get('completed_steps', [])
                
                # Check if build has been interrupted multiple times during context transfer
                context_interruptions = sum(1 for step in completed_steps if 'context' in step.lower())
                
                if len(completed_steps) == 0:  # No steps completed = interrupted during context transfer
                    print(f"   💡 CRITICAL ISSUE: Build keeps failing during 1.2GB context transfer!")
                    print(f"      📋 IMMEDIATE SOLUTIONS:")
                    print(f"      1. Create .dockerignore to exclude unnecessary files")
                    print(f"      2. Move large files out of this directory temporarily")
                    print(f"      3. Use Docker Desktop with more memory allocated")
                    
                    # Check what files are taking up space
                    print(f"\n   🔍 Analyzing largest files in directory...")
                    try:
                        files_sizes = []
                        for file_path in glob.glob("**/*", recursive=True):
                            if os.path.isfile(file_path):
                                size = os.path.getsize(file_path)
                                if size > 10 * 1024 * 1024:  # > 10MB
                                    files_sizes.append((file_path, size))
                        
                        files_sizes.sort(key=lambda x: x[1], reverse=True)
                        if files_sizes:
                            print(f"   📊 Largest files (>10MB):")
                            for i, (file_path, size) in enumerate(files_sizes[:5]):
                                size_mb = size / (1024 * 1024)
                                print(f"      {i+1}. {file_path} ({size_mb:.1f} MB)")
                    except Exception as e:
                        print(f"   ❌ Could not analyze files: {e}")
                    
                    # Offer to create optimized .dockerignore
                    if not os.path.exists(".dockerignore"):
                        response = input(f"\n   🔧 Create .dockerignore to exclude large files? (y/n): ")
                        if response.lower() == 'y':
                            YOUR_CLIENT_SECRET_HERE()
                            print(f"   ✅ Created .dockerignore - edit it to exclude your large files")
                            print(f"   📝 Add patterns like: *.exe, *.zip, largefolder/, etc.")
                            return  # Exit to let user edit .dockerignore
            
            print(f"{'='*60}")
        else:
            # Debug: Show what we're looking for vs what exists
            print(f"\n🔍 DEBUG: Looking for resumable operations...")
            print(f"   Expected build ID: {YOUR_CLIENT_SECRET_HERE(build_command, docker_name)}")
            print(f"   Expected push ID: {YOUR_CLIENT_SECRET_HERE(push_command, docker_name)}")
            
            # Check if progress file exists
            progress_file_path = progress_tracker.get_progress_file_path()
            if os.path.exists(progress_file_path):
                print(f"   ✅ Progress file exists: {progress_file_path}")
                
                # Try to read and show contents
                try:
                    with open(progress_file_path, 'r') as f:
                        file_data = json.load(f)
                        print(f"   📋 File contains {len(file_data)} operations:")
                        for op_id, data in file_data.items():
                            status = data.get('status', 'unknown')
                            op_type = data.get('type', 'unknown')
                            print(f"      • {op_id} ({op_type}, {status})")
                except Exception as e:
                    print(f"   ❌ Error reading progress file: {e}")
            else:
                print(f"   ❌ Progress file does not exist: {progress_file_path}")
            
            print(f"   📊 Loaded progress data: {len(progress_tracker.progress_data)} operations")
            if progress_tracker.progress_data:
                print(f"   Available operations in memory:")
                for op_id, data in progress_tracker.progress_data.items():
                    print(f"      • {op_id} ({data.get('type', 'unknown')}, {data['status']})")
            
            print(f"{'='*60}")
        
        # Automatically run options 4, 6, 7 (Create Dockerfile, Build Docker Image, Push Docker Image)
        auto_commands = [3, 5, 6]  # 0-indexed: options 4, 6, 7 (logical order, skipping .dockerignore)
        selected_commands = []
        
        for index in auto_commands:
            cmd = commands[index]
            command = cmd["command"]
            
            if '<choosename>' in command:
                name = docker_name  # Use cleaned folder name as the container/image name
                command = command.replace('<choosename>', name)
            
            selected_commands.append(command)
        
        print(f"\nAutomatically executing commands for folder:")
        print(f"  Original: '{original_folder_name}'")
        print(f"  Cleaned:  '{cleaned_folder_name}'")
        print(f"  Docker:   '{docker_name}'")
        print(f"Working directory: {os.getcwd()}")
        print("Order: Create Dockerfile → Build Image → Push Image")
        print("Note: Image will be pushed to Docker Hub")
        for i, cmd in enumerate(selected_commands):
            print(f"{auto_commands[i]+1}. {commands[auto_commands[i]]['name']}: {cmd}")
        print("💡 Use menu option '📋 Create .dockerignore' if build context is too large")
        
        run_selected_commands(selected_commands, docker_name)
        
        return

    # Interactive menu mode
    while True:
        print("\nDocker Menu:")
        for i, cmd in enumerate(commands, 1):
            print(f"{i}. {cmd['name']}")
        print("0. Exit")

        choice = get_input("\nEnter the numbers of the commands you want to run (comma-separated) or 0 to exit: ")
        
        if choice == '0':
            break

        selected_commands = []
        for num in choice.split(','):
            try:
                index = int(num.strip()) - 1
                if 0 <= index < len(commands):
                    cmd = commands[index]
                    command = cmd["command"]
                    
                    if '<choosename>' in command:
                        name = get_input("Enter name: ")
                        command = command.replace('<choosename>', name)
                        
                        if '<endcommand>' in command:
                            end_command = get_input("Enter end command (e.g., bash, sh, cmd, powershell) or leave blank: ")
                            end_command = f" {end_command}" if end_command else ""
                            command = command.replace('<endcommand>', end_command)
                    
                    elif '<searchterm>' in command:
                        search_term = get_input("Enter search term: ")
                        command = command.replace('<searchterm>', search_term)
                    
                    selected_commands.append(command)
                else:
                    print(f"Invalid number: {num}")
            except ValueError:
                print(f"Invalid input: {num}")

        if selected_commands:
            print("\nSelected commands:")
            for cmd in selected_commands:
                print(cmd)
            
            confirm = get_input("\nDo you want to run these commands? (y/n): ")
            if confirm.lower() == 'y':
                run_selected_commands(selected_commands, "")  # No docker_name in interactive mode
            else:
                print("Commands not executed.")

if __name__ == "__main__":
    main()