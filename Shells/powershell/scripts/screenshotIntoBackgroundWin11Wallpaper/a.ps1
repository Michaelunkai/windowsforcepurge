# Set output encoding to UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Color definitions for a better visual experience
$RED = "`e[31m"
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$BLUE = "`e[34m"
$NC = "`e[0m"

# File paths
$STORAGEFILE = "$env:APPDATA\Cursor\User\globalStorage\storage.json"
$BACKUPDIR = "$env:APPDATA\Cursor\User\globalStorage\backups"

# ---

# Function to generate a random string
function Generate-RandomString {
    param(
        [int]$Length
    )
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    $result = ""
    for ($i = 0; $i -lt $Length; $i++) {
        $result += $chars[(Get-Random -Maximum $chars.Length)]
    }
    return $result
}

# ---

# Function to modify Cursor's core JS files to bypass device ID
function Modify-CursorJSFiles {
    Write-Host ""
    Write-Host "$BLUE🔧 [Kernel Modification]$NC Starting to modify Cursor core JS files to bypass device identification..."
    Write-Host ""
    
    $cursorAppPath = "${env:LOCALAPPDATA}\Programs\Cursor"

    if (-not (Test-Path $cursorAppPath)) {
        $alternatePaths = @(
            "${env:ProgramFiles}\Cursor",
            "${env:ProgramFiles(x86)}\Cursor",
            "${env:USERPROFILE}\AppData\Local\Programs\Cursor"
        )
        foreach ($path in $alternatePaths) {
            if (Test-Path $path) {
                $cursorAppPath = $path
                break
            }
        }
        if (-not (Test-Path $cursorAppPath)) {
            Write-Host "$RED❌ [Error]$NC Cursor application installation path not found"
            Write-Host "$YELLOW💡 [Tip]$NC Please confirm that Cursor is installed correctly"
            return $false
        }
    }
    Write-Host "$GREEN✅ [Found]$NC Found Cursor installation path: $cursorAppPath"

    $newUuid = [System.Guid]::NewGuid().ToString().ToLower()
    $machineId = "auth0|user_$(Generate-RandomString -Length 32)"
    $deviceId = [System.Guid]::NewGuid().ToString().ToLower()
    $macMachineId = Generate-RandomString -Length 64

    Write-Host "$GREEN🔑 [Generated]$NC New device identifiers have been generated"
    
    $jsFiles = @(
        "$cursorAppPath\resources\app\out\vs\workbench\api\node\extensionHostProcess.js",
        "$cursorAppPath\resources\app\out\main.js",
        "$cursorAppPath\resources\app\out\vs\code\node\cliProcessMain.js"
    )

    $modifiedCount = 0
    $needModification = $false

    Write-Host "$BLUE🔍 [Checking]$NC Checking JS file modification status..."
    foreach ($file in $jsFiles) {
        if (-not (Test-Path $file)) {
            Write-Host "$YELLOW⚠️ [Warning]$NC File does not exist: $(Split-Path $file -Leaf)"
            continue
        }
        $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
        if ($content -and $content -notmatch "return crypto\.randomUUID\(\)") {
            Write-Host "$BLUE📝 [Needed]$NC File needs modification: $(Split-Path $file -Leaf)"
            $needModification = $true
            break
        } else {
            Write-Host "$GREEN✅ [Modified]$NC File already modified: $(Split-Path $file -Leaf)"
        }
    }

    if (-not $needModification) {
        Write-Host "$GREEN✅ [Skipping]$NC All JS files have already been modified, no need to repeat"
        return $true
    }

    Write-Host "$BLUE🔄 [Closing]$NC Closing Cursor processes to modify files..."
    Stop-AllCursorProcesses -MaxRetries 3 -WaitSeconds 3 | Out-Null

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = "$env:TEMP\Cursor_JS_Backup_$timestamp"
    Write-Host "$BLUE💾 [Backup]$NC Creating Cursor JS file backup..."
    try {
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
        foreach ($file in $jsFiles) {
            if (Test-Path $file) {
                $fileName = Split-Path $file -Leaf
                Copy-Item $file "$backupPath\$fileName" -Force
            }
        }
        Write-Host "$GREEN✅ [Backup]$NC Backup created successfully: $backupPath"
    } catch {
        Write-Host "$RED❌ [Error]$NC Failed to create backup: $($_.Exception.Message)"
        return $false
    }
    
    Write-Host "$BLUE🔧 [Modifying]$NC Starting to modify JS files..."
    foreach ($file in $jsFiles) {
        if (-not (Test-Path $file)) {
            Write-Host "$YELLOW⚠️ [Skipping]$NC File does not exist: $(Split-Path $file -Leaf)"
            continue
        }
        Write-Host "$BLUE📝 [Processing]$NC Processing: $(Split-Path $file -Leaf)"
        try {
            $content = Get-Content $file -Raw -Encoding UTF8
            if ($content -match "return crypto\.randomUUID\(\)" -or $content -match "// Cursor ID Modification Tool Injected") {
                Write-Host "$GREEN✅ [Skipping]$NC File has already been modified"
                $modifiedCount++
                continue
            }

            $timestampVar = [DateTimeOffset]::Now.ToUnixTimeSeconds()
            $injectCode = @"
// Cursor ID Modification Tool Injected - $(Get-Date) - ES Module Compatible Version
import crypto from 'crypto';
const originalRandomUUID_${timestampVar} = crypto.randomUUID;
crypto.randomUUID = function() { return '${newUuid}'; };
globalThis.getMachineId = function() { return '${machineId}'; };
globalThis.getDeviceId = function() { return '${deviceId}'; };
globalThis.macMachineId = '${macMachineId}';
if (typeof window !== 'undefined') { window.getMachineId = globalThis.getMachineId; window.getDeviceId = globalThis.getDeviceId; window.macMachineId = globalThis.macMachineId; }
console.log('Cursor device identifier has been successfully hijacked');
"@

            if ($content -match "IOPlatformUUID") {
                Write-Host "$BLUE🔍 [Found]$NC Found IOPlatformUUID keyword"
                if ($content -match "function a\$") {
                    $content = $content -replace "function a\$\(t\)\{switch", "function a`$(t){return crypto.randomUUID(); switch"
                    Write-Host "$GREEN✅ [Success]$NC Modified a`$ function successfully"
                    $modifiedCount++
                    continue
                }
                $content = $injectCode + $content
                Write-Host "$GREEN✅ [Success]$NC Generic injection method modification successful"
                $modifiedCount++
            } elseif ($content -match "function t\$\(\)" -or $content -match "async function y5") {
                Write-Host "$BLUE🔍 [Found]$NC Found device ID related functions"
                if ($content -match "function t\$\(\)") {
                    $content = $content -replace "function t\$\(\)\{", "function t`$(){return `"00:00:00:00:00:00`";"
                    Write-Host "$GREEN✅ [Success]$NC Modified MAC address retrieval function"
                }
                if ($content -match "async function y5") {
                    $content = $content -replace "async function y5\(t\)\{", "async function y5(t){return crypto.randomUUID();"
                    Write-Host "$GREEN✅ [Success]$NC Modified device ID retrieval function"
                }
                $modifiedCount++
            } else {
                Write-Host "$YELLOW⚠️ [Warning]$NC Unknown device ID function pattern found, using generic injection"
                $content = $injectCode + $content
                $modifiedCount++
            }

            Set-Content -Path $file -Value $content -Encoding UTF8 -NoNewline
            Write-Host "$GREEN✅ [Complete]$NC File modification complete: $(Split-Path $file -Leaf)"
        } catch {
            Write-Host "$RED❌ [Error]$NC Failed to modify file: $($_.Exception.Message)"
            $fileName = Split-Path $file -Leaf
            $backupFile = "$backupPath\$fileName"
            if (Test-Path $backupFile) {
                Copy-Item $backupFile $file -Force
                Write-Host "$YELLOW🔄 [Restored]$NC File restored from backup"
            }
        }
    }
    
    if ($modifiedCount -gt 0) {
        Write-Host ""
        Write-Host "$GREEN🎉 [Complete]$NC Successfully modified $modifiedCount JS files"
        Write-Host "$BLUE💾 [Backup]$NC Original file backup location: $backupPath"
        Write-Host "$BLUE💡 [Note]$NC JavaScript injection enabled for device identification bypass"
        return $true
    } else {
        Write-Host "$RED❌ [Failed]$NC No files were successfully modified"
        return $false
    }
}

# ---

# Function to remove Cursor trial folders
function Remove-CursorTrialFolders {
    Write-Host ""
    Write-Host "$GREEN🎯 [Core Feature]$NC Executing Cursor trial Pro folder removal..."
    Write-Host "$BLUE📋 [Note]$NC This feature will delete specified Cursor-related folders to reset the trial status"
    Write-Host ""

    $foldersToDelete = @(
        "C:\Users\Administrator\.cursor",
        "C:\Users\Administrator\AppData\Roaming\Cursor",
        "$env:USERPROFILE\.cursor",
        "$env:APPDATA\Cursor"
    )

    Write-Host "$BLUE📂 [Checking]$NC The following folders will be checked:"
    foreach ($folder in $foldersToDelete) {
        Write-Host "   📁 $folder"
    }
    Write-Host ""

    $deletedCount = 0
    $skippedCount = 0
    $errorCount = 0

    foreach ($folder in $foldersToDelete) {
        Write-Host "$BLUE🔍 [Checking]$NC Checking folder: $folder"
        if (Test-Path $folder) {
            try {
                Write-Host "$YELLOW⚠️ [Warning]$NC Folder found, deleting..."
                Remove-Item -Path $folder -Recurse -Force -ErrorAction Stop
                Write-Host "$GREEN✅ [Success]$NC Deleted folder: $folder"
                $deletedCount++
            } catch {
                Write-Host "$RED❌ [Error]$NC Failed to delete folder: $folder"
                Write-Host "$RED💥 [Details]$NC Error message: $($_.Exception.Message)"
                $errorCount++
            }
        } else {
            Write-Host "$YELLOW⏭️ [Skipping]$NC Folder does not exist: $folder"
            $skippedCount++
        }
        Write-Host ""
    }

    Write-Host "$GREEN📊 [Statistics]$NC Operation completion statistics:"
    Write-Host "   ✅ Successfully deleted: $deletedCount folders"
    Write-Host "   ⏭️ Skipped: $skippedCount folders"
    Write-Host "   ❌ Failed to delete: $errorCount folders"
    Write-Host ""

    if ($deletedCount -gt 0) {
        Write-Host "$GREEN🎉 [Complete]$NC Cursor trial Pro folder removal complete!"
        Write-Host "$BLUE🔧 [Fixing]$NC Pre-creating necessary directory structure to avoid permission issues..."
        try {
            if (-not (Test-Path "$env:APPDATA\Cursor")) { New-Item -ItemType Directory -Path "$env:APPDATA\Cursor" -Force | Out-Null }
            if (-not (Test-Path "$env:USERPROFILE\.cursor")) { New-Item -ItemType Directory -Path "$env:USERPROFILE\.cursor" -Force | Out-Null }
            Write-Host "$GREEN✅ [Complete]$NC Directory structure pre-creation complete"
        } catch {
            Write-Host "$YELLOW⚠️ [Warning]$NC An issue occurred while pre-creating directories: $($_.Exception.Message)"
        }
    } else {
        Write-Host "$YELLOW🤔 [Tip]$NC No folders to delete were found, possibly already cleaned up"
    }
    Write-Host ""
}

# ---

# Function to restart Cursor and wait for config file generation
function Restart-CursorAndWait {
    Write-Host ""
    Write-Host "$GREEN🔄 [Restarting]$NC Restarting Cursor to regenerate the configuration file..."
    
    # This part of the original script was incomplete. I've added a more robust way to find the Cursor executable.
    $cursorPath = $null
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe",
        "$env:ProgramFiles\Cursor\Cursor.exe",
        "$env:ProgramFiles(x86)\Cursor\Cursor.exe",
        "$env:USERPROFILE\AppData\Local\Programs\Cursor\Cursor.exe"
    )
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $cursorPath = $path
            break
        }
    }

    if (-not $cursorPath) {
        Write-Host "$RED❌ [Error]$NC Could not find Cursor executable. Please check your installation."
        return $false
    }
    
    Write-Host "$BLUE📍 [Path]$NC Using path: $cursorPath"

    try {
        Write-Host "$GREEN🚀 [Starting]$NC Starting Cursor..."
        $process = Start-Process -FilePath $cursorPath -PassThru -WindowStyle Hidden
        Write-Host "$YELLOW⏳ [Waiting]$NC Waiting for Cursor to start and generate the config file..."

        $configPath = "$env:APPDATA\Cursor\User\globalStorage\storage.json"
        $maxWait = 45
        $waited = 0
        while (-not (Test-Path $configPath) -and $waited -lt $maxWait) {
            Write-Host "$YELLOW⏳ [Waiting]$NC Waiting for config file generation... ($waited/$maxWait seconds)"
            Start-Sleep -Seconds 1
            $waited++
        }

        if (Test-Path $configPath) {
            Write-Host "$GREEN✅ [Success]$NC Config file generated: $configPath"
            Write-Host "$YELLOW⏳ [Waiting]$NC Waiting 5 seconds to ensure the config file is fully written..."
            Start-Sleep -Seconds 5
        } else {
            Write-Host "$YELLOW⚠️ [Warning]$NC Config file not generated within the expected time"
            Write-Host "$BLUE💡 [Tip]$NC You may need to manually start Cursor once to generate the config file"
        }

        Write-Host "$YELLOW🔄 [Closing]$NC Closing Cursor for configuration modification..."
        if ($process -and -not $process.HasExited) {
            $process.Kill()
            $process.WaitForExit(5000)
        }
        Get-Process -Name "Cursor" -ErrorAction SilentlyContinue | Stop-Process -Force
        Get-Process -Name "cursor" -ErrorAction SilentlyContinue | Stop-Process -Force
        
        Write-Host "$GREEN✅ [Complete]$NC Cursor restart process complete"
        return $true
    } catch {
        Write-Host "$RED❌ [Error]$NC Failed to restart Cursor: $($_.Exception.Message)"
        return $false
    }
}

# ---

# Function to force-close all Cursor processes
function Stop-AllCursorProcesses {
    param(
        [int]$MaxRetries = 3,
        [int]$WaitSeconds = 5
    )
    Write-Host "$BLUE🔒 [Process Check]$NC Checking and closing all Cursor related processes..."

    $cursorProcessNames = @(
        "Cursor", "cursor", "Cursor Helper", "Cursor Helper (GPU)",
        "Cursor Helper (Plugin)", "Cursor Helper (Renderer)", "CursorUpdater"
    )

    for ($retry = 1; $retry -le $MaxRetries; $retry++) {
        Write-Host "$BLUE🔍 [Checking]$NC Process check attempt $retry/$MaxRetries..."
        
        $foundProcesses = @()
        foreach ($processName in $cursorProcessNames) {
            $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($processes) {
                $foundProcesses += $processes
                Write-Host "$YELLOW⚠️ [Found]$NC Process: $processName (PID: $($processes.Id -join ', '))"
            }
        }

        if ($foundProcesses.Count -eq 0) {
            Write-Host "$GREEN✅ [Success]$NC All Cursor processes are closed"
            return $true
        }
        Write-Host "$YELLOW🔄 [Closing]$NC Closing $($foundProcesses.Count) Cursor processes..."

        foreach ($process in $foundProcesses) {
            try { $process.CloseMainWindow() | Out-Null } catch {}
        }
        Start-Sleep -Seconds 3

        foreach ($processName in $cursorProcessNames) {
            $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($processes) {
                foreach ($process in $processes) {
                    try { Stop-Process -Id $process.Id -Force } catch {}
                }
            }
        }
        if ($retry -lt $MaxRetries) {
            Write-Host "$YELLOW⏳ [Waiting]$NC Waiting for $WaitSeconds seconds before rechecking..."
            Start-Sleep -Seconds $WaitSeconds
        }
    }
    Write-Host "$RED❌ [Failed]$NC Cursor processes are still running after $MaxRetries attempts"
    return $false
}

# ---

# Function to check file permissions and lock status
function Test-FileAccessibility {
    param(
        [string]$FilePath
    )
    Write-Host "$BLUE🔐 [Permission Check]$NC Checking file access permissions: $(Split-Path $FilePath -Leaf)"
    if (-not (Test-Path $FilePath)) {
        Write-Host "$RED❌ [Error]$NC File does not exist"
        return $false
    }
    try {
        $fileStream = [System.IO.File]::Open($FilePath, 'Open', 'ReadWrite', 'None')
        $fileStream.Close()
        Write-Host "$GREEN✅ [Permission]$NC File is readable and writable, not locked"
        return $true
    } catch [System.IO.IOException] {
        Write-Host "$RED❌ [Locked]$NC File is locked by another process: $($_.Exception.Message)"
        return $false
    } catch [System.UnauthorizedAccessException] {
        Write-Host "$YELLOW⚠️ [Permission]$NC File permissions are restricted, attempting to modify permissions..."
        try {
            $file = Get-Item $FilePath
            if ($file.IsReadOnly) { $file.IsReadOnly = $false }
            $fileStream = [System.IO.File]::Open($FilePath, 'Open', 'ReadWrite', 'None')
            $fileStream.Close()
            Write-Host "$GREEN✅ [Permission]$NC Permission fix successful"
            return $true
        } catch {
            Write-Host "$RED❌ [Permission]$NC Failed to fix permissions: $($_.Exception.Message)"
            return $false
        }
    } catch {
        Write-Host "$RED❌ [Error]$NC Unknown error: $($_.Exception.Message)"
        return $false
    }
}

# ---

# Function for Cursor initialization cleanup
function Invoke-CursorInitialization {
    Write-Host ""
    Write-Host "$GREEN🧹 [Initialization]$NC Performing Cursor initialization cleanup..."
    
    $BASE_PATH = "$env:APPDATA\Cursor\User"
    $filesToDelete = @(
        (Join-Path -Path $BASE_PATH -ChildPath "globalStorage\state.vscdb"),
        (Join-Path -Path $BASE_PATH -ChildPath "globalStorage\state.vscdb.backup")
    )
    $folderToCleanContents = Join-Path -Path $BASE_PATH -ChildPath "History"
    $folderToDeleteCompletely = Join-Path -Path $BASE_PATH -ChildPath "workspaceStorage"
    Write-Host "$BLUE🔍 [Debug]$NC Base path: $BASE_PATH"

    foreach ($file in $filesToDelete) {
        if (Test-Path $file) {
            try { Remove-Item -Path $file -Force -ErrorAction Stop } catch {}
            Write-Host "$GREEN✅ [Success]$NC Deleted file: $file"
        } else {
            Write-Host "$YELLOW⚠️ [Skipping]$NC File does not exist, skipping deletion: $file"
        }
    }
    if (Test-Path $folderToCleanContents) {
        try { Get-ChildItem -Path $folderToCleanContents -Recurse | Remove-Item -Force -Recurse -ErrorAction Stop } catch {}
        Write-Host "$GREEN✅ [Success]$NC Emptied folder contents: $folderToCleanContents"
    } else {
        Write-Host "$YELLOW⚠️ [Skipping]$NC Folder does not exist, skipping emptying: $folderToCleanContents"
    }
    if (Test-Path $folderToDeleteCompletely) {
        try { Remove-Item -Path $folderToDeleteCompletely -Recurse -Force -ErrorAction Stop } catch {}
        Write-Host "$GREEN✅ [Success]$NC Deleted folder: $folderToDeleteCompletely"
    } else {
        Write-Host "$YELLOW⚠️ [Skipping]$NC Folder does not exist, skipping deletion: $folderToDeleteCompletely"
    }
    Write-Host "$GREEN✅ [Complete]$NC Cursor initialization cleanup complete"
    Write-Host ""
}

# ---

# Function to modify the system registry MachineGuid
function Update-MachineGuid {
    try {
        Write-Host "$BLUE🔧 [Registry]$NC Modifying system registry MachineGuid..."
        
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Cryptography"
        if (-not (Test-Path $registryPath)) { New-Item -Path $registryPath -Force | Out-Null }
        
        $originalGuid = ""
        try {
            $currentGuid = Get-ItemProperty -Path $registryPath -Name MachineGuid -ErrorAction SilentlyContinue
            if ($currentGuid) { $originalGuid = $currentGuid.MachineGuid }
        } catch {}
        
        $backupFile = $null
        if ($originalGuid) {
            $backupFile = "$BACKUP_DIR\MachineGuid_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
            $backupResult = Start-Process "reg.exe" -ArgumentList "export", "`"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography`"", "`"$backupFile`"" -NoNewWindow -Wait -PassThru
            if ($backupResult.ExitCode -eq 0) {
                Write-Host "$GREEN✅ [Backup]$NC Registry key backed up to: $backupFile"
            }
        }
        
        $newGuid = [System.Guid]::NewGuid().ToString()
        Write-Host "$BLUE🔄 [Generating]$NC New MachineGuid: $newGuid"
        Set-ItemProperty -Path $registryPath -Name MachineGuid -Value $newGuid -Force -ErrorAction Stop
        
        $verifyGuid = (Get-ItemProperty -Path $registryPath -Name MachineGuid -ErrorAction Stop).MachineGuid
        if ($verifyGuid -ne $newGuid) { throw "Registry verification failed" }
        
        Write-Host "$GREEN✅ [Success]$NC Registry updated successfully:"
        Write-Host "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography"
        Write-Host "    MachineGuid    REG_SZ    $newGuid"
        return $true
    } catch {
        Write-Host "$RED❌ [Error]$NC Registry operation failed: $($_.Exception.Message)"
        if ($backupFile -and (Test-Path $backupFile)) {
            $restoreResult = Start-Process "reg.exe" -ArgumentList "import", "`"$backupFile`"" -NoNewWindow -Wait -PassThru
            if ($restoreResult.ExitCode -eq 0) {
                Write-Host "$GREEN✅ [Restore Successful]$NC Original registry value has been restored"
            }
        }
        return $false
    }
}

# ---

# Function to check the Cursor environment
function Test-CursorEnvironment {
    param(
        [string]$Mode = "FULL"
    )
    Write-Host ""
    Write-Host "$BLUE🔍 [Environment Check]$NC Checking Cursor environment..."

    $configPath = "$env:APPDATA\Cursor\User\globalStorage\storage.json"
    $cursorAppData = "$env:APPDATA\Cursor"
    $issues = @()

    if (-not (Test-Path $configPath)) {
        $issues += "Config file does not exist: $configPath"
    } else {
        try {
            $content = Get-Content $configPath -Raw -Encoding UTF8 -ErrorAction Stop
            $content | ConvertFrom-Json -ErrorAction Stop
            Write-Host "$GREEN✅ [Check]$NC Config file format is correct"
        } catch {
            $issues += "Config file format is incorrect: $($_.Exception.Message)"
        }
    }
    if (-not (Test-Path $cursorAppData)) {
        $issues += "Cursor application data directory does not exist: $cursorAppData"
    }
    
    $cursorFound = $false
    $cursorPaths = @("$env:LOCALAPPDATA\Programs\cursor\Cursor.exe", "$env:PROGRAMFILES\Cursor\Cursor.exe", "$env:PROGRAMFILES(X86)\Cursor\Cursor.exe")
    foreach ($path in $cursorPaths) {
        if (Test-Path $path) {
            Write-Host "$GREEN✅ [Check]$NC Cursor installation found: $path"
            $cursorFound = $true
            break
        }
    }
    if (-not $cursorFound) { $issues += "Cursor installation not found" }

    if ($issues.Count -eq 0) {
        Write-Host "$GREEN✅ [Environment Check]$NC All checks passed"
        return @{ Success = $true; Issues = @() }
    } else {
        Write-Host "$RED❌ [Environment Check]$NC Found $($issues.Count) issues:"
        foreach ($issue in $issues) { Write-Host "$RED  • ${issue}$NC" }
        return @{ Success = $false; Issues = $issues }
    }
}

# ---

# Function to modify machine code configuration in the JSON file
function Modify-MachineCodeConfig {
    param(
        [string]$Mode = "FULL"
    )
    Write-Host ""
    Write-Host "$GREEN🛠️ [Configuration]$NC Modifying machine code configuration..."

    $configPath = "$env:APPDATA\Cursor\User\globalStorage\storage.json"
    if (-not (Test-Path $configPath)) {
        Write-Host "$RED❌ [Error]$NC Configuration file does not exist: $configPath"
        Write-Host "$YELLOW💡 [Solution]$NC Please try to manually start and close Cursor before running this script again."
        return $false
    }
    
    if ($Mode -eq "MODIFY_ONLY") {
        Stop-AllCursorProcesses -MaxRetries 3 -WaitSeconds 3 | Out-Null
    }
    if (-not (Test-FileAccessibility -FilePath $configPath)) {
        Write-Host "$RED❌ [Error]$NC Unable to access the configuration file."
        return $false
    }
    
    try {
        $originalContent = Get-Content $configPath -Raw -Encoding UTF8 -ErrorAction Stop
        $config = $originalContent | ConvertFrom-Json -ErrorAction Stop
        Write-Host "$GREEN✅ [Verified]$NC Config file format is correct"
    } catch {
        Write-Host "$RED❌ [Error]$NC Config file format is incorrect: $($_.Exception.Message)"
        return $false
    }

    $maxRetries = 3
    $retryCount = 0
    while ($retryCount -lt $maxRetries) {
        $retryCount++
        Write-Host "$BLUE🔄 [Attempt]$NC Modification attempt $retryCount/$maxRetries..."
        try {
            $MAC_MACHINE_ID = [System.Guid]::NewGuid().ToString()
            $UUID = [System.Guid]::NewGuid().ToString()
            $MACHINE_ID = "auth0|user_$(Generate-RandomString -Length 32)"
            $SQM_ID = "{$([System.Guid]::NewGuid().ToString().ToUpper())}"

            $backupDir = "$env:APPDATA\Cursor\User\globalStorage\backups"
            if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force -ErrorAction Stop | Out-Null }
            $backupName = "storage.json.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')_retry$retryCount"
            $backupPath = "$backupDir\$backupName"
            Copy-Item $configPath $backupPath -ErrorAction Stop
            
            $config.'telemetry.machineId' = $MACHINE_ID
            $config.'telemetry.macMachineId' = $MAC_MACHINE_ID
            $config.'telemetry.devDeviceId' = $UUID
            $config.'telemetry.sqmId' = $SQM_ID
            
            $tempPath = "$configPath.tmp"
            $updatedJson = $config | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($tempPath, $updatedJson, [System.Text.Encoding]::UTF8)
            
            Remove-Item $configPath -Force
            Move-Item $tempPath $configPath
            
            Write-Host "$GREEN✅ [Success]$NC Modification successful!"
            Write-Host "$GREEN🎉 [Complete]$NC Machine code configuration modification complete!"
            Write-Host "$BLUE📋 [Details]$NC Updated identifiers:"
            Write-Host "   🔹 machineId: $MACHINE_ID"
            Write-Host "   🔹 macMachineId: $MAC_MACHINE_ID"
            Write-Host "   🔹 devDeviceId: $UUID"
            Write-Host "   🔹 sqmId: $SQM_ID"
            Write-Host "$GREEN💾 [Backup]$NC Original config backed up to: $backupName"
            
            try {
                $configFile = Get-Item $configPath
                $configFile.IsReadOnly = $true
                Write-Host "$GREEN✅ [Protected]$NC Config file set to read-only."
            } catch {}
            
            return $true
        } catch {
            Write-Host "$RED❌ [Error]$NC An error occurred: $($_.Exception.Message)"
            if (Test-Path $backupPath) {
                Copy-Item $backupPath $configPath -Force
                Write-Host "$GREEN✅ [Restored]$NC Original configuration restored."
            }
            if ($retryCount -lt $maxRetries) {
                Write-Host "$BLUE🔄 [Retry]$NC Retrying in 2 seconds..."
                Start-Sleep -Seconds 2
            }
        }
    }
    Write-Host "$RED❌ [Final Failure]$NC All retries failed. Please check for file permissions or other issues."
    return $false
}
