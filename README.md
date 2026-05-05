# GNU coreutils 8.32 for SCO OpenServer 5

A working build of [GNU coreutils 8.32](https://www.gnu.org/software/coreutils/)
(March 2020) for **SCO OpenServer 5.0.7**. Binaries install with a `g`
prefix so they don't shadow SCO's stock tools — `gls`, `gcp`, `gdu`, etc.

```
$ gls --version
ls (GNU coreutils) 8.32

$ gdu -h /tmp        # human-readable sizes that SCO's du can't do
$ gsort -h           # sort with -K/-M/-G suffixes
$ gsort -V           # version sort: 1.2 1.10 1.20 (not 1.10 1.2 1.20)
```

105 utilities total. Headline wins over SCO's stock tools:

- `gls --color=auto`, `gls -h`, `gls --time-style`
- `gdu -h`, `gdf -h` (human-readable sizes)
- `gsort -h` (human numeric), `gsort -V` (version)
- `gtail -F` (follow-renamed), `ghead -c N` (first N bytes)
- `gsha256sum`, `gsha512sum` with `-c` verify mode
- `gtimeout 10s some-cmd` (run with deadline)
- `grealpath`, `gtruncate`, `gnumfmt`-style features
- All the long options (`--recursive`, `--exclude`, `--reverse`, …)
- Consistent error messages and `--help` text

## Install

> **Fresh SCO box?** Install [curl with TLS](https://github.com/tachytelic/curl-7.88.1-for-SCO-OpenServer-5)
> first — that's the only file that needs to be transferred via `scp`.
> After that, every release on tachytelic/* (including this one) fetches
> over HTTPS from GitHub.

The release tarball is ~3.5 MB. Fetch and extract on the SCO box:

```sh
# On the SCO box (assumes curl-with-TLS is on PATH — see curl-sco):
curl -LO https://github.com/tachytelic/Coreutils-8.32-for-SCO-OpenServer-5/releases/download/v1.0.0/coreutils-8.32-sco.tar.gz
gtar xzf coreutils-8.32-sco.tar.gz
mv install /usr/local/coreutils-8.32
```

To use:

```sh
# Direct path
/usr/local/coreutils-8.32/bin/gls -lh

# Or add to PATH for the session
export PATH=/usr/local/coreutils-8.32/bin:$PATH
gls --color=auto -lh

# Or alias common ones in ~/.bashrc to use them by default
alias ls='gls --color=auto'
alias ll='gls -lh --color=auto'
alias du='gdu -h'
alias df='gdf -h'
```

The g-prefix install path is the Skunkware convention — SCO's stock
`/bin/ls`, `/bin/cp`, etc. stay intact (boot scripts and SCO's `custom`
package management both depend on the exact behaviour of the originals),
and you opt into GNU semantics where you want them.

### Color support for `gls --color`

Combine with [Nano-2.9.8 for SCO's bundled `xterm-256color` terminfo](https://github.com/tachytelic/Nano-2.9.8-for-SCO-OpenServer-5#256-color-terminal-support)
and `gls --color=auto` produces full coloured directory listings the
same way Linux does:

```sh
TERM=xterm-256color
eval "$(gdircolors)"      # exports LS_COLORS
alias ls='gls --color=auto'
```

## What's included

105 binaries. The complete list of "g"-prefixed tools:

```
g[ gb2sum gbase32 gbase64 gbasename gbasenc gcat gchcon gchgrp gchmod
gchown gchroot gcksum gcomm gcp gcsplit gcut gdate gdd gdf gdir gdircolors
gdirname gdu gecho genv gexpand gexpr gfactor gfalse gfmt gfold ggroups
ghead ghostid gid ginstall gjoin gkill glink gln glogname gls gmd5sum
gmkdir gmkfifo gmknod gmktemp gmv gnice gnl gnohup gnproc gnumfmt god
gpaste gpathchk gpinky gpr gprintenv gprintf gptx gpwd greadlink grealpath
grm grmdir gruncon gseq gsha1sum gsha224sum gsha256sum gsha384sum
gsha512sum gshred gshuf gsleep gsort gsplit gstat gstdbuf gstty gsum
gsync gtac gtail gtee gtest gtimeout gtouch gtr gtrue gtruncate gtsort
gtty guname gunexpand guniq gunlink guptime gusers gvdir gwc gwhoami gyes
```

A few that build but aren't actually meaningful on SCO and are best
ignored: `gchcon`/`gruncon` (SELinux), `gpinky` (utmpx), `gnumfmt`
(newer features), `gstdbuf` (LD_PRELOAD-based — likely won't work).

## Building from source

This is a **native build** on SCO. Same pattern as the python/curl/lua
builds in this repo's siblings.

### Requirements

- **GCC 3.4 or later** somewhere on PATH (or `CC=`/`GCC=` env var).
- `/usr/gnu/bin/{gmake,gtar}`, `/usr/bin/patch`
- **bash** as the configure shell. SCO's `/bin/sh` is too slow on
  autoconf scripts.

### Build

```sh
cd coreutils-sco
./build.sh
```

Or with a non-default GCC:

```sh
GCC=/path/to/gcc-3.4 ./build.sh
```

The build script:

1. Fetches `coreutils-8.32.tar.gz` (you may need to convert the
   upstream `.tar.xz` once on a Linux box if SCO has no `xz`).
2. Applies `patches/coreutils-8.32-sco.patch`:
   - **`lib/unistd.in.h`** — skip gnulib's `gethostname` redeclaration
     (gnulib uses `size_t len`, SCO has `int len`; just defer to SCO's
     native).
   - **`lib/getprogname.c`** — replace the unconditional `#error` for
     unrecognised OSes with a `return "?";` fallback (same patch we used
     for tar 1.34).
   - **`lib/gethostname.c`** — match SCO's signature (`int len` instead
     of `size_t len`).
3. Drops `patches/pthread_stubs.c` into `lib/`.
4. Runs `configure` with `--program-prefix=g` and SCO-friendly flags.
5. Runs `gmake -k` (keep going past sort's pthread link error).
6. Compiles `lib/pthread_stubs.c` (no-op `pthread_cond_*` etc.) into
   `lib/libcoreutils.a` so `gsort` can finally link. The default sort
   path is single-threaded; `--parallel=N>1` would be a no-op (the
   pthread_create stub returns failure, so sort falls back to the
   single-threaded path).
7. Installs to `./install/`, strips.

### Why patches at all?

- gnulib targets POSIX.1-2008 / glibc; SCO 5.0.7 is POSIX.1-1990 vintage.
- The three diffs are surgical — gnulib's signature handling for systems
  where `gethostname` predates POSIX-2001, plus the OS-recognition
  fallback in `getprogname`. Total: 45-line patch.
- The pthread stub is what lets `gsort` link without a real pthread
  library. Six no-op functions, ~7 lines.

## Repository layout

```
patches/
  coreutils-8.32-sco.patch     45 lines, 3 hunks, lib-only
  pthread_stubs.c              7-line cond-var stubs

build.sh                       Native-build script (run on SCO)
LICENSE                        MIT (covers patch + build script;
                               coreutils itself is GPLv3)
README.md                      This file
```

The prebuilt 3.5 MB tarball ships via the
**[Releases](../../releases)** page, not via clone bloat.

## License

GNU coreutils is © Free Software Foundation, distributed under
[GPLv3+](https://www.gnu.org/licenses/gpl-3.0.html). The prebuilt
binaries are unmodified upstream coreutils 8.32 with the patches in
this repo applied.

The patches and build script in this repo are released under the MIT
license — see [LICENSE](LICENSE).

## See also

- [curl-7.88.1 for SCO](https://github.com/tachytelic/curl-7.88.1-for-SCO-OpenServer-5)
  — the natural first install on a fresh SCO box.
- [GNU bash 3.2.57 for SCO](https://github.com/tachytelic/Bash-3.2.57-for-SCO-OpenServer-5),
  [GNU tar 1.34 for SCO](https://github.com/tachytelic/Tar-1.34-for-SCO-OpenServer-5),
  [GNU nano 2.9.8 for SCO](https://github.com/tachytelic/Nano-2.9.8-for-SCO-OpenServer-5)
  — sibling builds.
- [More SCO OpenServer 5 binaries](https://tachytelic.net/2017/07/sco-openserver-5-binaries/)
  — the hub.
