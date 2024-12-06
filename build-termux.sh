#!/bin/bash
# set -x
# Wechsel zum Verzeichnis, in dem das Skript liegt
cd "$(dirname "$0")"

# Erkennen des Kerneltyps des Betriebssystems
unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    *)          machine="OTHER:${unameOut}"
esac

if [ $machine == Mac ]; then
    BSD_SED_BAKPATH="''"
    echo $BSD_SED_BAKPATH
fi

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

# Funktion, um Repositories herunterzuladen
download() {
    git clone https://github.com/termux-play-store/termux-packages.git termux-packages-main || exit 3
    git clone https://github.com/termux-play-store/termux-apps.git termux-apps-main || exit 4
}

# Funktion, um Bootstrap-Patches anzuwenden
patch_bootstraps() {
    local BOOTSTRAP_PATCHES=$(find "$(pwd)/bootstrap-patches/" -type f | sort)
    pushd termux-packages-main || exit 8
    for patch in $BOOTSTRAP_PATCHES
    do
        patch -p1 < "$patch" || exit 9
    done
    # $BSD_SED_BAKPATH darf nicht erweitert werden, sonst wird es zu "''" erweitert und funktioniert nicht!
    sed -i $BSD_SED_BAKPATH "s/TERMUX_APP_PACKAGE=\"com.fezaan.termux\"/TERMUX_APP_PACKAGE=\"$TERMUX_APP_PACKAGE\"/g" scripts/properties.sh || exit 10
    popd
}

# Funktion, um Bootstraps zu erstellen
build_bootstraps() {
    pushd termux-packages-main || exit 8

    if [ -z "${ADDITIONAL_PACKAGES}" ]; then
        scripts/run-docker.sh scripts/generate-bootstraps.sh --build || exit 11
    else
        scripts/run-docker.sh scripts/generate-bootstraps.sh --build --add "${ADDITIONAL_PACKAGES}" || exit 11
    fi

    popd
}

# Funktion, um Bootstraps zu kopieren
copy_bootstraps() {
    pushd termux-apps-main || exit 8
    mkdir -p termux-app/src/main/assets/
    cp ../termux-packages-main/bootstrap-*.zip termux-app/src/main/assets/ || exit 12
    popd
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
    local APP_PATCHES=$(find "$(pwd)/app-patches/" -type f | sort)
    pushd termux-apps-main || exit 13
    for patch in $APP_PATCHES
    do
        patch -p1 < "$patch" || exit 9
    done

    TERMUX_APP_PACKAGE_UNDERSCORE=$(echo "$TERMUX_APP_PACKAGE" | tr . _)
    
    # Nur Textdateien bearbeiten, um Fehler zu vermeiden
    # $BSD_SED_BAKPATH darf nicht erweitert werden, sonst wird es zu "''" erweitert und funktioniert nicht!
    find . -type f -exec file {} + | grep "text" | cut -d: -f1 | while read -r file; do
        sed -i $BSD_SED_BAKPATH -e "s/>Termux</>$TERMUX_APP_PACKAGE</g" \
                  -e "s/\"Termux\"/\"$TERMUX_APP_PACKAGE\"/g" \
                  -e "s/com\.termux/$TERMUX_APP_PACKAGE/g" \
                  -e "s/com_termux/$TERMUX_APP_PACKAGE_UNDERSCORE/g" "$file"
    done

    (
	while IFS= read -r -d '' termux_folder; do
		migrate_termux_folder "$termux_folder" "$TERMUX_APP_PACKAGE"
	done < <(find "$(pwd)" -type d -name termux -print0)
	)
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
    echo " -d, --dirty                 Build without cleaning previous artifacts."
    echo
}

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
        *)
            echo "[!] Unknown option '$1'"
            show_usage
            exit 1
            ;;
    esac
    shift 1
done

# Validierung und Ausführung
if [ ! -z "${TERMUX_APP_PACKAGE}" ]; then
    check_name
fi

if [ -z "${DO_NOT_CLEAN}" ]; then
    ./clean.sh
fi

download

if [ ! -z "${TERMUX_APP_PACKAGE}" ]; then
    patch_bootstraps
fi

build_bootstraps

copy_bootstraps

if [ ! -z "${TERMUX_APP_PACKAGE}" ]; then
    patch_app
fi

build_app

copy_app
