test_run() {
    # Test that links-chmod works.

    test_setup
    test_run_update

    local expected_output="$test_dest_dir->
$test_dest_dir/1.txt->$test_src_dir/%DEST%/1.txt
$test_dest_dir/bar->
$test_dest_dir/bar/3.txt->$test_src_dir/%DEST%/bar/3.txt
$test_dest_dir/bar/baz->
$test_dest_dir/bar/baz/4.txt->$test_src_dir/%DEST%/bar/baz/4.txt
$test_dest_dir/foo->
$test_dest_dir/foo/2.txt->$test_src_dir/%DEST%/foo/2.txt"
    test_verify_output "$expected_output"

    echo
    echo 'Verifying 1.txt (the shared file) permissions...'

    test_verify_mode 0644 "$test_src_dir/%DEST%/1.txt"
    test_run_chmod 0600
    test_verify_mode 0600 "$test_src_dir/%DEST%/1.txt"
}
