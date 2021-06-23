#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"

mbox_print_title Touch '~/.mbox/environment.conf'
conf="$HOME/.mbox/environment.conf"
if ! [[ -f "$conf" ]]; then
    touch "$conf"
fi

mbox_print_title Touch '~/.mboxrc'
mboxrc="$HOME/.mboxrc"
if ! [[ -f "$mboxrc" ]]; then
    touch "$mboxrc"
fi
if ! [[ "$(cat "$mboxrc")" =~ ".mbox/environment.conf" ]]; then
    echo '
if [[ -f "$HOME/.mbox/environment.conf" ]]; then
    set -a
    source "$HOME/.mbox/environment.conf"
    set +a
fi
' >> "$mboxrc"
fi

mbox_print_title Touch '~/.profile'
profile="$HOME/.profile"
if ! [[ -f "$profile" ]]; then
    touch "$profile"
fi
if ! [[ "$(cat "$profile")" =~ 'source "$HOME/.mboxrc"' ]]; then
    echo '
[[ -s "$HOME/.mboxrc" ]] && source "$HOME/.mboxrc"
' >> "$profile"
fi

for f in .zlogin .bash_profile
do
    mbox_print_title Touch '~'/$f
    p="$HOME/$f"
    if ! [[ -f "$p" ]]; then
        touch "$p"
    fi
    if ! [[ "$(cat $p)" =~ 'source "$HOME/.profile"' ]]; then
        echo '
[[ -s "$HOME/.profile" ]] && source "$HOME/.profile"
' >> "$p"
    fi
done

if [[ -z "$MBOX_GUI" ]]; then
    mbox_print_title Install MBox CLI
    "${MBOX_CORE_LAUNCHER}/../MBoxCLI" setup -v
else
    mbox_print_title Skip install mbox CLI
fi
