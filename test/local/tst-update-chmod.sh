test_run() {
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
