# Setup script for Ultimate Uninstaller function
# Run this once to create the 'uni' function

# Create the function definition
$functionDef = @'
function uni {
    param([Parameter(ValueFromRemainingArguments=$true)]$Apps)

    if ($Apps.Count -eq 0) {
        Write-Host "Usage: uni <app1> <app2> [app3] ..." -ForegroundColor Yellow
        Write-Host "Examples:" -ForegroundColor Cyan
        Write-Host "  uni wavebox" -ForegroundColor White
        Write-Host "  uni temp logs outlook" -ForegroundColor White
        return
    }

    $scriptPath = "F:\study\Dev_Toolchain\programming\python\apps\Uninstaller\UltimateUninstaller.ps1"

    if (-not (Test-Path $scriptPath)) {
        Write-Host "ERROR: UltimateUninstaller.ps1 not found at: $scriptPath" -ForegroundColor Red
        return
    }

    # Execute the uninstaller with all provided apps
    & $scriptPath -Apps $Apps
}
'@

# Add the function to the current session
Invoke-Expression $functionDef

# Add to PowerShell profile for persistence
$profilePath = $PROFILE
if (-not (Test-Path $profilePath)) {
    New-Item -Path $profilePath -Type File -Force | Out-Null
}

# Check if function already exists in profile
$profileContent = Get-Content $profilePath -ErrorAction SilentlyContinue
if ($profileContent -notcontains "function uni {") {
    Add-Content -Path $profilePath -Value "`n# Ultimate Uninstaller function"
    Add-Content -Path $profilePath -Value $functionDef
    Write-Host "✓ Function 'uni' added to PowerShell profile: $profilePath" -ForegroundColor Green
} else {
    Write-Host "✓ Function 'uni' already exists in PowerShell profile" -ForegroundColor Yellow
}

Write-Host "✓ Function 'uni' is now available in this session" -ForegroundColor Green
Write-Host ""
Write-Host "Usage:" -ForegroundColor Cyan
Write-Host "  uni wavebox temp logs outlook" -ForegroundColor White
Write-Host ""
Write-Host "Note: Run PowerShell as Administrator for full functionality" -ForegroundColor Yellow