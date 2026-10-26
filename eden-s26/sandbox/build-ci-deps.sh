#!/bin/bash
# Rebuild Eden's prebuilt Android CI packages (crueter-ci/*) locally and drop
# them into Eden's CPM source cache, keyed exactly like the official artifacts.
set -euo pipefail

CI_ROOT=/home/user/work/ci
CACHE=/home/user/work/eden/.cache/cpm
export ANDROID_NDK_ROOT=/home/user/android-sdk/ndk/28.2.13676358
export PLATFORM=android ARCH=aarch64
export PATH=/home/user/android-sdk/cmake/3.31.5/bin:$PATH

fetch_src() { # repo commit dir
    rm -rf "$3"
    mkdir -p "$3"
    git -C "$3" init -q
    git -C "$3" fetch -q --depth 1 "https://github.com/$1" "$2"
    git -C "$3" checkout -q FETCH_HEAD
}

install_pkg() { # lower_pkg version
    local dest="$CACHE/$1/$2-android-aarch64"
    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    cp -a out "$dest"
    printf none > "$dest/.cpm_patch_key"
    echo "-- installed $1 -> $dest"
}

build_one() { # name lower_pkg timestamp
    local name=$1 lower=$2 ts=$3
    cd "$CI_ROOT/$name"
    echo "$ts" > TIMESTAMP
    # shellcheck disable=SC1091
    . tools/vars.sh
    rm -rf out build artifacts && mkdir -p out
    fetch_src "$REPO" "$COMMIT" "$DIRECTORY"
    bash tools/configure.sh
    case "$name" in
        SDL3) cmake --build build -j4 ;;
        *) make -C "$DIRECTORY" -j4 ;;
    esac
    bash tools/package.sh
    install_pkg "$lower" "$VERSION"
}

build_one SDL3 sdl3 1788231389
build_one FFmpeg ffmpeg 1790726865
build_one OpenSSL openssl 1788234794
echo ALL_DEPS_OK
