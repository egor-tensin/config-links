test_run() {
    # Check that if a user adds a file to a destination directory, it's not
    # deleted by links-remove.

    test_setup
    test_run_update

    # User adds his own file to the directory:
    echo 'User content' > "$test_dest_dir/bar/my-file"

    test_run_remove

    # bar/ and bar/my-file must be kept:
    local expected_output="$test_dest_dir->
$test_dest_dir/bar->
$test_dest_dir/bar/my-file->"

    test_verify_output "$expected_output"
}
