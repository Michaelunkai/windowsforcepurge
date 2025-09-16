# 🚀 TodoNotes - One-Liner Setup

## Quick Start Commands

### Windows (PowerShell/Command Prompt)
```cmd
python run.py
```

### Windows (Batch Script)
```cmd
start.bat
```

### Linux/macOS (Terminal)
```bash
python3 run.py
```

### Linux/macOS (Shell Script)
```bash
./start.sh
```

### Direct Docker (if you prefer)
```bash
docker-compose up --build -d && echo "🌐 Open http://localhost:8000 in your browser"
```

## What the one-liner does:

1. ✅ **Checks Docker** - Verifies Docker is installed and running
2. 🏗️ **Builds Application** - Creates the Docker image with all dependencies
3. 🚀 **Starts Services** - Launches the web application on port 8000
4. ⏳ **Waits for Ready** - Ensures the app is fully loaded
5. 🌐 **Opens Browser** - Automatically opens http://localhost:8000
6. 📋 **Shows Info** - Displays all URLs and keyboard shortcuts
7. 🔄 **Keeps Running** - Maintains the application until you press Ctrl+C

## URLs after startup:
- **Dashboard**: http://localhost:8000
- **Tasks**: http://localhost:8000/tasks
- **Notes**: http://localhost:8000/notes

## Stop the application:
Press `Ctrl+C` in the terminal or run:
```bash
docker-compose down
```

That's it! One command and you have a fully functional task and note management system! 🎉