# Setup script to add 'screenit' command to PowerShell profile
# Run this once to set up the screenit command

Write-Host "Setting up 'screenit' command..." -ForegroundColor Green

# Get the current script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$screenitScript = Join-Path $scriptDir "screenit.ps1"

# Check if screenit.ps1 exists
if (!(Test-Path $screenitScript)) {
    Write-Host "Error: screenit.ps1 not found in current directory!" -ForegroundColor Red
    exit 1
}

# Get PowerShell profile path
$profilePath = $PROFILE

# Create profile directory if it doesn't exist
$profileDir = Split-Path -Parent $profilePath
if (!(Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    Write-Host "Created profile directory: $profileDir" -ForegroundColor Yellow
}

# Function definition to add to profile
$functionDef = @"

# Screenit function - takes screenshot and sets as wallpaper
function screenit {
    & "$screenitScript"
}

"@

# Check if profile exists, create if not
if (!(Test-Path $profilePath)) {
    Write-Host "Creating PowerShell profile: $profilePath" -ForegroundColor Yellow
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

# Check if screenit function already exists in profile
$profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
if ($profileContent -and $profileContent.Contains("function screenit")) {
    Write-Host "screenit function already exists in profile. Updating..." -ForegroundColor Yellow
    # Remove existing function and add new one
    $profileContent = $profileContent -replace "(?s)# Screenit function.*?^}", ""
    $profileContent = $profileContent.Trim()
    $profileContent + $functionDef | Set-Content $profilePath
} else {
    Write-Host "Adding screenit function to profile..." -ForegroundColor Yellow
    Add-Content $profilePath $functionDef
}

Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "To use the command:" -ForegroundColor Cyan
Write-Host "1. Restart PowerShell or run: . `$PROFILE" -ForegroundColor White
Write-Host "2. Type 'screenit' from any directory" -ForegroundColor White
Write-Host ""
Write-Host "Screenshots will be saved to: $env:USERPROFILE\Pictures\Screenshots" -ForegroundColor Yellow