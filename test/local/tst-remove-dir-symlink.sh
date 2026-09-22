test_run() {
    # Test that links-remove works for directory symlinks inside --shared-dir.

    test_setup_dir_symlink
    test_run_update
    test_run_remove

    local expected_output="$test_dest_dir->"
    test_verify_output "$expected_output"

    expected_output="$test_alt_dest_dir->"
    test_verify_output "$expected_output" "$test_alt_dest_dir"
}
