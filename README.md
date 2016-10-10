Configuration file sharing
==========================

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

Symlinks are managed by `update.sh`.

```
usage: update.sh [-h|--help] [-d|--database PATH] [-s|--shared-dir DIR] [-n|--dry-run]
```

Pass the `--help` flag to this script to examine its detailed usage
information.

A complete usage example is given below.
In this example, the symlinks to files in "../cfg" must appear in "~/env".

```
> pwd
/cygdrive/d/workspace/personal/config-links

> tree ~/env/
/home/Egor/env

0 directories, 0 files

> tree ../cfg/
../cfg/
└── %ENV%
    ├── a
    │   └── b
    │       └── c
    │           └── test.txt
    └── foo
        └── bar
            └── baz

6 directories, 2 files

> echo "$ENV"
/home/Egor/env

> ./update.sh --shared-dir ../cfg/
...

> tree ~/env/
/home/Egor/env/
├── a
│   └── b
│       └── c
│           └── test.txt -> /cygdrive/d/workspace/personal/cfg/%ENV%/a/b/c/test.txt
└── foo
    └── bar
        └── baz -> /cygdrive/d/workspace/personal/cfg/%ENV%/foo/bar/baz

5 directories, 2 files
```

For more realistic usage examples, see

* my [Cygwin environment],
* configuration files for various [Windows apps].

[Cygwin environment]: https://github.com/egor-tensin/cygwin-home
[Windows apps]: https://github.com/egor-tensin/windows-home

Limitations
-----------

Variable names must be alphanumeric.
More precisely, the corresponding directory names must match the
`^%[_[:alpha:]][_[:alnum:]]*%$` regular expression.
Consequently, `ProgramFiles(x86)` (and other weird variable names Windows
allows) are not supported.

License
-------

Distributed under the MIT License.
See [LICENSE.txt] for details.

[LICENSE.txt]: LICENSE.txt
