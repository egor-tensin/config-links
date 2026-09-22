# Copyright (c) 2026 Egor Tensin <egor@tensin.name>
# This file is part of the "config-links" project.
# For details, see https://github.com/egor-tensin/config-links
# Distributed under the MIT License.

root_dir=

src_dir_name='src'
dest_dir_name='dest'
alt_dest_dir_name='alt_dest'

src_dir_path="$script_dir/dirs/$src_dir_name"
dest_dir_path="$script_dir/dirs/$dest_dir_name"

test_root_dir=
test_src_dir=
test_dest_dir=
test_alt_dest_dir=

new_test() {
    root_dir="$( git -C "$script_dir" rev-parse --show-toplevel )"

    test_root_dir="$( mktemp -d )"
    # mktemp returns /var/..., which is actually in /private/var/... on macOS.
    test_root_dir="$( readlink -e -- "$test_root_dir" )"

    test_src_dir="$test_root_dir/$src_dir_name"
    test_dest_dir="$test_root_dir/$dest_dir_name"
    test_alt_dest_dir="$test_root_dir/$alt_dest_dir_name"

    echo "Root directory: $test_root_dir"
    echo "Shared directory: $test_src_dir"
    echo "%DEST% directory: $test_dest_dir"
    echo "%ALT_DEST% directory: $test_alt_dest_dir"

    cp -r -- "$src_dir_path" "$test_src_dir"
    cp -r -- "$dest_dir_path" "$test_dest_dir"
    cp -r -- "$dest_dir_path" "$test_alt_dest_dir"
}

new_test_symlink() {
    new_test

    # Create a stupid symlink.
    ln -s -- 'bar/3.txt' "$test_src_dir/%DEST%/3_copy.txt"
}

new_test_dir_symlink() {
    new_test "${FUNCNAME[1]}"

    # Files will get symlinks in the directory pointed to by $DEST, as well as
    # by $ALT_DEST.
    ln -s -- '%DEST%' "$test_src_dir/%ALT_DEST%"
}

test_cleanup_default() {
    [ -n "$test_root_dir" ] && rm -rf -- "$test_root_dir"
}

call_bin_script() {
    echo
    echo -n 'Executing script:'

    printf -- ' %q' "$@" --shared-dir "$test_src_dir" --database "$test_root_dir/links.bin"
    printf -- '\n'

    echo
    DEST="$test_dest_dir" ALT_DEST="$test_alt_dest_dir" "$@" --shared-dir "$test_src_dir" --database "$test_root_dir/links.bin"
}

call_update() {
    call_bin_script "$root_dir/bin/links-update" "$@"
}

call_remove() {
    call_bin_script "$root_dir/bin/links-remove"
}

call_chmod() {
    call_bin_script "$root_dir/bin/links-chmod" "$@"
}

verify_output() {
    if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        echo "usage: ${FUNCNAME[0]} EXPECTED_OUTPUT [DEST_DIR]" >&2
        return 1
    fi

    local expected_output="$1"
    echo
    echo 'Expected directory structure:'
    echo "$expected_output"

    local dest_dir="$test_dest_dir"
    [ "$#" -ge 2 ] && dest_dir="$2"

    local actual_output
    actual_output="$( find "$dest_dir" -printf '%h/%f->%l\n' | sort )"
    echo
    echo 'Actual directory structure:'
    echo "$actual_output"
    echo

    if [ "$actual_output" = "$expected_output" ]; then
        echo "... They match!"
    else
        echo "... The actual directory structure does not match the expected directory structure!" >&2
        return 1
    fi
}

verify_mode() {
    if [ "$#" -ne 2 ]; then
        echo "usage: ${FUNCNAME[0]} EXPECTED_MODE FILE" >&2
        return 1
    fi

    local expected_mode="$1"
    local path="$2"

    echo
    echo "Checking permissions for file: $path"
    echo "Expected mode: $expected_mode"

    local actual_mode
    actual_mode="$( stat -c '%a' -- "$path" )"
    actual_mode="0$actual_mode"

    echo "Actual mode: $actual_mode"

    if [ "$actual_mode" = "$expected_mode" ]; then
        echo "... They match!"
    else
        echo "... They don't match."
        return 1
    fi
}
