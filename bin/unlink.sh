#!/usr/bin/env bash

# Copyright (c) 2019 Egor Tensin <Egor.Tensin@gmail.com>
# This file is part of the "Configuration file sharing" project.
# For details, see https://github.com/egor-tensin/config-links.
# Distributed under the MIT License.

# usage: ./unlink.sh [-h|--help] [-d|--database PATH] [-s|--shared-dir DIR] [-n|--dry-run]

set -o errexit
set -o nounset
set -o pipefail

script_name="$( basename -- "${BASH_SOURCE[0]}" )"
readonly script_name
script_dir="$( dirname -- "${BASH_SOURCE[0]}" )"
script_dir="$( cd -- "$script_dir" && pwd )"
readonly script_dir
src_dir="$( cd -- "$script_dir/../src" && pwd )"
readonly src_dir

. "$src_dir/common.sh"
. "$src_dir/os.sh"
. "$src_dir/path.sh"
. "$src_dir/vars.sh"
. "$src_dir/db.sh"

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
                set_dry_run
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

main() {
    parse_script_options "$@"
    read_database
    unlink_all_entries
    write_database
}

main "$@"