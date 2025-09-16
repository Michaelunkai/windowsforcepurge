# Revo Uninstaller Pro 5.4 Auto Installation Scripts

This collection of scripts will automatically install Revo Uninstaller Pro 5.4 from your cracked source directory to the installed directory.

## Scripts Available

### 1. PowerShell Script (Recommended) - `install_revo_uninstaller.ps1`
**Most comprehensive option with error handling and interactive features.**

**Features:**
- Detailed progress reporting
- Error handling and validation
- Interactive prompts for overwrite confirmation
- Automatic shortcut creation
- Setup file detection and execution
- Colored output for better visibility

**Usage:**
```powershell
# Basic usage
.\install_revo_uninstaller.ps1

# Force overwrite without prompts
.\install_revo_uninstaller.ps1 -Force

# Custom paths
.\install_revo_uninstaller.ps1 -SourcePath "C:\your\source\path" -DestinationPath "C:\your\dest\path"
```

### 2. Batch Script - `install_revo_simple.bat`
**Simple batch file for users who prefer traditional batch scripts.**

**Features:**
- Easy to understand and modify
- Interactive confirmation prompts
- Automatic executable detection
- Opens destination folder on completion

**Usage:**
- Double-click the file or run from command prompt
- Follow the on-screen prompts

### 3. Quick Install Command - `quick_install.cmd`
**One-liner for immediate installation without prompts.**

**Features:**
- No user interaction required
- Fast execution
- Opens destination folder when complete

**Usage:**
- Double-click for instant installation
- Use when you want minimal interaction

## Default Paths

- **Source:** `F:\backup\windowsapps\install\cracked\Revo Uninstaller Pro 5.4 Multilingual`
- **Destination:** `F:\backup\windowsapps\installed\RevoUninstallerPro`
- **License Source:** `F:\backup\windowsapps\install\cracked\Revo Uninstaller Pro 5.4 Multilingual\revouninstallerpro5.lic`
- **License Destination:** `C:\ProgramData\VS Revo Group\Revo Uninstaller Pro\revouninstallerpro5.lic`

## What the Scripts Do

✅ **Smart Installation**: Detects and runs installer with silent parameters, or copies files as portable installation  
✅ **Automatic License Activation**: Copies license file to activate the software immediately  
✅ **Desktop Shortcuts**: Creates shortcuts to the installed application  
✅ **Error Handling**: Comprehensive error checking and user feedback  
✅ **Overwrite Protection**: Confirms before overwriting existing installations  
✅ **Multiple Methods**: Try different installation approaches automatically  

## Prerequisites

1. Ensure the source directory exists and contains the Revo Uninstaller Pro files
2. Have sufficient disk space in the destination location
3. Run with appropriate permissions (Administrator recommended)

## Usage Instructions

### Method 1: PowerShell (Recommended)
1. Right-click on PowerShell and "Run as Administrator"
2. Navigate to the script directory
3. Run: `.\install_revo_uninstaller.ps1`
4. Follow the interactive prompts

### Method 2: Batch File
1. Right-click on `install_revo_simple.bat`
2. Select "Run as Administrator"
3. Follow the prompts

### Method 3: Quick Install
1. Right-click on `quick_install.cmd`
2. Select "Run as Administrator"
3. Installation runs automatically

## Manual Command Line Option

If you prefer to run the command manually, use this robocopy command:

```cmd
robocopy "F:\backup\windowsapps\install\cracked\Revo Uninstaller Pro 5.4 Multilingual" "F:\backup\windowsapps\installed\RevoUninstallerPro" /E /COPY:DAT /R:3 /W:5 /MT:8
```

## Troubleshooting

- **"Access Denied" errors:** Run as Administrator
- **"Source not found" errors:** Verify the source path exists
- **Copy errors:** Check disk space and file permissions
- **PowerShell execution policy:** Run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` if needed
- **License file not copied:** Ensure `revouninstallerpro5.lic` exists in source folder and run as Administrator
- **Software not activated:** Check if license file was copied to `C:\ProgramData\VS Revo Group\Revo Uninstaller Pro\`

## Notes

- The scripts will overwrite existing installations when confirmed
- Desktop shortcuts are created automatically (PowerShell version)
- All scripts use robocopy for efficient file copying
- The installation preserves file attributes and timestamps