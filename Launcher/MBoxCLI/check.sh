#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"

mbox_print_title Check '~/.mbox/environment.conf'
conf="$HOME/.mbox/environment.conf"
if ! [[ -f "$conf" ]]; then
    mbox_print_error "'$conf' not exists!"
    exit 1
fi

mbox_print_title Check '~/.mboxrc'
mboxrc="$HOME/.mboxrc"
if ! [[ -f "$mboxrc" ]]; then
    mbox_print_error "'$mboxrc' not exists!"
    exit 1
fi

mbox_print_title Check '~/.profile'
profile="$HOME/.profile"
if ! [[ -f "$profile" ]]; then
    mbox_print_error "'$profile' not exists!"
    exit 1
fi

for f in .zlogin .bash_profile
do
    mbox_print_title Check "~/$f"
    p="$HOME/$f"
    if ! [[ -f "$p" ]]; then
        mbox_print_error "'$p' not exists!"
        exit 1
    fi
    if ! [[ "$(cat $p)" =~ 'source "$HOME/.profile"' ]]; then
        mbox_print_error "'$p' not source '~/.profile'!"
        exit 1
    fi
done

mbox_print_title Check MBox CLI
if mbox_check_exist mbox; then
    echo "MBox CLI has installed."
else
    mbox_print_error "MBox CLI has not installed!"
    exit 1
fi
