#!/usr/bin/env bash
# Builds the Galaxy S26 aPS3e APK: upstream aenu1/aps3e main4 (v2.43) plus the patches in ../patches.
#
# Needs: JDK 17+, Gradle 8.10+ on PATH (or set GRADLE), git, and an Android SDK (ANDROID_HOME) with
#   platforms;android-35  build-tools;35.0.0  ndk;30.0.16248370  cmake;3.31.5
# A cold build takes about an hour on 4 cores and needs ~15 GB of disk (the source tree alone is 5 GB).
#
# Optional release signing (otherwise the debug key is used):
#   APS3E_KEYSTORE=/path/key.jks APS3E_KEYSTORE_PASS=... APS3E_KEY_ALIAS=... APS3E_KEY_PASS=...
set -euo pipefail

UPSTREAM_URL=https://github.com/aenu1/aps3e.git
UPSTREAM_COMMIT=c6ca18217f2f1563235f83d94df78e35423a1720 # main4, "2.43"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="${1:-$here/work}"
: "${ANDROID_HOME:?set ANDROID_HOME to your Android SDK}"
gradle="${GRADLE:-gradle}"

if [ ! -d "$work/aps3e/.git" ]; then
	mkdir -p "$work"
	git clone --filter=blob:none --no-checkout "$UPSTREAM_URL" "$work/aps3e"
fi

cd "$work/aps3e"
git fetch --filter=blob:none origin "$UPSTREAM_COMMIT"
git checkout -B s26 "$UPSTREAM_COMMIT"
git -c user.name=build -c user.email=build@localhost am --3way "$here"/patches/*.patch

echo "sdk.dir=$ANDROID_HOME" > local.properties
"$gradle" --no-daemon assembleRelease

apk=app/build/outputs/apk/release/app-release.apk
echo "Built: $work/aps3e/$apk"
