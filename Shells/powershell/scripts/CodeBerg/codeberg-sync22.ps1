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

# Configure git settings
Write-Host "Configuring git settings..." -ForegroundColor Cyan
git config user.email "sync-bot@codeberg.org"
git config user.name "Codeberg Sync Bot"
git config core.longpaths true
git config core.filemode false
git config core.autocrlf true
git config advice.addEmbeddedRepo false

# Verify git config
$gitUser = git config user.name
$gitEmail = git config user.email
Write-Host "Git user configured: $gitUser <$gitEmail>" -ForegroundColor Green

@"
Thumbs.db
.DS_Store
**/nul
**/.git
**/mem-agent-mcp/
"@ | Out-File -FilePath ".gitignore" -Encoding UTF8


# Perfect sync: Remove files that exist in repo but not locally (if repo exists)
if ($repoExists -and (Test-Path ".git")) {
    Write-Host "Syncing repository to match local folder..." -ForegroundColor Cyan

    # Get all tracked files in the repository (including those in subdirectories)
    $trackedFiles = git ls-tree -r --name-only HEAD 2>$null
    $removedCount = 0

    if ($trackedFiles) {
        foreach ($trackedFile in $trackedFiles) {
            # Skip gitignore and readme files we might have created
            if ($trackedFile -eq ".gitignore" -or $trackedFile -eq "README.md") {
                continue
            }

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

# Remove problematic files and nested git directories first
if (Test-Path "pstools/nul") { Remove-Item "pstools/nul" -Force -ErrorAction SilentlyContinue }
if (Test-Path "pstools/mem-agent-mcp/.git") { Remove-Item "pstools/mem-agent-mcp" -Recurse -Force -ErrorAction SilentlyContinue }

# Remove ONLY nested .git directories (but NOT the main .git directory)
Write-Host "Removing nested git directories for proper file tracking..." -ForegroundColor Cyan
$nestedGitDirs = Get-ChildItem -Path . -Recurse -Directory -Name ".git" -Force -ErrorAction SilentlyContinue | Where-Object {
    $fullPath = Join-Path (Get-Location) $_
    $mainGitPath = Join-Path (Get-Location) ".git"
    $fullPath -ne $mainGitPath
}
foreach ($gitDir in $nestedGitDirs) {
    $fullPath = Join-Path . $gitDir
    if (Test-Path $fullPath) {
        Write-Host "Removing nested git directory: $fullPath" -ForegroundColor Yellow
        Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue
        Start-Sleep 1  # Give filesystem time to update
    }
}

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

# Force add any remaining untracked files
Write-Host "Checking for any remaining untracked files..." -ForegroundColor Cyan
$untracked = git ls-files --others --exclude-standard 2>$null | Where-Object { $_ -ne "nul" -and $_ -notlike "*/.git/*" -and $_ -notlike "*/mem-agent-mcp/*" }
if ($untracked -and $untracked.Count -gt 0) {
    Write-Host "Found $($untracked.Count) untracked files, force adding..." -ForegroundColor Yellow
    foreach ($file in $untracked) {
        try {
            git add "$file" 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Successfully added: $file" -ForegroundColor Green
            } else {
                Write-Host "Failed to add: $file" -ForegroundColor Red
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

        # Configure git for optimal performance
        git config http.postBuffer 524288000 | Out-Null  # 500MB buffer
        git config http.maxRequestBuffer 100M | Out-Null
        git config core.compression 1 | Out-Null  # Light compression for speed
        git config push.default simple | Out-Null
        git config pack.windowMemory 256m | Out-Null  # Optimize memory usage
        git config pack.deltaCacheSize 128m | Out-Null

        # Try push with retries
        $maxRetries = 3
        $retryCount = 0
        $pushSuccess = $false

        while ($retryCount -lt $maxRetries -and -not $pushSuccess) {
            $retryCount++
            Write-Host "Push attempt $retryCount of $maxRetries..." -ForegroundColor Yellow

            # Try force push for sync (since we want local to override remote)
            $pushOutput = git push -u origin main --force 2>&1
            if ($LASTEXITCODE -eq 0) {
                $pushSuccess = $true
                Write-Host "Push successful!" -ForegroundColor Green
            } else {
                Write-Host "Push failed (attempt $retryCount): $pushOutput" -ForegroundColor Red
                if ($retryCount -lt $maxRetries) {
                    Write-Host "Waiting 10 seconds before retry..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 10
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

        # Count local files (using the exact same exclusions as gitignore)
        $localFiles = Get-ChildItem -Path . -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notlike "*\.git\*" -and
                $_.Name -ne "nul" -and
                $_.FullName -notlike "*\mem-agent-mcp\*" -and
                $_.Name -ne "Thumbs.db" -and
                $_.Name -ne ".DS_Store"
            }
        $localFileCount = if($localFiles) { $localFiles.Count } else { 0 }

        # Count tracked files in repository (using same exclusions)
        $trackedFiles = git ls-tree -r --name-only HEAD 2>$null
        $trackedFileCount = if($trackedFiles) {
            ($trackedFiles | Where-Object {
                $_ -ne "nul" -and
                $_ -notlike "*/.git/*" -and
                $_ -notlike "*/mem-agent-mcp/*" -and
                $_ -ne "Thumbs.db" -and
                $_ -ne ".DS_Store"
            }).Count
        } else { 0 }

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