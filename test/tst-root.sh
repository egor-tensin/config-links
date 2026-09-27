if [ -z "${CI+y}" ] || [ "$EUID" -ne 0 ]; then
    test_should_fail=y
fi

test_run() {
    if [ -z "${CI+y}" ]; then
        fail "Don't run this test locally, it'll mess up your /"
        return 1
    fi
    if [ "$EUID" -ne 0 ]; then
        fail "This test requires root privileges"
        return 1
    fi

    test_root_dir="$( mktemp -d )"
    # mktemp returns /var/..., which is actually in /private/var/... on macOS.
    test_root_dir="$( readlink -e -- "$test_root_dir" )"

    test_src_dir="$test_root_dir/src"

    mkdir -p -- "$test_src_dir/%CONFIG_LINKS_ROOT%/foo"
    mkdir /foo
    chmod 0777 /foo
    touch -- "$test_src_dir/%CONFIG_LINKS_ROOT%/foo/bar.txt"

    test_run_update

    log "Checking /foo/bar.txt..."

    local actual
    actual="$( readlink -e -- "/foo/bar.txt" )"

    local expected
    expected="$test_src_dir/%CONFIG_LINKS_ROOT%/foo/bar.txt"

    if [ "$actual" != "$expected" ]; then
        fail "There was a problem with symlink /foo/bar.txt:"
        fail_details "Expected target: $expected"
        fail_details "Actual target: $actual"
        return 1
    fi
}
