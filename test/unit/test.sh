#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail
shopt -s inherit_errexit 2> /dev/null || true
shopt -s lastpipe

script_dir="$( dirname -- "${BASH_SOURCE[0]}" )"
script_dir="$( cd -- "$script_dir" && pwd )"
readonly script_dir
script_name="$( basename -- "${BASH_SOURCE[0]}" )"
readonly script_name

readonly src_dir_name='src'
readonly dest_dir_name='dest'
readonly alt_dest_dir_name='alt_dest'

src_dir_path="$script_dir/$src_dir_name"
readonly src_dir_path
dest_dir_path="$script_dir/$dest_dir_name"
readonly dest_dir_path

test_root_dir=
test_src_dir=
test_dest_dir=
test_alt_dest_dir=

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
    test_src_dir="$test_root_dir/$src_dir_name"
    test_dest_dir="$test_root_dir/$dest_dir_name"
    test_alt_dest_dir="$test_root_dir/$alt_dest_dir_name"

    echo "Root directory: $test_root_dir"
    echo "Shared directory: $test_src_dir"
    echo "%DEST% directory: $test_dest_dir"
    echo "%ALT_DEST% directory: $test_alt_dest_dir"
    echo ======================================================================

    cp -r -- "$src_dir_path" "$test_src_dir"
    cp -r -- "$dest_dir_path" "$test_dest_dir"
    cp -r -- "$dest_dir_path" "$test_alt_dest_dir"
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
    call_bin_script "$script_dir/../links-update" "$@"
}

call_remove() {
    call_bin_script "$script_dir/../links-remove"
}

call_chmod() {
    call_bin_script "$script_dir/../links-chmod" "$@"
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

test_update_works() {
    # Basic test to make sure that links-update actually creates the proper
    # symlinks.

    new_test
    call_update

    local expected_output="$test_dest_dir->
$test_dest_dir/1.txt->$test_src_dir/%DEST%/1.txt
$test_dest_dir/bar->
$test_dest_dir/bar/3.txt->$test_src_dir/%DEST%/bar/3.txt
$test_dest_dir/bar/baz->
$test_dest_dir/bar/baz/4.txt->$test_src_dir/%DEST%/bar/baz/4.txt
$test_dest_dir/foo->
$test_dest_dir/foo/2.txt->$test_src_dir/%DEST%/foo/2.txt"

    verify_output "$expected_output"
}

test_remove_works() {
    # Basic test to make sure links-remove actually removes the created
    # symlinks.

    new_test
    call_update
    call_remove

    local expected_output="$test_dest_dir->"
    verify_output "$expected_output"
}

test_remove_does_not_overwrite_files() {
    # Check that if a user overwrites a symlink with his own file, links-remove
    # keeps it.

    new_test
    call_update

    # Simulate a user overwriting one of the symlinks with his own file.
    rm -- "$test_dest_dir/bar/3.txt"
    echo 'User content' > "$test_dest_dir/bar/3.txt"

    call_remove

    # 3.txt must be kept:
    local expected_output="$test_dest_dir->
$test_dest_dir/bar->
$test_dest_dir/bar/3.txt->"

    verify_output "$expected_output"
}

test_remove_does_not_delete_used_dirs() {
    # Check that if a user adds a file to a destination directory, it's not
    # deleted by links-remove.

    new_test
    call_update

    # User adds his own file to the directory:
    echo 'User content' > "$test_dest_dir/bar/my-file"

    call_remove

    # bar/ and bar/my-file must be kept:
    local expected_output="$test_dest_dir->
$test_dest_dir/bar->
$test_dest_dir/bar/my-file->"

    verify_output "$expected_output"
}

new_test_dir_symlink() {
    new_test "${FUNCNAME[1]}"

    # Files will get symlinks in the directory pointed to by $DEST, as well as
    # by $ALT_DEST.
    ln -s -- '%DEST%' "$test_src_dir/%ALT_DEST%"
}

test_dir_symlink_update_works() {
    # We can symlink files to multiple directories by creating symlinks inside
    # --shared-dir.

    new_test_dir_symlink
    call_update

    local expected_output="$test_dest_dir->
$test_dest_dir/1.txt->$test_src_dir/%DEST%/1.txt
$test_dest_dir/bar->
$test_dest_dir/bar/3.txt->$test_src_dir/%DEST%/bar/3.txt
$test_dest_dir/bar/baz->
$test_dest_dir/bar/baz/4.txt->$test_src_dir/%DEST%/bar/baz/4.txt
$test_dest_dir/foo->
$test_dest_dir/foo/2.txt->$test_src_dir/%DEST%/foo/2.txt"

    verify_output "$expected_output"

    expected_output="$test_alt_dest_dir->
$test_alt_dest_dir/1.txt->$test_src_dir/%ALT_DEST%/1.txt
$test_alt_dest_dir/bar->
$test_alt_dest_dir/bar/3.txt->$test_src_dir/%ALT_DEST%/bar/3.txt
$test_alt_dest_dir/bar/baz->
$test_alt_dest_dir/bar/baz/4.txt->$test_src_dir/%ALT_DEST%/bar/baz/4.txt
$test_alt_dest_dir/foo->
$test_alt_dest_dir/foo/2.txt->$test_src_dir/%ALT_DEST%/foo/2.txt"

    verify_output "$expected_output" "$test_alt_dest_dir"
}

test_dir_symlink_remove_works() {
    # Test that links-remove works for directory symlinks inside --shared-dir.

    new_test_dir_symlink
    call_update
    call_remove

    local expected_output="$test_dest_dir->"
    verify_output "$expected_output"

    expected_output="$test_alt_dest_dir->"
    verify_output "$expected_output" "$test_alt_dest_dir"
}

test_dir_symlink_remove_shared_file() {
    # If we remove a shared file, both of the symlinks should be removed.

    new_test_dir_symlink
    call_update

    # Remove a random shared file:
    rm -- "$test_src_dir/%DEST%/bar/3.txt"
    call_update

    local expected_output="$test_dest_dir->
$test_dest_dir/1.txt->$test_src_dir/%DEST%/1.txt
$test_dest_dir/bar->
$test_dest_dir/bar/baz->
$test_dest_dir/bar/baz/4.txt->$test_src_dir/%DEST%/bar/baz/4.txt
$test_dest_dir/foo->
$test_dest_dir/foo/2.txt->$test_src_dir/%DEST%/foo/2.txt"

    verify_output "$expected_output"

    expected_output="$test_alt_dest_dir->
$test_alt_dest_dir/1.txt->$test_src_dir/%ALT_DEST%/1.txt
$test_alt_dest_dir/bar->
$test_alt_dest_dir/bar/baz->
$test_alt_dest_dir/bar/baz/4.txt->$test_src_dir/%ALT_DEST%/bar/baz/4.txt
$test_alt_dest_dir/foo->
$test_alt_dest_dir/foo/2.txt->$test_src_dir/%ALT_DEST%/foo/2.txt"

    verify_output "$expected_output" "$test_alt_dest_dir"
}

test_dir_symlink_remove_dir_symlink() {
    # If we remove a directory symlink in --shared-dir, all the symlinks
    # accessible through this directory symlink should be removed.

    new_test_dir_symlink
    call_update

    # Remove the directory symlink:
    rm -- "$test_src_dir/%ALT_DEST%"
    call_update

    local expected_output="$test_dest_dir->
$test_dest_dir/1.txt->$test_src_dir/%DEST%/1.txt
$test_dest_dir/bar->
$test_dest_dir/bar/3.txt->$test_src_dir/%DEST%/bar/3.txt
$test_dest_dir/bar/baz->
$test_dest_dir/bar/baz/4.txt->$test_src_dir/%DEST%/bar/baz/4.txt
$test_dest_dir/foo->
$test_dest_dir/foo/2.txt->$test_src_dir/%DEST%/foo/2.txt"

    verify_output "$expected_output"

    expected_output="$test_alt_dest_dir->"
    verify_output "$expected_output" "$test_alt_dest_dir"
}

new_test_symlink() {
    new_test "${FUNCNAME[1]}"

    # Create a stupid symlink.
    ln -s -- 'bar/3.txt' "$test_src_dir/%DEST%/3_copy.txt"
}

test_symlink_update_works() {
    # Shared files can also be symlinks, pointing to something else.

    new_test_symlink
    call_update

    local expected_output="$test_dest_dir->
$test_dest_dir/1.txt->$test_src_dir/%DEST%/1.txt
$test_dest_dir/3_copy.txt->$test_src_dir/%DEST%/3_copy.txt
$test_dest_dir/bar->
$test_dest_dir/bar/3.txt->$test_src_dir/%DEST%/bar/3.txt
$test_dest_dir/bar/baz->
$test_dest_dir/bar/baz/4.txt->$test_src_dir/%DEST%/bar/baz/4.txt
$test_dest_dir/foo->
$test_dest_dir/foo/2.txt->$test_src_dir/%DEST%/foo/2.txt"

    verify_output "$expected_output"

    echo
    echo 'Verifying 3_copy.txt (the symlink) is valid...'

    local copy_target
    copy_target="$( readlink -- "$test_dest_dir/3_copy.txt" )"
    test "$copy_target" = "$test_src_dir/%DEST%/3_copy.txt"

    local copy_content
    copy_content="$( cat -- "$test_dest_dir/3_copy.txt" )"
    test "$copy_content" = '3'
}

test_symlink_remove_works() {
    # Verify that links-remove doesn't delete shared symlinks.

    new_test_symlink
    call_update
    call_remove

    local expected_output="$test_dest_dir->"
    verify_output "$expected_output"

    echo
    echo 'Verifying 3_copy.txt (the shared file) is valid...'

    local copy_target
    copy_target="$( readlink -e -- "$test_src_dir/%DEST%/3_copy.txt" )"
    test "$copy_target" = "$test_src_dir/%DEST%/bar/3.txt"

    local copy_content
    copy_content="$( cat -- "$test_src_dir/%DEST%/3_copy.txt" )"
    test "$copy_content" = '3'
}

test_chmod_works() {
    # Test that links-chmod works.

    new_test
    call_update

    local expected_output="$test_dest_dir->
$test_dest_dir/1.txt->$test_src_dir/%DEST%/1.txt
$test_dest_dir/bar->
$test_dest_dir/bar/3.txt->$test_src_dir/%DEST%/bar/3.txt
$test_dest_dir/bar/baz->
$test_dest_dir/bar/baz/4.txt->$test_src_dir/%DEST%/bar/baz/4.txt
$test_dest_dir/foo->
$test_dest_dir/foo/2.txt->$test_src_dir/%DEST%/foo/2.txt"
    verify_output "$expected_output"

    echo
    echo 'Verifying 1.txt (the shared file) permissions...'

    verify_mode 0644 "$test_src_dir/%DEST%/1.txt"
    call_chmod 0600
    verify_mode 0600 "$test_src_dir/%DEST%/1.txt"
}

test_update_chmod() {
    # Test that links-update --mode works.

    new_test
    local expected_mode='0622'
    call_update --mode "$expected_mode"

    local expected_output="$test_dest_dir->
$test_dest_dir/1.txt->$test_src_dir/%DEST%/1.txt
$test_dest_dir/bar->
$test_dest_dir/bar/3.txt->$test_src_dir/%DEST%/bar/3.txt
$test_dest_dir/bar/baz->
$test_dest_dir/bar/baz/4.txt->$test_src_dir/%DEST%/bar/baz/4.txt
$test_dest_dir/foo->
$test_dest_dir/foo/2.txt->$test_src_dir/%DEST%/foo/2.txt"
    verify_output "$expected_output"

    verify_mode "$expected_mode" "$test_src_dir/%DEST%/1.txt"
}

main() {
    test_update_works
    test_remove_works
    test_remove_does_not_overwrite_files
    test_remove_does_not_delete_used_dirs

    test_dir_symlink_update_works
    test_dir_symlink_remove_works
    test_dir_symlink_remove_shared_file
    test_dir_symlink_remove_dir_symlink

    test_symlink_update_works
    test_symlink_remove_works

    test_chmod_works
    test_update_chmod
}

main
