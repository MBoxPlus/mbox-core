#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"

if mbox_check_exist brew; then
    echo "Homebrew installed!"
    # sh change_homebrew_source.sh
else
    mbox_print_title Installing Homebrew

    echo Download Install Script
    BREW_SCRIPT="${TMPDIR}/brew.sh"
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$BREW_SCRIPT"

    # echo Check Homebrew Source
    # source "./get_homebrew_source.sh"
    # perform_brew_url
    # if [[ -n "$HOMEBREW_BREW_GIT_REMOTE" ]]; then
    #     sed -i '' 's|^BREW_REPO=".*"$|BREW_REPO="'$HOMEBREW_BREW_GIT_REMOTE'"|' "$BREW_SCRIPT"
    # fi

    echo Install Homebrew
    export HAVE_SUDO_ACCESS=0
    sh "$BREW_SCRIPT"
    if [[ $? != 0 ]]; then
        exit 1
    fi
fi
