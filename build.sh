#!/bin/sh
# Build GNU coreutils 8.32 natively on SCO OpenServer 5.0.7.
#
# Run this script ON the SCO machine, in a writable directory.
#
# Required:
#   GCC 3.4 or later. Set CC, or use GCC env var.
#   /usr/gnu/bin/{gmake,gtar}, /usr/bin/patch
#   bash (used as configure shell)
#   wget or curl
#
# Output: ./install/bin/g* — ~105 binaries with `g`-prefix to avoid
# colliding with SCO's stock /bin/* tools.

set -e

SCRIPT_DIR=`cd \`dirname "$0"\` && pwd`
VERSION=8.32
TARBALL=coreutils-${VERSION}.tar.gz
SRCDIR=coreutils-${VERSION}

if [ -n "$GCC" ]; then
    CC="$GCC"
fi
CC="${CC:-gcc}"
export CC

PATH=/usr/gnu/bin:/usr/ccs/bin:/usr/bin:/bin
export PATH

if [ ! -f "$TARBALL" ]; then
    echo "Fetching $TARBALL..."
    if which wget >/dev/null 2>&1; then
        wget --no-check-certificate "https://ftp.gnu.org/gnu/coreutils/coreutils-${VERSION}.tar.xz"
        # Older SCO has no xz; convert to gzip on the fly via xz on the build host
        # Or fetch the .tar.gz mirror if available.  This block expects gunzip-tar.
        if [ -f "coreutils-${VERSION}.tar.xz" ]; then
            echo "Got .tar.xz — needs xz on this box. Convert on a Linux box first."
            exit 1
        fi
    fi
    if [ ! -f "$TARBALL" ]; then
        echo "ERROR: drop $TARBALL next to this script." >&2
        echo "       Get coreutils-${VERSION}.tar.xz from gnu.org and convert: xz -d -c file.tar.xz | gzip > file.tar.gz" >&2
        exit 1
    fi
fi

if [ ! -d "$SRCDIR" ]; then
    echo "Unpacking $TARBALL..."
    /usr/bin/gunzip -c "$TARBALL" | /usr/bin/tar xf -
fi

cd "$SRCDIR"

if [ -f .sco_patched ]; then
    echo "SCO patches already applied — skipping."
else
    echo "Applying SCO compatibility patch..."
    /usr/bin/patch -p1 < "$SCRIPT_DIR/patches/coreutils-${VERSION}-sco.patch"
    cp "$SCRIPT_DIR/patches/pthread_stubs.c" lib/pthread_stubs.c
    touch .sco_patched
fi

# Need bash for the configure script — SCO's /bin/sh (which is /bin/ksh)
# is too slow on autoconf-generated configure.
SHELL_BIN=`which bash 2>/dev/null`
if [ -z "$SHELL_BIN" ]; then
    echo "ERROR: bash required as configure shell." >&2
    exit 1
fi

echo "Configuring..."
# --program-prefix=g — install as gls, gcp, gdu... so as not to shadow
#                     SCO's stock /bin/* utilities. Skunkware convention.
# --disable-acl --disable-xattr — neither is meaningful on SCO
FORCE_UNSAFE_CONFIGURE=1 CONFIG_SHELL=$SHELL_BIN $SHELL_BIN configure \
    --prefix="$SCRIPT_DIR/install" \
    --program-prefix=g \
    --disable-nls \
    --disable-acl \
    --disable-xattr \
    CC="$CC" \
    CFLAGS="-O2 -std=gnu99"

# The patch above modifies lib/unistd.in.h; configure regenerates
# lib/unistd.h FROM that template, so the patch carries through.

echo "Compiling..."
# Compile the pthread stubs into libcoreutils.a so sort can link
# (SCO has no real libpthread).
gmake -k 2>&1 || true   # -k: keep going past sort's pthread link error
echo "Linking pthread stubs into libcoreutils.a so sort can finish..."
$CC -O2 -c lib/pthread_stubs.c -o lib/pthread_stubs.o
/usr/ccs/bin/ar rs lib/libcoreutils.a lib/pthread_stubs.o
rm -f src/sort
gmake src/sort

echo "Installing to $SCRIPT_DIR/install/..."
gmake install

echo "Stripping..."
find "$SCRIPT_DIR/install" -type f -perm -u+x -exec strip {} \; 2>/dev/null

ls "$SCRIPT_DIR/install/bin/" | wc -l | xargs printf "Built %s g-prefixed binaries\n"
echo
echo "Test it:"
echo "  $SCRIPT_DIR/install/bin/gls --version"
echo "  $SCRIPT_DIR/install/bin/gdu -h /tmp"
echo "  $SCRIPT_DIR/install/bin/gsort -h <<< '1K\\n500\\n2M'"
echo
echo "To package: gtar czf coreutils-${VERSION}-sco.tar.gz install"
