#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"

mbox_print_title Checking rsync
if mbox_exec brew ls --versions rsync; then
    echo "rsync installed."
else
    mbox_print_error "rsync is not installed."
    exit 1
fi
