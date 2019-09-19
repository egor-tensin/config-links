Configuration file sharing
==========================

[![Travis (.com) branch](https://img.shields.io/travis/com/egor-tensin/config-links/master?label=Travis)](https://travis-ci.com/egor-tensin/config-links)

A simple tool to help share (configuration) files across multiple machines.
Actual files are stored in directories with names roughly matching the `%.+%`
pattern.
The part between the percent signs is the name of an environment variable.
Every file in such a directory gets a symlink in the directory pointed to by
the environment variable.
Directory hierarchies are preserved.

A database of symlinks is maintained in case a shared file is deleted (the
corresponding symlink is then deleted too).
The default database file name is "links.bin", maintained in the top-level
directory with shared files.

This description is obviously confusing; see the complete usage example below.

Usage
-----

Symlinks are managed by `bin/update.sh`.

```
usage: update.sh [-h|--help] [-d|--database PATH] [-s|--shared-dir DIR] [-n|--dry-run]
```

Pass the `--help` flag to this script to examine its detailed usage
information.

A complete usage example is given below.
In this example, the symlinks to files in "../src" must appear in
"/test/dest".

```
> pwd
/cygdrive/d/workspace/personal/config-links/bin

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

> ./update.sh --shared-dir ../src/
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
