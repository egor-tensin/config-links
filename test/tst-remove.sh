test_run() {
    # Basic test to make sure links-remove actually removes the created
    # symlinks.

    test_setup
    test_run_update
    test_run_remove

    local expected_output="$test_dest_dir->"
    test_verify_output "$test_dest_dir" "$expected_output"
}
