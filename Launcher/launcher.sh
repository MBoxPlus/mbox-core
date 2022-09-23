#!/bin/bash

MBOX_PROFILE="$HOME/.profile"

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
    export SUDO_PROMPT=$@
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

mbox_echo() {
  command printf %s\\n "$*" 2>/dev/null
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
    mbox_exec brew list "$1" --cask
    if [[ $? == 0 ]]; then
        mbox_exe brew reinstall "$1" --cask
    else
        mbox_exe brew install "$1" --cask
    fi
}

mbox_sudo_exec() {
    local msg=$1
    shift
    echo "> sudo $@"
    if [[ -z "$SUDO_ASKPASS" ]]; then
        sudo -S -p "$msg" "$@"
    else
        sudo -A -p "$msg" "$@"
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

mbox_try_profile() {
    if [ -z "${1-}" ] || [ ! -f "${1}" ]; then
        return 1
    fi
    mbox_echo "${1}"
}

mbox_detect_profile() {
    if [ "${PROFILE-}" = '/dev/null' ]; then
        # the user has specifically requested NOT to have nvm touch their profile
        return
    fi

    if [ -n "${PROFILE}" ] && [ -f "${PROFILE}" ]; then
        mbox_echo "${PROFILE}"
        return
    fi

    local DETECTED_PROFILE
    DETECTED_PROFILE=''

    if [ "${SHELL#*bash}" != "$SHELL" ]; then
        if [ -f "$HOME/.bash_profile" ]; then
            DETECTED_PROFILE="$HOME/.bash_profile"
        fi
    elif [ "${SHELL#*zsh}" != "$SHELL" ]; then
        if [ -f "$HOME/.zlogin" ]; then
            DETECTED_PROFILE="$HOME/.zlogin"
        fi
    fi

    if [ -z "$DETECTED_PROFILE" ]; then
        for EACH_PROFILE in ".zlogin" ".bash_profile"
        do
            if DETECTED_PROFILE="$(mbox_try_profile "${HOME}/${EACH_PROFILE}")"; then
                break
            fi
        done
    fi

    if [ -n "$DETECTED_PROFILE" ]; then
        mbox_echo "$DETECTED_PROFILE"
    fi
}

mbox_add_source() {
    local PROFILE_FILE="$1"
    local SOURCE_STRING="$2"

    if ! [[ -f "$PROFILE_FILE" ]]; then
        echo "Failed on adding source '${SOURCE_STRING}' to ${PROFILE_FILE}"
        return
    fi

    if ! grep -R "\(\.\|source\)\\s\+\"${SOURCE_STRING}\"" "${PROFILE_FILE}" > /dev/null; then
      echo "Add source '${SOURCE_STRING}' to ${PROFILE_FILE}"
      command printf "\n[ -f \"${SOURCE_STRING}\" ] && . \"${SOURCE_STRING}\"\n" >> $PROFILE_FILE
    else
      echo "Source '${SOURCE_STRING}' exists in ${PROFILE_FILE}."
    fi
}

mbox_source_exist() {
    local PROFILE_FILE="$1"
    local SOURCE_STRING="$2"

    if ! [[ -f "$PROFILE_FILE" ]]; then
        return 1
    fi

    if ! grep -R "\(\.\|source\)\\s\+\"${SOURCE_STRING}\"" "${PROFILE_FILE}" > /dev/null; then
        return 1
    fi
}

mbox_inject_profile() {
    echo "Inject ~/.profile"
    local ENV_FILE="$MBOX_PROFILE"
    if ! [[ -f "$ENV_FILE" ]]; then
        echo "Touch ${ENV_FILE}"
        touch $ENV_FILE
    fi
    local SOURCE_STRING="$(mbox_echo $ENV_FILE | sed "s:^$HOME:\$HOME:")"

    for EACH_PROFILE in ".zlogin" ".bash_profile"
    do
        if ! PROFILE_FILE="$(mbox_try_profile "${HOME}/${EACH_PROFILE}")"; then
            touch "${HOME}/${EACH_PROFILE}"
        fi
        mbox_add_source "${HOME}/${EACH_PROFILE}" "$SOURCE_STRING"
    done
}

mbox_setup_environment() {
    local ENVIROMENT_CONFIG_FILE="$HOME/.mbox/environment.conf"
    if ! [[ -f $ENVIROMENT_CONFIG_FILE ]]; then
        echo "Create ${ENVIROMENT_CONFIG_FILE}"
        mkdir -p "$(dirname "$ENVIROMENT_CONFIG_FILE")" && touch "$ENVIROMENT_CONFIG_FILE"
    fi

    local ENV_FILE="$HOME/.mboxrc"
    if ! [[ -f "$ENV_FILE" ]]; then
        echo "Create ${ENV_FILE}"
        touch $ENV_FILE
    fi
    if ! [[ -s "$ENV_FILE" ]]; then
        cat >$ENV_FILE <<EOL
if [[ -f "$HOME/.mbox/environment.conf" ]]; then
    set -a
    source "$HOME/.mbox/environment.conf"
    set +a
fi

[[ -s "/Applications/MBox.app/Contents/Resources/Plugins/MBoxCore/sourced.sh" ]] && source "/Applications/MBox.app/Contents/Resources/Plugins/MBoxCore/sourced.sh" # MBox
EOL
    fi

    local SOURCE_STRING="$(mbox_echo $ENV_FILE | sed "s:^$HOME:\$HOME:")"

    mbox_inject_profile
    
    mbox_add_source "$MBOX_PROFILE" "$SOURCE_STRING"
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

mbox_export_enironment() {
    local path="${MBOX_ENVIRONMENT_FILE}"
    if [[ -z "${path}" ]]; then
        return
    fi

    local key="$1"
    local value="$2"

    echo "${key}=${value}" >> "${path}"
}

vercomp() {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

export HOMEBREW_COLOR=1
