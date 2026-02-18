# Sync Cursor Settings from dotfiles (Windows)
# This script syncs settings.json, keybindings.json, and installs extensions from WSL dotfiles to Windows Cursor

param(
    [switch]$Force,
    [switch]$SkipExtensions,
    [switch]$SkipSettings,
    [switch]$ExtensionsOnly
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Blue }
function Write-Success { Write-Host "[SUCCESS] $args" -ForegroundColor Green }
function Write-Warning { Write-Host "[WARNING] $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "[ERROR] $args" -ForegroundColor Red }

Write-Info "=== Cursor Settings Sync from Dotfiles (Windows) ==="
Write-Host ""

# Detect WSL distro and construct paths
$wslDistro = "Debian"
$dotfilesBase = "\\wsl$\$wslDistro\home\christian\.config\dotfiles\.config\cursor"

# Source files from WSL dotfiles
$sourceSettings = Join-Path $dotfilesBase "settings.json"
$sourceKeybindings = Join-Path $dotfilesBase "keybindings.json"
$sourceExtensions = Join-Path $dotfilesBase "extensions.json"

# Target directories on Windows
$cursorUserDir = "$env:APPDATA\Cursor\User"
$targetSettings = Join-Path $cursorUserDir "settings.json"
$targetKeybindings = Join-Path $cursorUserDir "keybindings.json"

Write-Info "Source (WSL): $dotfilesBase"
Write-Info "Target (Windows): $cursorUserDir"
Write-Host ""

# Check if WSL path is accessible
if (-not (Test-Path $dotfilesBase)) {
    Write-Error "Cannot access dotfiles at: $dotfilesBase"
    Write-Info "Make sure:"
    Write-Info "  1. WSL is running"
    Write-Info "  2. The path exists in your WSL distribution"
    Write-Info "  3. You're using the correct WSL distro name (current: $wslDistro)"
    Write-Host ""
    Write-Info "Available WSL distros:"
    wsl --list --quiet
    exit 1
}

# Check if Cursor User directory exists
if (-not (Test-Path $cursorUserDir)) {
    Write-Error "Cursor User directory not found: $cursorUserDir"
    Write-Info "Is Cursor installed?"
    exit 1
}

# Function to create backup
function New-Backup {
    param([string]$FilePath)
    
    if (Test-Path $FilePath) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = "$FilePath.backup.$timestamp"
        Write-Info "Creating backup: $backupPath"
        Copy-Item $FilePath $backupPath
        Write-Success "Backup created"
    }
}

# Function to sync file
function Sync-File {
    param(
        [string]$Source,
        [string]$Target,
        [string]$Description
    )
    
    if (-not (Test-Path $Source)) {
        Write-Warning "Source not found, skipping: $Description"
        return $false
    }
    
    # Check if target exists and compare
    if (Test-Path $Target) {
        $sourceHash = (Get-FileHash $Source -Algorithm MD5).Hash
        $targetHash = (Get-FileHash $Target -Algorithm MD5).Hash
        
        if ($sourceHash -eq $targetHash -and -not $Force) {
            Write-Success "✓ $Description is already up to date"
            return $true
        }
        
        # Create backup before overwriting
        New-Backup -FilePath $Target
    }
    
    # Copy file
    Write-Info "Syncing: $Description"
    Copy-Item $Source $Target -Force
    Write-Success "✓ Synced: $Description"
    return $true
}

# ============================================
# SYNC SETTINGS FILES
# ============================================

if (-not $ExtensionsOnly) {
    if (-not $SkipSettings) {
        Write-Info "--- Syncing Settings Files ---"
        Write-Host ""
        
        $settingsSynced = Sync-File -Source $sourceSettings -Target $targetSettings -Description "settings.json"
        $keybindingsSynced = Sync-File -Source $sourceKeybindings -Target $targetKeybindings -Description "keybindings.json"
        
        Write-Host ""
        
        if ($settingsSynced -or $keybindingsSynced) {
            Write-Success "Settings sync complete"
            Write-Info "Restart Cursor to apply changes"
        } else {
            Write-Warning "No settings were synced"
        }
        
        Write-Host ""
    } else {
        Write-Info "Skipping settings sync (--SkipSettings)"
        Write-Host ""
    }
}

# ============================================
# INSTALL EXTENSIONS
# ============================================

if (-not $SkipExtensions) {
    Write-Info "--- Installing Extensions ---"
    Write-Host ""
    
    # Check if extensions.json exists
    if (-not (Test-Path $sourceExtensions)) {
        Write-Warning "Extensions file not found: $sourceExtensions"
        Write-Warning "Skipping extension installation"
    } else {
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
            Write-Warning "Skipping extension installation"
        } else {
            Write-Info "Using CLI: $cursorCli"
            Write-Host ""
            
            # Read and parse extensions.json
            try {
                $extensionsJson = Get-Content -Path $sourceExtensions -Raw | ConvertFrom-Json
            } catch {
                Write-Error "Failed to parse extensions.json: $_"
                Write-Warning "Skipping extension installation"
                $extensionsJson = $null
            }

            if ($extensionsJson -and $extensionsJson.Count -gt 0) {
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
                    if (-not $Force -and ($installedExtensions -contains $extensionId)) {
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
                
                # Extension Summary
                Write-Host ""
                Write-Info "=== Extension Installation Summary ==="
                Write-Success "✓ Installed: $installedCount"
                Write-Info "⊙ Already installed (skipped): $skippedCount"
                if ($failedCount -gt 0) {
                    Write-Error "✗ Failed: $failedCount"
                    Write-Host ""
                    Write-Warning "Failed extensions:"
                    foreach ($failed in $failedExtensions) {
                        Write-Warning "  - $failed"
                    }
                }
            } else {
                Write-Warning "No extensions found in extensions.json"
            }
        }
    }
} else {
    Write-Info "Skipping extension installation (--SkipExtensions)"
}

# ============================================
# FINAL SUMMARY
# ============================================

Write-Host ""
Write-Success "=== Cursor Sync Complete! ==="
Write-Host ""

if (-not $ExtensionsOnly -and -not $SkipSettings) {
    Write-Info "Settings and keybindings have been synced from dotfiles"
}

if (-not $SkipExtensions) {
    Write-Info "Extensions have been installed"
}

Write-Host ""
Write-Warning "IMPORTANT: Restart Cursor to apply all changes"
Write-Host ""
Write-Info "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
