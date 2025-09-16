# === Watch-GameSetup.ps1 ===
$watchDir = "F:\Downloads"
$launchedSetups = @{}

Write-Host "[Watcher] Scanning $watchDir for setup.exe every 5 seconds..."

while ($true) {
    # Get newest setup.exe that hasn't been launched yet
    $setupFile = Get-ChildItem -Path $watchDir -Filter "setup.exe" -Recurse -File |
                 Sort-Object LastWriteTime -Descending |
                 Where-Object { -not $launchedSetups.ContainsKey($_.FullName) } |
                 Select-Object -First 1

    if ($setupFile) {
        # Check if the file is locked (still downloading)
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

        # Wait 20 seconds before processing the next one
        Start-Sleep -Seconds 20
    } else {
        # No new setup.exe found, wait a short time
        Start-Sleep -Seconds 5
    }
}
