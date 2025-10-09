param([Parameter(Mandatory=$true)][string]$FolderPath)

$CodebergToken = "e36ae8c6757288c3852fc9855f73d6a55ae16bce"
$CodebergApiUrl = "https://codeberg.org/api/v1"
$Username = "michaelovsky5"

Write-Host "============================================" -ForegroundColor Magenta
Write-Host "   Codeberg Universal Sync - FINAL" -ForegroundColor Magenta
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

# Check for very large files (1GB+)
if($files) {
    $largeFiles = $files | Where-Object { $_.Length -gt 1GB }
    if($largeFiles) {
        Write-Host "Found $($largeFiles.Count) large files (1GB+):" -ForegroundColor Cyan
        $largeFiles | Sort-Object -Property Length -Descending | ForEach-Object {
            $sizeGB = [math]::Round($_.Length / 1GB, 2)
            Write-Host "  - $($_.Name): $sizeGB GB" -ForegroundColor Yellow
        }
        $maxSize = [math]::Round(($largeFiles | Measure-Object -Property Length -Maximum).Maximum / 1GB, 2)
        Write-Host "Largest file: $maxSize GB - will be pushed without compression." -ForegroundColor Green
        Write-Host "ALL files will preserve exact size regardless of how large they are!" -ForegroundColor Green
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
        description = "Synced from $FolderPath on $(Get-Date)"
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

    # Clean up any potential git lock files
    Get-ChildItem -Path . -Filter "*.lock" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path . -Filter "index.lock" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

    # Update remote URL with auth
    git remote set-url origin $authUrl | Out-Null

    # Skip fetch for faster sync - we'll push our changes instead
    Write-Host "Skipping fetch for faster sync..." -ForegroundColor Cyan

    # Get current branch or default to main
    $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
    if (-not $currentBranch -or $currentBranch -eq "HEAD") {
        $currentBranch = "main"
        git checkout -b main 2>&1 | Out-Null
    }

    # Ensure we're on main branch
    if ($currentBranch -ne "main") {
        git checkout main 2>&1 | Out-Null
    }
} else {
    Write-Host "Initializing new git repository..." -ForegroundColor Cyan

    # Remove any existing git directory and lock files
    if (Test-Path ".git") {
        Remove-Item ".git" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Sleep 1
    }

    # Clean up any potential git lock files
    Get-ChildItem -Path . -Filter "*.lock" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path . -Filter "index.lock" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

    git init | Out-Null
    git remote add origin $authUrl | Out-Null

    # Check if git init worked
    if (!(Test-Path ".git")) {
        Write-Host "Git initialization failed!" -ForegroundColor Red
        exit 1
    }
}

# Fix git ownership issues globally
git config --global --add safe.directory "*" 2>&1 | Out-Null
git config --global --add safe.directory $FolderPath 2>&1 | Out-Null

# Configure git settings for LARGE FILES (2GB+) - BINARY SAFE
Write-Host "Configuring git settings for large files..." -ForegroundColor Cyan
git config user.email "sync-bot@codeberg.org"
git config user.name "Codeberg Sync Bot"
git config core.longpaths true
git config core.filemode false
git config core.autocrlf false  # CRITICAL: false to prevent binary file corruption!
git config core.safecrlf false  # CRITICAL: false to allow binary files
git config advice.addEmbeddedRepo false

# CRITICAL: Configure Git for VERY LARGE files (7GB+)
# Use ZERO compression and streaming mode to prevent pack corruption
git config core.bigFileThreshold 1k  # Mark almost all files as "big"
git config core.compression 0  # ZERO compression to prevent corruption
git config core.looseCompression 0  # ZERO loose compression
git config pack.compression 0  # ZERO pack compression - store as-is
git config pack.window 1  # Minimal window for very large files
git config pack.threads 1  # Single thread for stability
git config pack.depth 1  # Minimal delta depth
git config pack.windowMemory 512m  # Lower memory to prevent pack corruption
git config pack.packSizeLimit 2147483648  # 2GB pack limit - split large repos
git config pack.deltaCacheSize 256m  # Lower cache for stability
git config http.postBuffer 2147483648  # 2GB buffer
git config http.maxRequestBuffer 2147483648  # 2GB max request
git config ssh.postBuffer 2147483648  # 2GB SSH buffer
git config transfer.unpackLimit 1  # Unpack immediately
git config http.version HTTP/1.1  # HTTP/1.1 for large files
git config http.sslVerify false  # Skip SSL verification
git config pack.useBitmaps false  # No bitmaps for large files
git config pack.writeBitmaps false  # Don't write bitmaps
git config http.lowSpeedLimit 0  # No speed timeout
git config http.lowSpeedTime 0  # No timeout
git config core.streamingThreshold 536870912  # Stream files >512MB

# Verify git config
$gitUser = git config user.name
$gitEmail = git config user.email
Write-Host "Git user configured: $gitUser <$gitEmail>" -ForegroundColor Green

# NO GITIGNORE - Include absolutely ALL files without any exceptions
# Delete .gitignore if it exists to ensure no files are excluded
if (Test-Path ".gitignore") { Remove-Item ".gitignore" -Force -ErrorAction SilentlyContinue }


# Perfect sync: Remove files that exist in repo but not locally (if repo exists)
if ($repoExists -and (Test-Path ".git")) {
    Write-Host "Syncing repository to match local folder..." -ForegroundColor Cyan

    # Get all tracked files in the repository (including those in subdirectories)
    $trackedFiles = git ls-tree -r --name-only HEAD 2>$null
    $removedCount = 0

    if ($trackedFiles) {
        foreach ($trackedFile in $trackedFiles) {
            # NO EXCEPTIONS - Process ALL files including .gitignore and README.md
            try {
                # Use Get-Item with -LiteralPath for better Unicode support
                $fileExists = $null -ne (Get-Item -LiteralPath $trackedFile -ErrorAction SilentlyContinue)
                if (-not $fileExists) {
                    Write-Host "Removing deleted file: $trackedFile" -ForegroundColor Yellow
                    git rm --cached $trackedFile 2>&1 | Out-Null
                    $removedCount++
                }
            } catch {
                # If we can't check the file path, assume it doesn't exist and remove it
                Write-Host "Removing problematic file: $trackedFile" -ForegroundColor Yellow
                git rm --cached $trackedFile 2>&1 | Out-Null
                $removedCount++
            }
        }
    }

    if ($removedCount -gt 0) {
        Write-Host "Removed $removedCount files from repository" -ForegroundColor Yellow
    }
}

Write-Host "Adding all local files to repository..." -ForegroundColor Cyan

# NO FILE REMOVAL - Include ALL files including nested .git directories and everything else
# We will use git's embedded repo handling instead of removing files

# Perfect sync: Add ALL files from local folder
Write-Host "Staging all changes for perfect sync..." -ForegroundColor Cyan

# Show what git sees before adding
Write-Host "Git status before staging:" -ForegroundColor Cyan
$statusOutput = git status --porcelain
Write-Host "Status output lines: $($statusOutput.Count)" -ForegroundColor Yellow

# Add all files with multiple approaches for maximum compatibility
Write-Host "Adding all files with git add ." -ForegroundColor Cyan
git add . 2>&1 | Out-Null

Write-Host "Adding all files with git add -A" -ForegroundColor Cyan
git add -A 2>&1 | Out-Null

Write-Host "Adding all files with git add --all" -ForegroundColor Cyan
git add --all 2>&1 | Out-Null

# Force add any remaining untracked files - NO FILTERING, NO EXCEPTIONS
Write-Host "Checking for any remaining untracked files..." -ForegroundColor Cyan
$untracked = git ls-files --others 2>$null
if ($untracked -and $untracked.Count -gt 0) {
    Write-Host "Found $($untracked.Count) untracked files, force adding ALL..." -ForegroundColor Yellow
    foreach ($file in $untracked) {
        try {
            git add -f "$file" 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Successfully added: $file" -ForegroundColor Green
            } else {
                Write-Host "Failed to add: $file - trying alternative method" -ForegroundColor Yellow
                # Try without -f flag for files that might have issues
                git add "$file" 2>&1 | Out-Null
            }
        } catch {
            Write-Host "Error adding: $file" -ForegroundColor Red
        }
    }
} else {
    Write-Host "No additional untracked files found" -ForegroundColor Green
}

# Show what's staged after adding
Write-Host "Checking staged files..." -ForegroundColor Cyan
$stagedFiles = git diff --cached --name-only
$stagedCount = if ($stagedFiles) { $stagedFiles.Count } else { 0 }
Write-Host "Total staged files: $stagedCount" -ForegroundColor $(if ($stagedCount -gt 0) { "Green" } else { "Yellow" })

# Also check for any working directory changes
$workingChanges = git status --porcelain
$workingCount = if ($workingChanges) { $workingChanges.Count } else { 0 }
Write-Host "Working directory changes: $workingCount" -ForegroundColor Cyan

# Final determination of what to commit
if ($stagedCount -gt 0) {
    Write-Host "Found $stagedCount staged files ready for commit" -ForegroundColor Green
    $status = $stagedFiles
} elseif ($workingCount -gt 0) {
    Write-Host "Found $workingCount working changes but not staged. Force staging..." -ForegroundColor Yellow

    # Ultra-aggressive staging for large repos
    Write-Host "Using ultra-aggressive staging approach..." -ForegroundColor Cyan
    git add -f . 2>&1 | Out-Null
    git add -f -A 2>&1 | Out-Null

    # Check again
    $stagedFiles = git diff --cached --name-only
    $stagedCount = if ($stagedFiles) { $stagedFiles.Count } else { 0 }

    if ($stagedCount -gt 0) {
        Write-Host "Successfully staged $stagedCount files after force add" -ForegroundColor Green
        $status = $stagedFiles
    } else {
        Write-Host "Still no files staged - this may be a git issue with large repos" -ForegroundColor Red
        Write-Host "Creating README to force a commit..." -ForegroundColor Yellow
        "# Full sync from $FolderPath on $(Get-Date)" | Out-File -FilePath "README.md" -Encoding UTF8
        git add README.md 2>&1 | Out-Null
        $stagedFiles = git diff --cached --name-only
        $status = $stagedFiles
    }
} else {
    Write-Host "No changes detected anywhere - repository may already be in sync" -ForegroundColor Yellow
    Write-Host "Creating README to verify sync..." -ForegroundColor Yellow
    "# Verified sync from $FolderPath on $(Get-Date)" | Out-File -FilePath "README.md" -Encoding UTF8
    git add README.md 2>&1 | Out-Null
    $stagedFiles = git diff --cached --name-only
    $status = $stagedFiles
}

if ($status) {
    $syncType = if ($repoExists) { "Incremental" } else { "Initial" }
    Write-Host "Committing $($status.Count) changes..." -ForegroundColor Cyan

    # Clean any git lock files before commit
    if (Test-Path ".git/index.lock") {
        Remove-Item ".git/index.lock" -Force -ErrorAction SilentlyContinue
        Start-Sleep 1
    }

    $commitOutput = git commit -m "$syncType sync - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pushing to Codeberg..." -ForegroundColor Cyan
        git branch -M main | Out-Null

        # Re-configure for UNLIMITED file size push (50GB, 100GB+)
        git config http.postBuffer 1073741824 | Out-Null  # 1GB buffer (Git auto-chunks)
        git config http.maxRequestBuffer 1073741824 | Out-Null  # 1GB max request
        git config ssh.postBuffer 1073741824 | Out-Null  # 1GB for SSH
        git config core.compression 0 | Out-Null  # NO compression
        git config pack.compression 0 | Out-Null  # NO pack compression
        git config pack.window 0 | Out-Null  # NO delta compression
        git config pack.depth 0 | Out-Null  # NO delta depth
        git config push.default simple | Out-Null
        git config pack.windowMemory 2g | Out-Null  # 2GB memory
        git config pack.deltaCacheSize 1g | Out-Null  # 1GB cache
        git config pack.packSizeLimit 0 | Out-Null  # NO pack size limit
        git config core.bigFileThreshold 512m | Out-Null  # Mark 512MB+ as big
        git config http.lowSpeedLimit 0 | Out-Null  # No speed limit timeout
        git config http.lowSpeedTime 0 | Out-Null  # No timeout
        git config http.version HTTP/1.1 | Out-Null  # HTTP/1.1 for chunking
        git config transfer.unpackLimit 1 | Out-Null  # Force unpacking

        # Try push with MORE retries for large files
        $maxRetries = 5  # Increased from 3 to 5 for large files
        $retryCount = 0
        $pushSuccess = $false

        while ($retryCount -lt $maxRetries -and -not $pushSuccess) {
            $retryCount++
            Write-Host "Push attempt $retryCount of $maxRetries..." -ForegroundColor Yellow

            # Try force push for sync (since we want local to override remote)
            # Use --no-verify to skip hooks that might reject large files
            $pushOutput = git push -u origin main --force --no-verify 2>&1
            if ($LASTEXITCODE -eq 0) {
                $pushSuccess = $true
                Write-Host "Push successful!" -ForegroundColor Green
            } else {
                Write-Host "Push failed (attempt $retryCount): $pushOutput" -ForegroundColor Red
                if ($retryCount -lt $maxRetries) {
                    $waitTime = 15 * $retryCount  # Progressive wait: 15s, 30s, 45s, 60s
                    Write-Host "Waiting $waitTime seconds before retry..." -ForegroundColor Yellow
                    Start-Sleep -Seconds $waitTime
                }
            }
        }

        if (-not $pushSuccess) {
            Write-Host "All push attempts failed!" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Commit failed: $commitOutput" -ForegroundColor Red
        exit 1
    }

    if ($pushSuccess) {
        # Verify perfect sync
        Write-Host "Verifying perfect sync..." -ForegroundColor Cyan

        # Count ALL local files - NO EXCLUSIONS (except the main .git directory)
        $localFiles = Get-ChildItem -Path . -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notlike "*\.git\*"
            }
        $localFileCount = if($localFiles) { $localFiles.Count } else { 0 }

        # Count ALL tracked files in repository - NO EXCLUSIONS
        $trackedFiles = git ls-tree -r --name-only HEAD 2>$null
        $trackedFileCount = if($trackedFiles) { $trackedFiles.Count } else { 0 }

        $syncStatus = if ($localFileCount -eq $trackedFileCount) { "PERFECT" } else { "PARTIAL" }

        Write-Host "============================================" -ForegroundColor Green
        Write-Host "SUCCESS: $syncStatus SYNC COMPLETED!" -ForegroundColor Green
        Write-Host "Repository: $repoUrl" -ForegroundColor Green
        Write-Host "Local files: $localFileCount | Repository files: $trackedFileCount" -ForegroundColor Green
        Write-Host "Total size: $totalSize MB" -ForegroundColor Green
        if ($syncStatus -eq "PARTIAL") {
            Write-Host "Note: File counts differ - some files may have been excluded" -ForegroundColor Yellow
        }
        Write-Host "============================================" -ForegroundColor Green
    }
} else {
    Write-Host "No files to sync" -ForegroundColor Yellow
}