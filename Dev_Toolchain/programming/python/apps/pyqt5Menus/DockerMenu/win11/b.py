import subprocess
import sys
import os

def run_command_as_admin(command):
    try:
        subprocess.run(command, shell=True, executable='cmd', check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error: {e}")

def get_input(prompt):
    return input(prompt).strip()

def run_selected_commands(selected_commands):
    for command in selected_commands:
        print(f"\nExecuting: {command}")
        run_command_as_admin(command)

def main():
    commands = [
        {"name": "KillAll", "command": 'docker stop $(docker ps -aq) 2>NUL & docker rm $(docker ps -aq) 2>NUL & docker rmi $(docker images -q) 2>NUL & docker system prune -a --volumes --force & docker network prune --force'},
        {"name": "Pull Docker Image", "command": "docker pull michadockermisha/backup:<choosename>"},
        {"name": "Run Docker Container", "command": "docker run -v C:\\:/c/ -it --name <choosename> michadockermisha/backup:<choosename><endcommand>"},
        {"name": "Create Dockerfile", "command": "echo # Use a base image > Dockerfile & echo FROM alpine:latest >> Dockerfile & echo. >> Dockerfile & echo # Install rsync >> Dockerfile & echo RUN apk --no-cache add rsync >> Dockerfile & echo. >> Dockerfile & echo # Set the working directory >> Dockerfile & echo WORKDIR /app >> Dockerfile & echo. >> Dockerfile & echo # Copy everything within the current path to /home/ >> Dockerfile & echo COPY . /home/ >> Dockerfile & echo. >> Dockerfile & echo # Default runtime options >> Dockerfile & echo CMD [\"rsync\", \"-aP\", \"/home/\", \"/home/\"] >> Dockerfile"},
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
        {"name": "Update Windows Packages", "command": "winget upgrade --all"},
        {"name": "Scan System Health", "command": "sc query state= all"},
        {"name": "Restore System Health", "command": "sfc /scannow"},
    ]

    # Check if folder name is provided as command line argument
    if len(sys.argv) > 1:
        folder_name = sys.argv[1]
        
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
        
        # Automatically run options 3, 4, 5 (Run Docker Container, Create Dockerfile, Build Docker Image)
        auto_commands = [2, 3, 4]  # 0-indexed: options 3, 4, 5
        selected_commands = []
        
        for index in auto_commands:
            cmd = commands[index]
            command = cmd["command"]
            
            if '<choosename>' in command:
                name = folder_name  # Use folder name as the container/image name
                command = command.replace('<choosename>', name)
                
                if '<endcommand>' in command:
                    if index == 2:  # Run Docker Container command
                        end_command = " bash"  # Default to bash for container
                    else:
                        end_command = ""
                    command = command.replace('<endcommand>', end_command)
            
            selected_commands.append(command)
        
        print(f"\nAutomatically executing commands for folder '{folder_name}':")
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
