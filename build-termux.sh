#!/bin/bash
# set -x
# Wechsel zum Verzeichnis, in dem das Skript liegt

# Anzeige der Hilfe
show_usage() {
    echo
    echo "Usage: build-termux.sh [options]"
    echo
    echo "Generate Termux application."
    echo
    echo "Options:"
    echo " -h, --help                  Show this help."
    echo " -a, --add PKG_LIST          Include additional packages in bootstrap archive."
    echo " -n, --name APP_NAME         Specify TERMUX_APP_PACKAGE name."
    echo " -p, --plugin PLUGIN         Specify a plugin from the plugins folder to apply during building."
    echo " -d, --dirty                 Build without cleaning previous artifacts."
    echo
}

portable_sed_i() {
    if sed v </dev/null 2> /dev/null
    then
        sed -i "$@"
    else
        sed -i '' "$@"
    fi
}

apply_patches() {
    srcdir=$(realpath "$1")
    targetdir=$(realpath "$2")
    local PATCHES=$(find "$srcdir" -type f | sort)
    pushd $targetdir || exit 13
    for patch in $PATCHES
    do
        patch -p1 < "$patch" || exit 9
    done
    popd
}

# Funktion, um den Paketnamen zu überprüfen
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
        echo "Package name must not contain underscores, dashes, or invalid patterns!"
        exit 2
    fi
}

clean_docker() {
    docker container kill termux-generator-package-builder 2> /dev/null || true
    docker container rm -f termux-generator-package-builder 2>/dev/null || true
    docker image rm ghcr.io/termux-play-store/package-builder 2>/dev/null || true
}

clean_artifacts() {
    rm -rf termux* 2>/dev/null
    rm *.apk 2>/dev/null
}

# Funktion, um Repositories herunterzuladen
download() {
    git clone https://github.com/termux-play-store/termux-packages.git termux-packages-main || exit 3
    git clone https://github.com/termux-play-store/termux-apps.git termux-apps-main || exit 4
}

build_plugin() {
    pushd plugins/$TERMUX_GENERATOR_PLUGIN || exit 13
    ./gradlew build
    popd
}

install_plugin() {
    mkdir -p termux-apps-main/termux-app/src/main/assets/
    cp -rf plugins/$TERMUX_GENERATOR_PLUGIN termux-apps-main/termux-app/src/main/assets/ || exit 12
    apply_patches plugins/$TERMUX_GENERATOR_PLUGIN/bootstrap-patches termux-packages-main
    apply_patches plugins/$TERMUX_GENERATOR_PLUGIN/app-patches termux-apps-main
}

# Funktion, um Bootstrap-Patches anzuwenden
patch_bootstraps() {
    apply_patches bootstrap-patches termux-packages-main
    pushd termux-packages-main
    portable_sed_i "s/TERMUX_APP_PACKAGE=\"com.termux\"/TERMUX_APP_PACKAGE=\"$TERMUX_APP_PACKAGE\"/g" scripts/properties.sh || exit 10
    popd
}

# Funktion, um Bootstraps zu erstellen
build_bootstraps() {
    pushd termux-packages-main || exit 8

    if [ -z "${ADDITIONAL_PACKAGES}" ]; then
        scripts/run-docker.sh scripts/generate-bootstraps.sh --build --architectures aarch64,x86_64,arm || exit 11
    else
        scripts/run-docker.sh scripts/generate-bootstraps.sh --build --architectures aarch64,x86_64,arm --add "${ADDITIONAL_PACKAGES}" || exit 11
    fi

    popd
}

# Funktion, um Bootstraps zu kopieren
copy_bootstraps() {
    mkdir -p termux-apps-main/termux-app/src/main/assets/
    cp termux-packages-main/bootstrap-*.zip termux-apps-main/termux-app/src/main/assets/ || exit 12
}

# Funktion, um Ordner zu migrieren
migrate_termux_folder() {
    PARENT_DIR="$(dirname "$(dirname "$1")")"
    TERMUX_APP_PACKAGE=$2
    DESTINATION="${PARENT_DIR}/$(echo "$TERMUX_APP_PACKAGE" | tr . /)/"
    echo "Migrating folder: renaming ${PARENT_DIR}/com/termux/ to ${DESTINATION}"
    mkdir -p "${DESTINATION}"
    mv "${PARENT_DIR}/com/termux/"* "${DESTINATION}"
    rm -r "${PARENT_DIR}/com/termux/"
}

# Funktion, um die App zu patchen
patch_app() {
    apply_patches app-patches termux-apps-main

    pushd termux-apps-main

    TERMUX_APP_PACKAGE_UNDERSCORE=$(echo "$TERMUX_APP_PACKAGE" | tr . _)
    
    # Nur Textdateien bearbeiten, um Fehler zu vermeiden
    find . -type f -exec file {} + | grep "text" | cut -d: -f1 | while read -r file; do
        portable_sed_i -e "s/>Termux</>$TERMUX_APP_PACKAGE</g" \
                       -e "s/\"Termux\"/\"$TERMUX_APP_PACKAGE\"/g" \
                       -e "s/com\.termux/$TERMUX_APP_PACKAGE/g" \
                       -e "s/com_termux/$TERMUX_APP_PACKAGE_UNDERSCORE/g" "$file"
    done

    # Vollständig macOS-kompatible Variante für Verzeichnismigration
    find "$(pwd)" -type d -name termux | while read -r dir; do
        migrate_termux_folder "$dir" "$TERMUX_APP_PACKAGE"
    done

    popd
}

# Funktion, um die App zu bauen
build_app() {
    pushd termux-apps-main || exit 13
    ./gradlew assembleDebug || exit 15
    popd
}

# Funktion, um die APK zu kopieren
copy_app() {
    cp termux-apps-main/termux-app/build/outputs/apk/debug/*.apk "$TERMUX_APP_PACKAGE".apk
}

cd "$(dirname "$0")"

export TERMUX_APP_PACKAGE="com.termux"

# Argumente verarbeiten
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
            if [ $# -gt 1 ] && [ -n "$2" ] && [[ $2 != -* ]]; then
                export ADDITIONAL_PACKAGES="$2"
                shift 1
            else
                echo "[!] Option '--add' requires an argument."
                show_usage
                exit 1
            fi
            ;;
        -n|--name)
            if [ $# -gt 1 ] && [ -n "$2" ] && [[ $2 != -* ]]; then
                export TERMUX_APP_PACKAGE="$2"
                shift 1
            else
                echo "[!] Option '--name' requires an argument."
                show_usage
                exit 1
            fi
            ;;
        -p|--plugin)
            if [ $# -gt 1 ] && [ -n "$2" ] && [[ $2 != -* ]]; then
                export TERMUX_GENERATOR_PLUGIN="$2"
                shift 1
            else
                echo "[!] Option '--plugin' requires an argument."
                show_usage
                exit 1
            fi
            ;;
        *)
            echo "[!] Unknown option '$1'"
            show_usage
            exit 1
            ;;
    esac
    shift 1
done

if [ -z "${DO_NOT_CLEAN}" ]
then
    # Validierung und Ausführung
    check_name
    clean_docker
    clean_artifacts
    download
    if [ -n "$TERMUX_GENERATOR_PLUGIN" ]
    then
        build_plugin
        install_plugin
    fi
    patch_bootstraps
    build_bootstraps
    copy_bootstraps
    patch_app
fi

build_app
copy_app
