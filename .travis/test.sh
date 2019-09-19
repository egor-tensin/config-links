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
    echo 'New test'

    test_root_dir="$( mktemp --directory )"
    test_src_dir="$test_root_dir/$sample_src_dir_name"
    test_dest_dir="$test_root_dir/$sample_dest_dir_name"

    echo "Root directory: $test_root_dir"
    echo "Shared directory: $test_src_dir"
    echo "%DEST% directory: $test_dest_dir"

    cp -r -- "$sample_src_dir_path" "$test_src_dir"
    cp -r -- "$sample_dest_dir_path" "$test_dest_dir"
}

verify_output() {
    if [ "$#" -ne 1 ]; then
        echo "usage: ${FUNCNAME[0]} EXPECTED_OUTPUT" >&2
        return 1
    fi

    local expected_output="$1"
    echo 'Expected directory structure:'
    echo "$expected_output"

    actual_output="$( find "$test_dest_dir" -printf '%h/%f->%l\n' )"
    echo 'Actual directory structure:'
    echo "$actual_output"

    if [ "$actual_output" != "$expected_output" ]; then
        echo "The actual directory structure does not match the expected directory structure!" >&2
        return 1
    fi
}

test_update_works() {
    new_test

    cd -- "$test_root_dir"
    DEST="$test_dest_dir" "$script_dir/../bin/update.sh" --shared-dir "$test_src_dir"

    expected_output="$test_dest_dir->
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

    expected_output="$test_dest_dir->"

    verify_output "$expected_output"
}

test_unlink_does_not_overwrite_files() {
    new_test

    cd -- "$test_root_dir"
    DEST="$test_dest_dir" "$script_dir/../bin/update.sh" --shared-dir "$test_src_dir"
    rm -- "$test_dest_dir/bar/3.txt"
    echo '+3' > "$test_dest_dir/bar/3.txt"
    DEST="$test_dest_dir" "$script_dir/../bin/unlink.sh" --shared-dir "$test_src_dir"

    expected_output="$test_dest_dir->
$test_dest_dir/bar->
$test_dest_dir/bar/3.txt->"

    verify_output "$expected_output"
}

main() {
    test_update_works
    test_unlink_works
    test_unlink_does_not_overwrite_files
}

main
