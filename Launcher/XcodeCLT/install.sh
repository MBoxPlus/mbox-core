#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"


mbox_print_title Checking Xcode Command Line Tools

_xcode_path=$(xcode-select -p 2>/dev/null)
echo "Xcode Command Line Tools: ${_xcode_path}"

# set nocasematch option
shopt -s nocasematch
if [[ "$_xcode_path" != *"Xcode"* ]] || [ ! -d "$_xcode_path" ]; then
    _xcode_path=$(mbox_get_app_path 'com.apple.dt.Xcode')
    if [[ "${_xcode_path}" == "" ]]; then
        echo "[WARN] Could not find Xcode."
        mbox_exec xcode-select --install
    else
        mbox_sudo_exec "Setting Command Line Tools to '${_xcode_path}', Password:" xcode-select -s "${_xcode_path}"
    fi
fi

if [[ "$_xcode_path" == *"Xcode"* ]]; then
    if mbox_check_exist xcodebuild; then
        mbox_exec xcodebuild -checkFirstLaunchStatus
        if [[ $? != 0 ]]; then
            mbox_sudo_exe "Please input the root password to agree the software license agreements from Xcode:" xcodebuild -runFirstLaunch accept
        fi
    fi
fi

# unset nocasematch option
shopt -u nocasematch
