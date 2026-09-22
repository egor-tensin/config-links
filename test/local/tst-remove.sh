test_run() {
    # Basic test to make sure links-remove actually removes the created
    # symlinks.

    new_test
    call_update
    call_remove

    local expected_output="$test_dest_dir->"
    verify_output "$expected_output"
}
