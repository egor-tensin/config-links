test_run() {
    # Shared files can also be symlinks, pointing to something else.

    test_setup_symlink
    test_run_update

    local expected_output="$test_dest_dir->
$test_dest_dir/1.txt->$test_src_dir/%DEST%/1.txt
$test_dest_dir/3_copy.txt->$test_src_dir/%DEST%/3_copy.txt
$test_dest_dir/bar->
$test_dest_dir/bar/3.txt->$test_src_dir/%DEST%/bar/3.txt
$test_dest_dir/bar/baz->
$test_dest_dir/bar/baz/4.txt->$test_src_dir/%DEST%/bar/baz/4.txt
$test_dest_dir/foo->
$test_dest_dir/foo/2.txt->$test_src_dir/%DEST%/foo/2.txt"

    test_verify_output "$test_dest_dir" "$expected_output"

    log 'Verifying 3_copy.txt (the symlink) is valid...'

    local copy_target
    copy_target="$( readlink -- "$test_dest_dir/3_copy.txt" )"
    test "$copy_target" = "$test_src_dir/%DEST%/3_copy.txt"

    local copy_content
    copy_content="$( cat -- "$test_dest_dir/3_copy.txt" )"
    test "$copy_content" = '3'
}
