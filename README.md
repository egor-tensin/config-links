Configuration file sharing
==========================

[![Test](https://github.com/egor-tensin/config-links/actions/workflows/test.yml/badge.svg)](https://github.com/egor-tensin/config-links/actions/workflows/test.yml)

* Store your files in a repository.
* Checkout it on any machine.
* Create and maintain symlinks to these files easily.

How it works
------------

Actual files are stored in directories with names matching the `%VAR_NAME%`
pattern.
The part between the percent signs is the name of an environment variable.
Every file in such directory gets a symlink in the directory pointed to by the
environment variable.
Directory hierarchies are preserved.

A database of symlinks is maintained in case a shared file is deleted (the
corresponding symlink is then deleted too).
The default database file name is "links.bin", maintained in the top-level
directory with shared files.

This description is obviously confusing; see the complete usage example below.

Usage
-----

Symlinks are managed by `links-update`.

```
usage: links-update [-h|--help] [-d|--database PATH] [-s|--shared-dir DIR] [-n|--dry-run]
```

Pass the `--help` flag to this script to examine its detailed usage
information.

A complete usage example is given below.
In this example, the symlinks to files in "../src" must appear in
"/test/dest".

```
> tree /test/dest/
/test/dest/

0 directories, 0 files

> tree ../src/
../src/
└── %DEST%
    ├── a
    │   └── b
    │       └── c
    │           └── test.txt
    └── foo
        └── bar
            └── baz

6 directories, 2 files

> echo "$DEST"
/test/dest

> ./links-update --shared-dir ../src/
...

> tree /test/dest/
/test/dest/
├── a
│   └── b
│       └── c
│           └── test.txt -> /cygdrive/d/workspace/personal/src/%DEST%/a/b/c/test.txt
└── foo
    └── bar
        └── baz -> /cygdrive/d/workspace/personal/src/%DEST%/foo/bar/baz

5 directories, 2 files
```

For more realistic usage examples, see

* my [Linux/Cygwin environment],
* configuration files for various [Windows apps].

[Linux/Cygwin environment]: https://github.com/egor-tensin/linux-home
[Windows apps]: https://github.com/egor-tensin/windows-home

Limitations
-----------

Variable names must be alphanumeric.
More precisely, the corresponding directory names must match the
`^%[_[:alpha:]][_[:alnum:]]*%$` regular expression.
Consequently, `ProgramFiles(x86)` (and other weird variable names Windows
allows) are not supported.

A special variable name `CONFIG_LINKS_ROOT` is resolved to the root path, "/".

License
-------

Distributed under the MIT License.
See [LICENSE.txt] for details.

[LICENSE.txt]: LICENSE.txt
