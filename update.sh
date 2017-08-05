#!/usr/bin/env bash

# Copyright (c) 2016 Egor Tensin <Egor.Tensin@gmail.com>
# This file is part of the "Configuration file sharing" project.
# For details, see https://github.com/egor-tensin/config-links.
# Distributed under the MIT License.

# This script relies on the availability of native symlinks.
# Those are indeed supported by NTFS, but require Administrator privileges for
# creation.
# It likely won't bother you as long as you don't use the functions defined in
# this file.
# In any case, you will see `ln` complaining about some access being denied in
# case something goes wrong.
#
# Remember that in order to force `ln` to use native NTFS symlinks, your
# `CYGWIN` Windows environment variable value **must** include either
# `winsymlinks:native` or `winsymlinks:nativestrict`!

# usage: ./update.sh [-h|--help] [-d|--database PATH] [-s|--shared-dir DIR] [-n|--dry-run]

set -o errexit
set -o nounset
set -o pipefail

dump() {
    local prefix="${FUNCNAME[0]}"
    [ "${#FUNCNAME[@]}" -gt 1 ] && prefix="${FUNCNAME[1]}"

    local msg
    for msg; do
        echo "$prefix: $msg"
    done
}

# Cygwin-related stuff

os="$( uname -o )"
readonly os

is_cygwin() {
    test "$os" == 'Cygwin'
}

check_symlinks_enabled_cygwin() {
    case "${CYGWIN-}" in
        *winsymlinks:native*)       ;;
        *winsymlinks:nativestrict*) ;;

        *)
            dump "native Windows symlinks aren't enabled in Cygwin" >&2
            return 1
            ;;
    esac
}

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
    while IFS= read -d '' -r path; do
        if [ -n "$must_exist" ] && [ ! -e "$path" ]; then
            dump "must exist: $path" >&2
            return 1
        fi

        if [ -e "$path" ] && [ -n "$type_flag" ] && ! test "$type_flag" "$path"; then
            dump "must be a $type_name: $path" >&2
            return 1
        fi

        abs_paths+=("$path")
    done < <( readlink -z --canonicalize-missing -- ${paths[@]+"${paths[@]}"} )

    printf -- "$fmt" ${abs_paths[@]+"${abs_paths[@]}"}
}

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

# Shared directory settings

shared_dir="$( pwd )"

update_shared_dir() {
    if [ "$#" -ne 1 ]; then
        echo "usage: ${FUNCNAME[0]} DIR" >&2
        return 1
    fi

    local new_shared_dir
    new_shared_dir="$( traverse_path --exist --directory -- "$1" )"

    [ "$db_path" == "$shared_dir/$default_db_name" ] \
        && db_path="$new_shared_dir/$default_db_name"

    shared_dir="$new_shared_dir"
}

# Database maintenance

readonly default_db_name='links.bin'
db_path="$shared_dir/$default_db_name"
declare -A database

update_database_path() {
    if [ "$#" -ne 1 ]; then
        echo "usage: ${FUNCNAME[0]} PATH" >&2
        return 1
    fi

    db_path="$( traverse_path --file -- "$1" )"
    mkdir -p -- "$( dirname -- "$db_path" )"
}

ensure_database_exists() {
    [ -f "$db_path" ] || is_dry_run || > "$db_path"
}

read_database() {
    [ ! -f "$db_path" ] && is_dry_run && return 0

    local entry
    while IFS= read -d '' -r entry; do
        database[$entry]=1
    done < "$db_path"
}

write_database() {
    is_dry_run && return 0

    > "$db_path"

    local entry
    for entry in "${!database[@]}"; do
        printf -- '%s\0' "$entry" >> "$db_path"
    done
}

delete_obsolete_dirs() {
    if [ "$#" -ne 2 ]; then
        echo "usage: ${FUNCNAME[0]} BASE_DIR DIR" >&2
        return 1
    fi

    is_dry_run && return 0

    local base_dir="$1"
    local dir="$2"

    base_dir="$( traverse_path --exist --directory -- "$base_dir" )"
    dir="$( traverse_path --exist --directory -- "$dir" )"

    [ "$base_dir" == "$dir" ] && return 0

    local subpath="${dir##$base_dir/}"

    if [ "$subpath" == "$dir" ]; then
        dump "base directory: $base_dir"    >&2
        dump "... is not a parent of: $dir" >&2
        return 1
    fi

    ( cd -- "$base_dir" && rmdir -p --ignore-fail-on-non-empty -- "$subpath" )
}

delete_obsolete_entries() {
    local entry
    for entry in "${!database[@]}"; do
        dump "entry: $entry"
        unset -v 'database[$entry]'

        local var_name
        var_name="$( extract_variable_name "$entry" )" || continue
        cache_variable "$var_name"

        local symlink_var_dir
        symlink_var_dir="$( resolve_variable "$var_name" )" || continue
        local shared_var_dir="$shared_dir/%$var_name%"
        local subpath="${entry#%$var_name%/}"
        local symlink_path="$symlink_var_dir/$subpath"
        local shared_path="$shared_var_dir/$subpath"

        dump "    shared file path: $shared_path"
        dump "    symlink path: $symlink_path"

        if [ ! -L "$shared_path" ] && [ ! -e "$shared_path" ]; then
            dump '    the shared file is missing, so going to delete the symlink'
            is_dry_run && continue

            if [ ! -L "$symlink_path" ]; then
                dump "    not a symlink or doesn't exist, so won't delete"
                continue
            fi

            local target_path
            target_path="$( traverse_path -- "$symlink_path" )"

            if [ "$shared_path" != "$target_path" ]; then
                dump "    doesn't point to the shared file, so won't delete"
                continue
            fi

            rm -f -- "$symlink_path"

            local symlink_dir
            symlink_dir="$( dirname -- "$symlink_path" )"
            delete_obsolete_dirs "$symlink_var_dir" "$symlink_dir" || true

            continue
        fi

        if [ ! -L "$symlink_path" ]; then
            dump "    not a symlink or doesn't exist"
            continue
        fi

        local target_path
        target_path="$( traverse_path -- "$symlink_path" )"

        if [ "$target_path" != "$shared_path" ]; then
            dump "    doesn't point to the shared file"
            continue
        fi

        dump '    ... points to the shared file'
        database[$entry]=1
    done
}

discover_new_entries() {
    local shared_var_dir
    while IFS= read -d '' -r shared_var_dir; do
        dump "shared directory: $shared_dir/$shared_var_dir"

        local var_name
        var_name="$( extract_variable_name "$shared_var_dir" )"
        cache_variable "$var_name"

        shared_var_dir="$shared_dir/$shared_var_dir"

        local symlink_var_dir
        symlink_var_dir="$( resolve_variable "$var_name" )" || continue
        dump "    symlinks directory: $symlink_var_dir"

        local shared_path
        while IFS= read -d '' -r shared_path; do
            dump "        shared file path: $shared_path"

            local entry="%$var_name%/${shared_path:${#shared_var_dir}}"

            if [ -n "${database[$entry]+x}" ]; then
                dump '        ... already has a symlink'
                continue
            fi

            local subpath="${shared_path:${#shared_var_dir}}"
            local symlink_path="$symlink_var_dir/$subpath"

            dump "        symlink path: $symlink_path"

            is_dry_run && continue

            mkdir -p -- "$( dirname -- "$symlink_path" )"
            ln -f -s --no-target-directory -- "$shared_path" "$symlink_path"

            database[$entry]=1
        done < <( find "$shared_var_dir" -type f -print0 )

    done < <( find "$shared_dir" -regextype posix-basic -mindepth 1 -maxdepth 1 -type d -regex ".*/$var_name_regex\$" -printf '%P/\0' )
}

# Main routines

script_name="$( basename -- "${BASH_SOURCE[0]}" )"
readonly script_name

script_usage() {
    local msg
    for msg; do
        echo "$script_name: $msg"
    done

    echo "usage: $script_name [-h|--help] [-d|--database PATH] [-s|--shared-dir DIR] [-n|--dry-run]
  -h,--help          show this message and exit
  -d,--database      set database file path
  -s,--shared-dir    set top-level shared directory path
                     (current working directory by default)
  -n,--dry-run       don't actually do anything intrusive"
}

parse_script_options() {
    while [ "$#" -gt 0 ]; do
        local key="$1"
        shift

        case "$key" in
            -h|--help)
                script_usage
                exit 0
                ;;
            -n|--dry-run)
                dry_run=1
                continue
                ;;
            -d|--database|-s|--shared-dir)
                ;;
            *)
                script_usage "unrecognized parameter: $key" >&2
                exit 1
                ;;
        esac

        if [ "$#" -eq 0 ]; then
            script_usage "missing argument for parameter: $key" >&2
            exit 1
        fi

        local value="$1"
        shift

        case "$key" in
            -d|--database)
                update_database_path "$value"
                ;;
            -s|--shared-dir)
                update_shared_dir "$value"
                ;;
            *)
                script_usage "unrecognized parameter: $key" >&2
                exit 1
                ;;
        esac
    done
}

is_dry_run() {
    test -n "${dry_run+x}"
}

check_symlinks_enabled() {
    if is_cygwin; then
        check_symlinks_enabled_cygwin
    else
        return 0
    fi
}

main() {
    parse_script_options "$@"
    check_symlinks_enabled
    ensure_database_exists
    read_database
    delete_obsolete_entries
    discover_new_entries
    write_database
}

main "$@"
