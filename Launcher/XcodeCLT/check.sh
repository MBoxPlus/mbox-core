#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"

xcode_path=$(xcode-select -p 2>/dev/null)
if [[ "${xcode_path}" == "" ]]; then
    mbox_print_error "No Xcode Command Line Tools."
    exit 1
fi

echo "Xcode Command Line Tools: ${xcode_path}"

if [[ ! -d "$xcode_path" ]]; then
    mbox_print_error "Invalid Xcode Command Line."
    exit 1
fi

xcode_app_path=$(find /Applications -name '*Xcode*.app' -maxdepth 1)
echo "Xcode Location: ${xcode_app_path}"
if [[ -n ${xcode_app_path} ]] && 
    mbox_check_exist xcodebuild; then
    mbox_exec xcodebuild -checkFirstLaunchStatus
    if [[ $? != 0 ]]; then
        mbox_print_error "Require launch Xcode at least once."
        exit 1
    fi
fi

# if mbox_check_exist xcodebuild; then
#     mbox_exec xcodebuild -checkFirstLaunchStatus
#     if [[ $? != 0 ]]; then
#         mbox_print_error "Require launch Xcode at least once."
#         exit 1
#     fi
# fi
