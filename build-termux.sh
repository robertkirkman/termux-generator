#!/bin/bash
if [ "$#" -ne 1 ]; then
    echo "usage: $0 [custom.package.name]"
fi

PLAY_STORE_TERMUX_PACKAGES_HASH=a41fd427b94dda5724edf9e1e1f5278fc6e7453e
PLAY_STORE_TERMUX_APPS_HASH=63dd74e8c5c2bbb8ee28d82e7eb0874902786849
PLAY_STORE_TERMUX_PACKAGES_ZIP_HASH=0e5045009ac752ed30a137ffc522090880583e8ca4c969e51db7b62809701e9c
PLAY_STORE_TERMUX_APPS_ZIP_HASH=760a0ebc90746d244e73dd5e635e0900d5b855f72e284837fdfb9f5e67bc498e

wget https://github.com/termux-play-store/termux-apps/archive/$PLAY_STORE_TERMUX_APPS_HASH.zip
wget https://github.com/termux-play-store/termux-packages/archive/$PLAY_STORE_TERMUX_PACKAGES_HASH.zip

echo "$PLAY_STORE_TERMUX_PACKAGES_ZIP_HASH $PLAY_STORE_TERMUX_PACKAGES_HASH.zip" | sha256sum --check --status
echo "$PLAY_STORE_TERMUX_APPS_ZIP_HASH $PLAY_STORE_TERMUX_APPS_HASH.zip" | sha256sum --check --status

unzip "*.zip"

git apply -d termux-packages-* termux-play-store-packages-name-change-helper.patch

sed -i 's/TERMUX_APP_PACKAGE="com.termux"/TERMUX_APP_PACKAGE="$1"/g' termux-packages-*/scripts/properties.sh

scripts/run-docker.sh scripts/build-bootstraps.sh