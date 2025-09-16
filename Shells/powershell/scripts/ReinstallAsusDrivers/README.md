# Deep System Cleanup Scripts

This collection of PowerShell and batch scripts performs a comprehensive deep cleanup of a Windows system, including:

1. System-cleanup MCP simulation
2. Deletion of system volume information files
3. Removal of restore point related files
4. Deletion of pagefiles and hibernation files
5. Automatic execution of cleanmgr on C drive
6. Complete removal of temporary and garbage files
7. Execution of final custom commands

## Files Included

1. `deep_cleanup.ps1` - A standalone PowerShell script that performs all cleanup tasks
2. `run_cleanup.bat` - Batch file to execute the standalone script without confirmation prompts
3. `cleanup_module.psm1` - PowerShell module containing the main cleanup function
4. `main_cleanup.ps1` - Main script that imports and executes the cleanup module
5. `run_main_cleanup.bat` - Batch file to execute the main cleanup script

## Usage

### Method 1: Using the batch file (Recommended)
1. Right-click on `run_main_cleanup.bat`
2. Select "Run as administrator"
3. The cleanup process will start automatically without any user prompts

### Method 2: Using PowerShell directly
1. Open PowerShell as Administrator
2. Navigate to this directory
3. Run: `.\main_cleanup.ps1`

### Method 3: Importing the module manually
1. Open PowerShell as Administrator
2. Navigate to this directory
3. Run: `Import-Module .\cleanup_module.psm1`
4. Run: `Invoke-DeepSystemCleanup -SkipConfirmation`

## ⚠️ Important Warnings

- These scripts must be run as Administrator
- The cleanup process is extensive and irreversible
- System restore points will be deleted
- Pagefiles and hibernation files will be disabled
- All temporary files will be removed
- Please restart your computer after running these scripts

## Estimated Runtime

The complete cleanup process should take less than 10 minutes on most systems.

## Customization

If you need to modify the behavior of any part of the cleanup process, you can edit the `cleanup_module.psm1` file.