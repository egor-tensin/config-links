Windows configuration files
=========================== 

An easy and ad-hoc way to store & sync various configuration files across
Windows installations.
Actual configuration files are stored in this repository in directories which
names must roughly match the `%.+%` regular expression.
The part between the percent signs is the name of an environment variable.
Its value replaces the path of this directory, making for the path of a symlink
which would point to a file in this repository.

A database of symlinks is maintained in case a file is removed from this
repository (the corresponding symlink is then deleted).
Default database file name is "db.bin".

Usage
-----

To update the symlinks, run `./update.sh`.
Requires Cygwin.

For example, here's a possible representation of the "%PROGRAMDATA%" directory:

    %PROGRAMDATA%/
    └── a
        └── b
            └── c
                └── test.txt

Running the script above would create a symlink at
"C:\ProgramData\a\b\c\test.txt" pointing "%PROGRAMDATA%\a\b\c\test.txt" in this
repository.

Limitations
-----------

Only alphanumeric variable names are supported.
Speaking more precisely, directory names must match the
`^%[_[:alpha:]][_[:alnum:]]+%$` regular expression.
This means that, for example, the environment variable `ProgramFiles(x86)` is
not supported.

License
-------

Distributed under the MIT License.
See [LICENSE.txt] for details.

[LICENSE.txt]: LICENSE.txt
