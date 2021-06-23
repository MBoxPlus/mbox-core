#!/usr/bin/env bash

export MBOX_CLI_DIR=

if [[ -z "$MBOX_CLI_DIR" ]]; then

    if [ -n "$BASH_SOURCE" ]; then
        MBOX_CLI_DIR=$BASH_SOURCE
    elif [ -n "$ZSH_VERSION" ]; then
        setopt function_argzero
        MBOX_CLI_DIR=$0
    elif eval '[[ -n ${.sh.file} ]]' 2>/dev/null; then
        eval 'MBOX_CLI_DIR=${.sh.file}'
    else
        return
    fi

    export MBOX_CLI_DIR=$(bash -c "cd '$(dirname "$MBOX_CLI_DIR")' && echo \$PWD")
fi

export MBOX_CLI_PATH="$MBOX_CLI_DIR/MBoxCLI"

mbox() {
    expand_alias=""
    if [[ -n $ZSH_VERSION ]]; then
        # shellcheck disable=2154  # aliases referenced but not assigned
        expand_alias="${aliases[$1]}"
    else
        # bash
        expand_alias="${BASH_ALIASES[$1]}"
    fi

    "$MBOX_CLI_PATH" "$@" --expand-alias="${expand_alias}"
}

sourced=0

if [ -n "$BASH_SOURCE" ]; then
    (return 0 2>/dev/null) && sourced=1
elif [ -n "$ZSH_VERSION" ]; then
    case $ZSH_EVAL_CONTEXT in *:file) sourced=1;; esac
fi

if [[ $sourced = 0 ]]; then
    "$MBOX_CLI_PATH" "$@"
    exit $?
else
    source "$MBOX_CLI_DIR/mdev.sh"
fi

unset sourced
