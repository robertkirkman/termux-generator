#!/bin/bash
set -e -u -o pipefail

cd "$(realpath "$(dirname "$0")")"

TERMUX_GENERATOR_HOME="$(pwd)"
TERMUX_APP__PACKAGE_NAME="com.termux"
TERMUX_APP_TYPE="f-droid"
BOOTSTRAP_ARCHITECTURES=""
PACKAGES_TO_BUILD=""

source "$TERMUX_GENERATOR_HOME/scripts/termux_generator_utils.sh"

show_usage() {
    echo
    echo "Usage: build-packages.sh [options]"
    echo
    echo "Compile specific packages for Termux."
    echo
    echo "Options:"
    echo " -h, --help                       Show this help."
    echo " -n, --name APP_NAME              Specify TERMUX_APP__PACKAGE_NAME name."
    echo " -t, --type APP_TYPE              Specify the Termux project to fork [f-droid, play-store]. Defaults to f-droid."
    echo " --architectures ARCH_LIST        Specify the architectures to include in a comma-separated list."
    echo " -p, --packages PKG_LIST          Specify packages to build in a comma-separated list."
    echo
}

while (($# > 0)); do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
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
        -p|--packages)
            if [ $# -gt 1 ] && [ -n "$2" ] && [[ $2 != -* ]]; then
                PACKAGES_TO_BUILD="$2"
                shift 1
            else
                echo "[!] Option '--packages' requires an argument."
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

if [ -z "$PACKAGES_TO_BUILD" ]; then
    echo "[!] No packages specified. Please specify packages to build with -p/--packages."
    exit 1
fi

if [ -z "$BOOTSTRAP_ARCHITECTURES" ]; then
    echo "[!] No architectures specified. Please specify architectures to build for with --architectures."
    exit 1
fi

TERMUX_GENERATOR_CONTAINER_NAME="$TERMUX_APP__PACKAGE_NAME-$TERMUX_APP_TYPE-package-builder"

# Clean docker container
docker container kill "$TERMUX_GENERATOR_CONTAINER_NAME" 2> /dev/null || true
docker container rm -f "$TERMUX_GENERATOR_CONTAINER_NAME" 2>/dev/null || true

# Remove old files
rm -rf termux-packages-main 2>/dev/null
rm -rf *.deb *.zip 2>/dev/null

# Download the termux-packages repository
echo "[*] Cloning termux-packages repository..."
if [[ "$TERMUX_APP_TYPE" == "f-droid" ]]; then
    git clone --depth 1 https://github.com/termux/termux-packages.git termux-packages-main
else
    git clone --depth 1 https://github.com/termux-play-store/termux-packages.git termux-packages-main
fi

if [[ "${CI-}" == "true" ]]; then
    if [ -f termux-packages-main/scripts/free-space.sh ]; then
        echo "[*] Freeing disk space on CI..."
        termux-packages-main/scripts/free-space.sh
    fi
fi

# Patch packages repository
echo "[*] Patching termux-packages repository..."
if [[ "$TERMUX_APP__PACKAGE_NAME" != "com.termux" ]]; then
    replace_termux_name termux-packages-main "$TERMUX_APP__PACKAGE_NAME"
fi

# Apply bootstrap patches (which are actually toolchain/build system patches)
apply_patches "$TERMUX_APP_TYPE-patches/bootstrap-patches" termux-packages-main

# Set custom container name
portable_sed_i -e "s|termux-package-builder|$TERMUX_GENERATOR_CONTAINER_NAME|g" termux-packages-main/scripts/run-docker.sh

# Run docker preparation
echo "[*] Running docker preparation..."
pushd termux-packages-main
scripts/run-docker.sh sudo ln -sf "/data/data/$TERMUX_APP__PACKAGE_NAME/aosp" /system

# Build each package for each architecture
IFS=',' read -ra ARCHS <<< "$BOOTSTRAP_ARCHITECTURES"
IFS=',' read -ra PKGS <<< "$PACKAGES_TO_BUILD"

for arch in "${ARCHS[@]}"; do
    for pkg in "${PKGS[@]}"; do
        echo "[*] Building package '$pkg' for architecture '$arch'..."
        scripts/run-docker.sh ./build-package.sh -a "$arch" "$pkg"
    done
done

popd

# Gather and zip packages
echo "[*] Packaging built .deb packages..."
mkdir -p built-packages
# Find and copy all built .deb packages from termux-packages-main/output
find termux-packages-main/output -name "*.deb" -exec cp {} built-packages/ \; 2>/dev/null || true

if [ -z "$(ls -A built-packages)" ]; then
    echo "[!] No packages built successfully!"
    exit 1
else
    echo "[*] Built packages:"
    ls -l built-packages
    zip -r built-packages.zip built-packages/
    echo "[*] Done! Packages zipped in built-packages.zip"
fi
