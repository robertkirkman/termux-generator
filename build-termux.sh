#!/bin/bash
set -e -u -o pipefail
# Wechsel zum Verzeichnis, in dem das Skript liegt

cd "$(realpath "$(dirname "$0")")"

TERMUX_GENERATOR_HOME="$(pwd)"
TERMUX_APP__PACKAGE_NAME="com.termux"
TERMUX_APP_TYPE="f-droid"
DO_NOT_CLEAN=""
TERMUX_GENERATOR_PLUGIN=""
ADDITIONAL_PACKAGES="xkeyboard-config" # for termux-x11-nightly which is always preinstalled
BOOTSTRAP_ARCHITECTURES=""
DISABLE_BOOTSTRAP_SECOND_STAGE=""
ENABLE_SSH_SERVER=""
DEFAULT_PASSWORD="changeme"

source "$TERMUX_GENERATOR_HOME/scripts/termux_generator_utils.sh"
source "$TERMUX_GENERATOR_HOME/scripts/termux_generator_steps.sh"

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
    echo "                                  NOTE: This option depends on the bootstrap second stage,"
    echo "                                  therefore '--disable-bootstrap-second-stage' will prevent it"
    echo "                                  from working, and since builds of type play-store do not implement"
    echo "                                  the bootstrap second stage, currently,"
    echo "                                  this option only affects builds of type f-droid."
    echo "                                  This can be done on a headless device using the command"
    echo "                                  'adb [-s ID] shell am start -n [APP_NAME]/.app.TermuxActivity'."
    echo "                                  If you would like automatic setup of Termux:Boot as well so that"
    echo "                                  Termux and its SSH server both launch automatically at device unlock,"
    echo "                                  install Termux:Boot also and launch it at least once, using"
    echo "                                  'adb [-s ID] shell am start -n [APP_NAME].boot/.BootActivity'!"
    echo " -d, --dirty                      Build without cleaning previous artifacts."
    echo
}

# Argumente verarbeiten
while (($# > 0)); do
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
                ADDITIONAL_PACKAGES+=",$2"
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
                        show_usage
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
                echo "[!] Option '--architectures' requires an argument."
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
            ;;
        *)
            echo "[!] Unknown option '$1'"
            show_usage
            exit 1
            ;;
    esac
    shift 1
done

if [ -z "${DO_NOT_CLEAN}" ]; then
    # Validierung und Ausführung
    check_names
    clean_docker
    clean_artifacts
    download
    if [ -n "$TERMUX_GENERATOR_PLUGIN" ]; then
        build_plugin
        install_plugin
    fi
    patch_bootstraps
    patch_apps
    if [[ "$TERMUX_APP_TYPE" == "f-droid" ]]; then
        build_termux_x11
        move_termux_x11_deb
    fi
    build_bootstraps
    move_bootstraps
fi

build_apps
move_apks
