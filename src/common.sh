# Copyright (c) 2016 Egor Tensin <Egor.Tensin@gmail.com>
# This file is part of the "Config file sharing" project.
# For details, see https://github.com/egor-tensin/config-links.
# Distributed under the MIT License.

dump() {
    local prefix="${FUNCNAME[0]}"
    [ "${#FUNCNAME[@]}" -gt 1 ] && prefix="${FUNCNAME[1]}"

    local msg
    for msg; do
        echo "$prefix: $msg"
    done
}

set_dry_run() {
    dry_run=1
}

is_dry_run() {
    test -n "${dry_run+x}"
}
