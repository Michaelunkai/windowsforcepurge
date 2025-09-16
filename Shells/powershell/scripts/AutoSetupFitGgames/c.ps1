$watchDir = "F:\Downloads"
$ahkPath = "F:\study\shells\powershell\scripts\AutoSetupFitGgames\a.ahk"
$ahkScriptName = "a.ahk"
$launchedSetups = @{}

function Ensure-AHK-Running {
    $running = Get-Process | Where-Object {
        $_.ProcessName -like "AutoHotkey*" -and $_.MainWindowTitle -eq $ahkScriptName
    } -ErrorAction SilentlyContinue

    if (-not $running) {
        Start-Process -FilePath $ahkPath -WindowStyle Hidden
        Write-Host "[AHK] a.ahk started"
    } else {
        Write-Host "[AHK] a.ahk is already running"
    }
}

Write-Host "[Watcher] Scanning $watchDir for setup.exe every 5 seconds..."

while ($true) {
    Ensure-AHK-Running

    $setupFile = Get-ChildItem -Path $watchDir -Filter "setup.exe" -Recurse -File |
                 Sort-Object LastWriteTime -Descending |
                 Where-Object { -not $launchedSetups.ContainsKey($_.FullName) } |
                 Select-Object -First 1

    if ($setupFile) {
        # Wait until the file is not locked
        try {
            $stream = $setupFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            $stream.Close()
        } catch {
            Write-Host "[Watcher] $($setupFile.Name) is still in use. Waiting..."
            Start-Sleep -Seconds 5
            continue
        }

        Write-Host "[Watcher] Launching $($setupFile.FullName)..."
        $proc = Start-Process -FilePath $setupFile.FullName -PassThru
        $launchedSetups[$setupFile.FullName] = $true

        # Wait for installer to finish
        $proc.WaitForExit()
        Write-Host "[Watcher] Installer finished."

        # Delete the parent folder of setup.exe
        $parentFolder = Split-Path $setupFile.FullName -Parent
        try {
            Remove-Item -Path $parentFolder -Recurse -Force
            Write-Host "[Watcher] Deleted folder: $parentFolder"
        } catch {
            Write-Host "[Watcher] Failed to delete folder: $parentFolder" -ForegroundColor Red
        }

        Start-Sleep -Seconds 5
    } else {
        Start-Sleep -Seconds 5
    }
}

