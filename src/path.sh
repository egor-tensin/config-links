# Copyright (c) 2016 Egor Tensin <egor@tensin.name>
# This file is part of the "Config file sharing" project.
# For details, see https://github.com/egor-tensin/config-links.
# Distributed under the MIT License.

# Making sure paths point to files/directories

_traverse_path_usage() {
    local prefix="${FUNCNAME[0]}"
    [ "${#FUNCNAME[@]}" -gt 1 ] && prefix="${FUNCNAME[1]}"

    local msg
    for msg; do
        echo "$prefix: $msg"
    done

    echo "usage: $prefix [-h|--help] [-0|--null|-z|--zero] [-e|--exist] [-f|--file] [-d|--directory] [--] [PATH]..."
}

traverse_path() {
    local -a paths=()

    local must_exist=
    local type_flag=
    local type_name=

    local fmt='%s\n'

    while [ "$#" -gt 0 ]; do
        local key="$1"
        shift

        case "$key" in
            -h|--help)
                _traverse_path_usage
                return 0
                ;;
            -0|--null|-z|--zero)
                fmt='%s\0'
                ;;
            --)
                break
                ;;
            -e|--exist)
                must_exist=1
                ;;
            -d|--directory)
                type_flag=-d
                type_name="directory"
                ;;
            -f|--file)
                type_flag=-f
                type_name="regular file"
                ;;
            -*)
                _traverse_path_usage "unrecognized parameter: $key" >&2
                return 1
                ;;
            *)
                paths+=("$key")
                ;;
        esac
    done

    paths+=("$@")

    [ "${#paths[@]}" -eq 0 ] && return 0

    if is_cygwin; then
        local i
        for i in "${!paths[@]}"; do
            paths[$i]="$( cygpath -- "${paths[$i]}" )"
        done
    fi

    local -a abs_paths=()

    local path
    readlink -z --canonicalize-missing -- ${paths[@]+"${paths[@]}"} | while IFS= read -d '' -r path; do
        if [ -n "$must_exist" ] && [ ! -e "$path" ]; then
            dump "must exist: $path" >&2
            return 1
        fi

        if [ -e "$path" ] && [ -n "$type_flag" ] && ! test "$type_flag" "$path"; then
            dump "must be a $type_name: $path" >&2
            return 1
        fi

        abs_paths+=("$path")
    done

    printf -- "$fmt" ${abs_paths[@]+"${abs_paths[@]}"}
}
