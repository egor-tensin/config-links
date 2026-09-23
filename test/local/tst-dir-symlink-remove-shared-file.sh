test_run() {
    # If we remove a shared file, both of the symlinks should be removed.

    test_setup_dir_symlink
    test_run_update

    # Remove a random shared file:
    rm -- "$test_src_dir/%DEST%/bar/3.txt"
    test_run_update

    local expected_output="$test_dest_dir->
$test_dest_dir/1.txt->$test_src_dir/%DEST%/1.txt
$test_dest_dir/bar->
$test_dest_dir/bar/baz->
$test_dest_dir/bar/baz/4.txt->$test_src_dir/%DEST%/bar/baz/4.txt
$test_dest_dir/foo->
$test_dest_dir/foo/2.txt->$test_src_dir/%DEST%/foo/2.txt"

    test_verify_output "$test_dest_dir" "$expected_output"

    expected_output="$test_alt_dest_dir->
$test_alt_dest_dir/1.txt->$test_src_dir/%ALT_DEST%/1.txt
$test_alt_dest_dir/bar->
$test_alt_dest_dir/bar/baz->
$test_alt_dest_dir/bar/baz/4.txt->$test_src_dir/%ALT_DEST%/bar/baz/4.txt
$test_alt_dest_dir/foo->
$test_alt_dest_dir/foo/2.txt->$test_src_dir/%ALT_DEST%/foo/2.txt"

    test_verify_output "$test_alt_dest_dir" "$expected_output"
}
