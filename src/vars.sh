# Copyright (c) 2016 Egor Tensin <Egor.Tensin@gmail.com>
# This file is part of the "Configuration file sharing" project.
# For details, see https://github.com/egor-tensin/config-links.
# Distributed under the MIT License.

# Variable resolution

declare -A cached_paths

resolve_variable() {
    if [ "$#" -ne 1 ]; then
        echo "usage: ${FUNCNAME[0]} VAR_NAME" >&2
        return 1
    fi

    local var_name="$1"

    if [ -n "${cached_paths[$var_name]+x}" ]; then
        echo "${cached_paths[$var_name]}"
        return 0
    fi

    if [ "$var_name" = "$root_var_name" ]; then
        echo ''
        return 0
    fi

    if [ -z "${!var_name+x}" ]; then
        dump "variable is not set: $var_name" >&2
        return 1
    fi

    local var_path="${!var_name}"
    traverse_path --exist --directory -- "$var_path"
}

cache_variable() {
    local var_name
    for var_name; do
        [ -n "${cached_paths[$var_name]+x}" ] && continue
        cached_paths[$var_name]="$( resolve_variable "$var_name" )"
    done
}

readonly root_var_name='CONFIG_LINKS_ROOT'
readonly var_name_regex='%\([_[:alpha:]][_[:alnum:]]*\)%'

extract_variable_name() {
    local s
    for s; do
        local var_name
        if ! var_name="$( expr "$s" : "$var_name_regex/" )"; then
            dump "couldn't extract variable name from: $s" >&2
            return 1
        fi
        echo "$var_name"
    done
}
