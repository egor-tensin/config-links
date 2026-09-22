test_run() {
    # Test that links-remove works for directory symlinks inside --shared-dir.

    new_test_dir_symlink
    call_update
    call_remove

    local expected_output="$test_dest_dir->"
    verify_output "$expected_output"

    expected_output="$test_alt_dest_dir->"
    verify_output "$expected_output" "$test_alt_dest_dir"
}
