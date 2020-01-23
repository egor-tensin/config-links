#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

script_dir="$( dirname -- "${BASH_SOURCE[0]}" )"
script_dir="$( cd -- "$script_dir" && pwd )"
readonly script_dir
script_name="$( basename -- "${BASH_SOURCE[0]}" )"
readonly script_name

readonly sample_src_dir_name='sample-src'
readonly sample_dest_dir_name='sample-dest'

sample_src_dir_path="$script_dir/$sample_src_dir_name"
readonly sample_src_dir_path
sample_dest_dir_path="$script_dir/$sample_dest_dir_name"
readonly sample_dest_dir_path

test_root_dir=
test_src_dir=
test_dest_dir=

new_test() {
    echo
    echo 'New test'

    test_root_dir="$( mktemp --directory )"
    test_src_dir="$test_root_dir/$sample_src_dir_name"
    test_dest_dir="$test_root_dir/$sample_dest_dir_name"

    echo "Root directory: $test_root_dir"
    echo "Shared directory: $test_src_dir"
    echo "%DEST% directory: $test_dest_dir"
    echo

    cp -r -- "$sample_src_dir_path" "$test_src_dir"
    cp -r -- "$sample_dest_dir_path" "$test_dest_dir"
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
    new_test

    cd -- "$test_root_dir"
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
    new_test

    cd -- "$test_root_dir"
    DEST="$test_dest_dir" "$script_dir/../bin/update.sh" --shared-dir "$test_src_dir"
    DEST="$test_dest_dir" "$script_dir/../bin/unlink.sh" --shared-dir "$test_src_dir"

    local expected_output="$test_dest_dir->"

    verify_output "$expected_output"
}

test_unlink_does_not_overwrite_files() {
    new_test

    cd -- "$test_root_dir"
    DEST="$test_dest_dir" "$script_dir/../bin/update.sh" --shared-dir "$test_src_dir"
    rm -- "$test_dest_dir/bar/3.txt"
    echo '+3' > "$test_dest_dir/bar/3.txt"
    DEST="$test_dest_dir" "$script_dir/../bin/unlink.sh" --shared-dir "$test_src_dir"

    local expected_output="$test_dest_dir->
$test_dest_dir/bar->
$test_dest_dir/bar/3.txt->"

    verify_output "$expected_output"
}

test_shared_directory_symlinks_work() {
    new_test

    cd -- "$test_src_dir"
    ln -s -- '%DEST%' '%ALT_DEST%'
    mkdir -- "$test_dest_dir-alt"

    DEST="$test_dest_dir" ALT_DEST="$test_dest_dir-alt" "$script_dir/../bin/update.sh" --shared-dir "$test_src_dir"

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

    expected_output="$test_dest_dir-alt->
$test_dest_dir-alt/1.txt->$test_src_dir/%ALT_DEST%/1.txt
$test_dest_dir-alt/foo->
$test_dest_dir-alt/foo/2.txt->$test_src_dir/%ALT_DEST%/foo/2.txt
$test_dest_dir-alt/bar->
$test_dest_dir-alt/bar/3.txt->$test_src_dir/%ALT_DEST%/bar/3.txt
$test_dest_dir-alt/bar/baz->
$test_dest_dir-alt/bar/baz/4.txt->$test_src_dir/%ALT_DEST%/bar/baz/4.txt"

    verify_output "$expected_output" "$test_dest_dir-alt"
}

main() {
    test_update_works
    test_unlink_works
    test_unlink_does_not_overwrite_files
    test_shared_directory_symlinks_work
}

main
