# -----------------------------------------------------------------------------
# Dev Cleanup Utility - Windows PowerShell Edition
# -----------------------------------------------------------------------------
# Version: 1.2.0
# Platform: Windows (PowerShell 5.1+)
# Repository: https://github.com/jemishavasoya/dev-cleaner
# -----------------------------------------------------------------------------

param(
    [switch]$Help,
    [switch]$Version,
    [string]$FlutterDir,
    [string]$VsDir
)

# --- Global Variables ---
$SCRIPT_VERSION = "1.2.0"
$GITHUB_REPO = "https://github.com/jemishavasoya/dev-cleaner"

# --- Error Tracking ---
$script:FailedItems = [System.Collections.ArrayList]::new()

# --- Helper Functions ---

function Show-Logo {
    Write-Host ""
    Write-Host "██████╗ ███████╗██╗    ██╗     ██████╗██╗     ███████╗ █████╗ ███╗   ██╗███████╗██████╗" -ForegroundColor Cyan
    Write-Host "██╔══██╗██╔════╝██║    ██║    ██╔════╝██║     ██╔════╝██╔══██╗████╗  ██║██╔════╝██╔══██╗" -ForegroundColor Cyan
    Write-Host "██║  ██║█████╗  ██║    ██║    ██║     ██║     █████╗  ███████║██╔██╗ ██║█████╗  ██████╔╝" -ForegroundColor Cyan
    Write-Host "██║  ██║██╔══╝  ╚██╗ ██╔╝     ██║     ██║     ██╔══╝  ██╔══██║██║╚██╗██║██╔══╝  ██╔══██╗" -ForegroundColor Cyan
    Write-Host "██████╔╝███████╗ ╚████╔╝      ╚██████╗███████╗███████╗██║  ██║██║ ╚████║███████╗██║  ██║" -ForegroundColor Cyan
    Write-Host "╚═════╝ ╚══════╝  ╚═══╝        ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-HeaderLine {
    param([string]$Char = "─")
    try {
        $width = $Host.UI.RawUI.WindowSize.Width
        if ($width -lt 1) { $width = 80 }
    } catch {
        $width = 80  # Fallback for non-interactive sessions
    }
    Write-Host ($Char * $width)
}

function Write-SectionHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "➤ $Title" -ForegroundColor Blue
    Write-HeaderLine "─"
}

function Write-Item {
    param(
        [string]$Icon,
        [string]$Color,
        [string]$Text
    )
    Write-Host "$Icon $Text" -ForegroundColor $Color
}

function Get-DiskSpace {
    $drive = Get-PSDrive -Name ($PWD.Drive.Name) -ErrorAction SilentlyContinue
    if ($drive) {
        $freeGB = [math]::Round($drive.Free / 1GB, 2)
        return "$freeGB GB"
    }
    return "Unknown"
}

# --- Admin Elevation Functions ---

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-Elevation {
    if (-not (Test-Administrator)) {
        Write-Host "This script requires Administrator privileges." -ForegroundColor Yellow
        Write-Host "Relaunching with elevation..." -ForegroundColor Yellow

        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""

        if ($FlutterDir) { $arguments += " -FlutterDir `"$FlutterDir`"" }
        if ($VsDir) { $arguments += " -VsDir `"$VsDir`"" }

        Start-Process PowerShell -Verb RunAs -ArgumentList $arguments
        exit
    }
}

# --- Error Tracking Functions ---

function Remove-SafelyWithTracking {
    param(
        [string]$Path,
        [string]$Description
    )

    try {
        if (Test-Path $Path) {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            Write-Item "✓" "Green" "Removed: $Description"
        }
    }
    catch {
        $script:FailedItems.Add([PSCustomObject]@{
            Path = $Path
            Reason = $_.Exception.Message
        }) | Out-Null
    }
}

function Show-FailureSummary {
    if ($script:FailedItems.Count -gt 0) {
        Write-Host ""
        Write-Host "Some items could not be deleted:" -ForegroundColor Yellow
        foreach ($item in $script:FailedItems) {
            Write-Host "  - $($item.Path)" -ForegroundColor Red
            Write-Host "    Reason: $($item.Reason)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
    $script:FailedItems.Clear()
}

# --- Cleanup Functions ---

function Clear-VisualStudio {
    param([string]$SearchDir = ".")

    Write-Item "✓" "Green" "Cleaning Visual Studio projects from: $SearchDir"

    if (-not (Test-Path $SearchDir)) {
        Write-Item "✕" "Red" "Directory not found: $SearchDir"
        return
    }

    # Project-level cleanup
    $solutionFiles = Get-ChildItem -Path $SearchDir -Filter "*.sln" -Recurse -ErrorAction SilentlyContinue
    $projectFiles = Get-ChildItem -Path $SearchDir -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue

    $cleanedCount = 0

    foreach ($sln in $solutionFiles) {
        $slnDir = $sln.DirectoryName
        Write-Host "  Cleaning solution: $slnDir" -ForegroundColor Cyan

        Remove-SafelyWithTracking -Path "$slnDir\.vs" -Description ".vs folder in $slnDir"
        $cleanedCount++
    }

    foreach ($proj in $projectFiles) {
        $projDir = $proj.DirectoryName
        Write-Host "  Cleaning project: $projDir" -ForegroundColor Cyan

        Remove-SafelyWithTracking -Path "$projDir\bin" -Description "bin folder in $projDir"
        Remove-SafelyWithTracking -Path "$projDir\obj" -Description "obj folder in $projDir"
        $cleanedCount++
    }

    if ($cleanedCount -gt 0) {
        Write-Item "✓" "Green" "Cleaned $cleanedCount Visual Studio project(s)/solution(s)"
    } else {
        Write-Item "ℹ️" "Yellow" "No Visual Studio projects found in: $SearchDir"
    }

    # Global Visual Studio caches
    Write-Item "✓" "Green" "Cleaning global Visual Studio caches..."

    $vsVersions = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\VisualStudio" -Directory -ErrorAction SilentlyContinue
    foreach ($vsVersion in $vsVersions) {
        Remove-SafelyWithTracking -Path "$($vsVersion.FullName)\ComponentModelCache" -Description "ComponentModelCache"
        Remove-SafelyWithTracking -Path "$($vsVersion.FullName)\MEFCacheData" -Description "MEFCacheData"
        Remove-SafelyWithTracking -Path "$($vsVersion.FullName)\Designer\ShadowCache" -Description "Designer ShadowCache"
        Remove-SafelyWithTracking -Path "$($vsVersion.FullName)\ImageLibrary" -Description "ImageLibrary"
    }
}

function Clear-AndroidGradle {
    if (Test-Path "$env:USERPROFILE\.gradle") {
        Write-Item "✓" "Green" "Cleaning Gradle caches..."
        Remove-SafelyWithTracking -Path "$env:USERPROFILE\.gradle\caches" -Description "Gradle caches"
        Remove-SafelyWithTracking -Path "$env:USERPROFILE\.gradle\daemon" -Description "Gradle daemon"
    } else {
        Write-Item "✕" "Yellow" "Gradle directory not found. Skipping."
    }

    Write-Item "✓" "Green" "Cleaning Android Studio caches..."
    $androidStudioPaths = @(
        "$env:LOCALAPPDATA\Google\AndroidStudio*",
        "$env:LOCALAPPDATA\JetBrains\AndroidStudio*"
    )

    foreach ($pattern in $androidStudioPaths) {
        $paths = Get-ChildItem -Path (Split-Path $pattern -Parent) -Filter (Split-Path $pattern -Leaf) -Directory -ErrorAction SilentlyContinue
        foreach ($path in $paths) {
            Remove-SafelyWithTracking -Path $path.FullName -Description "Android Studio cache: $($path.Name)"
        }
    }
}

function Clear-AndroidSdk {
    $sdkPath = "$env:LOCALAPPDATA\Android\Sdk"

    if (Test-Path $sdkPath) {
        Write-Item "✓" "Green" "Cleaning old Android SDK build-tools (keeping latest 2 versions)..."

        $buildToolsPath = "$sdkPath\build-tools"
        if (Test-Path $buildToolsPath) {
            $versions = Get-ChildItem -Path $buildToolsPath -Directory | Sort-Object Name -Descending
            $toRemove = $versions | Select-Object -Skip 2

            foreach ($version in $toRemove) {
                Remove-SafelyWithTracking -Path $version.FullName -Description "Old build-tools: $($version.Name)"
            }
        }

        Write-Item "✓" "Green" "Cleaning SDK temp files..."
        Remove-SafelyWithTracking -Path "$sdkPath\.temp" -Description "SDK temp folder"
    } else {
        Write-Item "✕" "Yellow" "Android SDK not found. Skipping."
    }
}

function Clear-Flutter {
    param([string]$SearchDir = ".")

    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        Write-Item "✕" "Yellow" "Flutter command not found. Skipping."
        return
    }

    Write-Item "✓" "Green" "Cleaning Flutter projects recursively from: $SearchDir"

    if (-not (Test-Path $SearchDir)) {
        Write-Item "✕" "Red" "Directory not found: $SearchDir"
        return
    }

    $pubspecFiles = Get-ChildItem -Path $SearchDir -Filter "pubspec.yaml" -Recurse -ErrorAction SilentlyContinue
    $cleanedCount = 0

    foreach ($pubspec in $pubspecFiles) {
        $projectDir = $pubspec.DirectoryName
        Write-Host "  Cleaning: $projectDir" -ForegroundColor Cyan

        Push-Location $projectDir

        # FVM cleanup
        if (Test-Path ".fvm") {
            Write-Host "    Removing FVM cache..." -ForegroundColor DarkGray
            Remove-SafelyWithTracking -Path ".fvm" -Description "FVM folder"
        }
        if (Test-Path ".fvmrc") {
            Remove-SafelyWithTracking -Path ".fvmrc" -Description "FVM config"
        }

        # Flutter build artifacts
        Write-Host "    Removing Flutter build artifacts..." -ForegroundColor DarkGray
        Remove-SafelyWithTracking -Path "build" -Description "build folder"
        Remove-SafelyWithTracking -Path ".dart_tool" -Description ".dart_tool folder"
        Remove-SafelyWithTracking -Path ".packages" -Description ".packages file"
        Remove-SafelyWithTracking -Path "pubspec.lock" -Description "pubspec.lock file"

        # Android artifacts
        if (Test-Path "android") {
            Write-Host "    Removing Android build artifacts..." -ForegroundColor DarkGray
            Remove-SafelyWithTracking -Path "android\.gradle" -Description "Android Gradle cache"
            Remove-SafelyWithTracking -Path "android\build" -Description "Android build folder"
            Remove-SafelyWithTracking -Path "android\app\build" -Description "Android app build folder"
        }

        # Windows artifacts
        if (Test-Path "windows\flutter\ephemeral") {
            Write-Host "    Removing Windows ephemeral files..." -ForegroundColor DarkGray
            Remove-SafelyWithTracking -Path "windows\flutter\ephemeral" -Description "Windows ephemeral folder"
        }

        Pop-Location
        $cleanedCount++
        Write-Host "  ✅ Cleaned $projectDir" -ForegroundColor Green
    }

    if ($cleanedCount -gt 0) {
        Write-Item "✓" "Green" "Cleaned $cleanedCount Flutter project(s)"
    } else {
        Write-Item "ℹ️" "Yellow" "No Flutter projects found in: $SearchDir"
    }

    Write-Item "✓" "Green" "Cleaning Flutter global cache..."
    try {
        flutter cache clean 2>$null
    } catch {
        Write-Item "✕" "Yellow" "Could not clean Flutter global cache"
    }
}

function Clear-NpmYarnPnpm {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Item "✓" "Green" "Cleaning npm cache..."
        try {
            npm cache clean --force 2>$null
        } catch {
            Write-Item "✕" "Yellow" "Could not clean npm cache"
        }
    } else {
        Write-Item "✕" "Yellow" "npm not found. Skipping."
    }

    if (Get-Command yarn -ErrorAction SilentlyContinue) {
        Write-Item "✓" "Green" "Cleaning yarn cache..."
        try {
            yarn cache clean 2>$null
        } catch {
            Write-Item "✕" "Yellow" "Could not clean yarn cache"
        }
    } else {
        Write-Item "✕" "Yellow" "yarn not found. Skipping."
    }

    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        Write-Item "✓" "Green" "Pruning pnpm store..."
        try {
            pnpm store prune 2>$null
        } catch {
            Write-Item "✕" "Yellow" "Could not prune pnpm store"
        }
    } else {
        Write-Item "✕" "Yellow" "pnpm not found. Skipping."
    }

    # Manual pnpm cache cleanup
    Remove-SafelyWithTracking -Path "$env:LOCALAPPDATA\pnpm\store" -Description "pnpm store"
    Remove-SafelyWithTracking -Path "$env:LOCALAPPDATA\pnpm-cache" -Description "pnpm cache"

    if (Get-Command bun -ErrorAction SilentlyContinue) {
        Write-Item "✓" "Green" "Cleaning bun cache..."
        try {
            bun --cm dl 2>$null
        } catch {
            Write-Item "✕" "Yellow" "Could not clean bun cache"
        }
    } else {
        Write-Item "✕" "Yellow" "bun not found. Skipping."
    }
}

function Clear-NuGet {
    Write-Item "✓" "Green" "Cleaning NuGet caches..."

    Remove-SafelyWithTracking -Path "$env:USERPROFILE\.nuget\packages" -Description "NuGet global packages"
    Remove-SafelyWithTracking -Path "$env:LOCALAPPDATA\NuGet\v3-cache" -Description "NuGet HTTP cache"
    Remove-SafelyWithTracking -Path "$env:LOCALAPPDATA\NuGet\plugins-cache" -Description "NuGet plugins cache"
    Remove-SafelyWithTracking -Path "$env:TEMP\NuGetScratch" -Description "NuGet temp files"

    # Alternative: Use dotnet CLI if available
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        try {
            dotnet nuget locals all --clear 2>$null
            Write-Item "✓" "Green" "Cleared NuGet caches via dotnet CLI"
        } catch {
            Write-Item "ℹ️" "Yellow" "dotnet nuget locals command skipped"
        }
    }
}

function Clear-PlatformIO {
    $pioBin = "$env:USERPROFILE\.platformio\penv\Scripts\pio.exe"

    if (-not (Test-Path $pioBin)) {
        if (Get-Command pio -ErrorAction SilentlyContinue) {
            $pioBin = "pio"
        } else {
            Write-Item "✕" "Yellow" "PlatformIO not found. Skipping."
            return
        }
    }

    Write-Item "✓" "Green" "Cleaning PlatformIO project builds..."

    $platformioFiles = Get-ChildItem -Path $env:USERPROFILE -Filter "platformio.ini" -Recurse -Depth 4 -ErrorAction SilentlyContinue |
                       Where-Object { $_.FullName -notmatch "\\Library\\" }

    foreach ($file in $platformioFiles) {
        $projectDir = $file.DirectoryName
        Write-Host "  Running pio clean in: $projectDir" -ForegroundColor Cyan

        Push-Location $projectDir
        try {
            & $pioBin run -t clean 2>$null
        } catch {
            Write-Item "✕" "Yellow" "Could not clean $projectDir"
        }
        Pop-Location
    }
}

function Clear-IdeCaches {
    Write-Item "✓" "Green" "Cleaning JetBrains IDE caches..."

    $jetBrainsVersions = Get-ChildItem -Path "$env:LOCALAPPDATA\JetBrains" -Directory -ErrorAction SilentlyContinue
    foreach ($version in $jetBrainsVersions) {
        Remove-SafelyWithTracking -Path "$($version.FullName)\caches" -Description "JetBrains caches: $($version.Name)"
        Remove-SafelyWithTracking -Path "$($version.FullName)\index" -Description "JetBrains index: $($version.Name)"
        Remove-SafelyWithTracking -Path "$($version.FullName)\tmp" -Description "JetBrains temp: $($version.Name)"
    }

    Write-Item "✓" "Green" "Cleaning VSCode cache..."
    Remove-SafelyWithTracking -Path "$env:APPDATA\Code\Cache" -Description "VSCode Cache"
    Remove-SafelyWithTracking -Path "$env:APPDATA\Code\CachedData" -Description "VSCode CachedData"
    Remove-SafelyWithTracking -Path "$env:APPDATA\Code\CachedExtensionVSIXs" -Description "VSCode CachedExtensionVSIXs"
    Remove-SafelyWithTracking -Path "$env:APPDATA\Code\User\workspaceStorage" -Description "VSCode workspaceStorage"

    Write-Item "✓" "Green" "Cleaning VSCode Insiders cache..."
    Remove-SafelyWithTracking -Path "$env:APPDATA\Code - Insiders\Cache" -Description "VSCode Insiders Cache"
    Remove-SafelyWithTracking -Path "$env:APPDATA\Code - Insiders\CachedData" -Description "VSCode Insiders CachedData"
}

function Clear-WindowsTemp {
    Write-Item "✓" "Green" "Cleaning user temp files..."

    Get-ChildItem -Path $env:TEMP -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-SafelyWithTracking -Path $_.FullName -Description "User temp: $($_.Name)"
    }

    Remove-SafelyWithTracking -Path "$env:LOCALAPPDATA\Temp" -Description "Local temp folder"

    Write-Item "✓" "Green" "Emptying Recycle Bin..."
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Item "✓" "Green" "Recycle Bin emptied"
    } catch {
        Write-Item "✕" "Yellow" "Could not empty Recycle Bin"
    }

    if (Test-Administrator) {
        Write-Item "✓" "Green" "Cleaning system temp files (admin)..."

        Get-ChildItem -Path "C:\Windows\Temp" -Force -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-SafelyWithTracking -Path $_.FullName -Description "System temp: $($_.Name)"
        }

        Write-Item "✓" "Green" "Cleaning Windows Update cache (optional)..."
        Get-ChildItem -Path "C:\Windows\SoftwareDistribution\Download" -Force -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-SafelyWithTracking -Path $_.FullName -Description "Windows Update: $($_.Name)"
        }
    } else {
        Write-Item "ℹ️" "Yellow" "System temp cleanup requires admin privileges (skipped)"
    }
}

function Clear-BrowserCaches {
    $browsers = @{
        "Chrome" = @{
            "Cache" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
            "CodeCache" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"
        }
        "Edge" = @{
            "Cache" = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
            "CodeCache" = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"
        }
        "Brave" = @{
            "Cache" = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache"
            "CodeCache" = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Code Cache"
        }
        "Opera" = @{
            "Cache" = "$env:APPDATA\Opera Software\Opera Stable\Cache"
        }
        "Opera GX" = @{
            "Cache" = "$env:APPDATA\Opera Software\Opera GX Stable\Cache"
        }
    }

    foreach ($browser in $browsers.Keys) {
        $found = $false
        foreach ($cacheType in $browsers[$browser].Keys) {
            $path = $browsers[$browser][$cacheType]
            if (Test-Path $path) {
                $found = $true
                Remove-SafelyWithTracking -Path $path -Description "$browser $cacheType"
            }
        }
        if (-not $found) {
            Write-Item "✕" "Yellow" "$browser cache not found. Skipping."
        }
    }

    # Firefox (multiple profiles)
    $firefoxProfiles = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $firefoxProfiles) {
        Write-Item "✓" "Green" "Cleaning Firefox cache..."
        $profiles = Get-ChildItem -Path $firefoxProfiles -Directory -ErrorAction SilentlyContinue
        foreach ($profile in $profiles) {
            Remove-SafelyWithTracking -Path "$($profile.FullName)\cache2" -Description "Firefox cache: $($profile.Name)"
        }
    } else {
        Write-Item "✕" "Yellow" "Firefox cache not found. Skipping."
    }
}

function Clear-AppContainers {
    Write-Item "✓" "Green" "Cleaning app container caches..."

    # Slack
    if (Test-Path "$env:APPDATA\Slack") {
        Remove-SafelyWithTracking -Path "$env:APPDATA\Slack\Cache" -Description "Slack Cache"
        Remove-SafelyWithTracking -Path "$env:APPDATA\Slack\Service Worker\CacheStorage" -Description "Slack Service Worker"
    }

    # Microsoft Teams Classic
    if (Test-Path "$env:APPDATA\Microsoft\Teams") {
        Remove-SafelyWithTracking -Path "$env:APPDATA\Microsoft\Teams\Cache" -Description "Teams Cache"
        Remove-SafelyWithTracking -Path "$env:APPDATA\Microsoft\Teams\blob_storage" -Description "Teams blob storage"
        Remove-SafelyWithTracking -Path "$env:APPDATA\Microsoft\Teams\databases" -Description "Teams databases"
        Remove-SafelyWithTracking -Path "$env:APPDATA\Microsoft\Teams\GPUCache" -Description "Teams GPU Cache"
        Remove-SafelyWithTracking -Path "$env:APPDATA\Microsoft\Teams\IndexedDB" -Description "Teams IndexedDB"
        Remove-SafelyWithTracking -Path "$env:APPDATA\Microsoft\Teams\Local Storage" -Description "Teams Local Storage"
        Remove-SafelyWithTracking -Path "$env:APPDATA\Microsoft\Teams\tmp" -Description "Teams temp"
    }

    # Microsoft Teams New
    $teamsNew = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams"
    if (Test-Path $teamsNew) {
        Remove-SafelyWithTracking -Path $teamsNew -Description "Teams New cache"
    }

    # Discord
    if (Test-Path "$env:APPDATA\discord") {
        Remove-SafelyWithTracking -Path "$env:APPDATA\discord\Cache" -Description "Discord Cache"
        Remove-SafelyWithTracking -Path "$env:APPDATA\discord\Code Cache" -Description "Discord Code Cache"
    }

    # Spotify
    if (Test-Path "$env:LOCALAPPDATA\Spotify") {
        Remove-SafelyWithTracking -Path "$env:LOCALAPPDATA\Spotify\Storage" -Description "Spotify Storage"
    }
    if (Test-Path "$env:APPDATA\Spotify") {
        Remove-SafelyWithTracking -Path "$env:APPDATA\Spotify" -Description "Spotify Data"
    }

    # WhatsApp
    if (Test-Path "$env:LOCALAPPDATA\WhatsApp") {
        Remove-SafelyWithTracking -Path "$env:LOCALAPPDATA\WhatsApp\Cache" -Description "WhatsApp Cache"
    }

    # WhatsApp UWP
    $whatsappUwp = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Filter "*WhatsApp*" -Directory -ErrorAction SilentlyContinue
    foreach ($pkg in $whatsappUwp) {
        Remove-SafelyWithTracking -Path "$($pkg.FullName)\LocalCache" -Description "WhatsApp UWP cache"
    }
}

# --- Menu Display ---

function Show-Menu {
    Clear-Host
    $currentFreeSpace = Get-DiskSpace

    Show-Logo
    Write-Host "  Version: v$SCRIPT_VERSION" -ForegroundColor DarkGray
    Write-Item "✨" "Green" "Free Space: $currentFreeSpace"
    Write-Host ""
    Write-SectionHeader "Available Options:"
    Write-Host " 0. Exit Program" -ForegroundColor Red
    Write-Host " 1. Clear All Caches" -ForegroundColor Green
    Write-Host "─── Development Tools ───" -ForegroundColor DarkGray
    Write-Host " 2. Clear Visual Studio Caches (bin/obj/.vs + global)" -ForegroundColor Green
    Write-Host " 3. Clear Android/Gradle Caches" -ForegroundColor Green
    Write-Host " 4. Clear Android SDK (old build-tools)" -ForegroundColor Green
    Write-Host " 5. Clear Flutter Caches " -NoNewline -ForegroundColor Green
    Write-Host "(with custom directory option)" -ForegroundColor DarkGray
    Write-Host " 6. Clear npm/Yarn/pnpm/bun Caches" -ForegroundColor Green
    Write-Host " 7. Clear NuGet Package Cache" -ForegroundColor Green
    Write-Host " 8. Clear PlatformIO Caches" -ForegroundColor Green
    Write-Host "─── IDEs & Editors ───" -ForegroundColor DarkGray
    Write-Host " 9. Clear IDE Caches (JetBrains, VSCode)" -ForegroundColor Green
    Write-Host "─── System ───" -ForegroundColor DarkGray
    Write-Host "10. Clean Windows Temp & Recycle Bin" -ForegroundColor Green
    Write-Host "11. Clear Browser Caches (Chrome, Edge, Firefox, Brave, Opera)" -ForegroundColor Green
    Write-Host "12. Clean App Caches (Slack, Teams, Discord, Spotify, WhatsApp)" -ForegroundColor Green
    Write-Host ""
    Write-Host "→ Please enter your choice (0-12): " -NoNewline
}

# --- Main Loop ---

function Start-MainLoop {
    while ($true) {
        Show-Menu
        $choice = Read-Host

        Write-Host ""
        $initialFreeSpace = Get-DiskSpace

        switch ($choice) {
            "0" {
                Write-Host "Exiting cleanup utility. Goodbye!" -ForegroundColor Green
                return
            }
            "1" {
                Write-SectionHeader "Performing ALL Cleanup Tasks"
                Clear-VisualStudio -SearchDir $script:VsSearchDir
                Clear-AndroidGradle
                Clear-AndroidSdk
                Clear-Flutter -SearchDir $script:FlutterSearchDir
                Clear-NpmYarnPnpm
                Clear-NuGet
                Clear-PlatformIO
                Clear-IdeCaches
                Clear-WindowsTemp
                Clear-BrowserCaches
                Clear-AppContainers
            }
            "2" {
                Write-SectionHeader "Performing Visual Studio Cleanup"
                Write-Host "Current Visual Studio search directory: $script:VsSearchDir" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Enter a custom directory path, or press Enter to use current setting:" -ForegroundColor Yellow
                $customVsDir = Read-Host

                if ($customVsDir -and (Test-Path $customVsDir)) {
                    Write-Host "Using interactive override: $customVsDir" -ForegroundColor Cyan
                    Clear-VisualStudio -SearchDir $customVsDir
                } elseif ($customVsDir) {
                    Write-Host "Directory does not exist: $customVsDir" -ForegroundColor Red
                    Write-Host "Falling back to: $script:VsSearchDir" -ForegroundColor Yellow
                    Clear-VisualStudio -SearchDir $script:VsSearchDir
                } else {
                    Clear-VisualStudio -SearchDir $script:VsSearchDir
                }
            }
            "3" {
                Write-SectionHeader "Performing Android/Gradle Cleanup"
                Clear-AndroidGradle
            }
            "4" {
                Write-SectionHeader "Performing Android SDK Cleanup"
                Clear-AndroidSdk
            }
            "5" {
                Write-SectionHeader "Performing Flutter Cleanup"
                Write-Host "Current Flutter search directory: $script:FlutterSearchDir" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Enter a custom directory path, or press Enter to use current setting:" -ForegroundColor Yellow
                $customFlutterDir = Read-Host

                if ($customFlutterDir -and (Test-Path $customFlutterDir)) {
                    Write-Host "Using interactive override: $customFlutterDir" -ForegroundColor Cyan
                    Clear-Flutter -SearchDir $customFlutterDir
                } elseif ($customFlutterDir) {
                    Write-Host "Directory does not exist: $customFlutterDir" -ForegroundColor Red
                    Write-Host "Falling back to: $script:FlutterSearchDir" -ForegroundColor Yellow
                    Clear-Flutter -SearchDir $script:FlutterSearchDir
                } else {
                    Clear-Flutter -SearchDir $script:FlutterSearchDir
                }
            }
            "6" {
                Write-SectionHeader "Performing npm/Yarn/pnpm/bun Cleanup"
                Clear-NpmYarnPnpm
            }
            "7" {
                Write-SectionHeader "Performing NuGet Cache Cleanup"
                Clear-NuGet
            }
            "8" {
                Write-SectionHeader "Performing PlatformIO Cleanup"
                Clear-PlatformIO
            }
            "9" {
                Write-SectionHeader "Performing IDE Caches Cleanup"
                Clear-IdeCaches
            }
            "10" {
                Write-SectionHeader "Performing Windows Temp & Recycle Bin Cleanup"
                Clear-WindowsTemp
            }
            "11" {
                Write-SectionHeader "Performing Browser Caches Cleanup"
                Clear-BrowserCaches
            }
            "12" {
                Write-SectionHeader "Performing App Caches Cleanup"
                Clear-AppContainers
            }
            default {
                Write-Host "Invalid choice. Please enter a number between 0 and 12." -ForegroundColor Red
                Start-Sleep -Seconds 2
                continue
            }
        }

        Show-FailureSummary

        $finalFreeSpace = Get-DiskSpace
        Write-Host ""
        Write-Host "✅ Cleanup task(s) completed!" -ForegroundColor Green
        Write-Host "Disk space before: $initialFreeSpace" -ForegroundColor Blue
        Write-Host "Disk space after:  $finalFreeSpace" -ForegroundColor Blue
        Write-Host ""
        Write-Host "Press Enter to return to the menu..." -NoNewline
        Read-Host
    }
}

# --- Entry Point ---

# Handle -Help flag
if ($Help) {
    Write-Host @"
Dev Cleanup Utility v$SCRIPT_VERSION
A powerful cleanup utility for development environments on Windows

Usage: .\dev-cleaner.ps1 [OPTIONS]

Options:
  -Help               Show this help message
  -Version            Show version information
  -FlutterDir PATH    Set custom directory for Flutter cleanup (default: current directory)
                      Example: .\dev-cleaner.ps1 -FlutterDir "C:\Projects"
  -VsDir PATH         Set custom directory for Visual Studio cleanup (default: current directory)
                      Example: .\dev-cleaner.ps1 -VsDir "C:\Projects\DotNet"

Examples:
  .\dev-cleaner.ps1                                    # Run interactive menu
  .\dev-cleaner.ps1 -FlutterDir "C:\Dev\Flutter"       # Custom Flutter search directory
  .\dev-cleaner.ps1 -VsDir "C:\Dev\DotNet"             # Custom VS search directory
  .\dev-cleaner.ps1 -FlutterDir "D:\Projects" -VsDir "D:\VS"  # Both custom directories

Environment Variables:
  `$env:FLUTTER_SEARCH_DIR = "C:\Projects\Flutter"
  `$env:VS_SEARCH_DIR = "C:\Projects\DotNet"

Repository: $GITHUB_REPO
"@
    exit 0
}

# Handle -Version flag
if ($Version) {
    Write-Host "Dev Cleaner v$SCRIPT_VERSION"
    Write-Host "A powerful cleanup utility for development environments"
    Write-Host "Repository: $GITHUB_REPO"
    exit 0
}

# Determine Flutter search directory (priority: CLI > ENV > Default)
$script:FlutterSearchDir = "."
$script:FlutterDirSource = "default"

if ($env:FLUTTER_SEARCH_DIR) {
    $script:FlutterSearchDir = $env:FLUTTER_SEARCH_DIR
    $script:FlutterDirSource = "environment"
}

if ($FlutterDir) {
    $script:FlutterSearchDir = $FlutterDir
    $script:FlutterDirSource = "command-line"
}

# Validate Flutter directory
if ($script:FlutterSearchDir -ne "." -and -not (Test-Path $script:FlutterSearchDir)) {
    Write-Host "Warning: Flutter search directory does not exist: $script:FlutterSearchDir" -ForegroundColor Yellow
    Write-Host "Falling back to current directory." -ForegroundColor Yellow
    $script:FlutterSearchDir = "."
    $script:FlutterDirSource = "default"
}

# Determine Visual Studio search directory (priority: CLI > ENV > Default)
$script:VsSearchDir = "."
$script:VsDirSource = "default"

if ($env:VS_SEARCH_DIR) {
    $script:VsSearchDir = $env:VS_SEARCH_DIR
    $script:VsDirSource = "environment"
}

if ($VsDir) {
    $script:VsSearchDir = $VsDir
    $script:VsDirSource = "command-line"
}

# Validate VS directory
if ($script:VsSearchDir -ne "." -and -not (Test-Path $script:VsSearchDir)) {
    Write-Host "Warning: Visual Studio search directory does not exist: $script:VsSearchDir" -ForegroundColor Yellow
    Write-Host "Falling back to current directory." -ForegroundColor Yellow
    $script:VsSearchDir = "."
    $script:VsDirSource = "default"
}

# Request elevation
Request-Elevation

# Initial confirmation
Clear-Host
Write-Host "--- Dev Cleanup Utility ---" -ForegroundColor Red
Write-Host "This script will permanently delete cache files from your system."
Write-Host "Review the options carefully before proceeding."
Write-Host ""

# Report search directories
if ($script:FlutterSearchDir -ne ".") {
    Write-Host "Flutter search directory: $script:FlutterSearchDir" -ForegroundColor Cyan
    switch ($script:FlutterDirSource) {
        "environment" { Write-Host "  (set via FLUTTER_SEARCH_DIR environment variable)" -ForegroundColor DarkGray }
        "command-line" { Write-Host "  (set via -FlutterDir command-line argument)" -ForegroundColor DarkGray }
    }
    Write-Host ""
} else {
    Write-Host "Flutter search directory: current directory (default)" -ForegroundColor DarkGray
    Write-Host ""
}

if ($script:VsSearchDir -ne ".") {
    Write-Host "Visual Studio search directory: $script:VsSearchDir" -ForegroundColor Cyan
    switch ($script:VsDirSource) {
        "environment" { Write-Host "  (set via VS_SEARCH_DIR environment variable)" -ForegroundColor DarkGray }
        "command-line" { Write-Host "  (set via -VsDir command-line argument)" -ForegroundColor DarkGray }
    }
    Write-Host ""
} else {
    Write-Host "Visual Studio search directory: current directory (default)" -ForegroundColor DarkGray
    Write-Host ""
}

Write-Host "⚠️ This action is IRREVERSIBLE for deleted files. ⚠️" -ForegroundColor Yellow
Write-Host "Please CLOSE all development applications (Visual Studio, Android Studio, VSCode, etc.) before running." -ForegroundColor Yellow
Write-Host ""
$initialConfirm = Read-Host "Are you sure you want to start the cleanup utility? (y/N)"

if ($initialConfirm -ne "y" -and $initialConfirm -ne "Y") {
    Write-Host "Cleanup utility cancelled."
    exit 0
}

# Start main loop
Start-MainLoop
