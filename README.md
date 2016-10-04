Windows configuration files
=========================== 

An easy way to store & sync various configuration files across Windows
installations.
Requires Cygwin.
Actual configuration files are stored in this repository in directories which
names must match the `^%[_[:alpha:]][_[:alnum:]]+%$` regular expression.
The part between the percent signs is the name of an environment variable.
Its value replaces the path of this directory, making for the path of a symlink
which would point to a file in this repository.

Usage
-----

```
usage: ./update.sh
```

For example, here's a possible representation of the "%PROGRAMDATA%" directory:

```
%PROGRAMDATA%/
└── a
    └── b
        └── c
            └── test.txt
```

Running the script above would create a symlink at
"C:\ProgramData\a\b\c\test.txt" pointing to this repository's
"%PROGRAMDATA%\a\b\c\test.txt".

Limitations
-----------

Only alphanumeric variable names are supported.
For example, the environment variable `ProgramFiles(x86)` is not supported.

License
-------

Distributed under the MIT License.
See [LICENSE.txt] for details.

[LICENSE.txt]: LICENSE.txt
