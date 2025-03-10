#!/bin/bash

# ---------------------------
# Multi-StalkerPro Setup Script
# ---------------------------
# Project: Multi-StalkerPro
# Author: zKhadiri
# ---------------------------

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

IPK=""
ARCH=""
PY_VER=""
VERSION="1.3-r02"
BASE_URL="https://raw.githubusercontent.com/zKhadiri/MultiStalkerPro-releases/refs/heads/main"

REQUIRED_PYTHON_DEPS=(
    "rapidfuzz"
    "rarfile"
    "requests"
    "cryptography"
    "pycryptodome"
    "dateutil"
    "pillow"
    "sqlite3"
    "six"
    "zoneinfo"
)


welcome_message() {
    echo -e "${CYAN}##########################################${RESET}"
    echo -e "${YELLOW}### Welcome to Multi-StalkerPro Setup! ###${RESET}"
    echo -e "${CYAN}##########################################${RESET}"
}

detect_python_version() {
    if command -v python3 &>/dev/null; then
        PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
        PYTHON_VERSION=$(echo "$PYTHON_VERSION" | cut -d'.' -f1-2)
        if [[ "$(printf '%s\n' "$PYTHON_VERSION" "3.9" | sort -V | head -n1)" != "3.9" ]]; then
            echo "Python version is lower than 3.9. Exiting..."
            exit 1
        else
            echo $PYTHON_VERSION
        fi
    elif command -v python &>/dev/null; then
        PYTHON_VERSION=$(python --version 2>&1 | awk '{print $2}')
        PYTHON_VERSION=$(echo "$PYTHON_VERSION" | cut -d'.' -f1-2)
        if [[ "$(printf '%s\n' "$PYTHON_VERSION" "3.9" | sort -V | head -n1)" != "3.9" ]]; then
            echo "Python version is lower than 3.9. Exiting..."
            exit 1
        else
            echo $PYTHON_VERSION
        fi
    else
        echo "Python is not installed. Please install Python 3.9 or higher."
        exit 1
    fi
}

detect_cpu_arch() {
    echo "Checking Python version..."
    PY_VER=$(detect_python_version)
    echo "Python version: $PY_VER is suitable for Multi-StalkerPro"

    echo "Detecting CPU architecture..."
    CPU_ARCH=$(uname -m)
    echo "CPU architecture: $CPU_ARCH"

    if [[ "$CPU_ARCH" == *"arm"* ]]; then
        CPU_ARCH="arm"
        ARCH=$(detect_arm_arch)
        if [[ "$ARM_ARCH" != "unknown" ]]; then
            IPK="enigma2-plugin-subscription-multi-stalkerpro_${VERSION}_${ARCH}_py${PY_VER}.ipk"
            echo "Detected architecture: ${ARCH}"
        else
            echo "Unsupported architecture: ${ARCH}"
            exit 1
        fi
    elif [[ "$CPU_ARCH" == *"mips"* ]]; then
        ARCH="mips32el"
        CPU_ARCH="mipsel"
        IPK="enigma2-plugin-subscription-multi-stalkerpro_${VERSION}_${ARCH}_py${PY_VER}.ipk"
        echo "Detected architecture: ${CPU_ARCH}"
    elif [[ "$CPU_ARCH" == *"aarch64"* ]]; then
        ARCH="aarch64"
        CPU_ARCH="aarch64"
        IPK="enigma2-plugin-subscription-multi-stalkerpro_${VERSION}_${ARCH}_py${PY_VER}.ipk"
        echo "Detected architecture: ${CPU_ARCH}"
    else
        echo "Unsupported CPU architecture: $CPU_ARCH"
        exit 1
    fi
}

detect_arm_arch() {
    OPKG_DIR="/etc/opkg/"
    if [[ -d "$OPKG_DIR" ]]; then
        if ls "$OPKG_DIR" | grep -q "cortexa15hf-neon-vfpv4"; then
            echo "cortexa15hf-neon-vfpv4"
        elif ls "$OPKG_DIR" | grep -q "cortexa9hf-neon"; then
            echo "cortexa9hf-neon"
        elif ls "$OPKG_DIR" | grep -q "cortexa7hf-vfp"; then
            echo "cortexa7hf-vfp"
        elif ls "$OPKG_DIR" | grep -q "armv7ahf-neon"; then
            echo "armv7ahf-neon"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

install_plugin_deps() {
    echo "Updating opkg package list..."
    opkg update

    echo "Checking for required Python dependencies..."

    for dep in "${REQUIRED_PYTHON_DEPS[@]}"; do
        echo -e "${CYAN}Checking for $dep...${RESET}"
        if ! opkg list-installed | grep -q "$dep"; then
            echo -e "${YELLOW}$dep is not installed. Installing using opkg...${RESET}"
            if ! opkg install "python3-$dep"; then
                if [[ "$dep" == "rarfile" || "$dep" == "rapidfuzz" ]]; then
                    echo -e "${YELLOW}$dep is not installed and not available in opkg. Installing from custom link...${RESET}"

                    case "$dep" in
                        rarfile)
                            package_url="${BASE_URL}/DEPS/Python/python${PY_VER}/python3-rarfile_4.2-r0_all.ipk"
                            ipk="python3-rarfile_4.2-r0_all.ipk"
                            ;;
                        rapidfuzz)
                            package_url="${BASE_URL}/DEPS/Python/python${PY_VER}/${CPU_ARCH}/python3-rapidfuzz_3.11.0_${ARCH}.ipk"
                            ipk="python3-rapidfuzz_3.11.0_${ARCH}.ipk"
                            ;;
                    esac

                    if wget -q "--no-check-certificate" -O "/tmp/${ipk}" "$package_url"; then
                        if opkg install "/tmp/${ipk}"; then
                            rm -f "/tmp/${ipk}"
                            echo -e "${GREEN}$dep successfully installed from custom link.${RESET}"
                        else
                            echo -e "${RED}Error: Failed to install $dep from custom link. Exiting...${RESET}"
                            exit 1
                        fi
                    else
                        echo -e "${RED}Error: Failed to download $dep from custom link. Exiting...${RESET}"
                        exit 1
                    fi
                elif [[ "$dep" == "zoneinfo" ]]; then
                    echo -e "${YELLOW}Warning: $dep is not available. Skipping...${RESET}"
                else
                    echo -e "${RED}Error: $dep is not available or failed to install. Exiting...${RESET}"
                    exit 1
                fi
            fi
        else
            echo -e "${GREEN}$dep is already installed.${RESET}"
        fi
    done
}

install_ipaudiopro() {
    echo "Checking IPAudioPro installation..."
    if ! opkg list-installed | grep -q "enigma2-plugin-extensions-ipaudiopro"; then
        echo "IPAudioPro is not installed."

        if [[ -t 0 && "$CONSOLE" != "multistalkerpro" ]]; then
            read -t 60 -p "Do you want to install IPAudioPro? (yes/no) [default: yes]: " choice
            choice=${choice:-yes}

            case "$choice" in 
                [Yy][Ee][Ss]|[Yy]) 
                    echo "Installing IPAudioPro..."
                    wget -q "--no-check-certificate" https://raw.githubusercontent.com/zKhadiri/IPAudioPro-Releases-/refs/heads/main/installer.sh -O - | /bin/sh
                    ;;
                *) 
                    echo "IPAudioPro Installation skipped."
                    ;;
            esac
        else
            echo "Skipping IPAudioPro installation due to non-interactive shell or CONSOLE=$CONSOLE."
        fi
    else
        echo "IPAudioPro is already installed."
    fi
}

restart_box(){
    killall -9 enigma2
    exit 0
}

parse_version() {
    local version=$1
    if [[ $version =~ ([0-9]+\.[0-9]+(\.[0-9]+)?)(-r([0-9]+))? ]]; then
        echo "${BASH_REMATCH[1]} ${BASH_REMATCH[4]:-0}"
    else
        echo "$version 0"
    fi
}

needs_update() {
    local current_version=$1
    local source_version=$2

    read -r current_main current_rev <<< "$(parse_version "$current_version")"
    read -r source_main source_rev <<< "$(parse_version "$source_version")"

    if [[ "$current_main" != "$source_main" || "$current_rev" != "$source_rev" ]]; then
        return 0
    else
        return 1
    fi
}

install_plugin() {
    welcome_message
    detect_cpu_arch
    
    echo "Checking if Multi-StalkerPro is installed..."

    OLD_PACKAGE="enigma2-plugin-extensions-multi-stalkerpro"
    NEW_PACKAGE="enigma2-plugin-subscription-multi-stalkerpro"

    INSTALLED_VERSION=$(opkg status $OLD_PACKAGE | grep -i 'Version:' | awk '{print $2}' | sed 's/+.*//')
    if [[ -z "$INSTALLED_VERSION" ]]; then
        INSTALLED_VERSION=$(opkg status $NEW_PACKAGE | grep -i 'Version:' | awk '{print $2}' | sed 's/+.*//')
    fi

    echo "Current version: $VERSION"
    
    if [[ -n "$INSTALLED_VERSION" ]]; then
        echo "Current installed version: $INSTALLED_VERSION"

        if needs_update "$INSTALLED_VERSION" "$VERSION"; then
            install_plugin_deps
            echo "Newer version found. Installing version $VERSION..."

            if [ -e /etc/enigma2/MultiStalkerPro.json ]; then
                cp /etc/enigma2/MultiStalkerPro.json /tmp
            fi
            
            if opkg list-installed | grep -q "$OLD_PACKAGE"; then
                opkg remove $OLD_PACKAGE
            fi

            if opkg list-installed | grep -q "$NEW_PACKAGE"; then
                opkg remove $NEW_PACKAGE
            fi

            IPK_URL="${BASE_URL}/v${VERSION}/python${PY_VER}/${CPU_ARCH}/${IPK}"
            wget -q "--no-check-certificate" -O "/tmp/${IPK}" "$IPK_URL"
            opkg install "/tmp/${IPK}"
            rm -f "/tmp/${IPK}"

            if [ -e /tmp/MultiStalkerPro.json ]; then
                mv -f /tmp/MultiStalkerPro.json /etc/enigma2/MultiStalkerPro.json
                rm -f /tmp/MultiStalkerPro.json
            fi
            
            install_ipaudiopro
            restart_box
        else
            echo "Multi-StalkerPro is already up to date (version $INSTALLED_VERSION). No action needed."
        fi
    else
        install_plugin_deps
        echo "Multi-StalkerPro is not installed. Installing..."
        IPK_URL="${BASE_URL}/v${VERSION}/python${PY_VER}/${CPU_ARCH}/${IPK}"
        wget -q "--no-check-certificate" -O "/tmp/${IPK}" "$IPK_URL"
        opkg install "/tmp/${IPK}"
        rm -f "/tmp/${IPK}"
        install_ipaudiopro
        restart_box
    fi
    exit 0
}

install_plugin
