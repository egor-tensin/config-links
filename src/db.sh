# Copyright (c) 2016 Egor Tensin <Egor.Tensin@gmail.com>
# This file is part of the "Configuration file sharing" project.
# For details, see https://github.com/egor-tensin/config-links.
# Distributed under the MIT License.

# Shared directory settings

shared_root_dir="$( pwd )/"

update_shared_dir() {
    if [ "$#" -ne 1 ]; then
        echo "usage: ${FUNCNAME[0]} DIR" >&2
        return 1
    fi

    local new_shared_dir
    new_shared_dir="$( traverse_path --exist --directory -- "$1" )"

    [ "$new_shared_dir" = / ] || new_shared_dir="$new_shared_dir/"

    [ "$db_path" = "$shared_root_dir$default_db_name" ] \
        && db_path="$new_shared_dir$default_db_name"

    shared_root_dir="$new_shared_dir"
}

# Database maintenance

readonly default_db_name='links.bin'
db_path="$shared_root_dir$default_db_name"
declare -A database=()
declare -A shared_paths=()
declare -A symlink_paths=()

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

add_entry() {
    local entry
    for entry; do
        dump "entry: $entry"

        local var_name
        var_name="$( extract_variable_name "$entry" )"
        cache_variable "$var_name"

        local shared_var_dir="$shared_root_dir%$var_name%"
        local symlink_var_dir
        symlink_var_dir="$( resolve_variable "$var_name" )"
        local subpath="${entry#%$var_name%/}"

        local shared_path="$shared_var_dir"
        [ "$shared_var_dir" != / ] && shared_path="$shared_path/"
        shared_path="$shared_path$subpath"
        shared_path="$( traverse_path -- "$shared_path" )"

        local symlink_path="$symlink_var_dir"
        [ "$symlink_var_dir" != / ] && symlink_path="$symlink_path/"
        symlink_path="$symlink_path$subpath"

        dump "    shared file path: $shared_path"
        dump "    symlink path: $symlink_path"

        database[$entry]="$var_name"
        shared_paths[$entry]="$shared_path"
        symlink_paths[$entry]="$symlink_path"
    done
}

remove_entry() {
    local entry
    for entry; do
        unset -v 'database[$entry]'
        unset -v 'shared_paths[$entry]'
        unset -v 'symlink_paths[$entry]'
    done
}

read_database() {
    [ ! -r "$db_path" ] && return 0

    local entry
    while IFS= read -d '' -r entry; do
        add_entry "$entry"
    done < "$db_path"
}

write_database() {
    is_dry_run && return 0

    [ "${#database[@]}" -eq 0 ] && rm -f -- "$db_path" && return 0

    > "$db_path"

    local entry
    for entry in "${!database[@]}"; do
        printf -- '%s\0' "$entry" >> "$db_path"
    done
}

link_entry() {
    local entry
    for entry; do
        local shared_path="${shared_paths[$entry]}"
        local symlink_path="${symlink_paths[$entry]}"

        local symlink_dir
        symlink_dir="$( dirname -- "$symlink_path" )"
        mkdir -p -- "$symlink_dir"
        ln -f -s --no-target-directory -- "$shared_path" "$symlink_path"
    done
}

delete_obsolete_dirs() {
    if [ "$#" -ne 2 ]; then
        echo "usage: ${FUNCNAME[0]} BASE_DIR DIR" >&2
        return 1
    fi

    local base_dir="$1"
    local dir="$2"

    base_dir="$( traverse_path --exist --directory -- "$base_dir" )"
    dir="$( traverse_path --exist --directory -- "$dir" )"

    [ "$base_dir" = "$dir" ] && return 0

    local subpath="${dir##$base_dir/}"

    if [ "$subpath" = "$dir" ]; then
        dump "base directory: $base_dir"    >&2
        dump "... is not a parent of: $dir" >&2
        return 1
    fi

    ( cd -- "$base_dir/" && rmdir -p --ignore-fail-on-non-empty -- "$subpath" )
}

unlink_entry() {
    local entry
    for entry; do
        local shared_path="${shared_paths[$entry]}"
        local symlink_path="${symlink_paths[$entry]}"

        rm -f -- "$symlink_path"

        local symlink_dir
        symlink_dir="$( dirname -- "$symlink_path" )"
        local var_name="${database[$entry]}"
        local symlink_var_dir
        symlink_var_dir="$( resolve_variable "$var_name" )"
        delete_obsolete_dirs "$symlink_var_dir" "$symlink_dir" || true
    done
}

symlink_present() {
    local entry
    for entry; do
        local symlink_path="${symlink_paths[$entry]}"
        test -L "$symlink_path" -o -e "$symlink_path"
    done
}

symlink_points_to_shared_file() {
    symlink_present "$@"
    local entry
    for entry; do
        local shared_path="${shared_paths[$entry]}"
        local symlink_path="${symlink_paths[$entry]}"
        local target_path
        target_path="$( traverse_path -- "$symlink_path" )"
        test "$target_path" = "$shared_path"
    done
}

shared_file_present() {
    local entry
    for entry; do
        local shared_path="${shared_paths[$entry]}"
        test -L "$shared_path" -o -e "$shared_path"
    done
}

link_all_entries() {
    local shared_var_dir
    while IFS= read -d '' -r shared_var_dir; do
        dump "shared directory: $shared_root_dir$shared_var_dir"

        local shared_path
        while IFS= read -d '' -r shared_path; do
            dump "    shared file path: $shared_path"
            local entry="${shared_path:${#shared_root_dir}}"
            add_entry "$entry" > /dev/null
            dump "    symlink path: ${symlink_paths[$entry]}"

            if symlink_present "$entry"; then
                if symlink_points_to_shared_file "$entry"; then
                    dump '    ... up-to-date'
                else
                    dump "    ... not a symlink or doesn't point to the shared file, adding a symlink"
                    is_dry_run || link_entry "$entry"
                fi
            else
                dump '    ... adding a symlink'
                is_dry_run || link_entry "$entry"
            fi

        done < <( find "$shared_root_dir$shared_var_dir/" -type f -print0 )
    done < <( find "$shared_root_dir" -regextype posix-basic -mindepth 1 -maxdepth 1 -\( -type d -o -type l -\) -regex ".*/$var_name_regex\$" -printf '%P\0' )
}

unlink_all_entries() {
    local entry
    for entry in "${!database[@]}"; do
        dump "entry: $entry"
        local shared_path="${shared_paths[$entry]}"
        local symlink_path="${symlink_paths[$entry]}"
        dump "    shared file path: $shared_path"
        dump "    symlink path: $symlink_path"

        if symlink_points_to_shared_file "$entry"; then
            dump '    ... removing the symlink'
            is_dry_run || unlink_entry "$entry"
            remove_entry "$entry"
        else
            dump "    ... not a symlink or doesn't point to the shared file"
            remove_entry "$entry"
        fi
    done
}

unlink_obsolete_entries() {
    local entry
    for entry in "${!database[@]}"; do
        dump "entry: $entry"
        local shared_path="${shared_paths[$entry]}"
        local symlink_path="${symlink_paths[$entry]}"
        dump "    shared file path: $shared_path"
        dump "    symlink path: $symlink_path"

        if symlink_points_to_shared_file "$entry"; then
            if shared_file_present "$entry"; then
                dump '    ... up-to-date'
            else
                dump '    ... obsolete'
                is_dry_run || unlink_entry "$entry"
                remove_entry "$entry"
            fi
        else
            dump "    ... not a symlink or doesn't point to the shared file"
            remove_entry "$entry"
        fi
    done
}
