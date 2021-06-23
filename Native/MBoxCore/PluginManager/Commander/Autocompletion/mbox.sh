#compdef mbox

_arguments -C '*:: :->subcmds' && return 0

local -a _commands
local -a _options

while read -r line; do
    if [[ "$line" = "##NORMAL##" ]]; then
        _normal
    elif [[ "$line" =~ "##NORMAL##@(.*)" ]]; then
        pushd "$match[1]" >/dev/null
        _normal
        popd >/dev/null
    elif [[ "$line" = "-"* ]]; then
        _options+=("$line");
    else
        _commands+=("$line");
    fi
done <<<$(mbox $line --help --api=plain)

if [[ -n "${_commands}" ]]; then
    _describe -t commands "mbox commands" _commands
fi
if [[ -n "${_options}" ]]; then
    _describe -t options "mbox options" _options
fi
