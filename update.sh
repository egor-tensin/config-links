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

config_dir="$script_dir"

update_config_dir() {
    if [ "$#" -ne 1 ]; then
        echo "usage: ${FUNCNAME[0]} DIR" || true
        return 1
    fi

    config_dir="$( readlink --canonicalize-existing "$1" )"

    if [ ! -d "$config_dir" ]; then
        dump "must be a directory: $config_dir" >&2
        return 1
    fi
}

ensure_symlinks_enabled() {
    case "${CYGWIN:-}" in
        *winsymlinks:native*)       ;;
        *winsymlinks:nativestrict*) ;;

        *)
            dump 'native Windows symlinks aren'"'"'t enabled in Cygwin' >&2
            return 1
            ;;
    esac
}

database_path="$config_dir/db.bin"
declare -A database

update_database_path() {
    if [ "$#" -ne 1 ]; then
        echo "usage: ${FUNCNAME[0]} PATH" || true
        return 1
    fi

    database_path="$( readlink --canonicalize "$1" )"

    if [ -e "$database_path" ] && [ ! -f "$database_path" ]; then
        dump "must be a regular file: $database_path" >&2
        return 1
    fi
}

ensure_database_exists() {
    [ -f "$database_path" ] || touch "$database_path"
}

read_database() {
    local entry
    while IFS= read -d '' -r entry; do
        database[$entry]=1
    done < "$database_path"
}

write_database() {
    if [ -n "${dry_run+x}" ]; then
        dump 'won'"'"'t write the database because it'"'"'s a dry run'
        return 0
    fi

    > "$database_path"

    local entry
    for entry in "${!database[@]}"; do
        printf '%s\0' "$entry" >> "$database_path"
    done
}

delete_obsolete_dirs() {
    if [ $# -ne 2 ]; then
        echo "usage: ${FUNCNAME[0]} BASE_DIR DIR" || true
        return 1
    fi

    local base_dir="$1"
    local dir="$2"

    base_dir="$( readlink --canonicalize-missing "$base_dir" )"
    dir="$( readlink --canonicalize-missing "$dir" )"

    if [ ! -d "$base_dir" ]; then
        dump "base directory doesn't exist: $base_dir" >&2
        return 1
    fi

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

delete_obsolete_entries() {
    local entry
    for entry in "${!database[@]}"; do
        dump "entry: $entry"

        local var_name
        var_name="$( expr "$entry" : '%\([_[:alpha:]][_[:alnum:]]*\)%/' )"

        if [ -z "$var_name" ]; then
            dump '    couldn'"'"'t extract variable name' >&2
            unset -v 'database[$entry]'
            continue
        fi

        if [ -z "${!var_name+x}" ]; then
            dump "    variable is not set: $var_name" >&2
            unset -v 'database[$entry]'
            continue
        fi

        local symlink_var_dir
        symlink_var_dir="$( readlink --canonicalize-missing "$( cygpath "${!var_name}" )" )"
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
        target_path="$( readlink --canonicalize-existing "$symlink_path" )"

        if [ "$target_path" != "$config_path" ]; then
            dump "    points to a wrong file: $symlink_path" >&2
            unset -v 'database[$entry]'
            continue
        fi

        dump '    ... points to the right file'
    done
}

var_name_regex='%\([_[:alpha:]][_[:alnum:]]*\)%'

discover_new_entries() {
    local config_var_dir
    while IFS= read -d '' -r config_var_dir; do
        dump "source directory: $config_var_dir"

        local var_name
        var_name="$( basename "$config_var_dir" )"
        var_name="$( expr "$var_name" : "$var_name_regex" )"
        dump "    variable name: $var_name"

        if [ -z "${!var_name+x}" ]; then
            dump "    variable is not set: $var_name" >&2
            continue
        fi

        local symlink_var_dir
        symlink_var_dir="$( readlink --canonicalize-missing "$( cygpath "${!var_name}" )" )"
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
    ensure_database_exists
    read_database
    delete_obsolete_entries
    ensure_symlinks_enabled
    discover_new_entries
    write_database
}

main "$@"
