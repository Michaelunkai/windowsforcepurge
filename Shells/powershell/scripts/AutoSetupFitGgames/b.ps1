# === Watch-GameSetup-and-AHK.ps1 ===
$watchDir = "F:\Downloads"
$ahkPath = "F:\study\shells\powershell\scripts\AutoSetupFitGgames\a.ahk"
$ahkExe = "AutoHotkey.exe"  # Update if using AHK v2 or a custom compiled name
$ahkScriptName = "a.ahk"
$launchedSetups = @{}

function Ensure-AHK-Running {
    $isRunning = Get-Process | Where-Object { $_.ProcessName -like "*AutoHotkey*" -and $_.MainWindowTitle -eq $ahkScriptName } -ErrorAction SilentlyContinue
    if (-not $isRunning) {
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
        try {
            $stream = $setupFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            $stream.Close()
        } catch {
            Write-Host "[Watcher] $($setupFile.Name) is still in use. Waiting..."
            Start-Sleep -Seconds 5
            continue
        }

        Write-Host "[Watcher] Launching $($setupFile.FullName)..."
        Start-Process -FilePath $setupFile.FullName
        $launchedSetups[$setupFile.FullName] = $true

        Start-Sleep -Seconds 20
    } else {
        Start-Sleep -Seconds 5
    }
}

