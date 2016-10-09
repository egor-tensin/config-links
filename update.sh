#!/usr/bin/env bash

# Copyright (c) 2016 Egor Tensin <Egor.Tensin@gmail.com>
# This file is part of the "Configuration file management" project.
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

# usage: ./update.sh [-d|--database PATH] [-c|--config-dir DIR] [-n|--dry-run] [-h|--help]

set -o errexit
set -o nounset
set -o pipefail

# Cygwin-related stuff

readonly os="$( uname -o )"

is_cygwin() {
    test "$os" == 'Cygwin'
}

check_symlinks_enabled_cygwin() {
    case "${CYGWIN-}" in
        *winsymlinks:native*)       ;;
        *winsymlinks:nativestrict*) ;;

        *)
            dump 'native Windows symlinks aren'"'"'t enabled in Cygwin' >&2
            return 1
            ;;
    esac
}

# Utility routines

script_argv0="${BASH_SOURCE[0]}"
script_dir="$( cd "$( dirname "$script_argv0" )" && pwd )"

dump() {
    local prefix="${FUNCNAME[0]}"

    if [ "${#FUNCNAME[@]}" -gt 1 ]; then
        prefix="${FUNCNAME[1]}"
    fi

    while [ "$#" -ne 0 ]; do
        echo "$prefix: $1" || true
        shift
    done
}

resolve_path() {
    local -a paths
    local exit_with_usage=

    local must_exist=
    local type_flag=
    local type_name=

    while [ "$#" -gt 0 ]; do
        local key="$1"
        shift

        case "$key" in
            -h|--help)
                exit_with_usage=0
                break
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
            *)
                paths+=("$key")
                ;;
        esac
    done

    if [ -n "$exit_with_usage" ]; then
        echo "usage: ${FUNCNAME[0]} [-h|--help] [-e|--exist] [-f|--file] [-d|--directory] [--] [PATH]..." || true
        return "$exit_with_usage"
    fi

    paths+=("$@")

    if is_cygwin; then
        local i
        for i in "${!paths[@]}"; do
            paths[$i]="$( cygpath "${paths[$i]}" )"
        done
    fi

    local path
    while IFS= read -d '' -r path; do
        if [ -n "$must_exist" ] && [ ! -e "$path" ]; then
            dump "must exist: $path" >&2
        fi

        if [ -e "$path" ] && [ -n "$type_flag" ] && ! test "$type_flag" "$path"; then
            dump "must be a $type_name: $path" >&2
            return 1
        fi

        echo "$path"
    done < <( readlink --zero --canonicalize-missing ${paths[@]+"${paths[@]}"} )
}

declare -A cached_paths

resolve_variable() {
    if [ "$#" -ne 1 ]; then
        echo "usage: ${FUNCNAME[0]} VAR_NAME" || true
        return 1
    fi

    local var_name="$1"

    if [ -z "${!var_name+x}" ]; then
        dump "variable is not set: $var_name" >&2
        return 1
    fi

    local var_path="${!var_name}"
    resolve_path --exist --directory -- "$var_path"
}

check_symlinks_enabled() {
    if is_cygwin; then
        check_symlinks_enabled_cygwin
    else
        return 0
    fi
}

# Configuration directory settings

config_dir="$script_dir"

update_config_dir() {
    if [ "$#" -ne 1 ]; then
        echo "usage: ${FUNCNAME[0]} DIR" || true
        return 1
    fi

    local new_config_dir
    new_config_dir="$( resolve_path --exist --directory -- "$1" )"

    [ "$db_path" == "$config_dir/$default_db_fn" ] \
        && db_path="$new_config_dir/$default_db_fn"

    config_dir="$new_config_dir"
}

# Database maintenance

readonly default_db_fn='db.bin'
db_path="$config_dir/$default_db_fn"
declare -A database

update_database_path() {
    if [ "$#" -ne 1 ]; then
        echo "usage: ${FUNCNAME[0]} PATH" || true
        return 1
    fi

    db_path="$( resolve_path --file "$1" )"
    mkdir --parents "$( dirname "$db_path" )"
}

ensure_database_exists() {
    [ -f "$db_path" ] || touch "$db_path"
}

read_database() {
    local entry
    while IFS= read -d '' -r entry; do
        database[$entry]=1
    done < "$db_path"
}

write_database() {
    if [ -n "${dry_run+x}" ]; then
        dump 'won'"'"'t write the database because it'"'"'s a dry run'
        return 0
    fi

    > "$db_path"

    local entry
    for entry in "${!database[@]}"; do
        printf '%s\0' "$entry" >> "$db_path"
    done
}

delete_obsolete_dirs() {
    if [ $# -ne 2 ]; then
        echo "usage: ${FUNCNAME[0]} BASE_DIR DIR" || true
        return 1
    fi

    local base_dir="$1"
    local dir="$2"

    if [ ! -d "$base_dir" ]; then
        dump "base directory doesn't exist: $base_dir" >&2
        return 1
    fi

    if [ ! -d "$dir" ]; then
        dump "directory doesn't exist: $dir" >&2
        return 1
    fi

    base_dir="$( resolve_path --exist --directory -- "$base_dir" )"
    dir="$( resolve_path --exist --directory -- "$dir" )"

    [ "$base_dir" == "$dir" ] && return 0

    local subpath="${dir##$base_dir/}"

    if [ "$subpath" == "$dir" ]; then
        dump "base directory: $base_dir"    >&2
        dump "... is not a parent of: $dir" >&2
        return 1
    fi

    if [ -n "${dry_run+x}" ]; then
        dump 'won'"'"'t delete the directory because it'"'"'s a dry run'
        return 0
    fi

    ( cd "$base_dir" && rmdir --parents "$subpath" --ignore-fail-on-non-empty )
}

readonly var_name_regex='%\([_[:alpha:]][_[:alnum:]]*\)%'

delete_obsolete_entries() {
    local entry
    for entry in "${!database[@]}"; do
        dump "entry: $entry"

        local var_name
        var_name="$( expr "$entry" : "$var_name_regex/" )"

        if [ -z "$var_name" ]; then
            dump '    couldn'"'"'t extract variable name' >&2
            unset -v 'database[$entry]'
            continue
        fi

        local symlink_var_dir
        if ! symlink_var_dir="${cached_paths[$var_name]="$( resolve_variable "$var_name" )"}"; then
            unset -v 'cached_paths[$var_name]'
            unset -v 'database[$entry]'
            continue
        fi
        local config_var_dir="$config_dir/%$var_name%"

        local subpath="${entry#%$var_name%/}"

        local symlink_path="$symlink_var_dir/$subpath"
        local config_path="$config_var_dir/$subpath"

        if [ ! -e "$config_path" ]; then
            dump "    missing source file: $config_path" >&2

            if [ -z "${dry_run+x}" ]; then
                rm --force "$symlink_path"
            else
                dump '    won'"'"'t delete an obsolete symlink, because it'"'"'s a dry run'
            fi

            unset -v 'database[$entry]'

            local symlink_dir
            symlink_dir="$( dirname "$symlink_path" )"

            delete_obsolete_dirs "$symlink_var_dir" "$symlink_dir" || true
            continue
        fi

        if [ ! -L "$symlink_path" ] || [ ! -e "$symlink_path" ]; then
            dump "    not a symlink or doesn't exist: $symlink_path" >&2
            unset -v 'database[$entry]'
            continue
        fi

        local target_path
        target_path="$( resolve_path "$symlink_path" )"

        if [ "$target_path" != "$config_path" ]; then
            dump "    points to a wrong file: $symlink_path" >&2
            unset -v 'database[$entry]'
            continue
        fi

        dump '    ... points to the right file'
    done
}

discover_new_entries() {
    local config_var_dir
    while IFS= read -d '' -r config_var_dir; do
        dump "source directory: $config_var_dir"

        local var_name
        var_name="$( basename "$config_var_dir" )"
        var_name="$( expr "$var_name" : "$var_name_regex" )"
        dump "    variable name: $var_name"

        local symlink_var_dir
        if ! symlink_var_dir="${cached_paths[$var_name]="$( resolve_variable "$var_name" )"}"; then
            unset -v 'cached_paths[$var_name]'
            continue
        fi
        dump "    destination directory: $symlink_var_dir"

        local config_path
        while IFS= read -d '' -r config_path; do
            dump "        source file: $config_path"

            local entry="%$var_name%${config_path:${#config_var_dir}}"

            if [ -n "${database[$entry]+x}" ]; then
                dump '        ... points to the right file'
                continue
            fi

            local symlink_path="$symlink_var_dir${config_path:${#config_var_dir}}"
            dump "        destination file: $symlink_path"

            if [ -z "${dry_run+x}" ]; then
                mkdir --parents "$( dirname "$symlink_path" )"
                ln --force --symbolic "$config_path" "$symlink_path"
            else
                dump '        won'"'"'t create a symlink because it'"'"'s a dry run'
            fi

            database[$entry]=1
        done < <( find "$config_var_dir" -type f -print0 )

    done < <( find "$config_dir" -regextype posix-basic -mindepth 1 -maxdepth 1 -type d -regex ".*/$var_name_regex\$" -print0 )
}

# Main routines

exit_with_usage() {
    local msg
    IFS= read -d '' -r msg <<MSG || echo -n "$msg" || true
usage: $script_argv0 [-d|--database PATH] [-c|--config-dir DIR] [-n|--dry-run] [-h|--help]
optional parameters:
  -h,--help          show this message and exit
  -d,--database      set database file path
  -c,--config-dir    set configuration files directory path
                     (script directory by default)
  -n,--dry-run       don't actually do anything intrusive
MSG
    exit "${exit_with_usage:-0}"
}

parse_script_options() {
    while [ "$#" -gt 0 ]; do
        local key="$1"
        shift

        case "$key" in
            -h|--help)
                exit_with_usage=0
                break
                ;;

            -n|--dry-run)
                dry_run=1
                continue
                ;;

            -d|--database|-c|--config-dir)
                ;;

            *)
                dump "usage error: unrecognized parameter: $key" >&2
                exit_with_usage=1
                break
                ;;
        esac

        if [ "$#" -eq 0 ]; then
            dump "usage error: missing argument for parameter: $key" >&2
            exit_with_usage=1
            break
        fi

        local value="$1"
        shift

        case "$key" in
            -d|--database)
                update_database_path "$value"
                ;;

            -c|--config-dir)
                update_config_dir "$value"
                ;;

            *)
                dump "usage error: unrecognized parameter: $key" >&2
                exit_with_usage=1
                break
                ;;
        esac
    done
}

main() {
    parse_script_options "$@"
    [ -n "${exit_with_usage+x}" ] && exit_with_usage
    check_symlinks_enabled
    ensure_database_exists
    read_database
    delete_obsolete_entries
    discover_new_entries
    write_database
}

main "$@"
