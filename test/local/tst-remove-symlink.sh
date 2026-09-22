test_run() {
    # Verify that links-remove doesn't delete shared symlinks.

    new_test_symlink
    call_update
    call_remove

    local expected_output="$test_dest_dir->"
    verify_output "$expected_output"

    echo
    echo 'Verifying 3_copy.txt (the shared file) is valid...'

    local copy_target
    copy_target="$( readlink -e -- "$test_src_dir/%DEST%/3_copy.txt" )"
    test "$copy_target" = "$test_src_dir/%DEST%/bar/3.txt"

    local copy_content
    copy_content="$( cat -- "$test_src_dir/%DEST%/3_copy.txt" )"
    test "$copy_content" = '3'
}
