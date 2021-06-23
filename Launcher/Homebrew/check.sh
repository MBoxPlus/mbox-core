#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"

if mbox_check_exist brew; then
    echo "Homebrew installed."
else
    mbox_print_error "Homebrew is not installed."
    exit 1
fi
