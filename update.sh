#!/usr/bin/env bash

# Copyright (c) 2016 Egor Tensin <Egor.Tensin@gmail.com>
# This file is part of the "Windows configuration files" project.
# For details, see https://github.com/egor-tensin/windows-home.
# Distributed under the MIT License.

# This relies on the availability of native symlinks.
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

set -o errexit
set -o nounset
set -o pipefail

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

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
 
ensure_symlinks_enabled() {
    case "${CYGWIN:-}" in
        *winsymlinks:native*)       ;;
        *winsymlinks:nativestrict*) ;;

        *)
            dump 'native Windows symbolic links aren'"'"'t enabled in Cygwin' >&2
            return 1
            ;;
    esac
}

database_path="$script_dir/db.bin"
declare -A database

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
    > "$database_path"

    local entry
    for entry in "${!database[@]}"; do
        printf '%s\0' "$entry" >> "$database_path"
    done
}

delete_obsolete_dirs() {
    if [ $# -ne 2 ]; then
        echo "usage: ${FUNCNAME[0]} BASE_DIR DIR"
        return 1
    fi

    local base_dir="$1"
    local dir="$2"

    base_dir="$( readlink -m "$base_dir" )"
    dir="$( readlink -m "$dir" )"

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

    ( cd "$base_dir" && rmdir -p "$subpath" --ignore-fail-on-non-empty )
}

delete_obsolete_entries() {
    local entry
    for entry in "${!database[@]}"; do
        dump "entry: $entry"

        local var_name
        var_name="$( expr "$entry" : '%\([_[:alpha:]][_[:alnum:]]*\)%/' )"

        if [ -z "$var_name" ]; then
            dump '    couldn'"'"'t extract variable name' >&2
            unset database["$entry"]
            continue
        fi

        if [ -z "${!var_name+x}" ]; then
            dump "    variable is not set: $var_name" >&2
            unset database["$entry"]
            continue
        fi

        local dest_var_dir
        dest_var_dir="$( readlink -m "$( cygpath "${!var_name}" )" )"
        local src_var_dir="$script_dir/%$var_name%"

        local subpath="${entry#%$var_name%/}"

        local dest_path="$dest_var_dir/$subpath"
        local src_path="$src_var_dir/$subpath"

        if [ ! -e "$dest_path" ]; then
            dump "    missing destination file: $dest_path" >&2
            unset database["$entry"]
            continue
        fi

        if [ ! -e "$src_path" ]; then
            dump "    missing source file: $src_path" >&2
            rm -f "$dest_path"
            unset database["$entry"]

            local dest_dir
            dest_dir="$( dirname "$dest_path" )"

            delete_obsolete_dirs "$dest_var_dir" "$dest_dir" || true
            continue
        fi

        if [ ! -L "$dest_path" ]; then
            dump "    not a symbolic link: $dest_path" >&2
            unset database["$entry"]
            continue
        fi

        local target_path
        target_path="$( readlink -e "$dest_path" )"

        if [ "$target_path" != "$src_path" ]; then
            dump "    points to a wrong file: $dest_path" >&2
            unset database["$entry"]
            continue
        fi

        dump '... points to the right file'
    done
}

discover_new_entries() {
    local src_var_dir
    while IFS= read -d '' -r src_var_dir; do
        dump "source directory: $src_var_dir"

        local var_name
        var_name="$( basename "$src_var_dir" )"
        var_name="$( expr "$var_name" : '%\([_[:alpha:]][_[:alnum:]]*\)%' )"
        dump "    variable name: $var_name"

        if [ -z "${!var_name+x}" ]; then
            dump "    variable is not set: $var_name" >&2
            continue
        fi

        local dest_var_dir
        dest_var_dir="$( readlink -m "$( cygpath "${!var_name}" )" )"
        dump "    destination directory: $dest_var_dir"

        local src_path
        while IFS= read -d '' -r src_path; do
            dump "        source file: $src_path"

            local entry="%$var_name%${src_path:${#src_var_dir}}"

            if [ -n "${database[$entry]+x}" ]; then
                dump '        ... points to the right file'
                continue
            fi

            local dest_path="$dest_var_dir${src_path:${#src_var_dir}}"
            dump "        destination file: $dest_path"

            mkdir -p "$( dirname "$dest_path" )"
            ln --force -s "$src_path" "$dest_path"

            database[$entry]=1
        done < <( find "$src_var_dir" -type f -print0 )

    done < <( find "$script_dir" -regextype posix-extended -mindepth 1 -maxdepth 1 -type d -regex '.*/%[_[:alpha:]][_[:alnum:]]*%$' -print0 )
}

main() {
    ensure_database_exists
    read_database
    delete_obsolete_entries
    ensure_symlinks_enabled
    discover_new_entries
    write_database
}

main
