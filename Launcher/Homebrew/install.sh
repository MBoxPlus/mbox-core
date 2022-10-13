#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"
source "./common.sh"

mbox_print_title Install Homebrew
check_brew_installed
if [[ $? != 0 ]]; then
    export HAVE_SUDO_ACCESS=0
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ $? != 0 ]]; then
        exit 1
    fi
    if [[ $(uname -p) == 'arm' ]]; then
        # ARM device
        echo '
if [[ "${HOMEBREW_PREFIX}" != "/opt/homebrew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi
' >> ~/.profile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

mbox_print_title Upgrade Homebrew
check_brew_version
if [[ $? != 0 ]]; then
    mbox_exe brew update
fi

var=(
  'HOMEBREW_PREFIX'
  'HOMEBREW_CELLAR'
  'HOMEBREW_REPOSITORY'
  'PATH'
  'MANPATH'
  'INFOPATH')

for name in ${var[@]}; do
    mbox_export_enironment "${name}" "${!name}"
done
