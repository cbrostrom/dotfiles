# Install Cursor Extensions from dotfiles (Windows)
# This script reads extensions.json from WSL and installs all extensions to Windows Cursor

param(
    [switch]$Force,
    [switch]$SkipInstalled
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Blue }
function Write-Success { Write-Host "[SUCCESS] $args" -ForegroundColor Green }
function Write-Warning { Write-Host "[WARNING] $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "[ERROR] $args" -ForegroundColor Red }

Write-Info "=== Cursor Extension Installer (Windows) ==="
Write-Host ""

# Detect WSL distro and construct path
$wslDistro = "Debian"
$extensionsFilePath = "\\wsl$\$wslDistro\home\christian\.config\dotfiles\.config\cursor\extensions.json"

Write-Info "Extensions file: $extensionsFilePath"

# Check if WSL path is accessible
if (-not (Test-Path $extensionsFilePath)) {
    Write-Error "Cannot access extensions.json at: $extensionsFilePath"
    Write-Info "Make sure:"
    Write-Info "  1. WSL is running"
    Write-Info "  2. The path exists in your WSL distribution"
    Write-Info "  3. You're using the correct WSL distro name (current: $wslDistro)"
    Write-Host ""
    Write-Info "Available WSL distros:"
    wsl --list --quiet
    exit 1
}

# Find Cursor CLI
$cursorPaths = @(
    "$env:LOCALAPPDATA\Programs\Cursor\resources\app\bin\cursor.cmd",
    "$env:LOCALAPPDATA\Programs\Cursor\Cursor.exe",
    "C:\Program Files\Cursor\resources\app\bin\cursor.cmd",
    "C:\Program Files (x86)\Cursor\resources\app\bin\cursor.cmd"
)

$cursorCli = $null
foreach ($path in $cursorPaths) {
    if (Test-Path $path) {
        $cursorCli = $path
        break
    }
}

if (-not $cursorCli) {
    Write-Error "Cursor CLI not found"
    Write-Info "Searched paths:"
    foreach ($path in $cursorPaths) {
        Write-Info "  - $path"
    }
    Write-Host ""
    Write-Info "Please ensure Cursor is installed"
    exit 1
}

Write-Info "Using CLI: $cursorCli"
Write-Host ""

# Read and parse extensions.json
try {
    $extensionsJson = Get-Content -Path $extensionsFilePath -Raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse extensions.json: $_"
    exit 1
}

if (-not $extensionsJson -or $extensionsJson.Count -eq 0) {
    Write-Error "No extensions found in extensions.json"
    exit 1
}

$totalExtensions = $extensionsJson.Count
Write-Info "Found $totalExtensions extensions to install"
Write-Host ""

# Get currently installed extensions
Write-Info "Checking currently installed extensions..."
$installedExtensions = @()

try {
    $output = & $cursorCli --list-extensions 2>&1
    if ($LASTEXITCODE -eq 0) {
        $installedExtensions = $output | Where-Object { $_ -match '^\S+\.\S+$' }
    }
} catch {
    Write-Warning "Could not list installed extensions: $_"
}

Write-Info "Found $($installedExtensions.Count) currently installed extensions"
Write-Host ""

# Install extensions
$installedCount = 0
$skippedCount = 0
$failedCount = 0
$failedExtensions = @()

$counter = 0
foreach ($ext in $extensionsJson) {
    $counter++
    $extensionId = $ext.identifier
    
    if (-not $extensionId) {
        Write-Warning "Skipping invalid entry (no identifier)"
        continue
    }
    
    $progressPercent = [math]::Round(($counter / $totalExtensions) * 100)
    Write-Progress -Activity "Installing Cursor Extensions" -Status "Processing $extensionId" -PercentComplete $progressPercent
    
    # Check if already installed
    if ($SkipInstalled -and ($installedExtensions -contains $extensionId)) {
        Write-Success "[$counter/$totalExtensions] ✓ Already installed: $extensionId"
        $skippedCount++
        continue
    }
    
    # Install extension
    Write-Info "[$counter/$totalExtensions] Installing: $extensionId"
    
    try {
        $installArgs = @("--install-extension", $extensionId)
        if ($Force) {
            $installArgs += "--force"
        }
        
        $output = & $cursorCli $installArgs 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0 -or $output -match "successfully installed|already installed") {
            Write-Success "[$counter/$totalExtensions] ✓ Installed: $extensionId"
            $installedCount++
        } else {
            Write-Error "[$counter/$totalExtensions] ✗ Failed: $extensionId"
            $failedCount++
            $failedExtensions += $extensionId
        }
    } catch {
        Write-Error "[$counter/$totalExtensions] ✗ Failed: $extensionId ($_)"
        $failedCount++
        $failedExtensions += $extensionId
    }
    
    # Small delay to avoid rate limiting
    Start-Sleep -Milliseconds 500
}

Write-Progress -Activity "Installing Cursor Extensions" -Completed

# Summary
Write-Host ""
Write-Info "=== Installation Summary ==="
Write-Success "✓ Installed: $installedCount"
if ($SkipInstalled) {
    Write-Info "⊙ Already installed (skipped): $skippedCount"
}
if ($failedCount -gt 0) {
    Write-Error "✗ Failed: $failedCount"
    Write-Host ""
    Write-Warning "Failed extensions:"
    foreach ($failed in $failedExtensions) {
        Write-Warning "  - $failed"
    }
    Write-Host ""
    Write-Info "These extensions may be:"
    Write-Info "  - Deprecated or removed from marketplace"
    Write-Info "  - Renamed or moved to different identifier"
    Write-Info "  - Platform-specific (not available on Windows)"
}
Write-Host ""

if ($installedCount -gt 0) {
    Write-Success "Extension installation complete!"
    Write-Info "Restart Cursor to activate all extensions"
} else {
    Write-Warning "No new extensions were installed"
}

Write-Host ""
Write-Info "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
