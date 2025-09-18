#!/usr/bin/env powershell

Write-Host "🚀 Building ULTIMATE UNINSTALLER (Rust Edition)..." -ForegroundColor Green

# Build the Rust project
cargo build --release

if ($LASTEXITCODE -eq 0) {
    # Copy to a convenient location
    Copy-Item "target\release\uni.exe" "F:\Downloads\uni.exe" -Force

    Write-Host "✅ BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "📍 Executable copied to: F:\Downloads\uni.exe" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🎯 Ready to use! Run:" -ForegroundColor Yellow
    Write-Host "   uni edge" -ForegroundColor White
    Write-Host "   uni temp logs cache" -ForegroundColor White
} else {
    Write-Host "❌ Build failed!" -ForegroundColor Red
}