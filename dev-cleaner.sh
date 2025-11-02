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
SCRIPT_VERSION="1.0.1"
GITHUB_REPO="https://github.com/jemishavasoya/dev-cleaner"

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

# --- Cleanup Functions ---
cleanup_xcode() {
    print_item "✓" "${GREEN}" "Clearing Xcode DerivedData..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/
    print_item "✓" "${GREEN}" "Removing old Simulator devices..."
    rm -rf ~/Library/Developer/CoreSimulator/Devices/
    print_item "✓" "${GREEN}" "Removing old device support files..."
    rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/
    print_item "✓" "${GREEN}" "Removing Xcode caches..."
    rm -rf ~/Library/Caches/com.apple.dt.Xcode/
}

cleanup_android() {
    if [ -d "$HOME/.gradle" ]; then
        print_item "✓" "${GREEN}" "Cleaning Gradle caches..."
        rm -rf ~/.gradle/caches/
        rm -rf ~/.gradle/daemon/
    else
        print_item "✕" "${YELLOW}" "Gradle directory not found. Skipping."
    fi
    print_item "✓" "${GREEN}" "Cleaning Android Studio caches..."
    rm -rf ~/Library/Caches/Google/AndroidStudio*
    rm -rf ~/Library/Caches/JetBrains/AndroidStudio*
}

cleanup_flutter() {
    local search_dir="${1:-.}"  # Directory to search, current by default
    
    if command -v flutter &> /dev/null; then
        print_item "✓" "${GREEN}" "Cleaning Flutter projects recursively from: $search_dir"
        
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
            print_item "ℹ️" "${YELLOW}" "No Flutter projects found to clean"
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
        rm -rf ~/.cocoapods/repos/
        rm -rf ~/Library/Caches/CocoaPods/
    else
        print_item "✕" "${YELLOW}" "CocoaPods not found. Skipping."
    fi
}

cleanup_ide_caches() {
    print_item "✓" "${GREEN}" "Cleaning general JetBrains IDE caches..."
    rm -rf ~/Library/Caches/JetBrains/
    print_item "✓" "${GREEN}" "Cleaning VSCode cache..."
    rm -rf ~/Library/Application\ Support/Code/Cache/
    rm -rf ~/Library/Application\ Support/Code/CachedData/
    rm -rf ~/Library/Application\ Support/Code/User/workspaceStorage/
}

cleanup_system_junk() {
    print_item "✓" "${GREEN}" "Emptying the Trash..."
    sudo rm -rf ~/.Trash/*
    sudo rm -rf /Volumes/*/.Trashes/*
    print_item "✓" "${GREEN}" "Cleaning system-level library caches..."
    sudo rm -rf /Library/Caches/*
    print_item "✓" "${GREEN}" "Cleaning user-level log files..."
    rm -rf ~/Library/Logs/*
    print_item "✓" "${GREEN}" "Cleaning system-level log files..."
    sudo rm -rf /private/var/log/*
    sudo rm -rf /Library/Logs/*
}

cleanup_browser_caches() {
    if [ -d "$HOME/Library/Caches/Google/Chrome" ]; then
        print_item "✓" "${GREEN}" "Cleaning Chrome cache..."
        rm -rf ~/Library/Caches/Google/Chrome/*
    else
        print_item "✕" "${YELLOW}" "Chrome cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/BraveSoftware/Brave-Browser" ]; then
        print_item "✓" "${GREEN}" "Cleaning Brave cache..."
        rm -rf ~/Library/Caches/BraveSoftware/Brave-Browser/*
    else
        print_item "✕" "${YELLOW}" "Brave cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/Firefox" ]; then
        print_item "✓" "${GREEN}" "Cleaning Firefox cache..."
        rm -rf ~/Library/Caches/Firefox/*
    else
        print_item "✕" "${YELLOW}" "Firefox cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/com.apple.Safari" ]; then
        print_item "✓" "${GREEN}" "Cleaning Safari cache..."
        rm -rf ~/Library/Caches/com.apple.Safari/*
    else
        print_item "✕" "${YELLOW}" "Safari cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/Microsoft Edge" ]; then
        print_item "✓" "${GREEN}" "Cleaning Microsoft Edge cache..."
        rm -rf ~/Library/Caches/Microsoft\ Edge/*
    elif [ -d "$HOME/Library/Caches/com.microsoft.edgemac" ]; then
        print_item "✓" "${GREEN}" "Cleaning Microsoft Edge cache..."
        rm -rf ~/Library/Caches/com.microsoft.edgemac/*
    else
        print_item "✕" "${YELLOW}" "Microsoft Edge cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/com.operasoftware.Opera" ]; then
        print_item "✓" "${GREEN}" "Cleaning Opera cache..."
        rm -rf ~/Library/Caches/com.operasoftware.Opera/*
    else
        print_item "✕" "${YELLOW}" "Opera cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/com.operasoftware.OperaGX" ]; then
        print_item "✓" "${GREEN}" "Cleaning Opera GX cache..."
        rm -rf ~/Library/Caches/com.operasoftware.OperaGX/*
    fi
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
    echo -e "${GREEN} 1.${NC} Clear All Caches"
    echo -e "${GREEN} 2.${NC} Clear Xcode Caches & DerivedData"
    echo -e "${GREEN} 3.${NC} Clear Android/Gradle Caches"
    echo -e "${GREEN} 4.${NC} Clear Flutter Caches"
    echo -e "${GREEN} 5.${NC} Clear npm/Yarn/pnpm Caches"
    echo -e "${GREEN} 6.${NC} Clean Homebrew Caches"
    echo -e "${GREEN} 7.${NC} Clear CocoaPods Caches"
    echo -e "${GREEN} 8.${NC} Clear IDE (JetBrains, VSCode) Caches"
    echo -e "${GREEN} 9.${NC} Clean System Junk & Logs (requires sudo)"
    echo -e "${GREEN}10.${NC} Clear Browser Caches (Chrome, Brave, Firefox, Safari, Edge, Opera)"
    echo -e "${GREEN}11.${NC} Clear PlatformIO Caches"
    echo ""
    echo -e "→ Please enter your choice (0-11): ${NC}\c"
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
                cleanup_flutter
                cleanup_platformIO
                cleanup_npm_yarn
                cleanup_homebrew
                cleanup_cocoapods
                cleanup_ide_caches
                cleanup_system_junk
                cleanup_browser_caches
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
                cleanup_flutter
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
            *)
                echo -e "${RED}Invalid choice. Please enter a number between 0 and 10.${NC}"
                sleep 2
                ;;
        esac

        local final_free_space=$(get_disk_space)
        echo ""
        echo -e "${GREEN}✅ Cleanup task(s) completed!${NC}"
        echo -e "${BLUE}Disk space before: ${initial_free_space}${NC}"
        echo -e "${BLUE}Disk space after:  ${final_free_space}${NC}"
        echo ""
        read -p "Press Enter to return to the menu..."
    done

    # Kill the background sudo-keep-alive process
    kill "$SUDO_PID" 2>/dev/null
    echo -e "${GREEN}Cleanup session ended.${NC}"
}

# --- Initial check for user confirmation before starting the interactive menu ---
clear
echo -e "${RED}--- 🚀 Dev Cleanup Utility ---${NC}"
echo "This script will permanently delete cache files from your system."
echo "Review the options carefully before proceeding."
echo ""
echo -e "${YELLOW}⚠️ This action is IRREVERSIBLE for deleted files. ⚠️${NC}"
echo -e "${YELLOW}Please CLOSE all development applications (Xcode, Android Studio, VSCode, etc.) before running.${NC}"
echo ""
read -p "Are you sure you want to start the cleanup utility? (y/N): " initial_confirm
if [[ "$initial_confirm" != "y" && "$initial_confirm" != "Y" ]]; then
    echo "Cleanup utility cancelled."
    exit 0
fi

main_loop
