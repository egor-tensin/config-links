test_run() {
    # Check that if a user overwrites a symlink with his own file, links-remove
    # keeps it.

    new_test
    call_update

    # Simulate a user overwriting one of the symlinks with his own file.
    rm -- "$test_dest_dir/bar/3.txt"
    echo 'User content' > "$test_dest_dir/bar/3.txt"

    call_remove

    # 3.txt must be kept:
    local expected_output="$test_dest_dir->
$test_dest_dir/bar->
$test_dest_dir/bar/3.txt->"

    verify_output "$expected_output"
}
