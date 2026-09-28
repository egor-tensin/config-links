_test_should_fail() {
    if [ -z "${CI+y}" ]; then
        fail "Don't run this test locally, it'll mess up your \$HOME"
        return 0
    fi
    if ! command -v git &> /dev/null; then
        fail "git isn't available, assuming running inside a pbuilder"
        return 0
    fi
    return 1
}

_test_should_fail 2> /dev/null && test_should_fail=y

test_run() {
    _test_should_fail && return 1

    readonly src_name=linux-home
    src_url="https://github.com/egor-tensin/$src_name.git"
    readonly src_url

    test_root_dir="$( mktemp -d )"
    # mktemp returns /var/..., which is actually in /private/var/... on macOS.
    test_root_dir="$( readlink -e -- "$test_root_dir" )"

    test_src_dir="$test_root_dir/$src_name"

    log "Cloning $src_url to $test_src_dir..."
    git clone -q -- "$src_url" "$test_src_dir"

    test_run_update
    # Again:
    test_run_update

    log "Checking a couple of well-known files..."
    local file
    for file in .gitconfig .ssh/config; do
        local actual
        actual="$( readlink -e -- "$HOME/$file" )"

        local expected
        expected="$test_src_dir/%HOME%/$file"

        if [ "$actual" != "$expected" ]; then
            fail "There was a problem with symlink $file:"
            fail_details "Expected target: $expected"
            fail_details "Actual target: $actual"
            return 1
        fi
    done
}
