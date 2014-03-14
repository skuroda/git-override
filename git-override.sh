function git() {
    if [[ $# -eq 0 ]]; then
        command git
    else
        __git_intercept_hook "pre" $1 $2
        if [[ "$?" -eq 0 ]]; then
            command git "$@"
            __git_intercept_hook "post" $1 $2
        fi
    fi
}

function __git_intercept_run_hook() {
    local hook_type=$1
    local git_cmd=$2
    local svn_cmd=$3
    local root=$(command git rev-parse --show-toplevel 2>/dev/null);
    local hooks_directory="$root/.git/hooks"
    local prehook_location="$hooks_directory/"
    local prehook_command="$hooks_directory/$hook_type-$git_cmd"
    if [[ "$git_cmd" == "svn" ]]; then
        prehook_command="$prehook_command-$svn_cmd"
    fi

    if [[ "$hook_type" == "pre" ]]; then
        local command_with_hooks=" commit rebase "
    else
        local command_with_hooks=" commit checkout merge "
    fi
    local command_token=" $git_cmd "
    if [[ "${command_with_hooks/$command_token}" == "$command_with_hooks" ]]; then
        if [ -x "$prehook_command" ]; then
            $prehook_command
            local ret_code=$?
            if [[ "$ret_code" -ne 0 ]]; then
                return "$ret_code"
            fi
        fi
    fi
    return 0
}

function __git_intercept_get_alias_cmd() {
    local git_aliases=$(command git config --get-regexp alias | sed -e s/alias\.//g)
    local OLD_IFS=$IFS
    local input=$1
    IFS="
"
    local alias_cmd=""

    for alias_entry in $git_aliases
    do
        local git_cmd=$(echo $alias_entry | cut -d " " -f2)
        local git_alias=$(echo $alias_entry | awk {'print $1'})
        if [[ $git_alias == $input ]]; then
            if [[ ${git_cmd:0:1} != "!" ]]; then
                if [[ "$git_cmd" == "svn" ]]; then
                     local svn_cmd=$(echo $alias_entry | cut -d " " -f3)
                fi
                alias_cmd="$git_cmd $svn_cmd"
            fi
            break
        fi
    done
    IFS=$OLD_IFS
    echo "$alias_cmd"
}

function __git_intercept_hook() {
    local hook_type=$1
    local git_cmd=$2
    local svn_cmd=$3
    if [[ "$git_cmd" == "" ]]; then
        return 0
    fi
    __git_intercept_run_hook "$hook_type" "$git_cmd" "$svn_cmd"
    if [[ "$?" -ne 0 ]]; then
        return "$?"
    fi

    local alias_cmd=$(__git_intercept_get_alias_cmd $git_cmd)
    if [[  "$alias_cmd" != "" ]]; then
        __git_intercept_hook "$hook_type" "$alias_cmd"
        return "$?"
    fi

    return 0
}
