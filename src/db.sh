# Copyright (c) 2016 Egor Tensin <Egor.Tensin@gmail.com>
# This file is part of the "Configuration file sharing" project.
# For details, see https://github.com/egor-tensin/config-links.
# Distributed under the MIT License.

# Shared directory settings

shared_dir="$( pwd )"

update_shared_dir() {
    if [ "$#" -ne 1 ]; then
        echo "usage: ${FUNCNAME[0]} DIR" >&2
        return 1
    fi

    local new_shared_dir
    new_shared_dir="$( traverse_path --exist --directory -- "$1" )"

    [ "$db_path" == "$shared_dir/$default_db_name" ] \
        && db_path="$new_shared_dir/$default_db_name"

    shared_dir="$new_shared_dir"
}

# Database maintenance

readonly default_db_name='links.bin'
db_path="$shared_dir/$default_db_name"
declare -A database

update_database_path() {
    if [ "$#" -ne 1 ]; then
        echo "usage: ${FUNCNAME[0]} PATH" >&2
        return 1
    fi

    db_path="$( traverse_path --file -- "$1" )"

    local db_dir
    db_dir="$( dirname -- "$db_path" )"
    mkdir -p -- "$db_dir"
}

ensure_database_exists() {
    [ -f "$db_path" ] || is_dry_run || > "$db_path"
}

read_database() {
    [ ! -f "$db_path" ] && is_dry_run && return 0

    local entry
    while IFS= read -d '' -r entry; do
        database[$entry]=1
    done < "$db_path"
}

write_database() {
    is_dry_run && return 0

    > "$db_path"

    local entry
    for entry in "${!database[@]}"; do
        printf -- '%s\0' "$entry" >> "$db_path"
    done
}

delete_obsolete_dirs() {
    if [ "$#" -ne 2 ]; then
        echo "usage: ${FUNCNAME[0]} BASE_DIR DIR" >&2
        return 1
    fi

    is_dry_run && return 0

    local base_dir="$1"
    local dir="$2"

    base_dir="$( traverse_path --exist --directory -- "$base_dir" )"
    dir="$( traverse_path --exist --directory -- "$dir" )"

    [ "$base_dir" == "$dir" ] && return 0

    local subpath="${dir##$base_dir/}"

    if [ "$subpath" == "$dir" ]; then
        dump "base directory: $base_dir"    >&2
        dump "... is not a parent of: $dir" >&2
        return 1
    fi

    ( cd -- "$base_dir/" && rmdir -p --ignore-fail-on-non-empty -- "$subpath" )
}

delete_obsolete_entries() {
    local entry
    for entry in "${!database[@]}"; do
        dump "entry: $entry"
        unset -v 'database[$entry]'

        local var_name
        var_name="$( extract_variable_name "$entry" )" || continue
        cache_variable "$var_name"

        local symlink_var_dir
        symlink_var_dir="$( resolve_variable "$var_name" )" || continue
        local shared_var_dir="$shared_dir/%$var_name%"
        local subpath="${entry#%$var_name%/}"
        local symlink_path="$symlink_var_dir/$subpath"
        local shared_path="$shared_var_dir/$subpath"

        dump "    shared file path: $shared_path"
        dump "    symlink path: $symlink_path"

        if [ ! -L "$shared_path" ] && [ ! -e "$shared_path" ]; then
            dump '    the shared file is missing, so going to delete the symlink'
            is_dry_run && continue

            if [ ! -L "$symlink_path" ]; then
                dump "    not a symlink or doesn't exist, so won't delete"
                continue
            fi

            local target_path
            target_path="$( traverse_path -- "$symlink_path" )"

            if [ "$shared_path" != "$target_path" ]; then
                dump "    doesn't point to the shared file, so won't delete"
                continue
            fi

            rm -f -- "$symlink_path"

            local symlink_dir
            symlink_dir="$( dirname -- "$symlink_path" )"
            delete_obsolete_dirs "$symlink_var_dir" "$symlink_dir" || true

            continue
        fi

        if [ ! -L "$symlink_path" ]; then
            dump "    not a symlink or doesn't exist"
            continue
        fi

        local target_path
        target_path="$( traverse_path -- "$symlink_path" )"

        if [ "$target_path" != "$shared_path" ]; then
            dump "    doesn't point to the shared file"
            continue
        fi

        dump '    ... points to the shared file'
        database[$entry]=1
    done
}

discover_new_entries() {
    local shared_var_dir
    while IFS= read -d '' -r shared_var_dir; do
        dump "shared directory: $shared_dir/$shared_var_dir"

        local var_name
        var_name="$( extract_variable_name "$shared_var_dir" )"
        cache_variable "$var_name"

        shared_var_dir="$shared_dir/$shared_var_dir"

        local symlink_var_dir
        symlink_var_dir="$( resolve_variable "$var_name" )" || continue
        dump "    symlinks directory: $symlink_var_dir"

        local shared_path
        while IFS= read -d '' -r shared_path; do
            dump "        shared file path: $shared_path"

            local entry="%$var_name%/${shared_path:${#shared_var_dir}}"

            if [ -n "${database[$entry]+x}" ]; then
                dump '        ... already has a symlink'
                continue
            fi

            local subpath="${shared_path:${#shared_var_dir}}"
            local symlink_path="$symlink_var_dir/$subpath"

            dump "        symlink path: $symlink_path"

            is_dry_run && continue

            local symlink_dir
            symlink_dir="$( dirname -- "$symlink_path" )"
            mkdir -p -- "$symlink_dir"
            ln -f -s --no-target-directory -- "$shared_path" "$symlink_path"

            database[$entry]=1
        done < <( find "$shared_var_dir" -type f -print0 )

    done < <( find "$shared_dir" -regextype posix-basic -mindepth 1 -maxdepth 1 -type d -regex ".*/$var_name_regex\$" -printf '%P/\0' )
}
