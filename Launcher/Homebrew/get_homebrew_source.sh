#!/bin/bash

get_network_time() {
    time=$(ping "$1" -c 2 2>/dev/null | tail -1 | awk '{print $4}' | cut -d '/' -f 2)
    if [[ -z "$time" ]]; then
        echo "9999"
    else
        echo $time
    fi
}

perform_brew_url() {
    local BREW_MIRROR_HOST="mirrors.tuna.tsinghua.edu.cn"
    local BREW_REPO_HOST="raw.githubusercontent.com"

    compare_str="$(get_network_time "${BREW_MIRROR_HOST}") < $(get_network_time "${BREW_REPO_HOST}")"
    if [[ $(echo "$compare_str" | bc -l) == 1 ]]; then
        export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
        export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
        export HOMEBREW_CASK_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-cask.git"

        export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles
        mbox_set_environment "HOMEBREW_BOTTLE_DOMAIN" "$HOMEBREW_BOTTLE_DOMAIN"
    fi
}
