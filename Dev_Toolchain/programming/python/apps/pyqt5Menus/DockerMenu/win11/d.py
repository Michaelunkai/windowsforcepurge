import subprocess
import sys
import os

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

def run_command_as_admin(command):
    try:
        subprocess.run(command, shell=True, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error: {e}")
    except FileNotFoundError as e:
        print(f"File not found error: {e}")
        print("Note: Make sure Docker Desktop is running and you're in the correct environment (WSL2 for /mnt/f/ paths)")

def get_input(prompt):
    return input(prompt).strip()

def run_selected_commands(selected_commands):
    for command in selected_commands:
        print(f"\nExecuting: {command}")
        try:
            # Handle special Python function calls
            if command.startswith("PYTHON_FUNCTION:"):
                function_name = command.split(":", 1)[1]
                if function_name == "create_dockerfile":
                    create_dockerfile()
                continue
            
            # For interactive commands (those containing -it), we might need special handling
            if '-it' in command:
                print("Note: Interactive command detected. If container doesn't exist, this will fail.")
            run_command_as_admin(command)
        except Exception as e:
            print(f"Error executing command: {e}")
            continue

def clean_docker_name(folder_name):
    """Clean folder name to make it Docker-compatible"""
    # Convert to lowercase first
    docker_name = folder_name.lower()
    
    # Define invalid characters for Docker names
    invalid_chars = [
        ' ', '(', ')', '[', ']', '{', '}', '&', '@', '#', '$', '%', '^',
        '!', '*', '+', '=', '?', '<', '>', '|', '"', "'", ':', ';',
        ',', '.', '\\', '/', '~', '`'
    ]
    
    # Replace invalid characters with underscores
    for char in invalid_chars:
        docker_name = docker_name.replace(char, '_')
    
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

def main():
    commands = [
        {"name": "KillAll", "command": 'docker stop $(docker ps -aq) 2>/dev/null || true && docker rm $(docker ps -aq) 2>/dev/null || true && docker rmi $(docker images -q) 2>/dev/null || true && docker system prune -a --volumes --force && docker network prune --force'},
        {"name": "Pull Docker Image", "command": "docker pull michadockermisha/backup:<choosename>"},
        {"name": "Run Docker Container", "command": "docker run -v F:\\:/f/ -it --name <choosename> michadockermisha/backup:<choosename><endcommand>"},
        {"name": "Create Dockerfile", "command": "PYTHON_FUNCTION:create_dockerfile"},
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
        {"name": "Update System Packages", "command": "winget upgrade --all"},
        {"name": "Scan System Health", "command": "docker info"},
        {"name": "Restart Docker Service", "command": "echo 'Restart Docker Desktop manually'"},
    ]

    # Check if folder name is provided as command line argument
    if len(sys.argv) > 1:
        folder_name = sys.argv[1]
        
        print("=== Docker Management Script ===")
        print("Note: Dockerfile will install bash for compatibility")
        print("Make sure Docker Desktop is running")
        print("=" * 40)
        
        # Check if folder exists
        if not os.path.exists(folder_name):
            print(f"Error: Folder '{folder_name}' does not exist.")
            return
        
        # Change to the specified directory
        try:
            os.chdir(folder_name)
            print(f"Changed directory to: {os.getcwd()}")
        except Exception as e:
            print(f"Error changing directory: {e}")
            return
        
        # Check Docker status before proceeding
        print("Checking Docker status...")
        if not check_docker_status():
            print("Docker is not available. Please start Docker Desktop and try again.")
            return
        
        # Extract just the folder name from the full path
        folder_name_only = os.path.basename(folder_name)
        
        # Clean folder name for Docker using the helper function
        docker_name = clean_docker_name(folder_name_only)
        
        # Check if container already exists and remove it
        print(f"Checking for existing container '{docker_name}'...")
        try:
            subprocess.run(f"docker rm -f {docker_name}", shell=True, capture_output=True)
            print(f"Removed existing container '{docker_name}' if it existed")
        except:
            pass  # Container doesn't exist, that's fine
        
        # Automatically run options 4, 5, 6 (Create Dockerfile, Build Docker Image, Push Docker Image)
        auto_commands = [3, 4, 5]  # 0-indexed: options 4, 5, 6 (logical order)
        selected_commands = []
        
        for index in auto_commands:
            cmd = commands[index]
            command = cmd["command"]
            
            # Replace volume mount placeholder
            if '<volume_mount>' in command:
                volume_mount = get_volume_mount_path()
                command = command.replace('<volume_mount>', volume_mount)
            
            if '<choosename>' in command:
                name = docker_name  # Use cleaned folder name as the container/image name
                command = command.replace('<choosename>', name)
                
                if '<endcommand>' in command:
                    if index == 2:  # Run Docker Container command (now executed last)
                        end_command = " bash"  # Now we install bash in the Dockerfile
                    else:
                        end_command = ""
                    command = command.replace('<endcommand>', end_command)
            
            selected_commands.append(command)
        
        print(f"\nAutomatically executing commands for folder '{folder_name_only}' (Docker name: '{docker_name}'):")
        print(f"Working directory: {os.getcwd()}")
        print("Order: Create Dockerfile → Build Image → Push Image")
        print("Note: Image will be pushed to Docker Hub")
        for i, cmd in enumerate(selected_commands):
            print(f"{auto_commands[i]+1}. {commands[auto_commands[i]]['name']}: {cmd}")
        
        run_selected_commands(selected_commands)
        
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
                run_selected_commands(selected_commands)
            else:
                print("Commands not executed.")

if __name__ == "__main__":
    main()