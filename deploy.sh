#!/bin/bash

# Has to be saved with LF line endings!

# Source
source ./lib/print.sh

# --- Variables --- #
# Probably you don't need to modify this. Do it if you know what you're doing, I won't blame you (unless you blame me).
personalDirectory="storage/emulated/0"
bluestacksDirectory="storage/emulated/0"
noxDirectory="data"
configFile="config.sh"

# Do not modify
adb=adb

# --- Functions --- #
# Checks for script update (with git)
function checkForUpdate() {
    if command -v git &>/dev/null; then
        printTask "Checking for updates..."
        git pull &>/dev/null && printSuccess "Checked/updated!" || printWarn "Couldn't check for updates. Please do it manually from time to time."
    fi
}

# Checks for ADB and installs if not present
function checkAdb() {
    printTask "Checking for adb..."
    # Check for custom adb directory
    if [ ! -d "./adb/platform-tools" ]; then
        # Check if ADB is already installed (with Path)
        if command -v adb &>/dev/null; then
            printSuccess "Found in PATH!"
        else
            # If not, install it locally for this script
            printWarn "Not found!"
            printTask "Installing adb..."
            mkdir -p adb # Create directory
            cd ./adb  # Change to new directory

            # Install depending on installed OS
            case "$OSTYPE" in
            "msys")
                curl -LO https://dl.google.com/android/repository/platform-tools-latest-windows.zip # Windows
                unzip ./platform-tools-latest-windows.zip                                           # Unzip
                rm ./platform-tools-latest-windows.zip                                              # Delete .zip
                ;;
            "darwin")
                curl -LO https://dl.google.com/android/repository/platform-tools-latest-darwin.zip # MacOS
                unzip ./platform-tools-latest-darwin.zip                                           # Unzip
                rm ./platform-tools-latest-darwin.zip                                              # Delete .zip
                ;;
            "linux-gnu")
                curl -LO https://dl.google.com/android/repository/platform-tools-latest-linux.zip # Linux
                unzip ./platform-tools-latest-linux.zip                                           # Unzip
                rm ./platform-tools-latest-linux.zip                                              # Delete .zip
                ;;
            *)
                printError "Couldn't find OS."
                printInfo "Please download platform-tools for your respective OS, unzip it into the ./adb folder and run this script again."
                printInfo "Windows: https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
                printInfo "MacOS: https://dl.google.com/android/repository/platform-tools-latest-darwin.zip"
                printInfo "Linux: https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
                exit
                ;;
            esac

            cd ..                        # Change directory back
            adb=./adb/platform-tools/adb # Set adb path
            printSuccess "Installed!"
        fi
    else
        printSuccess "Found locally!"
        adb=./adb/platform-tools/adb
    fi
}

# Creates a config.sh file if not found
function checkConfig() {
    printTask "Searching for config.sh file..."
    if [ -f "$configFile" ]; then
        printSuccess "Found!"
    else
        printWarn "Not found!"
        printTask "Creating new config.sh file..."
        printf '# CONFIG: Modify accordingly to your game! Use this link for help: https://github.com/zebscripts/AFK-Daily#configvariables

# Player
canOpenSoren=false

# General
waitForUpdate=true
endAt="championship"

# Repetitions
totalAmountArenaTries=2+0
totalAmountGuildBossTries=2+0

# Store
buyStoreDust=true
buyStorePoeCoins=true
buyStoreEmblems=false

# Oak Inn
collectOakPresents=false # Only works if "Hide Inn Heroes" is enabled under "Settings -> Memory"
' >config.sh
        printSuccess "Created!\n"
        printInfo "Please edit config.sh if necessary and run this script again."
        exit
    fi

    # Validate config file
    validateConfig
}

# Checks for every necessary variable that needs to be defined in config.sh
function validateConfig() {
    source config.sh
    printTask "Validating config.sh..."
    if [[ -z $canOpenSoren || -z \
        $waitForUpdate || -z \
        $endAt || -z \
        $totalAmountArenaTries || -z \
        $totalAmountGuildBossTries || -z \
        $buyStoreDust || -z \
        $buyStorePoeCoins || -z \
        $buyStoreEmblems ]]; then
        printError "config.sh has missing/wrong entries."
        printInfo "Please either delete config.sh and run the script again to generate a new one, or check the following link for help:"
        printInfo "https://github.com/zebscripts/AFK-Daily#configvariables"
        exit
    fi
    printSuccess "Passed!"
}

# Check if afk-daily.sh has correct Line endings (LF)
# Params: file
function checkLineEndings() {
    printTask "Checking Line endings of file ${cBlue}$1${cNc}..."
    if [[ $(head -1 $1 | cat -A) =~ \^M ]]; then
        printWarn "Found CLRF!"
        printTask "Converting to LF..."
        dos2unix $1 2>/dev/null

        if [[ $(head -1 $1 | cat -A) =~ \^M ]]; then
            printError "Failed to convert $1 to LF. Please do it yourself."
            exit
        else
            printSuccess "Converted!"
        fi
    else
        printSuccess "Passed!"
    fi
}

# Restarts ADB server
function restartAdb() {
    printTask "Restarting ADB..."
    $adb kill-server
    $adb start-server 1>/dev/null 2>&1
    printSuccess "Restarted!"
}

# Check if adb recognizes a device.
# Params: Platform
function checkForDevice() {
    # If parameters are sent
    if [ "$#" -gt "0" ]; then
        # Nox
        if [ "$1" == "Nox" ]; then
            printTask "Searching for Nox through ADB..."
            $adb connect localhost:62001 1>/dev/null
            if ! $adb get-state 1>/dev/null; then
                printError "Not found!"
                exit
            else
                printSuccess "Found Nox!"
            fi
        # Bluestacks
        elif [ "$1" == "Bluestacks" ]; then
            printTask "Searching for Bluestacks through ADB... "
            if ! $adb get-state 1>/dev/null; then
                printError "Not found!"
                exit
            else
                printSuccess "Found Bluestacks!"
            fi
        fi
    # If parameters aren't sent
    else
        printTask "Searching for device through ADB..."

        # Checks if adb finds device
        if ! $adb get-state 1>/dev/null 2>&1; then
            printError "No device found!"
            printInfo "Please make sure it's connected."
            printTip "If you're trying to use Nox, please run this script with './deploy nox'!"
            exit
        else
            # Bluestacks
            if [[ $($adb devices) =~ emulator ]]; then
                printSuccess "Found Bluestacks!"
                deploy "Bluestacks" "$bluestacksDirectory"
            # Personal
            else
                printSuccess "Found Personal Device!"
                deploy "Personal" "$personalDirectory"
            fi
        fi
    fi
}

# Makes a Dir (if it doesn't exist), pushes script into Dir, Executes script in Dir.
# Params: platform, directory
function deploy() {
    printf "\n"
    printInfo "Platform: ${cBlue}$1${cNc}"
    printInfo "Script Directory: ${cBlue}$2/scripts/afk-arena${cNc}\n"

    $adb shell mkdir -p "$2"/scripts/afk-arena                # Create directories if they don't already exist
    $adb push afk-daily.sh "$2"/scripts/afk-arena 1>/dev/null # Push script to device
    $adb push config.sh "$2"/scripts/afk-arena 1>/dev/null    # Push config to device
    $adb shell sh "$2"/scripts/afk-arena/afk-daily.sh "$2"    # Run script. Comment line if you don't want to run the script after pushing
}

# --- Script Start --- #
clear

checkAdb
checkConfig
checkForUpdate
checkLineEndings "config.sh"
checkLineEndings "afk-daily.sh"

# Check where to deploy
if [ "$1" ]; then
    # BlueStacks
    if [ "$1" == "bluestacks" ] || [ "$1" == "bs" ] || [ "$1" == "-bluestacks" ] || [ "$1" == "-bs" ]; then
        restartAdb
        checkForDevice "Bluestacks"
        deploy "Bluestacks" "$bluestacksDirectory"

    # Nox
    elif [ "$1" == "nox" ] || [ "$1" == "n" ] || [ "$1" == "-nox" ] || [ "$1" == "-n" ]; then
        restartAdb
        checkForDevice "Nox"
        deploy "Nox" "$noxDirectory"

    # Interactive Options
    elif [ "$1" == "dev" ]; then
        deploy "Personal" "$personalDirectory"
    fi
# Try to recognize device automatically
else
    restartAdb
    checkForDevice
fi
