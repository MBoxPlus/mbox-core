#!/bin/bash
requote() {
    local res=""
    for x in "${@}" ; do
        # try to figure out if quoting was required for the $x:
        grep -q "[[:space:]]" <<< "$x" && res="${res} '${x}'" || res="${res} ${x}"
    done
    # remove first space and print:
    sed -e 's/^ //' <<< "${res}"
}

mbox_print_title() {
    mbox_printf_title $@
    printf "\n"
}

mbox_printf_title() {
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
    printf "\n${CYAN}$@...${NC}"
}

mbox_print_error() {
    mbox_printf_error $@
    printf "\n" >&2
}

mbox_printf_error() {
    RED='\033[0;31m'
    NC='\033[0m' # No Color
    printf "\n${RED}[!] $@${NC}" >&2
}

mbox_exec() {
    echo "> $@"
    cmd=requote "${@}"
}

mbox_exe() {
    mbox_exec "$@"

    if [[ $? != 0 ]]; then
        exit 1
    fi
}

mbox_check_exist() {
    mbox_exec command -v $@
}

mbox_get_app_path() {
    local appNameOrBundleId=$1 isAppName=0 bundleId
    # Determine whether an app *name* or *bundle ID* was specified.
    [[ $appNameOrBundleId =~ \.[aA][pP][pP]$ || $appNameOrBundleId =~ ^[^.]+$ ]] && isAppName=1
    if (( isAppName )); then # an application NAME was specified
        # Translate to a bundle ID first.
        bundleId=$(osascript -e "id of application \"$appNameOrBundleId\"" 2>/dev/null) ||
        { echo "ERROR: Application with specified name not found: $appNameOrBundleId" 1>&2; return 1; }
    else # a BUNDLE ID was specified
        bundleId=$appNameOrBundleId
    fi
    fullPath=$(mdfind "kMDItemCFBundleIdentifier == '$1'" | head -1)
    if [[ -z "$fullPath" ]]; then
        # Let AppleScript determine the full bundle path.
        fullPath=$(osascript -e "tell application \"Finder\" to POSIX path of (get application file id \"$bundleId\" as alias)" 2>/dev/null)
        if [[ $? != 0 ]]; then
            echo "ERROR: Application with specified bundle ID not found: $bundleId" 1>&2
            return 1
        fi
    fi
    printf '%s\n' "$fullPath"

    # Warn about /Volumes/... paths, because applications launched from mounted
    # devices aren't persistently installed.
    if [[ $fullPath == /Volumes/* ]]; then
        echo "NOTE: Application is not persistently installed, due to being located on a mounted volume." >&2
    fi
}

mbox_install_app() {
    mbox_exec brew cask list "$1"
    if [[ $? == 0 ]]; then
        mbox_exe brew reinstall "$1" --cask
    else
        mbox_exe brew install "$1" --cask
    fi
}

mbox_sudo_exec() {
    echo "> $2"
    if [[ -z "$SUDO_ASKPASS" ]]; then
        sudo -S -p "$1" -- sh -c "$2"
    else
        sudo -A -p "$1" -- sh -c "$2"
        # osascript -e "do shell script \"$2\" with prompt \"$1\" with administrator privileges"
    fi
}

mbox_sudo_exe() {
    mbox_sudo_exec "$@"
    if [[ $? != 0 ]]; then
        exit 1
    fi
}

mbox_alert() {
    echo "$1"
    if [[ -n "$SUDO_ASKPASS" ]]; then
        osascript -e "
tell application \"$MBOX_GUI_NAME\"
    display alert \"$1\"
end"
    fi
}

mbox_user_confirm() {
    if [[ -z "$SUDO_ASKPASS" ]]; then
        while true; do
            read -p "$1 [Yes|No]" yn
            case $yn in
                [Yy]* ) return 0;;
                [Nn]* ) return 1;;
                * ) ;;
            esac
        done
    else
        local yn=$(osascript -e "display dialog \"$1\" buttons { \"No\", \"Yes\" }")
        if [[ "$yn" == "button returned:Yes" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

mbox_set_environment() {
    filename="$HOME/.mbox/environment.conf"
    thekey="$1"
    newvalue="$2"

    if ! [[ -f "$filename" ]]; then
        echo "" > "$filename"
    fi

    if ! grep -R "^[#]*\s*${thekey}=.*" "$filename" > /dev/null; then
      echo "Set ${thekey}=${newvalue}"
      echo "$thekey=$newvalue" >> $filename
    else
      echo "Update ${thekey}=${newvalue}"
      sed -i '' "s=^[#]*\s*${thekey}\=.*=${thekey}\=${newvalue}=" $filename
    fi
    export $thekey=$newvalue
}

export HOMEBREW_COLOR=1
