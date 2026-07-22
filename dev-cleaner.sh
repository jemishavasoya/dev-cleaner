#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# 🚀 Dev Cleanup Utility 🧹
# -----------------------------------------------------------------------------

# --- Colors for pretty printing ---
if [ -t 1 ]; then
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    RED="\033[0;31m"
    BLUE="\033[0;34m"
    CYAN="\033[0;36m"
    MAGENTA="\033[0;35m"
    NC="\033[0m"
    BOLD="\033[1m"
    FAINT="\033[2m"
else
    GREEN=""
    YELLOW=""
    RED=""
    BLUE=""
    CYAN=""
    MAGENTA=""
    NC=""
    BOLD=""
    FAINT=""
fi

# --- Global Variables ---
SCRIPT_VERSION="1.2.0"
GITHUB_REPO="https://github.com/jemishavasoya/dev-cleaner"
DRY_RUN=false

# Check if FLUTTER_SEARCH_DIR is already set as environment variable
if [ -z "${FLUTTER_SEARCH_DIR}" ]; then
    FLUTTER_SEARCH_DIR="."  # Default search directory for Flutter cleanup
    FLUTTER_DIR_SOURCE="default"
else
    # Expand ~ to home directory if present in environment variable
    FLUTTER_SEARCH_DIR="${FLUTTER_SEARCH_DIR/#\~/$HOME}"
    FLUTTER_DIR_SOURCE="environment"
    
    # Validate environment variable directory
    if [ ! -d "$FLUTTER_SEARCH_DIR" ]; then
        echo -e "${YELLOW}Warning: FLUTTER_SEARCH_DIR environment variable points to non-existent directory: ${FLUTTER_SEARCH_DIR}${NC}"
        echo -e "${YELLOW}Falling back to current directory.${NC}"
        FLUTTER_SEARCH_DIR="."
        FLUTTER_DIR_SOURCE="default"
    fi
fi

# Logo
print_logo() {
    echo -e "${CYAN}${BOLD}"
    # Using 'cat << "EOF"' with no leading space on the logo lines ensures perfect alignment.
    cat << "EOF"
██████╗ ███████╗██╗    ██╗     ██████╗██╗     ███████╗ █████╗ ███╗   ██╗███████╗██████╗
██╔══██╗██╔════╝██║    ██║    ██╔════╝██║     ██╔════╝██╔══██╗████╗  ██║██╔════╝██╔══██╗
██║  ██║█████╗  ██║    ██║    ██║     ██║     █████╗  ███████║██╔██╗ ██║█████╗  ██████╔╝
██║  ██║██╔══╝  ╚██╗ ██╔╝     ██║     ██║     ██╔══╝  ██╔══██║██║╚██╗██║██╔══╝  ██╔══██╗
██████╔╝███████╗ ╚████╔╝      ╚██████╗███████╗███████╗██║  ██║██║ ╚████║███████╗██║  ██║
╚═════╝ ╚══════╝  ╚═══╝        ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝
EOF
    echo -e "${NC}"
}

# --- Helper Functions ---
print_header_line() {
    local char="${1:-─}"
    printf "%$(tput cols)s\n" "" | tr " " "$char"
}

print_section_header() {
    echo -e "${BLUE}${BOLD}➤ $1${NC}"
    print_header_line "─"
}

print_item() {
    local icon="${1}"
    local color="${2}"
    local text="${3}"
    echo -e "${color}${icon} ${text}${NC}"
}

get_disk_space() {
    df -h . | awk 'NR==2 {print $4}'
}

# --- Estimation helpers (read-only: never delete anything) ---

# Format a size given in KB into a human-readable string using the same
# binary units as `df -h` on macOS (Gi/Mi/Ki), so the estimate matches the
# "Free Space" figure shown at the top of the menu.
human_kb() {
    awk -v kb="${1:-0}" 'BEGIN {
        if (kb >= 1048576)      printf "%.1fGi", kb / 1048576;
        else if (kb >= 1024)    printf "%.1fMi", kb / 1024;
        else                    printf "%dKi", kb;
    }'
}

# Convert a Docker size string (Docker uses DECIMAL units: B/kB/MB/GB/TB,
# e.g. "1.02GB", "728.5MB", "32.8kB", "0B") into KiB so Docker's own
# self-reported sizes can be summed and fed to human_kb() like every other
# estimate. Suffix order matters: kB/MB/GB/TB all end in "B", so the bare
# "B" case must be checked last. Read-only.
docker_size_to_kb() {
    awk -v s="${1:-0B}" 'BEGIN {
        if      (s ~ /TB$/) { sub(/TB$/,"",s); printf "%d", s*1e12/1024 }
        else if (s ~ /GB$/) { sub(/GB$/,"",s); printf "%d", s*1e9/1024 }
        else if (s ~ /MB$/) { sub(/MB$/,"",s); printf "%d", s*1e6/1024 }
        else if (s ~ /kB$/) { sub(/kB$/,"",s); printf "%d", s*1e3/1024 }
        else if (s ~  /B$/) { sub(/B$/,"",s);  printf "%d", s/1024 }
        else                { printf "0" }
    }'
}

# Sum the disk usage (in KB) of the given paths/globs. Read-only.
# Glob handling mirrors safe_rm() so the estimate matches what cleanup deletes.
# Usage: du_kb_sum <path-or-glob> [<path-or-glob> ...]
du_kb_sum() {
    local total=0 path expanded_path kb
    local expanded_paths=()
    for path in "$@"; do
        expanded_paths=()
        shopt -s nullglob
        if [[ "$path" == *\** || "$path" == *\?* ]]; then
            # Intentional glob expansion (same pattern as safe_rm)
            # shellcheck disable=SC2206
            expanded_paths=($path)
        else
            expanded_paths=("$path")
        fi
        shopt -u nullglob

        for expanded_path in "${expanded_paths[@]}"; do
            if [[ -e "$expanded_path" ]]; then
                kb=$(du -sk "$expanded_path" 2>/dev/null | awk '{print $1}')
                [[ -n "$kb" ]] && total=$((total + kb))
            fi
        done
    done
    echo "$total"
}

# Same as du_kb_sum but for paths that require elevated privileges.
# The sudo session is already kept alive by main_loop(), so no extra prompt.
sudo_du_kb_sum() {
    local total=0 path expanded_path kb
    local expanded_paths=()
    for path in "$@"; do
        expanded_paths=()
        shopt -s nullglob
        if [[ "$path" == *\** || "$path" == *\?* ]]; then
            # Intentional glob expansion (same pattern as safe_sudo_rm)
            # shellcheck disable=SC2206
            expanded_paths=($path)
        else
            expanded_paths=("$path")
        fi
        shopt -u nullglob

        for expanded_path in "${expanded_paths[@]}"; do
            if [[ -e "$expanded_path" ]] || sudo test -e "$expanded_path" 2>/dev/null; then
                kb=$(sudo du -sk "$expanded_path" 2>/dev/null | awk '{print $1}')
                [[ -n "$kb" ]] && total=$((total + kb))
            fi
        done
    done
    echo "$total"
}

# Dry-run aware file/directory removal
# Usage: safe_rm [-r] <path> [<path> ...]
safe_rm() {
    local recursive=""
    local paths=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|-rf|-fr)
                recursive="-rf"
                shift
                ;;
            *)
                paths+=("$1")
                shift
                ;;
        esac
    done
    
    for path in "${paths[@]}"; do
        # Expand globs and handle paths
        local expanded_paths=()
        # Use nullglob to handle non-matching patterns
        shopt -s nullglob
        if [[ "$path" == *\** || "$path" == *\?* ]]; then
            expanded_paths=($path)
        else
            expanded_paths=("$path")
        fi
        shopt -u nullglob
        
        for expanded_path in "${expanded_paths[@]}"; do
            if [[ -e "$expanded_path" ]]; then
                if $DRY_RUN; then
                    local size=""
                    if [[ -d "$expanded_path" ]]; then
                        size=$(du -sh "$expanded_path" 2>/dev/null | cut -f1)
                        echo -e "${YELLOW}[DRY-RUN] Would delete directory: ${expanded_path} (${size:-unknown size})${NC}"
                    else
                        size=$(du -h "$expanded_path" 2>/dev/null | cut -f1)
                        echo -e "${YELLOW}[DRY-RUN] Would delete file: ${expanded_path} (${size:-unknown size})${NC}"
                    fi
                else
                    if [[ -n "$recursive" ]]; then
                        rm -rf "$expanded_path"
                    else
                        rm -f "$expanded_path"
                    fi
                fi
            fi
        done
    done
}

# Dry-run aware sudo file/directory removal
# Usage: safe_sudo_rm [-r] <path> [<path> ...]
safe_sudo_rm() {
    local recursive=""
    local paths=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|-rf|-fr)
                recursive="-rf"
                shift
                ;;
            *)
                paths+=("$1")
                shift
                ;;
        esac
    done
    
    for path in "${paths[@]}"; do
        # Expand globs and handle paths
        local expanded_paths=()
        shopt -s nullglob
        if [[ "$path" == *\** || "$path" == *\?* ]]; then
            expanded_paths=($path)
        else
            expanded_paths=("$path")
        fi
        shopt -u nullglob
        
        for expanded_path in "${expanded_paths[@]}"; do
            if [[ -e "$expanded_path" ]] || sudo test -e "$expanded_path" 2>/dev/null; then
                if $DRY_RUN; then
                    local size=""
                    if [[ -d "$expanded_path" ]] || sudo test -d "$expanded_path" 2>/dev/null; then
                        size=$(sudo du -sh "$expanded_path" 2>/dev/null | cut -f1)
                        echo -e "${YELLOW}[DRY-RUN] Would delete directory (sudo): ${expanded_path} (${size:-unknown size})${NC}"
                    else
                        size=$(sudo du -h "$expanded_path" 2>/dev/null | cut -f1)
                        echo -e "${YELLOW}[DRY-RUN] Would delete file (sudo): ${expanded_path} (${size:-unknown size})${NC}"
                    fi
                else
                    if [[ -n "$recursive" ]]; then
                        sudo rm -rf "$expanded_path"
                    else
                        sudo rm -f "$expanded_path"
                    fi
                fi
            fi
        done
    done
}

# --- Cleanup Functions ---
cleanup_xcode() {
    print_item "✓" "${GREEN}" "Clearing Xcode DerivedData..."
    safe_rm -rf ~/Library/Developer/Xcode/DerivedData/
    print_item "✓" "${GREEN}" "Removing old Simulator devices..."
    safe_rm -rf ~/Library/Developer/CoreSimulator/Devices/
    print_item "✓" "${GREEN}" "Removing old device support files..."
    safe_rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/
    print_item "✓" "${GREEN}" "Removing Xcode caches..."
    safe_rm -rf ~/Library/Caches/com.apple.dt.Xcode/
    print_item "✓" "${GREEN}" "Removing Xcode Archives..."
    safe_rm -rf ~/Library/Developer/Xcode/Archives/
    print_item "✓" "${GREEN}" "Removing Xcode build Products..."
    safe_rm -rf ~/Library/Developer/Xcode/Products/
    print_item "✓" "${GREEN}" "Removing Xcode DocumentationCache..."
    safe_rm -rf ~/Library/Developer/Xcode/DocumentationCache/
    print_item "✓" "${GREEN}" "Cleaning CoreDevice cache..."
    safe_rm -rf ~/Library/Containers/com.apple.CoreDevice.CoreDeviceService/Data/Library/Caches/*
}

cleanup_android() {
    if [ -d "$HOME/.gradle" ]; then
        print_item "✓" "${GREEN}" "Cleaning Gradle caches..."
        safe_rm -rf ~/.gradle/caches/
        safe_rm -rf ~/.gradle/daemon/
        # Downloaded Gradle distributions; re-fetched on next wrapper run.
        safe_rm -rf ~/.gradle/wrapper/
    else
        print_item "✕" "${YELLOW}" "Gradle directory not found. Skipping."
    fi
    if [ -d "$HOME/.android" ]; then
        print_item "✓" "${GREEN}" "Cleaning Android tool caches..."
        # Legacy AVD/build caches under ~/.android; regenerated on demand.
        safe_rm -rf ~/.android/cache/
        safe_rm -rf ~/.android/build-cache/
    fi
    print_item "✓" "${GREEN}" "Cleaning Android Studio caches..."
    safe_rm -rf ~/Library/Caches/Google/AndroidStudio*
    safe_rm -rf ~/Library/Caches/JetBrains/AndroidStudio*
}

cleanup_android_sdk() {
    if [ -d "$HOME/Library/Android/sdk" ]; then
        print_item "✓" "${GREEN}" "Cleaning old Android SDK build-tools (keeping latest 2 versions)..."
        # Keep only latest 2 versions of build-tools
        if [ -d "$HOME/Library/Android/sdk/build-tools" ]; then
            cd "$HOME/Library/Android/sdk/build-tools" 2>/dev/null || return
            if $DRY_RUN; then
                ls -t | tail -n +3 | while read -r dir; do
                    echo -e "${YELLOW}[DRY-RUN] Would delete: $HOME/Library/Android/sdk/build-tools/$dir${NC}"
                done
            else
                ls -t | tail -n +3 | xargs -I {} rm -rf {}
            fi
        fi

        print_item "✓" "${GREEN}" "Cleaning old Android platform-tools..."
        safe_rm -rf ~/Library/Android/sdk/.temp

        # For Apple Silicon Macs, remove x86 emulator images if they exist
        if [ "$(uname -m)" = "arm64" ]; then
            print_item "✓" "${GREEN}" "Removing x86 emulator images (ARM Mac detected)..."
            if $DRY_RUN; then
                find ~/Library/Android/sdk/system-images -type d -name "x86" 2>/dev/null | while read -r dir; do
                    echo -e "${YELLOW}[DRY-RUN] Would delete: $dir${NC}"
                done
            else
                find ~/Library/Android/sdk/system-images -type d -name "x86" -exec rm -rf {} + 2>/dev/null || true
            fi
        fi
    else
        print_item "✕" "${YELLOW}" "Android SDK not found. Skipping."
    fi
}

cleanup_flutter() {
    local search_dir="${1:-.}"  # Directory to search, current by default
    
    if command -v flutter &> /dev/null; then
        print_item "✓" "${GREEN}" "Cleaning Flutter projects recursively from: $search_dir"
        
        # Validate that the directory exists
        if [ ! -d "$search_dir" ]; then
            print_item "✕" "${RED}" "Directory not found: $search_dir"
            return 1
        fi
        
        # Find all pubspec.yaml files recursively and clean each project
        local cleaned_count=0
        while IFS= read -r -d '' pubspec; do
            project_dir=$(cd "$(dirname "$pubspec")" 2>/dev/null && pwd)
            if [ -z "$project_dir" ]; then
                continue
            fi
            
            echo -e "${CYAN}  🧹 Cleaning: $project_dir${NC}"
            
            cd "$project_dir" 2>/dev/null || { 
                print_item "⚠️" "${YELLOW}" "Skipped (can't access $project_dir)"
                continue
            }
            
            # --- 1. FVM destroy ---
            if [ -d ".fvm" ]; then
                echo -e "${FAINT}    🔥 Destroying FVM SDK cache...${NC}"
                yes | fvm destroy >/dev/null 2>&1 || true
            fi
            
            # --- 2. Remove FVM configs ---
            if [ -d ".fvm" ] || [ -f ".fvmrc" ]; then
                echo -e "${FAINT}    🔥 Removing FVM folders...${NC}"
                rm -rf .fvm .fvmrc 2>/dev/null || true
            fi
            
            # --- 3. Clean Flutter build & cache dirs ---
            echo -e "${FAINT}    🔥 Removing Flutter build and Pub Dev caches...${NC}"
            rm -rf build .dart_tool .packages pubspec.lock 2>/dev/null || true
            
            # --- 4. Clean Gradle caches ---
            if [ -d "android" ]; then
                echo -e "${FAINT}    🔥 Removing Gradle caches...${NC}"
                rm -rf android/.gradle android/build android/app/build 2>/dev/null || true
            fi
            
            # --- 5. Clean CocoaPods (iOS) ---
            if [ -d "ios" ]; then
                echo -e "${FAINT}    🔥 Removing CocoaPods caches...${NC}"
                rm -rf ios/Pods ios/Podfile.lock ios/.symlinks ios/Flutter/Flutter.framework ios/Flutter/Flutter.podspec 2>/dev/null || true
            fi
            
            cleaned_count=$((cleaned_count + 1))
            echo -e "${GREEN}  ✅ Cleaned $project_dir${NC}"
        done < <(find "$search_dir" -type f -name "pubspec.yaml" -print0 2>/dev/null)
        
        if [ $cleaned_count -gt 0 ]; then
            print_item "✓" "${GREEN}" "Cleaned $cleaned_count Flutter project(s)"
        else
            print_item "ℹ️" "${YELLOW}" "No Flutter projects found to clean in: $search_dir"
        fi
        
        print_item "✓" "${GREEN}" "Cleaning Flutter global cache..."
        flutter cache clean 2>/dev/null || true
    else
        print_item "✕" "${YELLOW}" "Flutter command not found. Skipping."
    fi
}

cleanup_platformIO() {
    local PIO_BIN="$HOME/.platformio/penv/bin/pio"

    if [ -x "$PIO_BIN" ]; then
        :
    elif command -v pio >/dev/null 2>&1; then
        PIO_BIN="$(command -v pio)"
    else
        print_item "✕" "${YELLOW}" "pio command not found. Skipping."
        return 0
    fi

    print_item "✓" "${GREEN}" "Cleaning PlatformIO project builds (pio run clean)..."

    # Find pubspec.yaml and run 'pio run -t clean' in each directory
    # -print0 handles spaces/newlines safely
    find ~/ -maxdepth 4 -type d -name "Library" -prune -o -name "platformio.ini" -print0 | while IFS= read -r -d '' file; do
        dir="$(dirname "$file")"
        printf 'Running: %s run clean in %s\n' "$PIO_BIN" "$dir"

        # Run in a subshell to avoid changing caller's CWD
        ( cd "$dir" && "$PIO_BIN" run -t clean )
    done
}

cleanup_npm_yarn() {
    if command -v npm &> /dev/null; then
        print_item "✓" "${GREEN}" "Cleaning npm cache..."
        npm cache clean --force
    else
        print_item "✕" "${YELLOW}" "npm not found. Skipping."
    fi
    if command -v yarn &> /dev/null; then
        print_item "✓" "${GREEN}" "Cleaning yarn cache..."
        yarn cache clean
    else
        print_item "✕" "${YELLOW}" "yarn not found. Skipping."
    fi
    if command -v pnpm &> /dev/null; then
        print_item "✓" "${GREEN}" "Pruning pnpm store..."
        pnpm store prune
    else
        print_item "✕" "${YELLOW}" "pnpm not found. Skipping."
    fi
}

cleanup_homebrew() {
    if command -v brew &> /dev/null; then
        print_item "✓" "${GREEN}" "Cleaning Homebrew (brew)..."
        brew cleanup
    else
        print_item "✕" "${YELLOW}" "Homebrew not found. Skipping."
    fi
}

cleanup_cocoapods() {
    if [ -d "$HOME/.cocoapods" ]; then
        print_item "✓" "${GREEN}" "Cleaning CocoaPods cache..."
        safe_rm -r ~/.cocoapods/repos/
        safe_rm -r ~/Library/Caches/CocoaPods/
    else
        print_item "✕" "${YELLOW}" "CocoaPods not found. Skipping."
    fi
}

cleanup_ide_caches() {
    print_item "✓" "${GREEN}" "Cleaning general JetBrains IDE caches..."
    safe_rm -r ~/Library/Caches/JetBrains/
    print_item "✓" "${GREEN}" "Cleaning VSCode cache..."
    safe_rm -r "$HOME/Library/Application Support/Code/Cache/"
    safe_rm -r "$HOME/Library/Application Support/Code/CachedData/"
    safe_rm -r "$HOME/Library/Application Support/Code/User/workspaceStorage/"
}

cleanup_system_junk() {
    print_item "✓" "${GREEN}" "Emptying the Trash..."
    safe_sudo_rm -r ~/.Trash/*
    safe_sudo_rm -r /Volumes/*/.Trashes/*
    print_item "✓" "${GREEN}" "Cleaning system-level library caches..."
    safe_sudo_rm -r /Library/Caches/*
    print_item "✓" "${GREEN}" "Cleaning user-level log files..."
    safe_rm -r ~/Library/Logs/*
    print_item "✓" "${GREEN}" "Cleaning system-level log files..."
    safe_sudo_rm -r /private/var/log/*
    safe_sudo_rm -r /Library/Logs/*
}

cleanup_browser_caches() {
    if [ -d "$HOME/Library/Caches/Google/Chrome" ]; then
        print_item "✓" "${GREEN}" "Cleaning Chrome cache..."
        safe_rm -r ~/Library/Caches/Google/Chrome/*
    else
        print_item "✕" "${YELLOW}" "Chrome cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/BraveSoftware/Brave-Browser" ]; then
        print_item "✓" "${GREEN}" "Cleaning Brave cache..."
        safe_rm -r ~/Library/Caches/BraveSoftware/Brave-Browser/*
    else
        print_item "✕" "${YELLOW}" "Brave cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/Firefox" ]; then
        print_item "✓" "${GREEN}" "Cleaning Firefox cache..."
        safe_rm -r ~/Library/Caches/Firefox/*
    else
        print_item "✕" "${YELLOW}" "Firefox cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/com.apple.Safari" ]; then
        print_item "✓" "${GREEN}" "Cleaning Safari cache..."
        safe_rm -r ~/Library/Caches/com.apple.Safari/*
    else
        print_item "✕" "${YELLOW}" "Safari cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/Microsoft Edge" ]; then
        print_item "✓" "${GREEN}" "Cleaning Microsoft Edge cache..."
        safe_rm -r "$HOME/Library/Caches/Microsoft Edge/"*
    elif [ -d "$HOME/Library/Caches/com.microsoft.edgemac" ]; then
        print_item "✓" "${GREEN}" "Cleaning Microsoft Edge cache..."
        safe_rm -r ~/Library/Caches/com.microsoft.edgemac/*
    else
        print_item "✕" "${YELLOW}" "Microsoft Edge cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/com.operasoftware.Opera" ]; then
        print_item "✓" "${GREEN}" "Cleaning Opera cache..."
        safe_rm -r ~/Library/Caches/com.operasoftware.Opera/*
    else
        print_item "✕" "${YELLOW}" "Opera cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/com.operasoftware.OperaGX" ]; then
        print_item "✓" "${GREEN}" "Cleaning Opera GX cache..."
        safe_rm -r ~/Library/Caches/com.operasoftware.OperaGX/*
    fi
}

cleanup_app_containers() {
    print_item "✓" "${GREEN}" "Cleaning app container caches..."

    # Slack
    if [ -d "$HOME/Library/Containers/com.tinyspeck.slackmacgap" ]; then
        print_item "✓" "${GREEN}" "Cleaning Slack cache..."
        safe_rm -r ~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Caches/*
    fi

    # Microsoft Teams
    if [ -d "$HOME/Library/Containers/com.microsoft.teams2" ]; then
        print_item "✓" "${GREEN}" "Cleaning Microsoft Teams cache..."
        safe_rm -r ~/Library/Containers/com.microsoft.teams2/Data/Library/Caches/*
    fi

    # WhatsApp
    if [ -d "$HOME/Library/Containers/net.whatsapp.WhatsApp" ]; then
        print_item "✓" "${GREEN}" "Cleaning WhatsApp cache..."
        safe_rm -r ~/Library/Containers/net.whatsapp.WhatsApp/Data/Library/Caches/*
    fi

    # Discord
    if [ -d "$HOME/Library/Application Support/discord" ]; then
        print_item "✓" "${GREEN}" "Cleaning Discord cache..."
        safe_rm -r "$HOME/Library/Application Support/discord/Cache/"*
        safe_rm -r "$HOME/Library/Application Support/discord/Code Cache/"*
    fi

    # Spotify
    if [ -d "$HOME/Library/Caches/com.spotify.client" ]; then
        print_item "✓" "${GREEN}" "Cleaning Spotify cache..."
        safe_rm -r ~/Library/Caches/com.spotify.client/*
    fi
    if [ -d "$HOME/Library/Application Support/Spotify/PersistentCache" ]; then
        safe_rm -r "$HOME/Library/Application Support/Spotify/PersistentCache/"*
    fi
}

cleanup_timemachine_snapshots() {
    print_item "✓" "${GREEN}" "Removing Time Machine local snapshots..."

    # List and delete local snapshots
    local snapshot_count=0
    while IFS= read -r snapshot; do
        if [[ "$snapshot" == *"com.apple.TimeMachine"* ]]; then
            local snapshot_date=$(echo "$snapshot" | grep -o '[0-9-]*$')
            if [ -n "$snapshot_date" ]; then
                if $DRY_RUN; then
                    echo -e "${YELLOW}[DRY-RUN] Would delete Time Machine snapshot: $snapshot_date${NC}"
                else
                    print_item "✓" "${GREEN}" "Deleting snapshot: $snapshot_date"
                    sudo tmutil deletelocalsnapshots "$snapshot_date" 2>/dev/null || true
                fi
                snapshot_count=$((snapshot_count + 1))
            fi
        fi
    done < <(sudo tmutil listlocalsnapshots / 2>/dev/null)

    if [ $snapshot_count -eq 0 ]; then
        print_item "ℹ️" "${YELLOW}" "No Time Machine local snapshots found"
    else
        print_item "✓" "${GREEN}" "Deleted $snapshot_count Time Machine snapshot(s)"
    fi
}

cleanup_cordova() {
    if [ -d "$HOME/.cordova" ]; then
        print_item "✓" "${GREEN}" "Cleaning Cordova tmp files..."
        # Cordova leaves stale npm tarballs/extractions under lib/tmp*
        safe_rm -rf ~/.cordova/lib/tmp*
    else
        print_item "✕" "${YELLOW}" "Cordova not found. Skipping."
    fi
}

cleanup_electron() {
    if [ -d "$HOME/Library/Caches/electron" ]; then
        print_item "✓" "${GREEN}" "Cleaning Electron cache..."
        # Cached prebuilt binaries; wipe contents, keep the dir electron expects
        safe_rm -rf ~/Library/Caches/electron/*
    else
        print_item "✕" "${YELLOW}" "Electron not found. Skipping."
    fi
}

# Usage: cleanup_docker [interactive]
#   no arg      -> safe `prune -f` only, no prompt (used by "Clear All Caches"
#                  so a bulk run never deletes tagged images by surprise)
#   interactive -> offer the deeper `prune -af` via a secondary prompt
cleanup_docker() {
    local mode="${1:-}"
    if ! command -v docker &> /dev/null; then
        print_item "✕" "${YELLOW}" "Docker not found. Skipping."
        return
    fi
    # `command -v` only proves the CLI exists; the daemon may still be down.
    local df_out
    if ! df_out=$(docker system df 2>/dev/null); then
        print_item "✕" "${YELLOW}" "Docker daemon not running. Skipping."
        return
    fi
    print_item "✓" "${GREEN}" "Docker disk usage:"
    echo "$df_out"

    # `prune -f` removes stopped containers, unused networks, dangling
    # (untagged) images and unused build cache. `-a` additionally removes
    # EVERY image not used by a container, including tagged ones that may
    # only exist in a private registry — so it's opt-in via a prompt, never
    # in the bulk "Clear All" path. (--volumes stays omitted in both: it
    # would delete named-volume data like databases.)
    local prune_args="-f"
    if [ "$mode" = "interactive" ] && ! $DRY_RUN; then
        echo ""
        echo -e "${YELLOW}Also remove unused but TAGGED images? Frees more space, but they"
        echo -e "must be re-pulled/rebuilt (e.g. private-registry images). (y/N):${NC}"
        local ans
        read -r ans
        if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
            prune_args="-af"
        fi
    fi

    # Docker has no real --dry-run, so honour the flag manually like
    # cleanup_android_sdk: prune is destructive (but rebuildable), so just
    # announce it under --dry-run instead of running. -f skips docker's own
    # confirmation (the script already confirmed).
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN] Would run: docker system prune -f${NC}"
        echo -e "${FAINT}  (option 15 also offers 'docker system prune -af' to remove unused tagged images)${NC}"
    else
        docker system prune $prune_args
    fi
}

# --- Reclaimable-space estimation ---
# Read-only feature: computes the current on-disk size of what every cleanup
# option would remove, then display_menu() shows it next to each entry.
# Categories use STABLE string keys (not menu numbers) so the estimate keeps
# working when the menu is renumbered by later PRs.
# IMPORTANT: keep these path lists in sync with the cleanup_* functions above.
# Any new cleanup routine must add its own category to estimate_all() and a
# matching $(est <key>) in display_menu().

ESTIMATES_READY=false

# Store a formatted estimate label under a stable category key.
set_estimate() {
    printf -v "EST_${1}_LABEL" '%s' "$2"
}

# Echo " (Estimate: <label>)" for a category key, or nothing if not computed.
est() {
    [ "$ESTIMATES_READY" = "true" ] || return 0
    local varname="EST_${1}_LABEL"
    local label="${!varname}"
    [ -n "$label" ] || return 0
    printf ' %s(Estimate: %s)%s' "$FAINT" "$label" "$NC"
}

estimate_all() {
    print_item "🔍" "${CYAN}" "Calculating estimates... (this can take a while)"

    local kb total=0

    print_item "•" "${FAINT}" "Measuring Xcode caches..."
    kb=$(du_kb_sum \
        "$HOME/Library/Developer/Xcode/DerivedData" \
        "$HOME/Library/Developer/CoreSimulator/Devices" \
        "$HOME/Library/Developer/Xcode/iOS DeviceSupport" \
        "$HOME/Library/Caches/com.apple.dt.Xcode" \
        "$HOME/Library/Developer/Xcode/Archives" \
        "$HOME/Library/Developer/Xcode/Products" \
        "$HOME/Library/Developer/Xcode/DocumentationCache" \
        "$HOME/Library/Containers/com.apple.CoreDevice.CoreDeviceService/Data/Library/Caches"/*)
    set_estimate xcode "$(human_kb "$kb")"
    total=$((total + kb))

    print_item "•" "${FAINT}" "Measuring Android/Gradle caches..."
    kb=$(du_kb_sum \
        "$HOME/.gradle/caches" \
        "$HOME/.gradle/daemon" \
        "$HOME/.gradle/wrapper" \
        "$HOME/.android/cache" \
        "$HOME/.android/build-cache" \
        "$HOME/Library/Caches/Google"/AndroidStudio* \
        "$HOME/Library/Caches/JetBrains"/AndroidStudio*)
    set_estimate android "$(human_kb "$kb")"
    total=$((total + kb))

    print_item "•" "${FAINT}" "Measuring Android SDK..."
    local sdk_kb=0 d
    if [ -d "$HOME/Library/Android/sdk/build-tools" ]; then
        # Mirrors cleanup_android_sdk: keep latest 2 build-tools by mtime.
        # SDK version dir names are plain (e.g. 34.0.0), ls -t is safe here.
        # shellcheck disable=SC2012
        while IFS= read -r d; do
            [ -n "$d" ] || continue
            sdk_kb=$((sdk_kb + $(du_kb_sum "$HOME/Library/Android/sdk/build-tools/$d")))
        done < <(cd "$HOME/Library/Android/sdk/build-tools" 2>/dev/null && ls -t | tail -n +3)
    fi
    sdk_kb=$((sdk_kb + $(du_kb_sum "$HOME/Library/Android/sdk/.temp")))
    if [ "$(uname -m)" = "arm64" ]; then
        while IFS= read -r d; do
            [ -n "$d" ] || continue
            sdk_kb=$((sdk_kb + $(du_kb_sum "$d")))
        done < <(find "$HOME/Library/Android/sdk/system-images" -type d -name "x86" 2>/dev/null)
    fi
    set_estimate android_sdk "$(human_kb "$sdk_kb")"
    total=$((total + sdk_kb))

    print_item "•" "${FAINT}" "Measuring Flutter global cache..."
    local flutter_kb froot
    flutter_kb=$(du_kb_sum "$HOME/.pub-cache")
    if command -v flutter >/dev/null 2>&1; then
        froot="$(cd "$(dirname "$(command -v flutter)")" 2>/dev/null && pwd)"
        [ -n "$froot" ] && flutter_kb=$((flutter_kb + $(du_kb_sum "$froot/cache")))
    fi
    set_estimate flutter "~$(human_kb "$flutter_kb")"
    total=$((total + flutter_kb))

    print_item "•" "${FAINT}" "Measuring npm/Yarn/pnpm caches..."
    local npm_kb npm_cache yarn_dir pnpm_dir
    npm_cache=""
    command -v npm >/dev/null 2>&1 && npm_cache="$(npm config get cache 2>/dev/null)"
    case "$npm_cache" in ""|undefined|null) npm_cache="$HOME/.npm" ;; esac
    npm_kb=$(du_kb_sum "$npm_cache/_cacache")
    if command -v yarn >/dev/null 2>&1; then
        yarn_dir="$(yarn cache dir 2>/dev/null)"
        [ -n "$yarn_dir" ] && npm_kb=$((npm_kb + $(du_kb_sum "$yarn_dir")))
    fi
    if command -v pnpm >/dev/null 2>&1; then
        pnpm_dir="$(pnpm store path 2>/dev/null)"
        [ -n "$pnpm_dir" ] && npm_kb=$((npm_kb + $(du_kb_sum "$pnpm_dir")))
    fi
    set_estimate npm "~$(human_kb "$npm_kb")"
    total=$((total + npm_kb))

    print_item "•" "${FAINT}" "Measuring Homebrew cache..."
    local brew_kb=0 brew_cache
    if command -v brew >/dev/null 2>&1; then
        brew_cache="$(brew --cache 2>/dev/null)"
        [ -n "$brew_cache" ] && brew_kb=$(du_kb_sum "$brew_cache")
    fi
    set_estimate homebrew "~$(human_kb "$brew_kb")"
    total=$((total + brew_kb))

    print_item "•" "${FAINT}" "Measuring CocoaPods cache..."
    kb=$(du_kb_sum \
        "$HOME/.cocoapods/repos" \
        "$HOME/Library/Caches/CocoaPods")
    set_estimate cocoapods "$(human_kb "$kb")"
    total=$((total + kb))

    print_item "•" "${FAINT}" "Measuring IDE caches..."
    kb=$(du_kb_sum \
        "$HOME/Library/Caches/JetBrains" \
        "$HOME/Library/Application Support/Code/Cache" \
        "$HOME/Library/Application Support/Code/CachedData" \
        "$HOME/Library/Application Support/Code/User/workspaceStorage")
    set_estimate ide "$(human_kb "$kb")"
    total=$((total + kb))

    print_item "•" "${FAINT}" "Measuring system junk & logs (sudo)..."
    local system_kb
    system_kb=$(sudo_du_kb_sum \
        "$HOME/.Trash"/* \
        /Volumes/*/.Trashes/* \
        /Library/Caches/* \
        "$HOME/Library/Logs"/* \
        /private/var/log/* \
        /Library/Logs/*)
    set_estimate system "~$(human_kb "$system_kb")"
    total=$((total + system_kb))

    print_item "•" "${FAINT}" "Measuring browser caches..."
    kb=$(du_kb_sum \
        "$HOME/Library/Caches/Google/Chrome"/* \
        "$HOME/Library/Caches/BraveSoftware/Brave-Browser"/* \
        "$HOME/Library/Caches/Firefox"/* \
        "$HOME/Library/Caches/com.apple.Safari"/* \
        "$HOME/Library/Caches/Microsoft Edge"/* \
        "$HOME/Library/Caches/com.microsoft.edgemac"/* \
        "$HOME/Library/Caches/com.operasoftware.Opera"/* \
        "$HOME/Library/Caches/com.operasoftware.OperaGX"/*)
    set_estimate browser "$(human_kb "$kb")"
    total=$((total + kb))

    print_item "•" "${FAINT}" "Measuring PlatformIO global cache..."
    local pio_kb
    pio_kb=$(du_kb_sum "$HOME/.platformio/.cache")
    set_estimate platformio "~$(human_kb "$pio_kb")"
    total=$((total + pio_kb))

    print_item "•" "${FAINT}" "Measuring Cordova tmp files..."
    kb=$(du_kb_sum "$HOME/.cordova/lib"/tmp*)
    set_estimate cordova "$(human_kb "$kb")"
    total=$((total + kb))

    print_item "•" "${FAINT}" "Measuring Electron cache..."
    kb=$(du_kb_sum "$HOME/Library/Caches/electron"/*)
    set_estimate electron "$(human_kb "$kb")"
    total=$((total + kb))

    # Docker is not path-based: ask docker itself (read-only). Two figures,
    # because option 15 offers two prune modes:
    #   -f  : build-cache reclaimable + dangling (untagged) images
    #   -af : the above + ALL images not used by a container (tagged too)
    # Build-cache reclaimable comes from the `system df` summary (Docker
    # computes it correctly; only its Images figure is unreliable with the
    # containerd image store). Per-image sizes come from `system df -v`,
    # summing UNIQUE SIZE of 0-container rows so shared layers aren't double
    # counted. Approximate, so not added to the byte total.
    print_item "•" "${FAINT}" "Measuring Docker reclaimable space..."
    local df_fmt
    if command -v docker &> /dev/null \
        && df_fmt=$(docker system df --format '{{.Type}}|{{.Reclaimable}}' 2>/dev/null) \
        && [ -n "$df_fmt" ]; then
        local cache_tok cache_kb dangling_kb allunused_kb f_kb af_kb
        cache_tok=$(echo "$df_fmt" | awk -F'|' '$1=="Build Cache"{sub(/ *\(.*/,"",$2);print $2}')
        cache_kb=$(docker_size_to_kb "${cache_tok:-0B}")
        # Parse the "Images space usage:" table. CREATED is multi-word
        # ("4 days ago"), so index fields from the RIGHT: $NF=CONTAINERS,
        # $(NF-1)=UNIQUE SIZE. d=dangling 0-container, a=all 0-container.
        read -r dangling_kb allunused_kb < <(docker system df -v 2>/dev/null | awk '
            function tokb(s) {
                if      (s ~ /TB$/) { sub(/TB$/,"",s); return s*1e12/1024 }
                else if (s ~ /GB$/) { sub(/GB$/,"",s); return s*1e9/1024 }
                else if (s ~ /MB$/) { sub(/MB$/,"",s); return s*1e6/1024 }
                else if (s ~ /kB$/) { sub(/kB$/,"",s); return s*1e3/1024 }
                else if (s ~  /B$/) { sub(/B$/,"",s);  return s/1024 }
                return 0
            }
            /^Images space usage:/ { in_img=1; next }
            in_img && /^REPOSITORY/ { hdr=1; next }
            in_img && hdr {
                if (NF==0) { in_img=0; hdr=0; next }
                if ($NF==0) { a += tokb($(NF-1)); if ($1=="<none>") d += tokb($(NF-1)) }
                next
            }
            END { printf "%d %d\n", d+0, a+0 }')
        f_kb=$(( cache_kb + ${dangling_kb:-0} ))
        af_kb=$(( cache_kb + ${allunused_kb:-0} ))
        if [ "$af_kb" -gt "$f_kb" ]; then
            set_estimate docker "~$(human_kb "$f_kb") → ~$(human_kb "$af_kb") with -a"
        else
            set_estimate docker "~$(human_kb "$f_kb")"
        fi
    elif command -v docker &> /dev/null; then
        set_estimate docker "n/a (daemon not running)"
    else
        set_estimate docker "n/a (docker not found)"
    fi

    print_item "•" "${FAINT}" "Measuring app container caches..."
    kb=$(du_kb_sum \
        "$HOME/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Caches"/* \
        "$HOME/Library/Containers/com.microsoft.teams2/Data/Library/Caches"/* \
        "$HOME/Library/Containers/net.whatsapp.WhatsApp/Data/Library/Caches"/* \
        "$HOME/Library/Application Support/discord/Cache"/* \
        "$HOME/Library/Application Support/discord/Code Cache"/* \
        "$HOME/Library/Caches/com.spotify.client"/* \
        "$HOME/Library/Application Support/Spotify/PersistentCache"/*)
    set_estimate appcontainers "$(human_kb "$kb")"
    total=$((total + kb))

    print_item "•" "${FAINT}" "Counting Time Machine local snapshots..."
    local tm_count
    tm_count=$(sudo tmutil listlocalsnapshots / 2>/dev/null | grep -c 'com.apple.TimeMachine')
    [ -n "$tm_count" ] || tm_count=0
    set_estimate timemachine "${tm_count} snapshot(s)"

    set_estimate total "~$(human_kb "$total")"
    ESTIMATES_READY=true

    print_item "✓" "${GREEN}" "Estimates ready. ~ marks approximate values."
}

# --- Main Display Function ---
display_menu() {
    clear
    local current_free_space=$(get_disk_space)

    print_logo
    echo -e "${FAINT}  Version: v${SCRIPT_VERSION}${NC}" # Display version
    print_item "✨" "${GREEN}" "Free Space: ${current_free_space}"
    echo ""
    print_section_header "Available Options:"
    echo -e "${RED} 0.${NC} ${BOLD}Exit Program${NC}"
    echo -e "${GREEN} 1.${NC} Clear All Caches$(est total)"
    echo -e "${GREEN} 2.${NC} Clear Xcode Caches & DerivedData$(est xcode)"
    echo -e "${GREEN} 3.${NC} Clear Android/Gradle Caches$(est android)"
    echo -e "${GREEN} 4.${NC} Clear Flutter Caches ${FAINT}(with custom directory option)${NC}$(est flutter)"
    echo -e "${GREEN} 5.${NC} Clear npm/Yarn/pnpm Caches$(est npm)"
    echo -e "${GREEN} 6.${NC} Clean Homebrew Caches$(est homebrew)"
    echo -e "${GREEN} 7.${NC} Clear CocoaPods Caches$(est cocoapods)"
    echo -e "${GREEN} 8.${NC} Clear IDE (JetBrains, VSCode) Caches$(est ide)"
    echo -e "${GREEN} 9.${NC} Clean System Junk & Logs (requires sudo)$(est system)"
    echo -e "${GREEN}10.${NC} Clear Browser Caches (Chrome, Brave, Firefox, Safari, Edge, Opera)$(est browser)"
    echo -e "${GREEN}11.${NC} Clear PlatformIO Caches$(est platformio)"
    echo -e "${GREEN}12.${NC} Clean Android SDK (old build-tools, x86 images)$(est android_sdk)"
    echo -e "${GREEN}13.${NC} Clear Cordova tmp files$(est cordova)"
    echo -e "${GREEN}14.${NC} Clear Electron cache$(est electron)"
    echo -e "${GREEN}15.${NC} Clear Docker (prune containers, dangling images & build cache; asks before removing unused tagged images)$(est docker)"
    echo -e "${GREEN}16.${NC} Clean App Containers (Slack, Teams, Discord, Spotify, WhatsApp)$(est appcontainers)"
    echo -e "${GREEN}17.${NC} Remove Time Machine Local Snapshots (requires sudo)$(est timemachine)"
    echo ""
    echo -e "${CYAN}99.${NC} Estimate reclaimable space ${FAINT}(read-only, ~ = approximate)${NC}"
    echo ""
    echo -e "→ Please enter your choice (0-17, or 99 to estimate): ${NC}\c"
}

# --- Help function ---
show_help() {
    cat << EOF
Dev Cleanup Utility v${SCRIPT_VERSION}
A powerful cleanup utility for development environments on macOS

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  -v, --version           Show version information
  --dry-run               Show what would be deleted without actually removing files
  --flutter-dir PATH      Set custom directory for Flutter cleanup (default: current directory)
                          Example: $0 --flutter-dir ~/Projects

Command-line Flutter cleanup:
  You can specify a custom directory for Flutter cleanup using the --flutter-dir option.
  This directory will be used when running the interactive menu or the "Clear All" option.

Interactive menu:
  Option 99 estimates the reclaimable space for every entry and redraws the
  menu with "(Estimate: <size>)". It is read-only (only runs 'du', deletes
  nothing) and works in --dry-run too. A leading "~" marks an approximate
  value; Flutter and PlatformIO estimates cover the global cache only.

Examples:
  $0                                    # Run interactive menu (searches current directory for Flutter projects)
  $0 --dry-run                          # Preview what would be deleted without removing anything
  $0 --flutter-dir ~/Development        # Run with custom Flutter search directory
  $0 --flutter-dir ~/Projects/Flutter   # Search only in specific Flutter projects folder

Repository: ${GITHUB_REPO}
EOF
}

# --- Main Logic ---
main_loop() {
    # Request sudo at the start to cover all options that need it
    echo -e "${YELLOW}This script may require administrator privileges for some cleanup tasks.${NC}"
    echo -e "${YELLOW}You will be prompted to enter your password if needed.${NC}"
    sudo -v
    # Keep sudo session alive in background
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    SUDO_PID=$!

    while true; do
        display_menu
        read -r choice
        echo "" # New line for better separation

        local initial_free_space=$(get_disk_space)

        case "$choice" in
            0)
                echo -e "${GREEN}Exiting cleanup utility. Goodbye!${NC}"
                break
                ;;
            1)
                print_section_header "Performing ALL Cleanup Tasks"
                cleanup_xcode
                cleanup_android
                cleanup_android_sdk
                cleanup_flutter "$FLUTTER_SEARCH_DIR"
                cleanup_platformIO
                cleanup_npm_yarn
                cleanup_homebrew
                cleanup_cocoapods
                cleanup_ide_caches
                cleanup_system_junk
                cleanup_browser_caches
                cleanup_cordova
                cleanup_electron
                cleanup_docker
                cleanup_app_containers
                cleanup_timemachine_snapshots
                ;;
            2)
                print_section_header "Performing Xcode Cleanup"
                cleanup_xcode
                ;;
            3)
                print_section_header "Performing Android/Gradle Cleanup"
                cleanup_android
                ;;
            4)
                print_section_header "Performing Flutter Cleanup"
                echo -e "${CYAN}Current Flutter search directory: ${FLUTTER_SEARCH_DIR}${NC}"
                case "$FLUTTER_DIR_SOURCE" in
                    "environment")
                        echo -e "${FAINT}  (from FLUTTER_SEARCH_DIR environment variable)${NC}"
                        ;;
                    "command-line")
                        echo -e "${FAINT}  (from --flutter-dir command-line argument)${NC}"
                        ;;
                    "default")
                        echo -e "${FAINT}  (default: current directory)${NC}"
                        ;;
                esac
                echo ""
                echo -e "${YELLOW}Enter a custom directory path, or press Enter to use current setting:${NC}"
                read -r custom_flutter_dir
                
                # Use custom directory if provided, otherwise use global setting
                if [ -n "$custom_flutter_dir" ]; then
                    # Expand ~ to home directory
                    custom_flutter_dir="${custom_flutter_dir/#\~/$HOME}"
                    
                    if [ -d "$custom_flutter_dir" ]; then
                        echo -e "${CYAN}Using interactive override: ${custom_flutter_dir}${NC}"
                        cleanup_flutter "$custom_flutter_dir"
                    else
                        print_item "✕" "${RED}" "Directory does not exist: $custom_flutter_dir"
                        case "$FLUTTER_DIR_SOURCE" in
                            "environment")
                                echo -e "${YELLOW}Falling back to environment variable setting: ${FLUTTER_SEARCH_DIR}${NC}"
                                ;;
                            "command-line")
                                echo -e "${YELLOW}Falling back to command-line argument: ${FLUTTER_SEARCH_DIR}${NC}"
                                ;;
                            "default")
                                echo -e "${YELLOW}Falling back to default directory: ${FLUTTER_SEARCH_DIR}${NC}"
                                ;;
                        esac
                        cleanup_flutter "$FLUTTER_SEARCH_DIR"
                    fi
                else
                    cleanup_flutter "$FLUTTER_SEARCH_DIR"
                fi
                ;;
            5)
                print_section_header "Performing npm/Yarn/pnpm Cleanup"
                cleanup_npm_yarn
                ;;
            6)
                print_section_header "Performing Homebrew Cleanup"
                cleanup_homebrew
                ;;
            7)
                print_section_header "Performing CocoaPods Cleanup"
                cleanup_cocoapods
                ;;
            8)
                print_section_header "Performing IDE Caches Cleanup"
                cleanup_ide_caches
                ;;
            9)
                print_section_header "Performing System Junk & Logs Cleanup"
                cleanup_system_junk
                ;;
            10)
                print_section_header "Performing Browser Caches Cleanup"
                cleanup_browser_caches
                ;;
            11)
                print_section_header "Performing PlatformIO Caches cleanup"
                cleanup_platformIO
                ;;
            12)
                print_section_header "Performing Android SDK Cleanup"
                cleanup_android_sdk
                ;;
            13)
                print_section_header "Performing Cordova Cleanup"
                cleanup_cordova
                ;;
            14)
                print_section_header "Performing Electron Cleanup"
                cleanup_electron
                ;;
            15)
                print_section_header "Performing Docker Cleanup"
                cleanup_docker interactive
                ;;
            16)
                print_section_header "Performing App Containers Cleanup"
                cleanup_app_containers
                ;;
            17)
                print_section_header "Performing Time Machine Snapshots Cleanup"
                cleanup_timemachine_snapshots
                ;;
            99)
                print_section_header "Estimating Reclaimable Space"
                estimate_all
                # Read-only: skip the before/after summary and redraw the menu
                # with the freshly computed estimates.
                continue
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter a number between 0 and 17.${NC}"
                sleep 2
                ;;
        esac

        local final_free_space=$(get_disk_space)
        echo ""
        if $DRY_RUN; then
            echo -e "${CYAN}🔍 Dry-run analysis completed!${NC}"
            echo -e "${CYAN}No files were deleted. Run without --dry-run to perform actual cleanup.${NC}"
        else
            echo -e "${GREEN}✅ Cleanup task(s) completed!${NC}"
            echo -e "${BLUE}Disk space before: ${initial_free_space}${NC}"
            echo -e "${BLUE}Disk space after:  ${final_free_space}${NC}"
        fi
        echo ""
        read -p "Press Enter to return to the menu..."
    done

    # Kill the background sudo-keep-alive process
    kill "$SUDO_PID" 2>/dev/null
    echo -e "${GREEN}Cleanup session ended.${NC}"
}

# --- Handle command line arguments ---
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            echo "Dev Cleaner v${SCRIPT_VERSION}"
            echo "A powerful cleanup utility for development environments"
            echo "Repository: ${GITHUB_REPO}"
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --flutter-dir)
            if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                # Expand ~ to home directory
                FLUTTER_SEARCH_DIR="${2/#\~/$HOME}"
                FLUTTER_DIR_SOURCE="command-line"
                shift 2
            else
                echo -e "${RED}Error: --flutter-dir requires a directory path${NC}"
                echo "Use -h or --help for usage information"
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Validate Flutter search directory if custom one was provided
if [ "$FLUTTER_SEARCH_DIR" != "." ] && [ ! -d "$FLUTTER_SEARCH_DIR" ]; then
    echo -e "${RED}Error: Flutter search directory does not exist: ${FLUTTER_SEARCH_DIR}${NC}"
    echo "Please provide a valid directory path."
    exit 1
fi

# --- Initial check for user confirmation before starting the interactive menu ---
clear
echo -e "${RED}--- 🚀 Dev Cleanup Utility ---${NC}"
if $DRY_RUN; then
    echo -e "${CYAN}${BOLD}🔍 DRY-RUN MODE ENABLED${NC}"
    echo -e "${CYAN}This will show what would be deleted without actually removing any files.${NC}"
else
    echo "This script will permanently delete cache files from your system."
    echo "Review the options carefully before proceeding."
fi
echo ""

# Report Flutter search directory and its source
if [ "$FLUTTER_SEARCH_DIR" != "." ]; then
    echo -e "${CYAN}Flutter search directory: ${FLUTTER_SEARCH_DIR}${NC}"
    case "$FLUTTER_DIR_SOURCE" in
        "environment")
            echo -e "${FAINT}  (set via FLUTTER_SEARCH_DIR environment variable)${NC}"
            ;;
        "command-line")
            echo -e "${FAINT}  (set via --flutter-dir command-line argument)${NC}"
            ;;
    esac
    echo ""
else
    echo -e "${FAINT}Flutter search directory: current directory (default)${NC}"
    echo ""
fi

if $DRY_RUN; then
    echo -e "${GREEN}✓ Safe to run: No files will be modified in dry-run mode.${NC}"
    echo ""
    read -p "Start dry-run analysis? (y/N): " initial_confirm
else
    echo -e "${YELLOW}⚠️ This action is IRREVERSIBLE for deleted files. ⚠️${NC}"
    echo -e "${YELLOW}Please CLOSE all development applications (Xcode, Android Studio, VSCode, etc.) before running.${NC}"
    echo ""
    read -p "Are you sure you want to start the cleanup utility? (y/N): " initial_confirm
fi
if [[ "$initial_confirm" != "y" && "$initial_confirm" != "Y" ]]; then
    echo "Cleanup utility cancelled."
    exit 0
fi

main_loop
