#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

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

    echo
    echo "New test: $test_name"

    test_root_dir="$( mktemp --directory )"
    test_src_dir="$test_root_dir/$src_dir_name"
    test_dest_dir="$test_root_dir/$dest_dir_name"
    test_alt_dest_dir="$test_root_dir/$alt_dest_dir_name"

    echo "Root directory: $test_root_dir"
    echo "Shared directory: $test_src_dir"
    echo "%DEST% directory: $test_dest_dir"
    echo "%ALT_DEST% directory: $test_alt_dest_dir"
    echo

    cp -r -- "$src_dir_path" "$test_src_dir"
    cp -r -- "$dest_dir_path" "$test_dest_dir"
    cp -r -- "$dest_dir_path" "$test_alt_dest_dir"
}

verify_output() {
    if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        echo "usage: ${FUNCNAME[0]} EXPECTED_OUTPUT [DEST_DIR]" >&2
        return 1
    fi

    local expected_output="$1"
    echo 'Expected directory structure:'
    echo "$expected_output"

    local dest_dir="$test_dest_dir"
    [ "$#" -ge 2 ] && dest_dir="$2"

    actual_output="$( find "$dest_dir" -printf '%h/%f->%l\n' )"
    echo 'Actual directory structure:'
    echo "$actual_output"

    if [ "$actual_output" = "$expected_output" ]; then
        echo "They match!"
    else
        echo "The actual directory structure does not match the expected directory structure!" >&2
        return 1
    fi
}

test_update_works() {
    # Basic test to make sure update.sh actually creates the proper symlinks.

    new_test

    DEST="$test_dest_dir" "$script_dir/../bin/update.sh" --shared-dir "$test_src_dir"

    local expected_output="$test_dest_dir->
$test_dest_dir/1.txt->$test_src_dir/%DEST%/1.txt
$test_dest_dir/foo->
$test_dest_dir/foo/2.txt->$test_src_dir/%DEST%/foo/2.txt
$test_dest_dir/bar->
$test_dest_dir/bar/3.txt->$test_src_dir/%DEST%/bar/3.txt
$test_dest_dir/bar/baz->
$test_dest_dir/bar/baz/4.txt->$test_src_dir/%DEST%/bar/baz/4.txt"

    verify_output "$expected_output"
}

test_unlink_works() {
    # Basic test to make sure unlink.sh actually removes the created symlinks.

    new_test

    DEST="$test_dest_dir" "$script_dir/../bin/update.sh" --shared-dir "$test_src_dir"
    DEST="$test_dest_dir" "$script_dir/../bin/unlink.sh" --shared-dir "$test_src_dir"

    local expected_output="$test_dest_dir->"
    verify_output "$expected_output"
}

test_unlink_does_not_overwrite_files() {
    # Check that if a user overwrites a symlink with his own file, unlink.sh
    # keeps it.

    new_test

    DEST="$test_dest_dir" "$script_dir/../bin/update.sh" --shared-dir "$test_src_dir"

    # Simulate a user overwriting one of the symlinks with his own file.
    rm -- "$test_dest_dir/bar/3.txt"
    echo 'User content' > "$test_dest_dir/bar/3.txt"

    DEST="$test_dest_dir" "$script_dir/../bin/unlink.sh" --shared-dir "$test_src_dir"

    # 3.txt must be kept:
    local expected_output="$test_dest_dir->
$test_dest_dir/bar->
$test_dest_dir/bar/3.txt->"

    verify_output "$expected_output"
}

test_symlinks_update_works() {
    # We can symlink files to multiple directories by creating symlinks inside
    # --shared-dir.

    new_test

    # Files will get symlinks in the directory pointed to by $DEST, as well as
    # by $ALT_DEST.
    ln -s -- '%DEST%' "$test_src_dir/%ALT_DEST%"

    DEST="$test_dest_dir" ALT_DEST="$test_alt_dest_dir" "$script_dir/../bin/update.sh" --shared-dir "$test_src_dir"

    local expected_output

    expected_output="$test_dest_dir->
$test_dest_dir/1.txt->$test_src_dir/%DEST%/1.txt
$test_dest_dir/foo->
$test_dest_dir/foo/2.txt->$test_src_dir/%DEST%/foo/2.txt
$test_dest_dir/bar->
$test_dest_dir/bar/3.txt->$test_src_dir/%DEST%/bar/3.txt
$test_dest_dir/bar/baz->
$test_dest_dir/bar/baz/4.txt->$test_src_dir/%DEST%/bar/baz/4.txt"

    verify_output "$expected_output"

    expected_output="$test_alt_dest_dir->
$test_alt_dest_dir/1.txt->$test_src_dir/%ALT_DEST%/1.txt
$test_alt_dest_dir/foo->
$test_alt_dest_dir/foo/2.txt->$test_src_dir/%ALT_DEST%/foo/2.txt
$test_alt_dest_dir/bar->
$test_alt_dest_dir/bar/3.txt->$test_src_dir/%ALT_DEST%/bar/3.txt
$test_alt_dest_dir/bar/baz->
$test_alt_dest_dir/bar/baz/4.txt->$test_src_dir/%ALT_DEST%/bar/baz/4.txt"

    verify_output "$expected_output" "$test_alt_dest_dir"
}

test_symlinks_unlink_works() {
    # Test that unlink.sh works for symlinked directories inside --shared-dir.

    new_test

    # Files will get symlinks in the directory pointed to by $DEST, as well as
    # by $ALT_DEST.
    ln -s -- '%DEST%' "$test_src_dir/%ALT_DEST%"

    DEST="$test_dest_dir" ALT_DEST="$test_alt_dest_dir" "$script_dir/../bin/update.sh" --shared-dir "$test_src_dir"
    DEST="$test_dest_dir" ALT_DEST="$test_alt_dest_dir" "$script_dir/../bin/unlink.sh" --shared-dir "$test_src_dir"

    local expected_output

    expected_output="$test_dest_dir->"
    verify_output "$expected_output"

    expected_output="$test_alt_dest_dir->"
    verify_output "$expected_output" "$test_alt_dest_dir"
}

main() {
    test_update_works
    test_unlink_works
    test_unlink_does_not_overwrite_files
    test_symlinks_update_works
    test_symlinks_unlink_works
}

main
