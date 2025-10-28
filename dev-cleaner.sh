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
██║  ██║██╔══╝  ╚██╗ ██╔╝    ██║     ██║     ██╔══╝  ██╔══██║██║╚██╗██║██╔══╝  ██╔══██╗
██████╔╝███████╗ ╚████╔╝     ╚██████╗███████╗███████╗██║  ██║██║ ╚████║███████╗██║  ██║
╚═════╝ ╚══════╝  ╚═══╝       ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝
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
    if command -v flutter &> /dev/null; then
        print_item "✓" "${GREEN}" "Cleaning Flutter project builds (flutter clean)..."
        # Find all pubspec.yaml files and run 'flutter clean' in their directories
        find . -name "pubspec.yaml" -maxdepth 4 -execdir flutter clean \;
        print_item "✓" "${GREEN}" "Cleaning Flutter global cache..."
        flutter cache clean
    else
        print_item "✕" "${YELLOW}" "Flutter command not found. Skipping."
    fi
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
    echo ""
    echo -e "→ Please enter your choice (0-9): ${NC}\c"
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
                cleanup_npm_yarn
                cleanup_homebrew
                cleanup_cocoapods
                cleanup_ide_caches
                cleanup_system_junk
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
            *)
                echo -e "${RED}Invalid choice. Please enter a number between 0 and 9.${NC}"
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
