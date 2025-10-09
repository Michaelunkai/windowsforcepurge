#include "utils.h"
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <ctime>
#include <iomanip>
#include <windows.h>

// Function to get current timestamp
std::string getCurrentTimestamp() {
    auto now = std::time(nullptr);
    auto tm = *std::localtime(&now);
    std::ostringstream oss;
    oss << std::put_time(&tm, "%Y-%m-%d %H:%M:%S");
    return oss.str();
}

// Function to create the PowerShell execution script
bool createPowerShellScript(const std::string& scriptPath, const std::string& commandPath, 
                           const std::string& flagPath, const std::string& taskName, 
                           const std::string& logPath) {
    std::string psScript = 
        "# Auto Multi-Command Script - PowerShell 5 Compatible - ONE-TIME EXECUTION ONLY\n"
        "param()\n"
        "\n"
        "$LogPath = '" + logPath + "'\n"
        "$CommandPath = '" + commandPath + "'\n"
        "$FlagPath = '" + flagPath + "'\n"
        "$TaskName = '" + taskName + "'\n"
        "$LockFile = 'C:\\Windows\\Temp\\MultiCommand.lock'\n"
        "\n"
        "function Write-Log {\n"
        "    param([string]$Message, [string]$Color = \"White\")\n"
        "\n"
        "    try {\n"
        "        $Timestamp = Get-Date -Format \"yyyy-MM-dd HH:mm:ss\"\n"
        "        $LogEntry = \"$Timestamp - $Message\"\n"
        "        $LogEntry | Out-File -FilePath $LogPath -Append -Force -Encoding UTF8\n"
        "\n"
        "        # Also write to console with color for immediate feedback\n"
        "        $ColorMap = @{"
        "            \"Red\" = [System.ConsoleColor]::Red\n"
        "            \"Green\" = [System.ConsoleColor]::Green\n"
        "            \"Yellow\" = [System.ConsoleColor]::Yellow\n"
        "            \"Cyan\" = [System.ConsoleColor]::Cyan\n"
        "            \"Magenta\" = [System.ConsoleColor]::Magenta\n"
        "            \"White\" = [System.ConsoleColor]::White\n"
        "        }\n"
        "\n"
        "        if ($ColorMap.ContainsKey($Color)) {\n"
        "            Write-Host $LogEntry -ForegroundColor $ColorMap[$Color]\n"
        "        } else {\n"
        "            Write-Host $LogEntry\n"
        "        }\n"
        "    }\n"
        "    catch {\n"
        "        # Silently fail if logging doesn't work\n"
        "        Write-Host $Message\n"
        "    }\n"
        "}\n"
        "\n"
        "function Test-AlreadyExecuted {\n"
        "    Write-Log \"=== CHECKING ONE-TIME EXECUTION STATUS ===\" \"Yellow\"\n"
        "\n"
        "    # Check 1: Lock file (prevents concurrent execution)\n"
        "    if (Test-Path $LockFile) {\n"
        "        Write-Log \"EXECUTION BLOCKED: Lock file exists - script may already be running\" \"Red\"\n"
        "        return $true\n"
        "    }\n"
        "\n"
        "    # Check 2: Flag file existence and content\n"
        "    if (-not (Test-Path $FlagPath)) {\n"
        "        Write-Log \"EXECUTION BLOCKED: Flag file missing - commands already executed or cleaned up\" \"Red\"\n"
        "        return $true\n"
        "    }\n"
        "\n"
        "    try {\n"
        "        $FlagContent = Get-Content $FlagPath -Raw -Encoding UTF8 | ConvertFrom-Json\n"
        "\n"
        "        # Check 3: Already executed flag\n"
        "        if ($FlagContent.Executed -eq $true) {\n"
        "            Write-Log \"EXECUTION BLOCKED: Commands already executed (flag marked as executed)\" \"Red\"\n"
        "            return $true\n"
        "        }\n"
        "\n"
        "        # Check 4: One-time only flag\n"
        "        if ($FlagContent.OneTimeOnly -ne $true) {\n"
        "            Write-Log \"EXECUTION BLOCKED: Not marked as one-time execution\" \"Red\"\n"
        "            return $true\n"
        "        }\n"
        "\n"
        "        Write-Log \"EXECUTION APPROVED: All checks passed - ready to execute ONE TIME\" \"Green\"\n"
        "        Write-Log \"Commands to execute: $($FlagContent.Command)\" \"Cyan\"\n"
        "        Write-Log \"Created by: $($FlagContent.CreatedBy)\" \"White\"\n"
        "        Write-Log \"Created on: $($FlagContent.Timestamp)\" \"White\"\n"
        "\n"
        "        return $false\n"
        "\n"
        "    }\n"
        "    catch {\n"
        "        Write-Log \"EXECUTION BLOCKED: Could not read or parse flag file: $($_.Exception.Message)\" \"Red\"\n"
        "        return $true\n"
        "    }\n"
        "}\n"
        "\n"
        "function Create-LockFile {\n"
        "    try {\n"
        "        $LockContent = @{\n"
        "            StartTime = (Get-Date).ToString(\"yyyy-MM-dd HH:mm:ss\")\n"
        "            ProcessId = $PID\n"
        "            Purpose = \"Prevent concurrent execution\"\n"
        "        }\n"
        "        $LockContent | ConvertTo-Json | Out-File -FilePath $LockFile -Encoding UTF8 -Force\n"
        "        Write-Log \"Lock file created to prevent re-execution\" \"Yellow\"\n"
        "    }\n"
        "    catch {\n"
        "        Write-Log \"Warning: Could not create lock file: $($_.Exception.Message)\" \"Yellow\"\n"
        "    }\n"
        "}\n"
        "\n"
        "function Mark-AsExecuted {\n"
        "    try {\n"
        "        if (Test-Path $FlagPath) {\n"
        "            $FlagContent = Get-Content $FlagPath -Raw -Encoding UTF8 | ConvertFrom-Json\n"
        "            $FlagContent.Executed = $true\n"
        "            $FlagContent.ExecutedAt = (Get-Date).ToString(\"yyyy-MM-dd HH:mm:ss\")\n"
        "            $FlagContent.ExecutedBy = $env:USERNAME\n"
        "            $FlagContent.Note = \"EXECUTED - Will never run again\"\n"
        "            $FlagContent | ConvertTo-Json | Out-File -FilePath $FlagPath -Encoding UTF8 -Force\n"
        "            Write-Log \"FLAG UPDATED: Marked as executed - will NEVER run again\" \"Magenta\"\n"
        "        }\n"
        "    }\n"
        "    catch {\n"
        "        Write-Log \"Warning: Could not update execution flag: $($_.Exception.Message)\" \"Yellow\"\n"
        "    }\n"
        "}\n"
        "\n"
        "function Invoke-MultiCommand {\n"
        "    Write-Log \"=== STARTING ONE-TIME MULTI-COMMAND EXECUTION ===\" \"Cyan\"\n"
        "\n"
        "    # CRITICAL: Check if we should execute (one-time only)\n"
        "    if (Test-AlreadyExecuted) {\n"
        "        Write-Log \"=== EXECUTION CANCELLED - ALREADY RAN OR BLOCKED ===\" \"Red\"\n"
        "        Write-Log \"Press any key to close...\" \"White\"\n"
        "        $null = $Host.UI.RawUI.ReadKey(\"NoEcho,IncludeKeyDown\")\n"
        "        Start-ImmediateCleanup\n"
        "        return\n"
        "    }\n"
        "\n"
        "    # Create lock file to prevent concurrent execution\n"
        "    Create-LockFile\n"
        "\n"
        "    try {\n"
        "        # Read the custom command from file\n"
        "        if (Test-Path $CommandPath) {\n"
        "            $CustomCommand = Get-Content $CommandPath -Raw -Encoding UTF8\n"
        "            $CustomCommand = $CustomCommand.Trim()\n"
        "            Write-Log \"Multi-command loaded: $CustomCommand\" \"Green\"\n"
        "        } else {\n"
        "            Write-Log \"ERROR: Command file not found at $CommandPath\" \"Red\"\n"
        "            Write-Log \"Press any key to close...\" \"White\"\n"
        "            $null = $Host.UI.RawUI.ReadKey(\"NoEcho,IncludeKeyDown\")\n"
        "            Start-ImmediateCleanup\n"
        "            return\n"
        "        }\n"
        "\n"
        "        if ([string]::IsNullOrWhiteSpace($CustomCommand)) {\n"
        "            Write-Log \"ERROR: Custom command is empty\" \"Red\"\n"
        "            Write-Log \"Press any key to close...\" \"White\"\n"
        "            $null = $Host.UI.RawUI.ReadKey(\"NoEcho,IncludeKeyDown\")\n"
        "            Start-ImmediateCleanup\n"
        "            return\n"
        "        }\n"
        "\n"
        "        # CRITICAL: Mark as executed IMMEDIATELY to prevent any re-execution\n"
        "        Write-Log \"=== MARKING AS EXECUTED TO PREVENT RE-EXECUTION ===\" \"Magenta\"\n"
        "        Mark-AsExecuted\n"
        "\n"
        "        Write-Log \"=== EXECUTING YOUR CUSTOM COMMANDS (ONE TIME ONLY) ===\" \"Cyan\"\n"
        "\n"
        "        # Set execution policy temporarily\n"
        "        try {\n"
        "            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force\n"
        "            Write-Log \"Execution policy set to Bypass for this process\" \"Green\"\n"
        "        }\n"
        "        catch {\n"
        "            Write-Log \"Warning: Could not set execution policy: $($_.Exception.Message)\" \"Yellow\"\n"
        "        }\n"
        "\n"
        "        # Parse commands (split by semicolon)\n"
        "        $Commands = $CustomCommand -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }\n"
        "        \n"
        "        Write-Log \"Found $($Commands.Count) commands to execute sequentially\" \"Cyan\"\n"
        "        Write-Log \"=== COMMAND EXECUTION STARTING ===\" \"Green\"\n"
        "\n"
        "        # Execute each command sequentially\n"
        "        for ($i = 0; $i -lt $Commands.Count; $i++) {\n"
        "            $CurrentCommand = $Commands[$i]\n"
        "            $CommandNumber = $i + 1\n"
        "            \n"
        "            Write-Log \"\" \"White\"\n"
        "            Write-Log \"*** EXECUTING COMMAND $CommandNumber OF $($Commands.Count) ***\" \"Cyan\"\n"
        "            Write-Log \"Command: $CurrentCommand\" \"White\"\n"
        "            Write-Log \"---\" \"Gray\"\n"
        "\n"
        "            try {\n"
        "                # Execute command with comprehensive error handling\n"
        "                $CommandResult = Invoke-Expression $CurrentCommand 2>&1\n"
        "\n"
        "                if ($CommandResult) {\n"
        "                    $ResultString = $CommandResult | Out-String\n"
        "                    Write-Log \"Output: $ResultString\" \"White\"\n"
        "                } else {\n"
        "                    Write-Log \"Command completed successfully with no output\" \"Green\"\n"
        "                }\n"
        "\n"
        "                Write-Log \"*** COMMAND $CommandNumber COMPLETED SUCCESSFULLY ***\" \"Green\"\n"
        "                \n"
        "                # Small delay between commands for visibility\n"
        "                if ($i -lt ($Commands.Count - 1)) {\n"
        "                    Write-Log \"Waiting 2 seconds before next command...\" \"Yellow\"\n"
        "                    Start-Sleep -Seconds 2\n"
        "                }\n"
        "            }\n"
        "            catch {\n"
        "                Write-Log \"ERROR executing command $CommandNumber`: $($_.Exception.Message)\" \"Red\"\n"
        "\n"
        "                # Try alternative execution method\n"
        "                Write-Log \"Attempting alternative execution method for command $CommandNumber...\" \"Yellow\"\n"
        "                try {\n"
        "                    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo\n"
        "                    $ProcessInfo.FileName = \"powershell.exe\"\n"
        "                    $ProcessInfo.Arguments = \"-ExecutionPolicy Bypass -Command `\"$CurrentCommand`\"\"\n"
        "                    $ProcessInfo.UseShellExecute = $false\n"
        "                    $ProcessInfo.RedirectStandardOutput = $true\n"
        "                    $ProcessInfo.RedirectStandardError = $true\n"
        "                    $ProcessInfo.CreateNoWindow = $false\n"
        "\n"
        "                    $Process = New-Object System.Diagnostics.Process\n"
        "                    $Process.StartInfo = $ProcessInfo\n"
        "                    $Process.Start() | Out-Null\n"
        "                    $Process.WaitForExit()\n"
        "\n"
        "                    $Output = $Process.StandardOutput.ReadToEnd()\n"
        "                    $Errors = $Process.StandardError.ReadToEnd()\n"
        "\n"
        "                    if ($Output) { Write-Log \"Alternative method output: $Output\" \"White\" }\n"
        "                    if ($Errors) { Write-Log \"Alternative method errors: $Errors\" \"Yellow\" }\n"
        "\n"
        "                    Write-Log \"Alternative execution method completed for command $CommandNumber\" \"Green\"\n"
        "                }\n"
        "                catch {\n"
        "                    Write-Log \"Alternative execution method failed for command $CommandNumber`: $($_.Exception.Message)\" \"Red\"\n"
        "                }\n"
        "                \n"
        "                # Small delay before next command even if this one failed\n"
        "                if ($i -lt ($Commands.Count - 1)) {\n"
        "                    Write-Log \"Waiting 2 seconds before next command...\" \"Yellow\"\n"
        "                    Start-Sleep -Seconds 2\n"
        "                }\n"
        "            }\n"
        "        }\n"
        "\n"
        "        Write-Log \"\" \"White\"\n"
        "        Write-Log \"=== ALL COMMANDS EXECUTION COMPLETED ===\" \"Green\"\n"
        "        Write-Log \"Total commands executed: $($Commands.Count)\" \"Cyan\"\n"
        "        Write-Log \"\" \"White\"\n"
        "        Write-Log \"*** MULTI-COMMAND EXECUTION FINISHED ***\" \"Magenta\"\n"
        "        Write-Log \"This window will remain open for 30 seconds for you to review the output...\" \"Yellow\"\n"
        "        \n"
        "        # Keep window open for review\n"
        "        for ($countdown = 30; $countdown -gt 0; $countdown--) {\n"
        "            Write-Host \"`rWindow will close in $countdown seconds... (Press any key to close immediately)\" -NoNewline -ForegroundColor Yellow\n"
        "            \n"
        "            if ($Host.UI.RawUI.KeyAvailable) {\n"
        "                $null = $Host.UI.RawUI.ReadKey(\"NoEcho,IncludeKeyDown\")\n"
        "                break\n"
        "            }\n"
        "            \n"
        "            Start-Sleep -Seconds 1\n"
        "        }\n"
        "        \n"
        "        Write-Log \"\" \"White\"\n"
        "        Write-Log \"Closing window and cleaning up...\" \"Yellow\"\n"
        "\n"
        "    }\n"
        "    catch {\n"
        "        Write-Log \"CRITICAL ERROR in command execution: $($_.Exception.Message)\" \"Red\"\n"
        "        Write-Log \"Press any key to close...\" \"White\"\n"
        "        $null = $Host.UI.RawUI.ReadKey(\"NoEcho,IncludeKeyDown\")\n"
        "    }\n"
        "    finally {\n"
        "        # Always clean up, regardless of success or failure\n"
        "        Write-Log \"=== STARTING CLEANUP TO PREVENT FUTURE EXECUTION ===\" \"Yellow\"\n"
        "        Start-ThoroughCleanup\n"
        "    }\n"
        "}\n"
        "\n"
        "function Start-ImmediateCleanup {\n"
        "    Write-Log \"=== IMMEDIATE CLEANUP - REMOVING ALL TRACES ===\" \"Yellow\"\n"
        "\n"
        "    try {\n"
        "        # Remove lock file\n"
        "        if (Test-Path $LockFile) {\n"
        "            Remove-Item $LockFile -Force -ErrorAction SilentlyContinue\n"
        "            Write-Log \"Removed lock file\" \"Green\"\n"
        "        }\n"
        "\n"
        "        # Delete the scheduled task immediately\n"
        "        try {\n"
        "            $DeleteResult = & schtasks.exe /delete /tn $TaskName /f 2>&1\n"
        "            Write-Log \"Task deletion result: $DeleteResult\" \"White\"\n"
        "        }\n"
        "        catch {\n"
        "            Write-Log \"Task deletion error: $($_.Exception.Message)\" \"Yellow\"\n"
        "        }\n"
        "\n"
        "        # Also try PowerShell method\n"
        "        try {\n"
        "            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue\n"
        "            Write-Log \"PowerShell task deletion attempted\" \"Green\"\n"
        "        }\n"
        "        catch {\n"
        "            Write-Log \"PowerShell task deletion error: $($_.Exception.Message)\" \"Yellow\"\n"
        "        }\n"
        "\n"
        "        Write-Log \"Immediate cleanup completed\" \"Green\"\n"
        "\n"
        "    }\n"
        "    catch {\n"
        "        Write-Log \"Immediate cleanup error: $($_.Exception.Message)\" \"Red\"\n"
        "    }\n"
        "}\n"
        "\n"
        "function Start-ThoroughCleanup {\n"
        "    Write-Log \"=== THOROUGH CLEANUP - ENSURING NO FUTURE EXECUTION ===\" \"Yellow\"\n"
        "\n"
        "    # Wait a moment for any processes to finish\n"
        "    Start-Sleep -Seconds 2\n"
        "\n"
        "    try {\n"
        "        # Remove lock file\n"
        "        if (Test-Path $LockFile) {\n"
        "            Remove-Item $LockFile -Force -ErrorAction SilentlyContinue\n"
        "            Write-Log \"Removed lock file\" \"Green\"\n"
        "        }\n"
        "\n"
        "        # Delete the scheduled task (multiple methods)\n"
        "        try {\n"
        "            $DeleteResult = & schtasks.exe /delete /tn $TaskName /f 2>&1\n"
        "            if ($LASTEXITCODE -eq 0) {\n"
        "                Write-Log \"Successfully deleted scheduled task: $TaskName\" \"Green\"\n"
        "            } else {\n"
        "                Write-Log \"Task may already be deleted: $DeleteResult\" \"White\"\n"
        "            }\n"
        "        }\n"
        "        catch {\n"
        "            Write-Log \"schtasks deletion: $($_.Exception.Message)\" \"Yellow\"\n"
        "        }\n"
        "\n"
        "        # Also try PowerShell method\n"
        "        try {\n"
        "            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue\n"
        "            Write-Log \"PowerShell task deletion completed\" \"Green\"\n"
        "        }\n"
        "        catch {\n"
        "            Write-Log \"PowerShell task deletion: $($_.Exception.Message)\" \"Yellow\"\n"
        "        }\n"
        "\n"
        "        # Delete all related files\n"
        "        $FilesToDelete = @($CommandPath, $FlagPath)\n"
        "        foreach ($FileToDelete in $FilesToDelete) {\n"
        "            if (Test-Path $FileToDelete) {\n"
        "                Remove-Item $FileToDelete -Force -ErrorAction SilentlyContinue\n"
        "                Write-Log \"Deleted file: $FileToDelete\" \"Green\"\n"
        "            }\n"
        "        }\n"
        "\n"
        "        # Schedule self-deletion of the script\n"
        "        $SelfDeleteScript = @\"\n"
        "# Self-deletion script - removes all traces\n"
        "Start-Sleep -Seconds 5\n"
        "try {\n"
        "    Remove-Item 'C:\\Windows\\Temp\\AutoMultiCommand.ps1' -Force -ErrorAction SilentlyContinue\n"
        "    Remove-Item 'C:\\Windows\\Temp\\SelfDelete.ps1' -Force -ErrorAction SilentlyContinue\n"
        "    Remove-Item 'C:\\Windows\\Temp\\MultiCommand.*' -Force -ErrorAction SilentlyContinue\n"
        "} catch {}\n"
        "\"@\n"
        "\n"
        "        $SelfDeletePath = \"C:\\Windows\\Temp\\SelfDelete.ps1\"\n"
        "        $SelfDeleteScript | Out-File -FilePath $SelfDeletePath -Encoding UTF8 -Force\n"
        "\n"
        "        Start-Process -FilePath \"powershell.exe\" -ArgumentList \"-WindowStyle Hidden -ExecutionPolicy Bypass -File `\"$SelfDeletePath`\"\" -WindowStyle Hidden -ErrorAction SilentlyContinue\n"
        "\n"
        "        Write-Log \"Scheduled complete self-deletion - all traces will be removed\" \"Green\"\n"
        "        Write-Log \"=== CLEANUP COMPLETED - WILL NEVER RUN AGAIN ===\" \"Green\"\n"
        "\n"
        "    }\n"
        "    catch {\n"
        "        Write-Log \"Cleanup error: $($_.Exception.Message)\" \"Red\"\n"
        "    }\n"
        "}\n"
        "\n"
        "# ========================================\n"
        "# MAIN EXECUTION - ONE TIME ONLY\n"
        "# ========================================\n"
        "\n"
        "try {\n"
        "    # Set console title\n"
        "    $Host.UI.RawUI.WindowTitle = \"Multi-Command Executor - ONE TIME ONLY\"\n"
        "    \n"
        "    # Make sure console is visible and properly sized\n"
        "    try {\n"
        "        $Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(120, 50)\n"
        "        $Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(120, 30)\n"
        "    } catch {\n"
        "        # Ignore sizing errors\n"
        "    }\n"
        "\n"
        "    Write-Log \"=== AutoMultiCommand Script Started - ONE-TIME EXECUTION ONLY ===\" \"Cyan\"\n"
        "    Write-Log \"Current user: $env:USERNAME\" \"White\"\n"
        "    Write-Log \"Computer: $env:COMPUTERNAME\" \"White\"\n"
        "    Write-Log \"Date/Time: $(Get-Date)\" \"White\"\n"
        "\n"
        "    Write-Log \"Waiting 15 seconds after login for system stabilization...\" \"Yellow\"\n"
        "    for ($i = 15; $i -gt 0; $i--) {\n"
        "        Write-Host \"`rSystem stabilization: $i seconds remaining...\" -NoNewline -ForegroundColor Yellow\n"
        "        Start-Sleep -Seconds 1\n"
        "    }\n"
        "    Write-Log \"\" \"White\"\n"
        "    Write-Log \"System stabilization complete - proceeding with command execution\" \"Green\"\n"
        "\n"
        "    # Execute the custom commands (ONE TIME ONLY)\n"
        "    Invoke-MultiCommand\n"
        "\n"
        "    Write-Log \"=== SCRIPT EXECUTION COMPLETED - WILL NEVER RUN AGAIN ===\" \"Magenta\"\n"
        "\n"
        "}\n"
        "catch {\n"
        "    Write-Log \"CRITICAL ERROR in main script: $($_.Exception.Message)\" \"Red\"\n"
        "\n"
        "    # Emergency cleanup\n"
        "    try {\n"
        "        Write-Log \"Attempting emergency cleanup...\" \"Yellow\"\n"
        "        Start-ThoroughCleanup\n"
        "    }\n"
        "    catch {\n"
        "        Write-Log \"Emergency cleanup failed: $($_.Exception.Message)\" \"Red\"\n"
        "    }\n"
        "    \n"
        "    Write-Log \"Press any key to close...\" \"White\"\n"
        "    $null = $Host.UI.RawUI.ReadKey(\"NoEcho,IncludeKeyDown\")\n"
        "}\n";

    return writeFile(scriptPath, psScript);
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cout << "Usage: " << argv[0] << " \"command1; command2; command3\" [options]" << std::endl;
        std::cout << "Options:" << std::endl;
        std::cout << "  --skip-reboot: Skip reboot after setup" << std::endl;
        std::cout << "  --debug: Enable debug output" << std::endl;
        return 1;
    }

    bool skipReboot = false;
    bool debug = false;
    
    // Parse arguments
    std::string command = argv[1];
    for (int i = 2; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--skip-reboot") {
            skipReboot = true;
        } else if (arg == "--debug") {
            debug = true;
        }
    }

    if (debug) {
        std::cout << "Debug: Command received: " << command << std::endl;
    }

    // Check for admin rights
    if (!isRunningAsAdmin()) {
        std::cerr << "Error: This program must be run as Administrator." << std::endl;
        return 1;
    }

    if (debug) {
        std::cout << "Debug: Running with administrator privileges" << std::endl;
    }

    // Define paths
    std::string scriptDir = "C:\\Windows\\Temp";
    std::string scriptPath = scriptDir + "\\AutoMultiCommand.ps1";
    std::string commandPath = scriptDir + "\\MultiCommand.txt";
    std::string flagPath = scriptDir + "\\MultiCommand.flag";
    std::string taskName = "AutoMultiCommandTask";
    std::string logPath = scriptDir + "\\AutoMultiCommand.log";

    if (debug) {
        std::cout << "Debug: Script directory: " << scriptDir << std::endl;
        std::cout << "Debug: Script path: " << scriptPath << std::endl;
        std::cout << "Debug: Command path: " << commandPath << std::endl;
    }

    // Create the PowerShell script
    std::cout << "Creating PowerShell execution script..." << std::endl;
    if (!createPowerShellScript(scriptPath, commandPath, flagPath, taskName, logPath)) {
        std::cerr << "Failed to create PowerShell execution script." << std::endl;
        return 1;
    }
    std::cout << "PowerShell script created successfully." << std::endl;

    // Save the custom command
    std::cout << "Saving command to file..." << std::endl;
    if (!writeFile(commandPath, command)) {
        std::cerr << "Failed to save command to file." << std::endl;
        return 1;
    }
    std::cout << "Command saved to: " << commandPath << std::endl;

    // Create execution flag
    std::cout << "Creating execution flag..." << std::endl;
    std::string flagContent = "{\n";
    flagContent += "  \"UniqueId\": \"" + generateGUID() + "\",\n";
    flagContent += "  \"Timestamp\": \"" + getCurrentTimestamp() + "\",\n";
    flagContent += "  \"Command\": \"" + command + "\",\n";
    flagContent += "  \"Executed\": false,\n";
    flagContent += "  \"Version\": \"3.0-MULTI-COMMAND\",\n";
    flagContent += "  \"CreatedBy\": \"" + executeCommand("echo %USERNAME%") + "\",\n";
    flagContent += "  \"ComputerName\": \"" + executeCommand("echo %COMPUTERNAME%") + "\",\n";
    flagContent += "  \"OneTimeOnly\": true,\n";
    flagContent += "  \"MultiCommand\": true\n";
    flagContent += "}";
    
    if (!writeFile(flagPath, flagContent)) {
        std::cerr << "Failed to create execution flag." << std::endl;
        return 1;
    }
    std::cout << "Execution flag created: " << flagPath << std::endl;

    // Create scheduled task via command line
    // This is a simpler approach that doesn't require complex COM libraries
    std::cout << "Creating scheduled task..." << std::endl;
    std::string taskCommand = "schtasks /create /tn \"" + taskName + "\" /tr \"powershell.exe -ExecutionPolicy Bypass -NoProfile -File \\\"" + scriptPath + "\\\"\" /sc ONLOGON /rl HIGHEST /f";
    std::string taskResult = executeCommand(taskCommand);
    
    if (taskResult.find("ERROR") != std::string::npos || taskResult.empty()) {
        std::cerr << "Failed to create scheduled task." << std::endl;
        std::cout << "Task creation output: " << taskResult << std::endl;
        std::cout << "You can create it manually using: " << taskCommand << std::endl;
    } else {
        std::cout << "Scheduled task created successfully: " << taskName << std::endl;
        std::cout << "Task creation output: " << taskResult << std::endl;
    }

    // Summary
    std::cout << "\n=== SETUP COMPLETE ===" << std::endl;
    std::cout << "Script path: " << scriptPath << std::endl;
    std::cout << "Command file: " << commandPath << std::endl;
    std::cout << "Flag file: " << flagPath << std::endl;
    std::cout << "Task name: " << taskName << std::endl;
    std::cout << "Custom commands: " << command << std::endl;
    std::cout << "Log file: " << logPath << std::endl;
    std::cout << "\n*** ONE-TIME MULTI-COMMAND SETUP COMPLETE ***" << std::endl;
    std::cout << "Commands will run SEQUENTIALLY in a VISIBLE window ONLY ONCE after next login!" << std::endl;
    std::cout << "After execution, ALL files will be deleted automatically!" << std::endl;

    if (!skipReboot) {
        std::cout << "\nRebooting in 10 seconds... Press Ctrl+C to cancel." << std::endl;
        Sleep(10000); // Wait 10 seconds
        
        // Reboot the system
        std::cout << "Rebooting now..." << std::endl;
        std::string rebootCmd = "shutdown /r /f /t 0";
        executeCommand(rebootCmd);
    } else {
        std::cout << "\nReboot skipped as requested." << std::endl;
    }

    return 0;
}