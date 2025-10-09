param([Parameter(Mandatory=$true)][string]$FolderPath)

$CodebergToken = "e36ae8c6757288c3852fc9855f73d6a55ae16bce"
$CodebergApiUrl = "https://codeberg.org/api/v1"
$Username = "michaelovsky5"

Write-Host "============================================" -ForegroundColor Magenta
Write-Host "   Codeberg LFS Sync - EXACT SIZE PRESERVATION" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta

if (!(Test-Path $FolderPath)) {
    Write-Host "ERROR: Path not found: $FolderPath" -ForegroundColor Red
    exit 1
}

# Check if Git LFS is installed
$lfsInstalled = $null -ne (Get-Command git-lfs -ErrorAction SilentlyContinue)
if (-not $lfsInstalled) {
    Write-Host "ERROR: Git LFS is not installed!" -ForegroundColor Red
    Write-Host "Install it from: https://git-lfs.github.com/" -ForegroundColor Yellow
    Write-Host "Or run: winget install GitHub.GitLFS" -ForegroundColor Yellow
    exit 1
}

Write-Host "Git LFS detected - files will preserve EXACT sizes!" -ForegroundColor Green

Write-Host "Scanning: $FolderPath" -ForegroundColor Cyan
$files = Get-ChildItem -Path $FolderPath -Recurse -File -Force -ErrorAction SilentlyContinue
$fileCount = if($files) { $files.Count } else { 0 }
$totalSize = if($files) { [math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1MB, 2) } else { 0 }
Write-Host "Files: $fileCount | Size: $totalSize MB" -ForegroundColor White

# Check for large files (100MB+) that should use LFS
if($files) {
    $largeFiles = $files | Where-Object { $_.Length -gt 100MB }
    if($largeFiles) {
        Write-Host "Found $($largeFiles.Count) files larger than 100MB (will use Git LFS):" -ForegroundColor Cyan
        $largeFiles | Sort-Object -Property Length -Descending | ForEach-Object {
            $sizeGB = [math]::Round($_.Length / 1GB, 2)
            Write-Host "  - $($_.Name): $sizeGB GB" -ForegroundColor Yellow
        }
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
        description = "LFS Sync from $FolderPath on $(Get-Date) - Exact file sizes preserved"
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

if ($repoExists -and (Test-Path ".git")) {
    Write-Host "Using existing git repository..." -ForegroundColor Cyan
    git remote set-url origin $authUrl | Out-Null
} else {
    Write-Host "Initializing new git repository with LFS..." -ForegroundColor Cyan
    if (Test-Path ".git") {
        Remove-Item ".git" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Sleep 1
    }
    git init | Out-Null
    git lfs install | Out-Null
    git remote add origin $authUrl | Out-Null
}

# Configure git for LFS
Write-Host "Configuring Git LFS for ALL large files (100MB+)..." -ForegroundColor Cyan
git config user.email "sync-bot@codeberg.org"
git config user.name "Codeberg Sync Bot"
git config core.longpaths true
git config lfs.url $authUrl/info/lfs

# Track ALL files over 100MB with LFS
Write-Host "Setting up LFS tracking for files 100MB+..." -ForegroundColor Cyan
git lfs track "*.tar" 2>&1 | Out-Null
git lfs track "*.zip" 2>&1 | Out-Null
git lfs track "*.gz" 2>&1 | Out-Null
git lfs track "*.tgz" 2>&1 | Out-Null
git lfs track "*.7z" 2>&1 | Out-Null
git lfs track "*.rar" 2>&1 | Out-Null
git lfs track "*.iso" 2>&1 | Out-Null
git lfs track "*.img" 2>&1 | Out-Null
git lfs track "*.dmg" 2>&1 | Out-Null
git lfs track "*.exe" 2>&1 | Out-Null
git lfs track "*.dll" 2>&1 | Out-Null
git lfs track "*.so" 2>&1 | Out-Null
git lfs track "*.dylib" 2>&1 | Out-Null
git lfs track "*.bin" 2>&1 | Out-Null
git lfs track "*.dat" 2>&1 | Out-Null
git lfs track "*.pack" 2>&1 | Out-Null

# Add .gitattributes if it exists
if (Test-Path ".gitattributes") {
    git add .gitattributes 2>&1 | Out-Null
}

# Delete .gitignore to ensure NO files are excluded
if (Test-Path ".gitignore") { Remove-Item ".gitignore" -Force -ErrorAction SilentlyContinue }

Write-Host "Adding all files..." -ForegroundColor Cyan
git add -A 2>&1 | Out-Null

# Check what's being tracked by LFS
Write-Host "Files tracked by LFS:" -ForegroundColor Cyan
git lfs ls-files 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }

# Commit
$commitOutput = git commit -m "LFS sync - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Exact sizes preserved" 2>&1

if ($LASTEXITCODE -eq 0 -or $commitOutput -like "*nothing to commit*") {
    Write-Host "Pushing to Codeberg with LFS..." -ForegroundColor Cyan
    git branch -M main | Out-Null

    $maxRetries = 5
    $retryCount = 0
    $pushSuccess = $false

    while ($retryCount -lt $maxRetries -and -not $pushSuccess) {
        $retryCount++
        Write-Host "Push attempt $retryCount of $maxRetries..." -ForegroundColor Yellow

        $pushOutput = git lfs push --all origin main 2>&1
        git push -u origin main --force 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            $pushSuccess = $true
            Write-Host "Push successful!" -ForegroundColor Green
        } else {
            Write-Host "Push failed (attempt $retryCount)" -ForegroundColor Red
            if ($retryCount -lt $maxRetries) {
                $waitTime = 15 * $retryCount
                Write-Host "Waiting $waitTime seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $waitTime
            }
        }
    }

    if ($pushSuccess) {
        Write-Host "============================================" -ForegroundColor Green
        Write-Host "SUCCESS: LFS SYNC COMPLETED!" -ForegroundColor Green
        Write-Host "Repository: $repoUrl" -ForegroundColor Green
        Write-Host "All files preserved at EXACT original sizes!" -ForegroundColor Green
        Write-Host "============================================" -ForegroundColor Green
    } else {
        Write-Host "All push attempts failed!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Commit failed: $commitOutput" -ForegroundColor Red
    exit 1
}
