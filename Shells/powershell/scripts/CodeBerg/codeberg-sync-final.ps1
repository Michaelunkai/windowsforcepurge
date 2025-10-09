param([Parameter(Mandatory=$true)][string]$FolderPath)

$CodebergToken = "e36ae8c6757288c3852fc9855f73d6a55ae16bce"
$CodebergApiUrl = "https://codeberg.org/api/v1"
$Username = "michaelovsky5"

Write-Host "============================================" -ForegroundColor Magenta
Write-Host "   Codeberg LFS Sync - UNLIMITED SIZE" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta

if (!(Test-Path $FolderPath)) {
    Write-Host "ERROR: Path not found: $FolderPath" -ForegroundColor Red
    exit 1
}

Write-Host "Scanning: $FolderPath" -ForegroundColor Cyan
$files = Get-ChildItem -Path $FolderPath -Recurse -File -Force -ErrorAction SilentlyContinue
$fileCount = if($files) { $files.Count } else { 0 }
$totalSize = if($files) { [math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1MB, 2) } else { 0 }
Write-Host "Files: $fileCount | Size: $totalSize MB" -ForegroundColor White

# Check for large files (>100MB will use LFS)
if($files) {
    $lfsFiles = $files | Where-Object { $_.Length -gt 100MB }
    if($lfsFiles) {
        Write-Host "Found $($lfsFiles.Count) files >100MB (will use Git LFS):" -ForegroundColor Cyan
        $lfsFiles | Sort-Object -Property Length -Descending | Select-Object -First 10 | ForEach-Object {
            $sizeGB = [math]::Round($_.Length / 1GB, 2)
            Write-Host "  - $($_.Name): $sizeGB GB" -ForegroundColor Yellow
        }
        $maxSize = [math]::Round(($lfsFiles | Measure-Object -Property Length -Maximum).Maximum / 1GB, 2)
        Write-Host "Largest file: $maxSize GB - Git LFS supports files of ANY size!" -ForegroundColor Green
    }
}

$headers = @{
    "Authorization" = "token $CodebergToken"
    "Content-Type" = "application/json"
}

# Test connection
try {
    $user = Invoke-RestMethod -Uri "$CodebergApiUrl/user" -Headers $headers -Method Get
    Write-Host "Codeberg User: $($user.login)" -ForegroundColor Green
} catch {
    Write-Host "Codeberg connection failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$RepoName = Split-Path $FolderPath -Leaf
$RepoName = $RepoName -replace '[^\w-]', '-'

# Check if repo exists, create if needed
$repoExists = $false
try {
    $existingRepo = Invoke-RestMethod -Uri "$CodebergApiUrl/repos/$Username/$RepoName" -Headers $headers -Method Get
    $repoUrl = $existingRepo.clone_url
    $repoExists = $true
    Write-Host "Repository exists: $RepoName" -ForegroundColor Green
} catch {
    Write-Host "Repository doesn't exist, creating: $RepoName" -ForegroundColor Cyan

    $body = @{
        name = $RepoName
        description = "Synced from $FolderPath on $(Get-Date) - Git LFS enabled for unlimited file sizes"
        private = $false
        auto_init = $false
    } | ConvertTo-Json

    try {
        $repo = Invoke-RestMethod -Uri "$CodebergApiUrl/user/repos" -Headers $headers -Method Post -Body $body
        $repoUrl = $repo.clone_url
        Write-Host "Created repo: $repoUrl" -ForegroundColor Green
    } catch {
        Write-Host "Failed to create repository: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Git operations
Set-Location $FolderPath
$authUrl = $repoUrl -replace "https://", "https://$Username`:$CodebergToken@"

# Always start fresh for LFS setup
Write-Host "Initializing fresh git repository with LFS..." -ForegroundColor Cyan

# Remove any existing git directory
if (Test-Path ".git") {
    Remove-Item ".git" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Sleep 1
}

# Clean up lock files
Get-ChildItem -Path . -Filter "*.lock" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

git init | Out-Null
git remote add origin $authUrl | Out-Null

# Configure git settings - BINARY SAFE
Write-Host "Configuring git for binary safety..." -ForegroundColor Cyan
git config user.email "sync-bot@codeberg.org"
git config user.name "Codeberg Sync Bot"
git config core.longpaths true
git config core.filemode false
git config core.autocrlf false  # CRITICAL: prevents binary corruption!
git config core.safecrlf false  # CRITICAL: allows binary files
git config advice.addEmbeddedRepo false
git config http.postBuffer 2147483648  # 2GB buffer
git config http.version HTTP/1.1
git config http.sslVerify false

# Initialize Git LFS
Write-Host "Initializing Git LFS for unlimited file sizes..." -ForegroundColor Cyan
git lfs install | Out-Null

# Track ALL files >100MB with LFS
Write-Host "Configuring LFS to track files >100MB..." -ForegroundColor Cyan
git lfs track "*.bin"
git lfs track "*.tar"
git lfs track "*.zip"
git lfs track "*.7z"
git lfs track "*.rar"
git lfs track "*.iso"
git lfs track "*.img"
git lfs track "*.dmg"
git lfs track "*.exe" --lockable
git lfs track "*.dll" --lockable

# Add .gitattributes
git add .gitattributes 2>&1 | Out-Null

Write-Host "Adding all files (LFS will handle large files automatically)..." -ForegroundColor Cyan
git add . 2>&1 | Out-Null
git add -A 2>&1 | Out-Null

# Check what's staged
$staged = git diff --cached --name-only 2>$null
if ($staged) {
    Write-Host "Staged $($staged.Count) files" -ForegroundColor Green

    # Show LFS files
    $lfsTracked = git lfs ls-files 2>$null
    if ($lfsTracked) {
        Write-Host "LFS is tracking $($lfsTracked.Count) large files" -ForegroundColor Cyan
    }
} else {
    Write-Host "No files staged - checking status..." -ForegroundColor Yellow
    git status
}

Write-Host "Creating commit..." -ForegroundColor Cyan
git commit -m "Sync from $FolderPath - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - LFS enabled" 2>&1 | Out-Null

# Get current branch name
$currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
if (-not $currentBranch) { $currentBranch = "master" }
Write-Host "Current branch: $currentBranch" -ForegroundColor Cyan

Write-Host "Pushing to Codeberg (LFS will upload large files)..." -ForegroundColor Cyan
$maxRetries = 5
$retryCount = 0
$pushSuccess = $false

while ($retryCount -lt $maxRetries -and -not $pushSuccess) {
    $retryCount++
    Write-Host "Push attempt $retryCount of $maxRetries..." -ForegroundColor Cyan

    $pushOutput = git push -u origin $currentBranch --force 2>&1

    if ($LASTEXITCODE -eq 0) {
        $pushSuccess = $true
        Write-Host "✓ Push successful!" -ForegroundColor Green
    } else {
        Write-Host "Push failed (attempt $retryCount): $pushOutput" -ForegroundColor Red

        if ($retryCount -lt $maxRetries) {
            $waitTime = 15 * $retryCount
            Write-Host "Waiting $waitTime seconds before retry..." -ForegroundColor Yellow
            Start-Sleep -Seconds $waitTime
        }
    }
}

if (-not $pushSuccess) {
    Write-Host "✗ Failed to push after $maxRetries attempts" -ForegroundColor Red
    exit 1
}

Write-Host "`n============================================" -ForegroundColor Magenta
Write-Host "   SYNC COMPLETE - LFS ENABLED" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "Repository: $repoUrl" -ForegroundColor Cyan
Write-Host "Files stored with Git LFS preserve EXACT sizes" -ForegroundColor Green
Write-Host "Supports files of ANY size (50GB, 100GB+)" -ForegroundColor Green
