# Copyright (c) 2026 Egor Tensin <egor@tensin.name>
# This file is part of the "config-links" project.
# For details, see https://github.com/egor-tensin/config-links
# Distributed under the MIT License.

test_should_fail=

src_dir_name='src'
dest_dir_name='dest'
alt_dest_dir_name='alt_dest'

test_root_dir=
test_src_dir=
test_dest_dir=
test_alt_dest_dir=

test_setup() {
    test_root_dir="$( mktemp -d )"
    # mktemp returns /var/..., which is actually in /private/var/... on macOS.
    test_root_dir="$( readlink -e -- "$test_root_dir" )"

    test_src_dir="$test_root_dir/$src_dir_name"
    test_dest_dir="$test_root_dir/$dest_dir_name"
    test_alt_dest_dir="$test_root_dir/$alt_dest_dir_name"

    log "Root directory: $test_root_dir"
    log "Shared directory: $test_src_dir"
    log "%DEST% directory: $test_dest_dir"
    log "%ALT_DEST% directory: $test_alt_dest_dir"

    cp -r -- "$script_dir/data/$src_dir_name" "$test_src_dir"
    cp -r -- "$script_dir/data/$dest_dir_name" "$test_dest_dir"
    cp -r -- "$script_dir/data/$dest_dir_name" "$test_alt_dest_dir"
}

test_setup_symlink() {
    test_setup

    # Create a stupid symlink.
    ln -s -- 'bar/3.txt' "$test_src_dir/%DEST%/3_copy.txt"
}

test_setup_dir_symlink() {
    test_setup

    # Files will get symlinks in the directory pointed to by $DEST, as well as
    # by $ALT_DEST.
    ln -s -- '%DEST%' "$test_src_dir/%ALT_DEST%"
}

test_cleanup_default() {
    if [ -n "$test_root_dir" ]; then
        log "Removing test's root directory: $test_root_dir"
        rm -rf -- "$test_root_dir"
    fi
}

test_run_script() {
    local msg='Executing script:'
    msg="$msg$( printf -- ' %q' "$@" --shared-dir "$test_src_dir" --database "$test_root_dir/links.bin" )"
    log "$msg"

    DEST="$test_dest_dir" ALT_DEST="$test_alt_dest_dir" "$@" \
        --shared-dir "$test_src_dir" \
        --database "$test_root_dir/links.bin"
}

test_run_update() {
    test_run_script "$script_dir/../../bin/links-update" "$@"
}

test_run_remove() {
    test_run_script "$script_dir/../../bin/links-remove"
}

test_run_chmod() {
    test_run_script "$script_dir/../../bin/links-chmod" "$@"
}

test_verify_output() {
    if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        echo "usage: ${FUNCNAME[0]} DEST_DIR EXPECTED_OUTPUT" >&2
        return 1
    fi

    local dest_dir="$1"
    local expected_output="$2"

    log "Verifying directory structure in $dest_dir..."

    local actual_output
    actual_output="$( find "$dest_dir" -printf '%h/%f->%l\n' | sort )"

    if [ "$actual_output" != "$expected_output" ]; then
        fail "The actual files do not match the expected directory structure!"
        fail_details "Expected:\n$expected_output"
        fail_details "Actual:\n$actual_output"
        return 1
    fi
}

test_verify_mode() {
    if [ "$#" -ne 2 ]; then
        echo "usage: ${FUNCNAME[0]} PATH EXPECTED_MODE" >&2
        return 1
    fi

    local path="$1"
    local expected_mode="$2"

    log "Checking permissions for file: $path"

    local actual_mode
    actual_mode="$( stat -c '%a' -- "$path" )"
    actual_mode="0$actual_mode"

    if [ "$actual_mode" != "$expected_mode" ]; then
        fail "They don't match"
        fail_details "Expected: $expected_mode"
        fail_details "Actual: $actual_mode"
        return 1
    fi
}
