# 🧹 Dev Cleaner Utility

<p align="center">
    <a href="YOUR_GITHUB_REPO_LINK">
        <img src="https://img.shields.io/badge/Status-Active-brightgreen" alt="Status">
    </a>
    <a href="YOUR_GITHUB_REPO_LINK/stargazers">
        <img src="https://img.shields.io/github/stars/jemishavasoya/dev-cleaner" alt="GitHub stars">
    </a>
</p>

<p align="center">
  <img src="./images/poster_1.0.1.png" alt="poster_1.0.1" style="width:100%; height:auto; style="border-radius: 8px;"/><br>
</p>

## Support Latest macOS/Linux/Windows Dev Environments

This tool is for **educational purposes**, focusing on safely removing development-related junk files (Xcode, Flutter, Visual Studio, npm, etc.) to free up disk space.

---

### ✨ Features

* **One-Click Cleanup:** Clear Xcode, Flutter, Visual Studio, Gradle, npm, NuGet, IDE, and browser caches.
* **Comprehensive Flutter Cleanup:** Recursively finds and cleans all Flutter projects, removing:
  * FVM SDK caches and configurations (`.fvm`, `.fvmrc`)
  * Flutter build artifacts (`build`, `.dart_tool`, `.packages`, `pubspec.lock`)
  * Android Gradle caches (`android/.gradle`, `android/build`, `android/app/build`)
  * iOS CocoaPods caches (`ios/Pods`, `ios/Podfile.lock`, `ios/.symlinks`, Flutter frameworks)
  * Global Flutter cache
* **Interactive Menu:** Allows selection of specific cleanup targets (e.g., Xcode only).
* **Multi-platform Support:** Supports **macOS**, **Linux**, and **Windows**.

---

### 💻 System Support

| Operating System | Architecture | Supported |
| :--------------- | :----------- | :-------- |
| macOS            | Intel, Apple Silicon | ✅        |
| Linux            | x64, ARM64   | ✅        |
| Windows          | x64, ARM64   | ✅        |

---

### 👀 How to Use

#### ⭐ Auto Run Script

**Linux/macOS**

To download, grant permission, and run the utility in one line:

```bash
curl -fsSL https://raw.githubusercontent.com/jemishavasoya/dev-cleaner/main/dev-cleaner.sh -o dev-cleanup.sh && chmod +x dev-cleanup.sh && ./dev-cleanup.sh
```

#### 🍺 Install via Homebrew

**macOS/Linux**

For a permanent installation using Homebrew:

```bash
# Tap the repository
brew tap jemishavasoya/dev-cleaner

# Install dev-cleaner
brew install dev-cleaner

# Run the utility
dev-cleaner

# Check version
dev-cleaner --version
```

To update to the latest version:

```bash
brew update
brew upgrade dev-cleaner
```

To uninstall:

```bash
brew uninstall dev-cleaner
brew untap jemishavasoya/dev-cleaner
```

#### 🪟 Windows Installation

**PowerShell (Run as Administrator)**

##### One-Line Download & Run

```powershell
irm https://raw.githubusercontent.com/jemishavasoya/dev-cleaner/main/dev-cleaner.ps1 -OutFile dev-cleaner.ps1; .\dev-cleaner.ps1
```

> **Note:** You may need to set the execution policy first:
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```

##### Manual Download

1. Download `dev-cleaner.ps1` from this repository
2. Right-click the file → **Run with PowerShell**, or
3. Open PowerShell as Administrator and run:
   ```powershell
   .\dev-cleaner.ps1
   ```

##### Command-Line Options

```powershell
# Show help
.\dev-cleaner.ps1 -Help

# Show version
.\dev-cleaner.ps1 -Version

# Custom Flutter projects directory
.\dev-cleaner.ps1 -FlutterDir "C:\Projects\Flutter"

# Custom Visual Studio projects directory
.\dev-cleaner.ps1 -VsDir "C:\Projects\DotNet"

# Both custom directories
.\dev-cleaner.ps1 -FlutterDir "D:\Flutter" -VsDir "D:\VisualStudio"
```

##### Environment Variables

```powershell
# Set in your PowerShell profile for persistence
$env:FLUTTER_SEARCH_DIR = "C:\Projects\Flutter"
$env:VS_SEARCH_DIR = "C:\Projects\DotNet"
```

##### Windows-Specific Cleanup

The Windows version includes all cross-platform cleanups plus:

- **Visual Studio:** Cleans `bin/`, `obj/`, `.vs/` folders from all .NET projects, plus global VS caches (ComponentModelCache, MEFCacheData)
- **NuGet:** Clears global packages cache (`~/.nuget/packages`), HTTP cache, and temp files
- **Windows Temp:** Clears user and system temp folders, plus Recycle Bin

> **Note:** Some operations require Administrator privileges. The script will automatically request elevation if needed.

#### 🧹 Flutter Cleanup Details

The Flutter cleanup option (Option 4) performs a comprehensive recursive cleanup of all Flutter projects starting from the current directory. It:

- **Recursively searches** for all `pubspec.yaml` files
- **Removes FVM** SDK caches and configurations
- **Cleans build artifacts**: `build/`, `.dart_tool/`, `.packages`, `pubspec.lock`
- **Removes Android Gradle** caches from each project
- **Removes iOS CocoaPods** caches and Flutter frameworks
- **Cleans global Flutter cache**

**💡 Pro Tip:** If you have active projects you work on daily, consider running the cleanup from a specific subdirectory (e.g., `~/old_projects` or `~/research`) rather than your entire development folder. This avoids unnecessary rebuilds of dependencies for active projects.

**Expected Space Savings:** Users have reported freeing up 50-100GB+ of disk space after running Flutter cleanup on multiple projects.
### You can also buy me a cup of coffee &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://www.buymeacoffee.com/jempatellbv" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Tea" style="height: 60px !important;width: 217px !important;" ></a>

## 🤩 Contribution 

We welcome you to submit Issues and Pull Requests!

<a href="https://github.com/jemishavasoya/dev-cleaner/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=jemishavasoya/dev-cleaner&preview=false&max=&columns=" />
</a>
<br /><br />

## Common Issues

### Permission Errors
- If you encounter permission errors while running scripts, try running with `sudo` (Linux/macOS) or as Administrator (Windows).

### Tool Not Found
- Make sure tools like `flutter` or `brew` are installed and added to your system PATH.
- On macOS/Linux, check PATH with `echo $PATH`.
- On Windows, check Environment Variables in System Settings.
