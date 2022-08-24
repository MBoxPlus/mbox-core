#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"
source "./common.sh"

check_brew_installed
if [[ $? != 0 ]]; then
    exit 1
fi

check_brew_version
if [[ $? != 0 ]]; then
    exit 1
fi
