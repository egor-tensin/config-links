#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail
shopt -s inherit_errexit 2> /dev/null || true
shopt -s lastpipe

script_dir="$( dirname -- "${BASH_SOURCE[0]}" )"
script_dir="$( cd -- "$script_dir" && pwd )"
readonly script_dir
script_name="$( basename -- "${BASH_SOURCE[0]}" )"
readonly script_name

root_dir="$( git -C "$script_dir" rev-parse --show-toplevel )"
readonly root_dir

src_name='linux-home'
readonly src_name
src_url="https://github.com/egor-tensin/$src_name.git"
readonly src_url

test_root_dir=
test_src_dir=

new_test() {
    local test_name=
    [ "${#FUNCNAME[@]}" -gt 1 ] && test_name="${FUNCNAME[1]}"
    [ "$#" -gt 0 ] && test_name="$1"

    echo
    echo ======================================================================
    echo "New test: $test_name"

    test_root_dir="$( mktemp -d )"
    # mktemp returns /var/..., which is actually in /private/var/... on macOS.
    test_root_dir="$( readlink -e -- "$test_root_dir" )"
    test_src_dir="$test_root_dir/$src_name"

    echo "Root directory: $test_root_dir"
    echo "Shared directory: $test_src_dir"
    echo ======================================================================

    git clone -q -- "$src_url" "$test_src_dir"
    cd -- "$test_src_dir"
}

call_bin_script() {
    echo
    echo -n 'Executing script:'

    printf -- ' %q' "$@" --shared-dir "$test_src_dir" --database "$test_root_dir/links.bin"
    printf -- '\n'

    echo
    "$@" --shared-dir "$test_src_dir" --database "$test_root_dir/links.bin"
}

call_update() {
    call_bin_script "$root_dir/links-update" "$@"
}

call_remove() {
    call_bin_script "$root_dir/links-remove"
}

call_chmod() {
    call_bin_script "$root_dir/links-chmod" "$@"
}

test_my_dotfiles_work() {
    new_test
    call_update
    # Again:
    call_update
}

show_env() {
    echo
    echo ======================================================================
    echo Environment
    echo ======================================================================

    bash --version
}

main() {
    show_env

    test_my_dotfiles_work
}

main
