# Glary Utilities PARALLEL Automation Script - Runs ALL at once!
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

Write-Host "LAUNCHING ALL Glary Utilities SIMULTANEOUSLY..." -ForegroundColor Red

# Main Glary Utilities with 1-Click Maintenance
$mainExe = Get-ChildItem -Recurse -Name "GlaryUtilities.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($mainExe) {
    if ($Verbose) { Write-Host "LAUNCHING: 1-Click Maintenance" -ForegroundColor Cyan }
    Start-Process $mainExe -ArgumentList "/AUTO", "/SILENT" -ErrorAction SilentlyContinue
}

# Registry Cleaner
$regCleaner = Get-ChildItem -Recurse -Name "*Registry*Clean*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($regCleaner) {
    if ($Verbose) { Write-Host "LAUNCHING: Registry Cleaner" -ForegroundColor Cyan }
    Start-Process $regCleaner -ArgumentList "/AUTO", "/SILENT", "/CLEAN" -ErrorAction SilentlyContinue
}

# Disk Cleaner
$diskCleaner = Get-ChildItem -Recurse -Name "*Disk*Clean*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($diskCleaner) {
    if ($Verbose) { Write-Host "LAUNCHING: Disk Cleaner" -ForegroundColor Cyan }
    Start-Process $diskCleaner -ArgumentList "/AUTO", "/SILENT", "/CLEAN" -ErrorAction SilentlyContinue
}

# Tracks Eraser
$tracksEraser = Get-ChildItem -Recurse -Name "*Tracks*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($tracksEraser) {
    if ($Verbose) { Write-Host "LAUNCHING: Tracks Eraser" -ForegroundColor Cyan }
    Start-Process $tracksEraser -ArgumentList "/AUTO", "/SILENT", "/CLEAN" -ErrorAction SilentlyContinue
}

# Shortcut Fixer
$shortcutFixer = Get-ChildItem -Recurse -Name "*Shortcut*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($shortcutFixer) {
    if ($Verbose) { Write-Host "LAUNCHING: Shortcut Fixer" -ForegroundColor Cyan }
    Start-Process $shortcutFixer -ArgumentList "/AUTO", "/SILENT", "/FIX" -ErrorAction SilentlyContinue
}

# Startup Manager
$startupMgr = Get-ChildItem -Recurse -Name "*Startup*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($startupMgr) {
    if ($Verbose) { Write-Host "LAUNCHING: Startup Manager" -ForegroundColor Cyan }
    Start-Process $startupMgr -ArgumentList "/AUTO", "/SILENT" -ErrorAction SilentlyContinue
}

# Memory Optimizer
$memOptimizer = Get-ChildItem -Recurse -Name "*Memory*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($memOptimizer) {
    if ($Verbose) { Write-Host "LAUNCHING: Memory Optimizer" -ForegroundColor Cyan }
    Start-Process $memOptimizer -ArgumentList "/AUTO", "/SILENT", "/OPTIMIZE" -ErrorAction SilentlyContinue
}

# Context Menu Manager
$contextMenu = Get-ChildItem -Recurse -Name "*Context*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($contextMenu) {
    if ($Verbose) { Write-Host "LAUNCHING: Context Menu Manager" -ForegroundColor Cyan }
    Start-Process $contextMenu -ArgumentList "/AUTO", "/SILENT" -ErrorAction SilentlyContinue
}

# Duplicate Finder
$dupFinder = Get-ChildItem -Recurse -Name "*Duplicate*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($dupFinder) {
    if ($Verbose) { Write-Host "LAUNCHING: Duplicate Finder" -ForegroundColor Cyan }
    Start-Process $dupFinder -ArgumentList "/AUTO", "/SILENT", "/SCAN" -ErrorAction SilentlyContinue
}

# Uninstall Manager
$uninstallMgr = Get-ChildItem -Recurse -Name "*Uninstall*.exe" -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch "Glary.*Uninstall" } | Select-Object -First 1
if ($uninstallMgr) {
    if ($Verbose) { Write-Host "LAUNCHING: Uninstall Manager" -ForegroundColor Cyan }
    Start-Process $uninstallMgr -ArgumentList "/AUTO", "/SILENT" -ErrorAction SilentlyContinue
}

# Process Manager
$processMgr = Get-ChildItem -Recurse -Name "*Process*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($processMgr) {
    if ($Verbose) { Write-Host "LAUNCHING: Process Manager" -ForegroundColor Cyan }
    Start-Process $processMgr -ArgumentList "/AUTO", "/SILENT" -ErrorAction SilentlyContinue
}

# File Shredder
$fileShredder = Get-ChildItem -Recurse -Name "*Shred*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($fileShredder) {
    if ($Verbose) { Write-Host "LAUNCHING: File Shredder" -ForegroundColor Cyan }
    Start-Process $fileShredder -ArgumentList "/AUTO", "/SILENT" -ErrorAction SilentlyContinue
}

# NUCLEAR OPTION: Launch ALL remaining Glary utilities simultaneously
if ($Verbose) { Write-Host "LAUNCHING: All remaining utilities" -ForegroundColor Cyan }
$launchCount = 0
Get-ChildItem -Recurse -Name "*.exe" | Where-Object { 
    ($_ -match "(Glary|Clean|Fix|Optim|Manage|Scan)") -and 
    ($_ -notmatch "(Uninstall.*Glary|CrashReport|Update)") 
} | ForEach-Object { 
    if ($Verbose) { Write-Host ("  FIRING: " + $_) -ForegroundColor Yellow }
    Start-Process $_ -ArgumentList "/AUTO", "/SILENT", "/CLEAN", "/FIX", "/OPTIMIZE" -ErrorAction SilentlyContinue
    $launchCount++
}

Pop-Location

Write-Host ("LAUNCHED " + $launchCount + " utilities SIMULTANEOUSLY!") -ForegroundColor Green
Write-Host "Control returned to terminal - utilities running in background!" -ForegroundColor Magenta
Write-Host "Use Task Manager to monitor progress..." -ForegroundColor Gray
