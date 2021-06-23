#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"

mbox_print_title Checking rsync
if mbox_exec brew ls --versions rsync; then
    echo "rsync installed, skip!"
else
    mbox_print_title Installing rsync
    mbox_exe brew install rsync
fi
