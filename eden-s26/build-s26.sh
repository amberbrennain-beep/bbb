#!/bin/sh -e
# Rebuild "Eden S26" from upstream Eden plus the patches in ./patches.
#
# Needs: git, JDK 17+, Android SDK with NDK 30.0.16248370 and CMake 3.31.5
# (ANDROID_HOME set), glslangValidator, ninja, zstd.
#
#   ./build-s26.sh            -> APK ends up in $WORK/artifacts
#   WORK=/tmp/eden ./build-s26.sh

EDEN_REPO=https://git.eden-emu.dev/eden-emu/eden.git
EDEN_COMMIT=eb88a40a8eb0fe847281ea6913fcc7ff7daedcd2

HERE=$(cd "$(dirname "$0")" && pwd)
: "${WORK:=$PWD/eden-s26-src}"

if [ ! -d "$WORK/.git" ]; then
    git clone --filter=blob:none "$EDEN_REPO" "$WORK"
fi

cd "$WORK"
git fetch -q origin
git checkout -q -B s26 "$EDEN_COMMIT"
git -c user.name="Eden S26 build" -c user.email="eden-s26@localhost" \
    am -q --3way "$HERE"/patches/*.patch

# Profile recorded on a Galaxy S26; drop the argument to build without PGO
.ci/android/build.sh -t s26 -b Release -DYUZU_PGO_USE="$HERE/pgo/eden-s26.profdata" "$@"

echo "-- APK: $(ls "$WORK"/artifacts/*.apk)"
