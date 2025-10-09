################################################################################
# POST-REBOOT VERIFICATION SCRIPT
# Run this script AFTER rebooting to verify all installations work correctly
################################################################################

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "POST-REBOOT INSTALLATION VERIFICATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$allPassed = $true

# Test .NET 9
Write-Host "Testing .NET 9..." -ForegroundColor Yellow
try {
    $dotnetVersion = dotnet --version 2>&1
    if ($dotnetVersion -match '^9\.') {
        Write-Host "  ✅ .NET 9 works: $dotnetVersion" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  .NET version: $dotnetVersion (expected 9.x)" -ForegroundColor Yellow
        $allPassed = $false
    }
} catch {
    Write-Host "  ❌ .NET 9 not accessible: $_" -ForegroundColor Red
    $allPassed = $false
}

# Test pwsh
Write-Host "`nTesting PowerShell 7 (pwsh)..." -ForegroundColor Yellow
try {
    $pwshVersion = pwsh -Command '$PSVersionTable.PSVersion.ToString()' 2>&1
    if ($pwshVersion -match '^\d+\.\d+') {
        Write-Host "  ✅ pwsh works: $pwshVersion" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  pwsh response: $pwshVersion" -ForegroundColor Yellow
        $allPassed = $false
    }
} catch {
    Write-Host "  ❌ pwsh not accessible: $_" -ForegroundColor Red
    $allPassed = $false
}

# Test git
Write-Host "`nTesting Git..." -ForegroundColor Yellow
try {
    $gitVersion = git --version 2>&1
    if ($gitVersion -like "git version*") {
        Write-Host "  ✅ git works: $gitVersion" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  git response: $gitVersion" -ForegroundColor Yellow
        $allPassed = $false
    }
} catch {
    Write-Host "  ❌ git not accessible: $_" -ForegroundColor Red
    $allPassed = $false
}

# Test gh
Write-Host "`nTesting GitHub CLI (gh)..." -ForegroundColor Yellow
try {
    $ghVersion = gh --version 2>&1 | Select-Object -First 1
    if ($ghVersion -like "gh version*") {
        Write-Host "  ✅ gh works: $ghVersion" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  gh response: $ghVersion" -ForegroundColor Yellow
        $allPassed = $false
    }
} catch {
    Write-Host "  ❌ gh not accessible: $_" -ForegroundColor Red
    $allPassed = $false
}

# Test running a simple .NET app
Write-Host "`nTesting .NET runtime..." -ForegroundColor Yellow
try {
    $runtimeInfo = dotnet --list-runtimes 2>&1 | Select-String "Microsoft.NETCore.App 9"
    if ($runtimeInfo) {
        Write-Host "  ✅ .NET 9 runtime found: $runtimeInfo" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  .NET 9 runtime not found in list" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️  Could not list runtimes: $_" -ForegroundColor Yellow
}

# Final result
Write-Host "`n========================================" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host "✅✅✅ ALL TESTS PASSED! ✅✅✅" -ForegroundColor Green
    Write-Host "Your development environment is fully functional!" -ForegroundColor Green
    Write-Host "`nYou can now run any .NET 9 application!" -ForegroundColor Green
} else {
    Write-Host "⚠️⚠️⚠️ SOME TESTS FAILED ⚠️⚠️⚠️" -ForegroundColor Yellow
    Write-Host "Please reboot if you haven't already." -ForegroundColor Yellow
    Write-Host "If still failing after reboot, rerun SETUP-EVERYTHING.ps1" -ForegroundColor Yellow
}
Write-Host "========================================`n" -ForegroundColor Cyan
