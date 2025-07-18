#!/bin/bash
set -e -u -o pipefail
# Wechsel zum Verzeichnis, in dem das Skript liegt

# Anzeige der Hilfe
show_usage() {
    echo
    echo "Usage: build-termux.sh [options]"
    echo
    echo "Generate Termux application."
    echo
    echo "Options:"
    echo " -h, --help                       Show this help."
    echo " -a, --add PKG_LIST               Include additional packages in bootstrap archive."
    echo " -n, --name APP_NAME              Specify TERMUX_APP__PACKAGE_NAME name."
    echo " -t, --type APP_TYPE              Specify the Termux project to fork [f-droid, play-store]. Defaults to f-droid."
    echo " --architectures ARCH_LIST        Specify the bootstrap architectures to include in a comma-separated list."
    echo " -p, --plugin PLUGIN              Specify a plugin from the plugins folder to apply during building."
    echo " --disable-bootstrap-second-stage Disable the automatic execution of termux-bootstrap-second-stage.sh."
    echo "                                  Currently, this option only affects builds of type f-droid."
    echo " --enable-ssh-server              Bundle an SSH server with the default password 'changeme'."
    echo "                                  The SSH server will start when the main Termux Activity is launched."
    echo "                                  This can be done on a headless device using the command"
    echo "                                  'adb [-s ID] shell am start -n [APP_NAME]/.app.TermuxActivity'."
    echo "                                  If you would like automatic setup of Termux:Boot as well so that"
    echo "                                  Termux and its SSH server both launch automatically at device unlock,"
    echo "                                  please open an issue to request that!"
    echo " -d, --dirty                      Build without cleaning previous artifacts."
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
    pushd $targetdir
    for patch in $PATCHES
    do
        patch -p1 < "$patch"
    done
    popd
}

# Funktion, um den Paketnamen zu überprüfen
check_name() {
    if [[ $TERMUX_APP__PACKAGE_NAME =~ '_' ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME =~ '-' ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME == package ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME == package.* ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME == *.package ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME == *.package.* ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME == in ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME == in.* ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME == *.in ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME == *.in.* ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME == is ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME == is.* ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME == *.is ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME == *.is.* ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME == as ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME == as.* ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME == *.as ]] || \
       [[ $TERMUX_APP__PACKAGE_NAME == *.as.* ]]
    then
        echo "Package name must not contain underscores, dashes, or invalid patterns!"
        exit 2
    fi
}

clean_docker() {
    docker container kill termux-generator-package-builder 2> /dev/null || true
    docker container rm -f termux-generator-package-builder 2>/dev/null || true
    if ! docker image rm ghcr.io/termux/package-builder 2>/dev/null; then
        echo "[*] Warning: not removing Docker package builder image for \"F-Droid\" Termux, likely because it is either not downloaded yet, or in use by other containers."
    fi
    if ! docker image rm ghcr.io/termux-play-store/package-builder 2>/dev/null; then
        echo "[*] Warning: not removing Docker package builder image for \"Google Play\" Termux, likely because it is either not downloaded yet, or in use by other containers."
    fi
}

clean_artifacts() {
    rm -rf termux* *.apk *.deb *.xz 2>/dev/null
}

# Funktion, um Repositories herunterzuladen
download() {
    if [[ "$TERMUX_APP_TYPE" == "f-droid" ]]; then
        git clone --depth 1 https://github.com/termux/termux-packages.git               termux-packages-main
        git clone --depth 1 https://github.com/termux/termux-tasker.git                 termux-apps-main/termux-tasker
        git clone --depth 1 https://github.com/termux/termux-float.git                  termux-apps-main/termux-float
        git clone --depth 1 https://github.com/termux/termux-widget.git                 termux-apps-main/termux-widget
        git clone --depth 1 https://github.com/termux/termux-api.git                    termux-apps-main/termux-api
        git clone --depth 1 https://github.com/termux/termux-boot.git                   termux-apps-main/termux-boot
        git clone --depth 1 https://github.com/termux/termux-styling.git                termux-apps-main/termux-styling
        git clone --depth 1 https://github.com/termux/termux-app.git                    termux-apps-main/termux-app
        git clone --depth 1 https://github.com/termux/termux-gui.git                    termux-apps-main/termux-gui
        git clone --depth 1 --recursive https://github.com/termux/termux-x11.git        termux-apps-main/termux-x11
        # special case - for "F-Droid" Termux, it is necessary to move the termux-am-library subfolder of
        # the termux-am-library repository, which contains its actual code, into the termux-app folder,
        # where its code needs to be patched and compiled into the main "F-Droid" Termux APK
        git clone --depth 1 https://github.com/termux/termux-am-library.git             termux-apps-main/termux-am-library
        mv termux-apps-main/termux-am-library/termux-am-library/                        termux-apps-main/termux-app/termux-am-library
        rm -rf                                                                          termux-apps-main/termux-am-library/
    else
        git clone --depth 1 https://github.com/termux-play-store/termux-packages.git    termux-packages-main
        git clone --depth 1 https://github.com/termux-play-store/termux-apps.git        termux-apps-main
    fi
}

build_plugin() {
    pushd plugins/$TERMUX_GENERATOR_PLUGIN
    ./gradlew build
    popd
}

install_plugin() {
    mkdir -p termux-apps-main/termux-app/src/main/assets/
    cp -rf plugins/$TERMUX_GENERATOR_PLUGIN termux-apps-main/termux-app/src/main/assets/
    apply_patches "plugins/$TERMUX_GENERATOR_PLUGIN/$TERMUX_APP_TYPE-patches/bootstrap-patches" termux-packages-main
    apply_patches "plugins/$TERMUX_GENERATOR_PLUGIN/$TERMUX_APP_TYPE-patches/app-patches" termux-apps-main
}

# Funktion, um Bootstrap-Patches anzuwenden
patch_bootstraps() {
    apply_patches "$TERMUX_APP_TYPE-patches/bootstrap-patches" termux-packages-main
    pushd termux-packages-main

    if [[ -n "$ENABLE_SSH_SERVER" ]]; then
        echo "if [ ! -f \"\$HOME/.termux_authinfo\" ]; then" >> packages/bash/etc-bash.bashrc
        echo "    printf '$DEFAULT_PASSWORD\n$DEFAULT_PASSWORD' | passwd" >> packages/bash/etc-bash.bashrc
        echo "fi" >> packages/bash/etc-bash.bashrc
        echo "sshd" >> packages/bash/etc-bash.bashrc
    fi

    if [[ "$TERMUX_APP__PACKAGE_NAME" == "com.termux" ]]; then
        return
    fi

    # TODO: more patching is required than this alone.
    # there have been many more instances of string "com.termux" added to termux-packages repository recently.
    portable_sed_i "s/TERMUX_APP__PACKAGE_NAME=\"com.termux\"/TERMUX_APP__PACKAGE_NAME=\"$TERMUX_APP__PACKAGE_NAME\"/g" scripts/properties.sh
    popd
}

# Funktion, um Bootstraps zu erstellen
build_bootstraps() {
    pushd termux-packages-main

    local bootstrap_script_args=""

    if [ -n "${ADDITIONAL_PACKAGES}" ]; then
        bootstrap_script_args+=" --add ${ADDITIONAL_PACKAGES}"
    fi

    if [[ "$TERMUX_APP_TYPE" == "f-droid" ]]; then
        local bootstrap_script="build-bootstraps.sh"
        local bootstrap_architectures="aarch64,x86_64,arm,i686"
        if [ -n "${DISABLE_BOOTSTRAP_SECOND_STAGE-}" ]; then
            bootstrap_script_args+=" --disable-bootstrap-second-stage"
        fi
    else
        local bootstrap_script="generate-bootstraps.sh"
        local bootstrap_architectures="aarch64,x86_64,arm"
        bootstrap_script_args+=" --build"
    fi

    if [ -n "${BOOTSTRAP_ARCHITECTURES}" ]; then
        bootstrap_architectures="$BOOTSTRAP_ARCHITECTURES"
    fi

    bootstrap_script_args+=" --architectures $bootstrap_architectures"

    scripts/run-docker.sh "scripts/$bootstrap_script" $(echo "$bootstrap_script_args")

    popd
}

# Funktion, um Bootstraps zu kopieren
copy_bootstraps() {
    if [[ "$TERMUX_APP_TYPE" == "f-droid" ]]; then
        local app_assets_dir="app/src/main/assets/"
    else
        local app_assets_dir="src/main/assets/"
    fi
    mkdir -p "termux-apps-main/termux-app/$app_assets_dir"
    cp termux-packages-main/bootstrap-*.zip "termux-apps-main/termux-app/$app_assets_dir"
}

# Funktion, um Ordner zu migrieren
migrate_termux_folder() {
    PARENT_DIR="$(dirname "$(dirname "$1")")"
    TERMUX_APP__PACKAGE_NAME=$2
    DESTINATION="${PARENT_DIR}/$(echo "$TERMUX_APP__PACKAGE_NAME" | tr . /)/"
    echo "Migrating folder:"
    echo "- ${PARENT_DIR}/com/termux/"
    echo "to"
    echo "+ ${DESTINATION}"
    mkdir -p "${DESTINATION}"
    mv "${PARENT_DIR}/com/termux/"* "${DESTINATION}"
    rm -r "${PARENT_DIR}/com/termux/"
}

# Funktion, um die App zu patchen
patch_apps() {
    apply_patches "$TERMUX_APP_TYPE-patches/app-patches" termux-apps-main

    if [[ "$TERMUX_APP__PACKAGE_NAME" == "com.termux" ]]; then
        return
    fi

    pushd termux-apps-main

    TERMUX_APP__PACKAGE_NAME_UNDERSCORE=$(echo "$TERMUX_APP__PACKAGE_NAME" | tr . _)
    
    # Nur Textdateien bearbeiten, um Fehler zu vermeiden
    find . -type f -exec file {} + | grep "text" | cut -d: -f1 | while read -r file; do
        portable_sed_i -e "s/>Termux</>$TERMUX_APP__PACKAGE_NAME</g" \
                       -e "s/\"Termux\"/\"$TERMUX_APP__PACKAGE_NAME\"/g" \
                       -e "s/com\.termux/$TERMUX_APP__PACKAGE_NAME/g" \
                       -e "s/com_termux/$TERMUX_APP__PACKAGE_NAME_UNDERSCORE/g" "$file"
    done

    # Vollständig macOS-kompatible Variante für Verzeichnismigration
    find "$(pwd)" -type d -name termux | grep -v -e 'shared/termux' -e 'settings/termux' \
        | while read -r dir; do
        migrate_termux_folder "$dir" "$TERMUX_APP__PACKAGE_NAME"
    done

    popd
}

# Funktion, um die App zu bauen
build_apps() {
    pushd termux-apps-main
    if [[ "$TERMUX_APP_TYPE" == "f-droid" ]]; then
        pushd termux-app
            ./gradlew publishReleasePublicationToMavenLocal
        popd
        for app in *; do
            pushd "$app"
            ./gradlew assembleDebug
            popd
        done
        pushd termux-x11
            ./build_termux_package
        popd
    else
        ./gradlew assembleDebug
    fi
    popd
}

# Funktion, um die APK zu kopieren
move_apks() {
    if [[ "$TERMUX_APP_TYPE" == "f-droid" ]]; then
        for apk in termux-apps-main/*/app/build/outputs/apk/debug/*.{apk,deb,xz}; do
            mv "$apk" "$TERMUX_APP__PACKAGE_NAME-$TERMUX_APP_TYPE-$(basename $apk)"
        done
    else
        for apk in termux-apps-main/*/build/outputs/apk/debug/*.apk; do
            mv "$apk" "$TERMUX_APP__PACKAGE_NAME-$TERMUX_APP_TYPE-$(basename $apk)"
        done
    fi
}

cd "$(dirname "$0")"

TERMUX_APP__PACKAGE_NAME="com.termux"
TERMUX_APP_TYPE="f-droid"
DO_NOT_CLEAN=""
TERMUX_GENERATOR_PLUGIN=""
ADDITIONAL_PACKAGES=""
BOOTSTRAP_ARCHITECTURES=""
DISABLE_BOOTSTRAP_SECOND_STAGE=""
ENABLE_SSH_SERVER=""
DEFAULT_PASSWORD="changeme"

# Argumente verarbeiten
while (($# > 0))
do
    case "$1" in
        -d|--dirty)
            DO_NOT_CLEAN=1
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -a|--add)
            if [ $# -gt 1 ] && [ -n "$2" ] && [[ $2 != -* ]]; then
            ENABLE_SSH_SERVER=1
                if [ -n "$ADDITIONAL_PACKAGES" ]; then
                    ADDITIONAL_PACKAGES+=",$2"
                else
                    ADDITIONAL_PACKAGES="$2"
                fi
                shift 1
            else
                echo "[!] Option '--add' requires an argument."
                show_usage
                exit 1
            fi
            ;;
        -n|--name)
            if [ $# -gt 1 ] && [ -n "$2" ] && [[ $2 != -* ]]; then
                TERMUX_APP__PACKAGE_NAME="$2"
                if [[ $TERMUX_APP__PACKAGE_NAME == *"com.termux"* ]]; then
                        echo "[!] Sorry, please choose a unique custom name that does not contain 'com.termux'"
                        echo "(and is not an exact substring of it either) to avoid side effects."
                        echo "Examples: 'com.test.termux' is OK, but 'com.termux.test' or 'com.ter' could have side effects."
                        exit 1
                fi
                shift 1
            else
                echo "[!] Option '--name' requires an argument."
                show_usage
                exit 1
            fi
            ;;
        -t|--type)
            if [ $# -gt 1 ] && [ -n "$2" ] && [[ $2 != -* ]]; then
                case "$2" in
                    f-droid) TERMUX_APP_TYPE="$2" ;;
                    play-store) TERMUX_APP_TYPE="$2" ;;
                    *)
                        echo "[!] Unsupported app type '$2'. Choose one of: [f-droid, play-store]."
                        exit 1
                        ;;
                esac
                shift 1
            else
                echo "[!] Option '--type' requires an argument."
                show_usage
                exit 1
            fi
            ;;
		--architectures)
            if [ $# -gt 1 ] && [ -n "$2" ] && [[ $2 != -* ]]; then
                BOOTSTRAP_ARCHITECTURES="$2"
                shift 1
            else
                echo "[!] Option '--architectures' requires an argument." 1>&2
                show_usage
                return 1
            fi
            ;;
        -p|--plugin)
            if [ $# -gt 1 ] && [ -n "$2" ] && [[ $2 != -* ]]; then
                TERMUX_GENERATOR_PLUGIN="$2"
                shift 1
            else
                echo "[!] Option '--plugin' requires an argument."
                show_usage
                exit 1
            fi
            ;;
        --disable-bootstrap-second-stage)
            DISABLE_BOOTSTRAP_SECOND_STAGE=1
            ;;
        --enable-ssh-server)
            ENABLE_SSH_SERVER=1
            if [ -n "$ADDITIONAL_PACKAGES" ]; then
                ADDITIONAL_PACKAGES+=",openssh"
            else
                ADDITIONAL_PACKAGES="openssh"
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
    patch_apps
fi

build_apps
move_apks
