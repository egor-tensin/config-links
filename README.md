Config file sharing
===================

[![CI](https://github.com/egor-tensin/config-links/actions/workflows/ci.yml/badge.svg)](https://github.com/egor-tensin/config-links/actions/workflows/ci.yml)
[![Packages (Debian)](https://github.com/egor-tensin/config-links/actions/workflows/debian.yml/badge.svg)](https://github.com/egor-tensin/config-links/actions/workflows/debian.yml)
[![Publish (Launchpad)](https://github.com/egor-tensin/config-links/actions/workflows/ppa.yml/badge.svg)](https://github.com/egor-tensin/config-links/actions/workflows/ppa.yml)

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

For a complete usage example, see below.

Installation
------------

* For Arch Linux, use the [AUR package].
* For Ubuntu, use the [PPA].
* Alternatively, just checkout this repository.
* For macOS, see [this section].

[AUR package]: https://aur.archlinux.org/packages/config-links/
[PPA]: https://launchpad.net/~egor-tensin/+archive/ubuntu/config-links
[this section]: #macos

Usage
-----

Symlinks are created & maintained by `links-update`.

```
usage: links-update [-h|--help] [-d|--database PATH] [-s|--shared-dir DIR] [-m|--mode MODE] [-n|--dry-run]
```

To remove all symlinks, use `links-remove`.

```
usage: links-remove [-h|--help] [-d|--database PATH] [-s|--shared-dir DIR] [-n|--dry-run]
```

In this example, symlinks to files in "../src" must appear in "/test/dest".

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

For my personal real-life usage examples, see

* [my dotfiles],
* configuration files for various [Windows apps].

[my dotfiles]: https://github.com/egor-tensin/linux-home
[Windows apps]: https://github.com/egor-tensin/windows-home

Limitations
-----------

Variable names must be alphanumeric.
More precisely, the corresponding directory names must match the
`^%[_[:alpha:]][_[:alnum:]]*%$` regular expression.
Consequently, `ProgramFiles(x86)` (and other weird variable names Windows
allows) are not supported.

A special variable name `CONFIG_LINKS_ROOT` is resolved to the root path, "/".

macOS
-----

macOS is supported on a basic level.
GNU coreutils and findutils are required, which you can install using Homebrew.
Don't forget to add them to PATH!

License
-------

Distributed under the MIT License.
See [LICENSE.txt] for details.

[LICENSE.txt]: LICENSE.txt
