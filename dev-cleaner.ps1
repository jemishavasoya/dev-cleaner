#requires -Version 5.1
<#
    🚀 Dev Cleanup Utility 🧹 (Windows / PowerShell)

    Features:
    - Interactive menu
    - Clear caches for Gradle/Android, Flutter, npm/yarn/pnpm, IDEs, Browsers
    - System junk cleanup (Recycle Bin, temp files)

    Notes:
    - Some operations may require running PowerShell as Administrator.
    - The script avoids throwing on missing paths and continues safely.
#>

$ErrorActionPreference = 'Stop'

$script:ScriptVersion = '1.0.0'

function Write-Info {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "[x] $Message" -ForegroundColor Red
}

function Print-Logo {
    Write-Host "" 
    Write-Host "██████╗ ███████╗██╗    ██╗     ██████╗██╗     ███████╗ █████╗ ███╗   ██╗███████╗██████╗" -ForegroundColor Cyan
    Write-Host "██╔══██╗██╔════╝██║    ██║    ██╔════╝██║     ██╔════╝██╔══██╗████╗  ██║██╔════╝██╔══██╗" -ForegroundColor Cyan
    Write-Host "██║  ██║█████╗  ██║    ██║    ██║     ██║     █████╗  ███████║██╔██╗ ██║█████╗  ██████╔╝" -ForegroundColor Cyan
    Write-Host "██║  ██║██╔══╝  ╚██╗ ██╔╝     ██║     ██║     ██╔══╝  ██╔══██║██║╚██╗██║██╔══╝  ██╔══██╗" -ForegroundColor Cyan
    Write-Host "██████╔╝███████╗ ╚████╔╝      ╚██████╗███████╗███████╗██║  ██║██║ ╚████║███████╗██║  ██║" -ForegroundColor Cyan
    Write-Host "╚═════╝ ╚══════╝  ╚═══╝        ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝" -ForegroundColor Cyan
    Write-Host ""
}

function Get-FreeSpaceGB {
    try {
        $currentPath = (Get-Location).Path
        $driveLetter = $currentPath.Substring(0,1)
        if ($driveLetter -match '[A-Za-z]') {
            $drive = Get-PSDrive -Name $driveLetter -ErrorAction Stop
            return [math]::Round($drive.Free/1GB, 2)
        }
    } catch {
        try {
            $qualifier = Split-Path -Qualifier $currentPath -ErrorAction SilentlyContinue
            if ($qualifier) {
                $sys = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -eq $qualifier } | Select-Object -First 1
                if ($sys) { return [math]::Round($sys.Free/1GB,2) }
            }
        } catch {}
    }
    try {
        # Fallback: get free space from current directory's drive
        $driveInfo = [System.IO.DriveInfo]::GetDrives() | Where-Object { $currentPath.StartsWith($_.RootDirectory.FullName, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if ($driveInfo) { return [math]::Round($driveInfo.AvailableFreeSpace/1GB, 2) }
    } catch {}
    return $null
}

function Safe-Remove {
    param([Parameter(Mandatory)][string[]]$Paths)
    foreach ($p in $Paths) {
        try {
            # Check if path contains wildcards
            if ($p -match '\*') {
                # Expand wildcards using Get-ChildItem (without -LiteralPath)
                $parentPath = Split-Path -Parent $p -ErrorAction SilentlyContinue
                if (-not $parentPath) { $parentPath = Split-Path -Parent (Resolve-Path $p -ErrorAction SilentlyContinue) }
                if ($parentPath -and (Test-Path $parentPath)) {
                    $matches = Get-ChildItem -Path $p -ErrorAction SilentlyContinue | Where-Object { Test-Path $_.FullName }
                    foreach ($match in $matches) {
                        try {
                            Remove-Item -LiteralPath $match.FullName -Recurse -Force -ErrorAction SilentlyContinue
                            Write-Info "Removed: $($match.FullName)"
                        } catch {
                            Write-Warn "Skip (in use or protected): $($match.FullName)"
                        }
                    }
                    if (-not $matches) {
                        Write-Warn "Not found: $p"
                    }
                } else {
                    Write-Warn "Parent path not found: $p"
                }
            } else {
                # Normal path without wildcards
                if (Test-Path -LiteralPath $p) {
                    Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Info "Removed: $p"
                } else {
                    Write-Warn "Not found: $p"
                }
            }
        } catch {
            Write-Warn "Skip (in use or protected): $p"
        }
    }
}

function Cleanup-AndroidGradle {
    Write-Host "➤ Android/Gradle" -ForegroundColor Cyan
    $gradle = Join-Path $env:USERPROFILE ".gradle"
    Safe-Remove -Paths @( 
        Join-Path $gradle "caches",
        Join-Path $gradle "daemon"
    )
    # Android Studio caches (best-effort) - handle wildcards properly
    try {
        $androidStudioPaths = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA "Google") -Filter "AndroidStudio*" -Directory -ErrorAction SilentlyContinue
        foreach ($path in $androidStudioPaths) {
            $cachePath = Join-Path $path.FullName "caches"
            Safe-Remove -Paths @($cachePath)
        }
        $jetbrainsPaths = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA "JetBrains") -Directory -ErrorAction SilentlyContinue
        foreach ($path in $jetbrainsPaths) {
            $cachePath = Join-Path $path.FullName "caches"
            Safe-Remove -Paths @($cachePath)
        }
    } catch {
        Write-Warn "Could not enumerate IDE cache directories"
    }
}

function Cleanup-Flutter {
    Write-Host "➤ Flutter" -ForegroundColor Cyan
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterCmd) {
        Write-Info "Running 'flutter clean' in detected projects..."
        $pubspecs = Get-ChildItem -Path (Get-Location) -Filter pubspec.yaml -Recurse -ErrorAction SilentlyContinue
        foreach ($f in $pubspecs) {
            Push-Location $f.Directory.FullName
            try { flutter clean | Out-Null } catch { Write-Warn "flutter clean failed in $($f.Directory.FullName)" }
            Pop-Location
        }
        Write-Info "Cleaning Flutter global cache..."
        try { flutter cache clean | Out-Null } catch { Write-Warn "flutter cache clean failed" }
    } else {
        Write-Warn "Flutter not found. Skipping."
    }
}

function Cleanup-PackageManagers {
    Write-Host "➤ npm / yarn / pnpm" -ForegroundColor Cyan
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        try { npm cache clean --force | Out-Null; Write-Info "npm cache cleaned" } catch { Write-Warn "npm cache clean failed" }
    } else { Write-Warn "npm not found" }
    if (Get-Command yarn -ErrorAction SilentlyContinue) {
        try { yarn cache clean | Out-Null; Write-Info "yarn cache cleaned" } catch { Write-Warn "yarn cache clean failed" }
    } else { Write-Warn "yarn not found" }
    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        try { pnpm store prune | Out-Null; Write-Info "pnpm store pruned" } catch { Write-Warn "pnpm store prune failed" }
    } else { Write-Warn "pnpm not found" }
}

function Cleanup-IDECaches {
    Write-Host "➤ IDE Caches (JetBrains, VSCode)" -ForegroundColor Cyan
    Safe-Remove -Paths @(
        (Join-Path $env:LOCALAPPDATA "JetBrains"),
        (Join-Path $env:APPDATA "Code\Cache"),
        (Join-Path $env:APPDATA "Code\CachedData"),
        (Join-Path $env:APPDATA "Code\User\workspaceStorage")
    )
}

function Cleanup-SystemJunk {
    Write-Host "➤ System Junk & Logs" -ForegroundColor Cyan
    try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Write-Info "Recycle Bin emptied" } catch { Write-Warn "Recycle Bin not cleared" }
    # Clean temp directories - remove all contents but keep the directory
    try {
        $tempItems = Get-ChildItem -Path $env:TEMP -ErrorAction SilentlyContinue | Where-Object { Test-Path $_.FullName }
        foreach ($item in $tempItems) {
            try {
                Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Warn "Could not remove: $($item.FullName)"
            }
        }
        if ($tempItems) { Write-Info "Cleaned: $env:TEMP" }
    } catch { Write-Warn "Could not clean TEMP directory" }
    try {
        $localTemp = Join-Path $env:LOCALAPPDATA "Temp"
        if (Test-Path $localTemp) {
            $localTempItems = Get-ChildItem -Path $localTemp -ErrorAction SilentlyContinue | Where-Object { Test-Path $_.FullName }
            foreach ($item in $localTempItems) {
                try {
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-Warn "Could not remove: $($item.FullName)"
                }
            }
            if ($localTempItems) { Write-Info "Cleaned: $localTemp" }
        }
    } catch { Write-Warn "Could not clean LOCALAPPDATA\Temp directory" }
    $isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isElevated) {
        # Clean Windows temp directories
        try {
            $winTempItems = Get-ChildItem -Path "C:\Windows\Temp" -ErrorAction SilentlyContinue | Where-Object { Test-Path $_.FullName }
            foreach ($item in $winTempItems) {
                try {
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-Warn "Could not remove: $($item.FullName)"
                }
            }
            if ($winTempItems) { Write-Info "Cleaned: C:\Windows\Temp" }
        } catch { Write-Warn "Could not clean C:\Windows\Temp" }
        try {
            $winDownloadItems = Get-ChildItem -Path "C:\Windows\SoftwareDistribution\Download" -ErrorAction SilentlyContinue | Where-Object { Test-Path $_.FullName }
            foreach ($item in $winDownloadItems) {
                try {
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-Warn "Could not remove: $($item.FullName)"
                }
            }
            if ($winDownloadItems) { Write-Info "Cleaned: C:\Windows\SoftwareDistribution\Download" }
        } catch { Write-Warn "Could not clean C:\Windows\SoftwareDistribution\Download" }
    } else {
        Write-Warn "Run as Administrator for deeper system cleanup."
    }
}

function Cleanup-BrowserCaches {
    Write-Host "➤ Browser Caches" -ForegroundColor Cyan
    # Chrome
    Safe-Remove -Paths @(
        (Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Cache"),
        (Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Code Cache")
    )
    # Edge
    Safe-Remove -Paths @(
        (Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data\Default\Cache"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data\Default\Code Cache")
    )
    # Brave
    Safe-Remove -Paths @(
        (Join-Path $env:LOCALAPPDATA "BraveSoftware\Brave-Browser\User Data\Default\Cache"),
        (Join-Path $env:LOCALAPPDATA "BraveSoftware\Brave-Browser\User Data\Default\Code Cache")
    )
    # Firefox (cache2 inside profiles)
    $ffProfiles = Join-Path $env:APPDATA "Mozilla\Firefox\Profiles"
    if (Test-Path $ffProfiles) {
        Get-ChildItem -Path $ffProfiles -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Safe-Remove -Paths @((Join-Path $_.FullName "cache2"))
        }
    } else { Write-Warn "Firefox profiles not found" }
    # Opera / Opera GX
    Safe-Remove -Paths @(
        (Join-Path $env:LOCALAPPDATA "Opera Software\Opera Stable\Cache"),
        (Join-Path $env:LOCALAPPDATA "Opera Software\Opera GX Stable\Cache")
    )
}

function Show-Menu {
    Clear-Host
    $free = Get-FreeSpaceGB
    Print-Logo
    Write-Host ("  Version: v{0}" -f $script:ScriptVersion) -ForegroundColor DarkGray
    if ($free -ne $null) { Write-Host ("  Free Space: {0} GB" -f $free) -ForegroundColor Green }
    Write-Host ""
    Write-Host "Available Options:" -ForegroundColor Cyan
    Write-Host "  0. Exit"
    Write-Host "  1. Clear ALL"
    Write-Host "  2. Clear Android/Gradle Caches"
    Write-Host "  3. Clear Flutter Caches"
    Write-Host "  4. Clear npm/yarn/pnpm Caches"
    Write-Host "  5. Clear IDE Caches (JetBrains, VSCode)"
    Write-Host "  6. Clean System Junk & Logs (Recycle Bin, Temp)"
    Write-Host "  7. Clear Browser Caches (Chrome, Edge, Brave, Firefox, Opera)"
    Write-Host ""
}

function Run-Selection {
    param([int]$Choice)
    switch ($Choice) {
        0 { Write-Host "Exiting cleanup utility. Goodbye!" -ForegroundColor Green }
        1 { Cleanup-AndroidGradle; Cleanup-Flutter; Cleanup-PackageManagers; Cleanup-IDECaches; Cleanup-SystemJunk; Cleanup-BrowserCaches }
        2 { Cleanup-AndroidGradle }
        3 { Cleanup-Flutter }
        4 { Cleanup-PackageManagers }
        5 { Cleanup-IDECaches }
        6 { Cleanup-SystemJunk }
        7 { Cleanup-BrowserCaches }
        Default { Write-Err "Invalid choice. Enter a number 0-7." }
    }
}

function Start-CleanupUI {
    Clear-Host
    Write-Host "--- 🚀 Dev Cleanup Utility ---" -ForegroundColor Red
    Write-Host "This will permanently delete cache files from your system."
    Write-Host "Close development apps (Android Studio, VSCode, etc.) before running." -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Are you sure you want to start? (y/N)"
    if ($confirm -notin @('y','Y')) { Write-Host "Cancelled."; return }

    while ($true) {
        $before = Get-FreeSpaceGB
        Show-Menu
        $sel = Read-Host "→ Enter your choice (0-7)"
        if (-not ($sel -as [int])) { Write-Err "Please enter a number."; Start-Sleep -Seconds 1.5; continue }
        $sel = [int]$sel
        if ($sel -eq 0) { Run-Selection 0; break }
        Run-Selection $sel
        $after = Get-FreeSpaceGB
        Write-Host ""; Write-Host "✅ Completed!" -ForegroundColor Green
        if ($before -ne $null -and $after -ne $null) {
            Write-Host ("Free space before: {0} GB" -f $before) -ForegroundColor Blue
            Write-Host ("Free space after:  {0} GB" -f $after) -ForegroundColor Blue
        }
        Write-Host ""
        Read-Host "Press Enter to return to the menu"
    }
}

Start-CleanupUI



