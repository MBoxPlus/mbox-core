#!/usr/bin/env bash

mbox_cli() {
    # Get alias
    local expand_alias=""
    if [[ -n $ZSH_VERSION ]]; then
        expand_alias="${aliases[$2]}"
    else
        expand_alias="${BASH_ALIASES[$2]}"
    fi

    # Get CLI
    local cli=""
    if [ -n "$BASH_SOURCE" ]; then
        cli=$BASH_SOURCE
    elif [ -n "$ZSH_VERSION" ]; then
        cli=${(%):-%x}
    else
        echo "[MBox] Could not location CLI path." >&2
        return
    fi
    cli=$(bash -c "cd '$(dirname "$cli")' && echo \$PWD")
    cli="$cli/$1"
    shift

    "$cli" "$@" --expand-alias="${expand_alias}"
}

mdev() {
    mbox_cli MDevCLI "$@"
}

mbox() {
    mbox_cli MBoxCLI "$@"
}
