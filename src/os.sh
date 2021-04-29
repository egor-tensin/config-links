# Copyright (c) 2016 Egor Tensin <Egor.Tensin@gmail.com>
# This file is part of the "Config file sharing" project.
# For details, see https://github.com/egor-tensin/config-links.
# Distributed under the MIT License.

# Mostly Cygwin-related stuff

os="$( uname -o )"
readonly os

is_cygwin() {
    test "$os" == 'Cygwin'
}

check_symlinks_enabled_cygwin() {
    case "${CYGWIN-}" in
        *winsymlinks:nativestrict*) ;;
        *winsymlinks:native*)       ;;

        *)
            dump "native Windows symlinks aren't enabled in Cygwin" >&2
            return 1
            ;;
    esac
}

check_symlinks_enabled() {
    if is_cygwin; then
        check_symlinks_enabled_cygwin
    else
        return 0
    fi
}
