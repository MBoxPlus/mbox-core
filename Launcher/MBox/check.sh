#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"
mbox_print_title Checking MBox
if ! [[ -f "$HOME/.profile" ]]; then
    mbox_print_error "$HOME/.profile is not found."
    exit 1
fi

for EACH_PROFILE in ".zlogin" ".bash_profile"
do
    if ! PROFILE_FILE="$(mbox_try_profile "${HOME}/${EACH_PROFILE}")"; then
        mbox_print_error "${HOME}/${EACH_PROFILE} doesn't exist."
        exit 1
    fi
    if ! mbox_source_exist "${PROFILE_FILE}" "\$HOME/.profile"; then
        mbox_print_error "\$HOME/.profile is not sourced in ${HOME}/${EACH_PROFILE}."
        exit 1
    fi
done


if ! [[ -f "$HOME/.mboxrc" ]]; then
    mbox_print_error "$HOME/.mboxrc is not found."
    exit 1
fi

if ! [[ -f "$HOME/.mbox/environment.conf" ]]; then
    mbox_print_error "$HOME/.mbox/environment.conf is not found."
    exit 1
fi
echo "MBox profile environment is ok."