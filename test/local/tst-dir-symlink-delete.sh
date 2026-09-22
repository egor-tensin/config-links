test_run() {
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
