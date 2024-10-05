#!/bin/bash

cd "$(dirname "$0")"

check_name() {
    if [[ $TERMUX_APP_PACKAGE =~ '_' ]] || \
       [[ $TERMUX_APP_PACKAGE =~ '-' ]] || \
       [[ $TERMUX_APP_PACKAGE == package ]] || \
       [[ $TERMUX_APP_PACKAGE == package.* ]] || \
       [[ $TERMUX_APP_PACKAGE == *.package ]] || \
       [[ $TERMUX_APP_PACKAGE == *.package.* ]] || \
       [[ $TERMUX_APP_PACKAGE == in ]] || \
       [[ $TERMUX_APP_PACKAGE == in.* ]] || \
       [[ $TERMUX_APP_PACKAGE == *.in ]] || \
       [[ $TERMUX_APP_PACKAGE == *.in.* ]] || \
       [[ $TERMUX_APP_PACKAGE == is ]] || \
       [[ $TERMUX_APP_PACKAGE == is.* ]] || \
       [[ $TERMUX_APP_PACKAGE == *.is ]] || \
       [[ $TERMUX_APP_PACKAGE == *.is.* ]] || \
       [[ $TERMUX_APP_PACKAGE == as ]] || \
       [[ $TERMUX_APP_PACKAGE == as.* ]] || \
       [[ $TERMUX_APP_PACKAGE == *.as ]] || \
       [[ $TERMUX_APP_PACKAGE == *.as.* ]]
    then
        echo "package name must not contain certain strings and must not contain underscore, dash, or possibly other characters!"
        exit 2
    fi
}

download() {
    # Version originally tested
    # PLAY_STORE_TERMUX_PACKAGES_GIT_HASH=a41fd427b94dda5724edf9e1e1f5278fc6e7453e
    # PLAY_STORE_TERMUX_APPS_GIT_HASH=63dd74e8c5c2bbb8ee28d82e7eb0874902786849
    # PLAY_STORE_TERMUX_PACKAGES_SHA256SUM=0e5045009ac752ed30a137ffc522090880583e8ca4c969e51db7b62809701e9c
    # PLAY_STORE_TERMUX_APPS_SHA256SUM=760a0ebc90746d244e73dd5e635e0900d5b855f72e284837fdfb9f5e67bc498e

    # wget -nc https://github.com/termux-play-store/termux-apps/archive/$PLAY_STORE_TERMUX_APPS_GIT_HASH.zip || exit 3
    # wget -nc https://github.com/termux-play-store/termux-packages/archive/$PLAY_STORE_TERMUX_PACKAGES_GIT_HASH.zip || exit 4

    # echo "$PLAY_STORE_TERMUX_PACKAGES_SHA256SUM $PLAY_STORE_TERMUX_PACKAGES_GIT_HASH.zip" | sha256sum --check --status || exit 5
    # echo "$PLAY_STORE_TERMUX_APPS_SHA256SUM $PLAY_STORE_TERMUX_APPS_GIT_HASH.zip" | sha256sum --check --status || exit 6

    wget -nc https://github.com/termux-play-store/termux-apps/archive/main.zip -O termux-apps.zip || exit 3
    wget -nc https://github.com/termux-play-store/termux-packages/archive/main.zip -O termux-packages.zip || exit 4

    unzip "*.zip" || exit 7
}

patch_bootstraps() {
    local BOOTSTRAP_PATCHES=$(find $(pwd)/bootstrap-patches/ -type f | sort)
    pushd termux-packages-* || exit 8
    for patch in $BOOTSTRAP_PATCHES
    do
        patch -p1 < "$patch" || exit 9
    done
    sed -i "s/TERMUX_APP_PACKAGE=\"com.termux\"/TERMUX_APP_PACKAGE=\"$TERMUX_APP_PACKAGE\"/g" scripts/properties.sh || exit 10
    popd
}

build_bootstraps() {
    pushd termux-packages-* || exit 8

    if [ -z "${ADDITIONAL_PACKAGES}" ]
    then
        scripts/run-docker.sh scripts/generate-bootstraps.sh --build || exit 11
    else
        scripts/run-docker.sh scripts/generate-bootstraps.sh --build --add "${ADDITIONAL_PACKAGES}" || exit 11
    fi

    popd
}

copy_bootstraps() {
    pushd termux-apps-* || exit 8
    mkdir -p termux-app/src/main/assets/
    cp ../termux-packages-*/bootstrap-*.zip termux-app/src/main/assets/ || exit 12
    popd
}

migrate_termux_folder() {
    PARENT_DIR="$(dirname "$(dirname "$1")")"
    TERMUX_APP_PACKAGE=$2
    DESTINATION="${PARENT_DIR}"/$(echo "$TERMUX_APP_PACKAGE" | tr . /)/
    echo "migrate_termux_folder: renaming ${PARENT_DIR}/com/termux/ to ${DESTINATION}"
    mkdir -p "${DESTINATION}"
    mv "${PARENT_DIR}"/com/termux/* "${DESTINATION}"
    rm -r "${PARENT_DIR}"/com/termux/
}
export -f migrate_termux_folder

patch_app() {
    local APP_PATCHES=$(find $(pwd)/app-patches/ -type f | sort)
    pushd termux-apps-* || exit 13
    for patch in $APP_PATCHES
    do
        patch -p1 < "$patch" || exit 9
    done

    TERMUX_APP_PACKAGE_UNDERSCORE=$(echo "$TERMUX_APP_PACKAGE" | tr . _)
    find . -type f -exec sed -i -e "s/>Termux</>$TERMUX_APP_PACKAGE</g" \
                                -e "s/\"Termux\"/\"$TERMUX_APP_PACKAGE\"/g" \
                                -e "s/com\.termux/$TERMUX_APP_PACKAGE/g" \
                                -e "s/com_termux/$TERMUX_APP_PACKAGE_UNDERSCORE/g" {} \;

    find $(pwd) -type d -name termux -exec bash -c 'migrate_termux_folder "$0" $(echo $TERMUX_APP_PACKAGE)' {} \; 2>/dev/null

    popd
}

build_app() {
    pushd termux-apps-* || exit 13

    ./gradlew assembleDebug || exit 15

    popd
}

copy_app() {
    cp termux-apps-*/termux-app/build/outputs/apk/debug/*.apk "$TERMUX_APP_PACKAGE".apk
}

show_usage() {
	echo
	echo "Usage: build-termux.sh [options]"
	echo
	echo "Generate Termux application."
	echo
	echo "Options:"
	echo
	echo " -h, --help                  Show this help."
	echo
	echo " -a, --add PKG_LIST          Specify one or more additional packages"
	echo "                             to include into bootstrap archive."
	echo "                             Multiple packages should be passed as"
	echo "                             comma-separated list."
	echo
	echo " -n, --name APP_NAME         Specify TERMUX_APP_PACKAGE"
	echo "                             app package name to patch the entire"
	echo "                             Termux source code with."
	echo
	echo " -d, --dirty                 Attempt building without first deleting"
	echo "                             artifacts from previous builds."
	echo
}

while (($# > 0))
do
	case "$1" in
		-d|--dirty)
			DO_NOT_CLEAN=1
            shift 1
			;;
		-h|--help)
			show_usage
			exit 0
			;;
		-a|--add)
			if [ $# -gt 1 ] && [ -n "$2" ] && [[ $2 != -* ]]
            then
                export ADDITIONAL_PACKAGES="$2"
				shift 1
			else
				echo "[!] Option '--add' requires an argument."
				show_usage
				exit 1
			fi
			;;
		-n|--name)
			if [ $# -gt 1 ] && [ -n "$2" ] && [[ $2 != -* ]]
            then
				export TERMUX_APP_PACKAGE="$2"
				shift 1
			else
				echo "[!] Option '--name' requires an argument."
				show_usage
				exit 1
			fi
			;;
		*)
			echo "[!] Got unknown option '$1'"
			show_usage
			exit 1
			;;
	esac
	shift 1
done

if [ ! -z "${TERMUX_APP_PACKAGE}" ]
then
    check_name
fi

if [ -z "${DO_NOT_CLEAN}" ]
then
    ./clean.sh
fi

download

if [ ! -z "${TERMUX_APP_PACKAGE}" ]
then
    patch_bootstraps
fi

build_bootstraps

copy_bootstraps

if [ ! -z "${TERMUX_APP_PACKAGE}" ]
then
    patch_app
fi

build_app

copy_app