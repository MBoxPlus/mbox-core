#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"

if mbox_check_exist brew; then
    echo "Homebrew installed!"
else
    mbox_print_title Installing Homebrew

    echo Download Install Script
    BREW_SCRIPT="${TMPDIR}/brew.sh"
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$BREW_SCRIPT"

    echo Install Homebrew
    export HAVE_SUDO_ACCESS=0
    sh "$BREW_SCRIPT"
    if [[ $? != 0 ]]; then
        exit 1
    fi
fi
