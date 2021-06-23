#!/bin/bash

source "${MBOX_CORE_LAUNCHER}/launcher.sh"

current_repo=$(git -C "$(brew --repo)" config --get remote.origin.url)
echo "Homebrew source: ${current_repo}"

source "./get_homebrew_source.sh"
perform_brew_url

if [[ -n "$HOMEBREW_CORE_GIT_REMOTE" ]]; then
    echo "Change homebrew source: ${HOMEBREW_CORE_GIT_REMOTE}"
    mbox_exec git -C "$(brew --repo)" remote set-url origin "$HOMEBREW_BREW_GIT_REMOTE"

    # 以下针对 mac OS 系统上的 Homebrew
    mbox_exec git -C "$(brew --repo homebrew/core)" remote set-url origin "$HOMEBREW_CORE_GIT_REMOTE"
    cask_path=$(brew --repo homebrew/cask)
    if [[ -d "$cask_path" ]]; then
        mbox_exec git -C "$cask_path" remote set-url origin "$HOMEBREW_CASK_GIT_REMOTE"
    fi
fi
