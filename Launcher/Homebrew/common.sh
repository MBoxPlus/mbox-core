
check_brew_installed() {
    if mbox_check_exist brew; then
        echo "Homebrew installed."
    else
        mbox_print_error "Homebrew is not installed."
        return 1
    fi
}

check_brew_version() {
    local version=$(brew --version | head -1 | cut -d " " -f 2 | cut -d "-" -f 1)
    echo "Brew Version: ${version}"

    vercomp "$version" "3.5.7"
    if [[ $? != 2 ]]; then
        echo "Brew Version is OK."
        return 0
    fi

    echo "Brew Version is outdated."
    return 1
}
