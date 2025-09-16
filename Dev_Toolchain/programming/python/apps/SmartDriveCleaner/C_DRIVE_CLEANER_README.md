# Drive Cleaner - File Size Analyzer

A powerful PyQt5 desktop application designed to help Windows users identify and optionally delete large files on their C:, E:, and F: drives to free up disk space.

## ⚠️ IMPORTANT SAFETY WARNING

**USE WITH EXTREME CAUTION!** This application can permanently delete files from your system **WITHOUT CONFIRMATION PROMPTS**. Always:
- **DOUBLE-CHECK** files before deleting - there are no "are you sure?" dialogs
- Verify the purpose of a file before deleting it
- Create backups of important data before use
- Run the application as administrator when necessary
- Understand that file deletion is **IMMEDIATE and IRREVERSIBLE**
- Be especially careful with bulk deletion operations

## Features

### 🔍 Multi-Drive Scanning
- **Drive Selection**: Choose between C:, E:, and F: drives
- Recursively scans the entire selected drive for all accessible files
- Handles permission errors gracefully (logs and continues)
- Excludes system-critical directories automatically

### 🛡️ Smart Filtering
- Automatically filters out files from critical system directories containing:
  - Microsoft, Asus, Nvidia (hardware/system files)
  - Python, pip (development environments)
  - Docker, WSL 2 (containerization tools)
  - WeModTools, Cursor (application files)

### 📊 Top 1000 Analysis
- Identifies and displays the 1000 largest files on your system
- Sorts files by size (largest to smallest)
- Shows file sizes in MB with 2 decimal precision

### 🖥️ User-Friendly GUI
- Modern PyQt5 interface with intuitive design
- Responsive table with sortable columns
- Real-time progress updates during scanning
- Comprehensive status messages

### 🗑️ Instant Deletion System
- **Immediate deletion** - No confirmation prompts for faster workflow
- Individual delete buttons for each file
- **Bulk selection and deletion** by clicking/selecting rows (Ctrl+Click, Shift+Click)
- Select All / Clear Selection buttons for mass operations
- **Copy selected entries** to clipboard for backup/sharing
- Real-time status updates with deletion count and space freed
- Automatic removal from display after successful deletion

### 💾 Real-Time Disk Space Monitoring
- **Live drive space display** for selected drive showing Free, Used, and Total space
- Updates automatically every 2 seconds
- Immediate refresh after file deletions
- Easy-to-read format in GB

## Installation & Setup

### Prerequisites
- Windows 10/11
- Python 3.6 or higher
- pip package manager

### Installation Steps

1. **Install Python Dependencies**
   ```bash
   pip install -r c_drive_cleaner_requirements.txt
   ```

2. **Run the Application**
   
   **Option A: Using Python directly**
   ```bash
   python c_drive_cleaner.py
   ```
   
   **Option B: Using the batch file**
   ```bash
   run_cleaner.bat
   ```

### Administrator Privileges

For optimal performance and access to all files:
1. Right-click on Command Prompt or PowerShell
2. Select "Run as administrator"
3. Navigate to the application directory
4. Run the application

## How to Use

### 1. Launch the Application
- Start the application using one of the methods above
- Read the safety warnings displayed in the interface

### 2. Select Drive and Start Scanning
- **Choose your drive**: Click C:, E:, or F: drive buttons to select which drive to scan
- Click the "🔍 Start [Drive]: Drive Scan" button (updates based on selection)
- The application will begin scanning your selected drive
- Progress updates will appear in the status bar
- Use "⏹️ Stop Scan" if you need to cancel

### 3. Review Results
- Once scanning completes, the top 1000 largest files will be displayed
- The table shows:
  - **File Path**: Complete path to the file
  - **Size (MB)**: File size in megabytes (2 decimal places)
  - **Action**: Delete button for each file
- **Selection**: Click rows to select (Ctrl+Click for multiple, Shift+Click for range)

### 4. Delete Files (Optional)

**Individual File Deletion:**
- Click the "🗑️ Delete" button next to any file you want to remove
- **NEW**: Files are deleted immediately without confirmation prompts
- Status bar shows success/failure for each deletion
- The file will be permanently removed from your system

**Bulk File Operations:**
- **Row Selection**: Click on table rows to select files
  - Single click: Select one file
  - Ctrl+Click: Add/remove files from selection
  - Shift+Click: Select range of files
- Click "☑️ Select All" to select all displayed files
- Click "☐ Clear Selection" to unselect all files  
- Click "🗑️ Delete Selected" to delete all selected files at once
- Click "📋 Copy Selected" to copy all selected file paths to clipboard
- Status bar shows total files deleted and space freed

**Real-Time Space Monitoring:**
- Watch the disk space display update automatically as you delete files
- See immediate feedback on space freed from deletions

**Copy to Clipboard:**
- Creates a formatted report with:
  - Header with application name and total file count
  - Summary with total size in MB and GB
  - List of all selected files with their paths and sizes
  - Timestamp of when the list was generated
- Perfect for creating backups before deletion or sharing file lists

**Example Clipboard Output:**
```
E: Drive Cleaner - Selected Files List
==================================================
Total Files: 3
Total Size: 2048.50 MB (2.00 GB)

File Path | Size (MB)
--------------------------------------------------------------------------------
E:\Media\LargeVideo.mp4 | 1024.25
E:\Backups\OldBackup.zip | 512.75
E:\Archive\Documents.rar | 511.50

Generated on: 2024-01-15 14:30:22
```

## 🎯 **Quick Usage Workflow:**

1. **Choose Drive** → Click C:, E:, or F: drive button to select
2. **Scan** → Click "🔍 Start [Drive]: Drive Scan"
3. **Monitor** → Watch real-time disk space at the top
4. **Select** → Click on table rows (Ctrl+Click, Shift+Click for multiple)
5. **Copy** → Use "📋 Copy Selected" to backup file lists (optional but recommended)
6. **Delete** → Individual buttons or "Delete Selected" for bulk deletion
7. **Track** → See immediate space freed in status and disk display

## Technical Details

### Architecture
- **Main Thread**: Handles GUI updates and user interactions
- **Background Thread**: Performs file system scanning to keep GUI responsive
- **Signal/Slot System**: Ensures thread-safe communication

### Performance Optimizations
- Efficient `os.walk()` traversal
- Directory-level filtering to skip entire subtrees
- Progress updates every 1000 files to minimize GUI overhead
- Memory-efficient file data storage

### Error Handling
- **Permission Errors**: Logged and skipped, scan continues
- **File Not Found**: Handled gracefully during deletion
- **General I/O Errors**: Comprehensive error messages displayed
- **Thread Safety**: Proper cleanup on application exit

### File Filtering Logic
The application excludes files whose paths contain these keywords (case-insensitive):
- `microsoft` - Windows system files
- `asus` - ASUS hardware/software files  
- `nvidia` - NVIDIA graphics drivers/software
- `python` - Python installation files
- `pip` - Python package manager files
- `docker` - Docker containerization files
- `wsl 2` - Windows Subsystem for Linux files
- `wemod` - WeModTools application files
- `cursor` - Cursor IDE files

## Troubleshooting

### "Permission Denied" Errors
- Run the application as administrator
- Some system files cannot be deleted even with admin rights (this is normal)

### Application Not Responding
- Large drives may take time to scan (progress shown in status bar)
- Use the "Stop Scan" button if needed

### Files Not Appearing in Results
- Check if file paths contain filtered keywords
- Ensure files are accessible (not locked by other processes)

### Deletion Failures  
- Verify file still exists (may have been moved/deleted)
- Check if file is currently in use by another application
- Ensure sufficient permissions

## Safety Best Practices

1. **Always backup important data** before using any file deletion tool
2. **Research unfamiliar files** before deleting them
3. **Start with smaller, obviously unnecessary files** (downloads, temp files, etc.)
4. **Avoid deleting system files** even if they appear large
5. **Monitor system performance** after deletions
6. **Keep the application updated** for latest safety improvements

## Support & Development

This application is designed for experienced Windows users who understand file system management. If you're unsure about deleting any file, please:
- Research the file online
- Consult with IT professionals
- Use built-in Windows disk cleanup tools first

## License

This software is provided "as-is" without any warranties. Users are responsible for any consequences of file deletions performed with this tool.

---

**Remember: File deletion is permanent. When in doubt, don't delete!**