test_run() {
    # Check that if a user overwrites a symlink with his own file, links-remove
    # keeps it.

    test_setup
    test_run_update

    # Simulate a user overwriting one of the symlinks with his own file.
    rm -- "$test_dest_dir/bar/3.txt"
    echo 'User content' > "$test_dest_dir/bar/3.txt"

    test_run_remove

    # 3.txt must be kept:
    local expected_output="$test_dest_dir->
$test_dest_dir/bar->
$test_dest_dir/bar/3.txt->"

    test_verify_output "$expected_output"
}
