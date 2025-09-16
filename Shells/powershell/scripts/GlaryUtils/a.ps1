# Glary Utilities Complete Automation Script
# Usage: .\GlaryAuto.ps1 [-Verbose]

param(
    [switch]$Verbose
)

$glaryPath = "F:\backup\windowsapps\installed\glaryutilities"

if (-not (Test-Path $glaryPath)) {
    Write-Error "Glary Utilities path not found: $glaryPath"
    exit 1
}

Push-Location $glaryPath

Write-Host "Starting comprehensive Glary Utilities automation..." -ForegroundColor Green

# Main Glary Utilities with 1-Click Maintenance
$mainExe = Get-ChildItem -Recurse -Name "GlaryUtilities.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($mainExe) {
    Write-Host "Running 1-Click Maintenance..." -ForegroundColor Yellow
    Start-Process $mainExe -ArgumentList "/AUTO", "/SILENT" -Wait -ErrorAction SilentlyContinue
}

# Registry Cleaner
$regCleaner = Get-ChildItem -Recurse -Name "*Registry*Clean*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($regCleaner) {
    Write-Host "Running Registry Cleaner..." -ForegroundColor Yellow
    Start-Process $regCleaner -ArgumentList "/AUTO", "/SILENT", "/CLEAN" -Wait -ErrorAction SilentlyContinue
}

# Disk Cleaner
$diskCleaner = Get-ChildItem -Recurse -Name "*Disk*Clean*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($diskCleaner) {
    Write-Host "Running Disk Cleaner..." -ForegroundColor Yellow
    Start-Process $diskCleaner -ArgumentList "/AUTO", "/SILENT", "/CLEAN" -Wait -ErrorAction SilentlyContinue
}

# Tracks Eraser
$tracksEraser = Get-ChildItem -Recurse -Name "*Tracks*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($tracksEraser) {
    Write-Host "Running Tracks Eraser..." -ForegroundColor Yellow
    Start-Process $tracksEraser -ArgumentList "/AUTO", "/SILENT", "/CLEAN" -Wait -ErrorAction SilentlyContinue
}

# Shortcut Fixer
$shortcutFixer = Get-ChildItem -Recurse -Name "*Shortcut*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($shortcutFixer) {
    Write-Host "Running Shortcut Fixer..." -ForegroundColor Yellow
    Start-Process $shortcutFixer -ArgumentList "/AUTO", "/SILENT", "/FIX" -Wait -ErrorAction SilentlyContinue
}

# Startup Manager
$startupMgr = Get-ChildItem -Recurse -Name "*Startup*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($startupMgr) {
    Write-Host "Running Startup Manager..." -ForegroundColor Yellow
    Start-Process $startupMgr -ArgumentList "/AUTO", "/SILENT" -Wait -ErrorAction SilentlyContinue
}

# Memory Optimizer
$memOptimizer = Get-ChildItem -Recurse -Name "*Memory*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($memOptimizer) {
    Write-Host "Running Memory Optimizer..." -ForegroundColor Yellow
    Start-Process $memOptimizer -ArgumentList "/AUTO", "/SILENT", "/OPTIMIZE" -Wait -ErrorAction SilentlyContinue
}

# Context Menu Manager
$contextMenu = Get-ChildItem -Recurse -Name "*Context*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($contextMenu) {
    Write-Host "Running Context Menu Manager..." -ForegroundColor Yellow
    Start-Process $contextMenu -ArgumentList "/AUTO", "/SILENT" -Wait -ErrorAction SilentlyContinue
}

# Duplicate Finder
$dupFinder = Get-ChildItem -Recurse -Name "*Duplicate*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($dupFinder) {
    Write-Host "Running Duplicate Finder..." -ForegroundColor Yellow
    Start-Process $dupFinder -ArgumentList "/AUTO", "/SILENT", "/SCAN" -Wait -ErrorAction SilentlyContinue
}

# Uninstall Manager
$uninstallMgr = Get-ChildItem -Recurse -Name "*Uninstall*.exe" -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch "Glary.*Uninstall" } | Select-Object -First 1
if ($uninstallMgr) {
    Write-Host "Running Uninstall Manager..." -ForegroundColor Yellow
    Start-Process $uninstallMgr -ArgumentList "/AUTO", "/SILENT" -Wait -ErrorAction SilentlyContinue
}

# Process Manager
$processMgr = Get-ChildItem -Recurse -Name "*Process*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($processMgr) {
    Write-Host "Running Process Manager..." -ForegroundColor Yellow
    Start-Process $processMgr -ArgumentList "/AUTO", "/SILENT" -Wait -ErrorAction SilentlyContinue
}

# File Shredder
$fileShredder = Get-ChildItem -Recurse -Name "*Shred*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($fileShredder) {
    Write-Host "Running File Shredder..." -ForegroundColor Yellow
    Start-Process $fileShredder -ArgumentList "/AUTO", "/SILENT" -Wait -ErrorAction SilentlyContinue
}

# Run ALL remaining utilities that weren't caught above
Write-Host "Running additional Glary utilities..." -ForegroundColor Yellow
$additionalExes = Get-ChildItem -Recurse -Name "*.exe" | Where-Object { 
    ($_ -match "(Glary|Clean|Fix|Optim|Manage|Scan)") -and 
    ($_ -notmatch "(Uninstall.*Glary|CrashReport|Update)") 
}

foreach ($exe in $additionalExes) {
    if ($Verbose) { 
        Write-Host ("  Running: " + $exe) -ForegroundColor Cyan 
    }
    Start-Process $exe -ArgumentList "/AUTO", "/SILENT", "/CLEAN", "/FIX", "/OPTIMIZE" -ErrorAction SilentlyContinue -Wait
}

# Final comprehensive cleanup run
Write-Host "Final comprehensive cleanup..." -ForegroundColor Yellow
if ($mainExe) {
    Start-Process $mainExe -ArgumentList "/1CLICK", "/AUTO", "/SILENT" -Wait -ErrorAction SilentlyContinue
}

Write-Host "Glary Utilities automation completed!" -ForegroundColor Green
Write-Host "Script finished. All utilities have been executed." -ForegroundColor Gray

Pop-Location
