build_all_packages() {
    set +e

    local bootstrap_architecture="$1"

    TERMUX_SCRIPTDIR="$(pwd)"

    DOCKERSCRIPT="$TERMUX_SCRIPTDIR/scripts/run-docker.sh"

    # a safe place outside of docker is just needed to temporarily store the results of the tests,
    # and I preferred not to use anywhere in $HOME.
    BUILDSTATUS_DIR="$TERMUX_SCRIPTDIR/build-validation-results"
    rm -rf "$BUILDSTATUS_DIR"
    mkdir -p "$BUILDSTATUS_DIR"

    # remove packages that are too large (in storage size)
    # for Retired64 Termux to realistically support without sacrificing many other packages
    rm -rf "$TERMUX_SCRIPTDIR/packages/algernon"
    rm -rf "$TERMUX_SCRIPTDIR/packages/artalk"
    rm -rf "$TERMUX_SCRIPTDIR/packages/biome2"
    rm -rf "$TERMUX_SCRIPTDIR/packages/btfs2"
    rm -rf "$TERMUX_SCRIPTDIR/packages/buf"
    rm -rf "$TERMUX_SCRIPTDIR/packages/caddy"
    rm -rf "$TERMUX_SCRIPTDIR/packages/carapace"
    rm -rf "$TERMUX_SCRIPTDIR/packages/codon"
    rm -rf "$TERMUX_SCRIPTDIR/packages/dart"
    rm -rf "$TERMUX_SCRIPTDIR/packages/deno"
    rm -rf "$TERMUX_SCRIPTDIR/packages/difft"
    rm -rf "$TERMUX_SCRIPTDIR/packages/dnscontrol"
    rm -rf "$TERMUX_SCRIPTDIR/packages/dotnet"*
    rm -rf "$TERMUX_SCRIPTDIR/packages/duckdb"
    rm -rf "$TERMUX_SCRIPTDIR/packages/emscripten"
    rm -rf "$TERMUX_SCRIPTDIR/packages/erlang"
    rm -rf "$TERMUX_SCRIPTDIR/packages/gleam"
    rm -rf "$TERMUX_SCRIPTDIR/packages/elixir"
    rm -rf "$TERMUX_SCRIPTDIR/packages/git-credential-manager"
    rm -rf "$TERMUX_SCRIPTDIR/packages/jackett"
    rm -rf "$TERMUX_SCRIPTDIR/packages/marksman"
    rm -rf "$TERMUX_SCRIPTDIR/packages/netstandard-targeting-pack-2.1"
    rm -rf "$TERMUX_SCRIPTDIR/packages/rabbitmq-server"
    # rm -rf "$TERMUX_SCRIPTDIR/packages/flang" # clang
    rm -rf "$TERMUX_SCRIPTDIR/packages/flyctl"
    rm -rf "$TERMUX_SCRIPTDIR/packages/forgejo"
    rm -rf "$TERMUX_SCRIPTDIR/packages/fresh-editor"
    rm -rf "$TERMUX_SCRIPTDIR/packages/gap"
    rm -rf "$TERMUX_SCRIPTDIR/packages/geth"
    rm -rf "$TERMUX_SCRIPTDIR/packages/ghc"
    rm -rf "$TERMUX_SCRIPTDIR/packages/gitea"
    rm -rf "$TERMUX_SCRIPTDIR/packages/gogs"
    rm -rf "$TERMUX_SCRIPTDIR/packages/goose"
    rm -rf "$TERMUX_SCRIPTDIR/packages/gotify"
    rm -rf "$TERMUX_SCRIPTDIR/packages/grafana"
    rm -rf "$TERMUX_SCRIPTDIR/packages/groovy"
    rm -rf "$TERMUX_SCRIPTDIR/packages/helm_ls"
    rm -rf "$TERMUX_SCRIPTDIR/packages/helm"
    rm -rf "$TERMUX_SCRIPTDIR/packages/hugo"
    rm -rf "$TERMUX_SCRIPTDIR/packages/influxdb"
    rm -rf "$TERMUX_SCRIPTDIR/packages/jadx"
    rm -rf "$TERMUX_SCRIPTDIR/packages/jellyfin-server"
    rm -rf "$TERMUX_SCRIPTDIR/packages/jfrog-cli"
    rm -rf "$TERMUX_SCRIPTDIR/packages/jython"
    rm -rf "$TERMUX_SCRIPTDIR/packages/k9s"
    rm -rf "$TERMUX_SCRIPTDIR/packages/keybase"
    rm -rf "$TERMUX_SCRIPTDIR/packages/kotlin"
    rm -rf "$TERMUX_SCRIPTDIR/packages/kubecolor"
    rm -rf "$TERMUX_SCRIPTDIR/packages/kubectl"
    rm -rf "$TERMUX_SCRIPTDIR/packages/kubelogin"
    rm -rf "$TERMUX_SCRIPTDIR/packages/kubo"
    rm -rf "$TERMUX_SCRIPTDIR/packages/ldc"
    rm -rf "$TERMUX_SCRIPTDIR/packages/lego"
    rm -rf "$TERMUX_SCRIPTDIR/packages/lfortran"
    rm -rf "$TERMUX_SCRIPTDIR/packages/libdart"
    rm -rf "$TERMUX_SCRIPTDIR/packages/llvm-mingw-w64-tools"
    rm -rf "$TERMUX_SCRIPTDIR/packages/llvm-mingw-w64"
    rm -rf "$TERMUX_SCRIPTDIR/packages/matterbridge"
    rm -rf "$TERMUX_SCRIPTDIR/packages/mautrix-whatsapp"
    rm -rf "$TERMUX_SCRIPTDIR/packages/sideloader"
    rm -rf "$TERMUX_SCRIPTDIR/packages/maxima"
    rm -rf "$TERMUX_SCRIPTDIR/packages/mediamtx"
    rm -rf "$TERMUX_SCRIPTDIR/packages/monero"
    rm -rf "$TERMUX_SCRIPTDIR/packages/mono"
    rm -rf "$TERMUX_SCRIPTDIR/packages/navidrome"
    rm -rf "$TERMUX_SCRIPTDIR/packages/ndk-multilib"
    rm -rf "$TERMUX_SCRIPTDIR/packages/openjdk-17"
    rm -rf "$TERMUX_SCRIPTDIR/packages/openlist"
    rm -rf "$TERMUX_SCRIPTDIR/packages/praat"
    rm -rf "$TERMUX_SCRIPTDIR/packages/pypy"*
    rm -rf "$TERMUX_SCRIPTDIR/packages/python-llvmlite"
    rm -rf "$TERMUX_SCRIPTDIR/packages/rclone"
    rm -rf "$TERMUX_SCRIPTDIR/packages/restic"
    rm -rf "$TERMUX_SCRIPTDIR/packages/scala"
    rm -rf "$TERMUX_SCRIPTDIR/packages/sftpgo"
    rm -rf "$TERMUX_SCRIPTDIR/packages/shiori"
    rm -rf "$TERMUX_SCRIPTDIR/packages/sing-box"
    rm -rf "$TERMUX_SCRIPTDIR/packages/sops"
    rm -rf "$TERMUX_SCRIPTDIR/packages/stockfish"
    rm -rf "$TERMUX_SCRIPTDIR/packages/tdl"
    rm -rf "$TERMUX_SCRIPTDIR/packages/teleport-tsh"
    rm -rf "$TERMUX_SCRIPTDIR/packages/tinygo"
    rm -rf "$TERMUX_SCRIPTDIR/packages/tinymist"
    rm -rf "$TERMUX_SCRIPTDIR/packages/usql"
    # rm -rf "$TERMUX_SCRIPTDIR/packages/wasi-libc" # rust
    rm -rf "$TERMUX_SCRIPTDIR/packages/wasmer"
    rm -rf "$TERMUX_SCRIPTDIR/packages/wasmtime"
    rm -rf "$TERMUX_SCRIPTDIR/packages/wtfutil"
    rm -rf "$TERMUX_SCRIPTDIR/packages/zig"
    rm -rf "$TERMUX_SCRIPTDIR/packages/zrok"
    rm -rf "$TERMUX_SCRIPTDIR/root-packages/frida"
    rm -rf "$TERMUX_SCRIPTDIR/root-packages/nexttrace"
    rm -rf "$TERMUX_SCRIPTDIR/root-packages/wush"
    rm -rf "$TERMUX_SCRIPTDIR/root-packages/minikube"
    rm -rf "$TERMUX_SCRIPTDIR/x11-packages/ardour"
    rm -rf "$TERMUX_SCRIPTDIR/x11-packages/code-oss"
    rm -rf "$TERMUX_SCRIPTDIR/x11-packages/codelldb"
    rm -rf "$TERMUX_SCRIPTDIR/x11-packages/electron-for-code-oss"
    rm -rf "$TERMUX_SCRIPTDIR/x11-packages/tilix"
    rm -rf "$TERMUX_SCRIPTDIR/x11-packages/electron-host-tools-for-code-oss"
    rm -rf "$TERMUX_SCRIPTDIR/x11-packages/godot"
    rm -rf "$TERMUX_SCRIPTDIR/x11-packages/hangover-wine"
    rm -rf "$TERMUX_SCRIPTDIR/x11-packages/librewolf"
    rm -rf "$TERMUX_SCRIPTDIR/x11-packages/papirus-icon-theme"
    rm -rf "$TERMUX_SCRIPTDIR/x11-packages/qtcreator"
    rm -rf "$TERMUX_SCRIPTDIR/x11-packages/telegram-desktop"
    rm -rf "$TERMUX_SCRIPTDIR/x11-packages/wine-stable"
    rm -rf "$TERMUX_SCRIPTDIR/x11-packages/wxmaxima"
    rm -rf "$TERMUX_SCRIPTDIR/x11-packages/zen-browser"

    PACKAGES=()

    for PKG in $(find "$TERMUX_SCRIPTDIR"/{packages,root-packages,x11-packages} \
        -mindepth 1 -maxdepth 1 -exec basename {} \;); do
        PACKAGES+=("$PKG")
    done

    echo "==============="
    echo "Build Order:"
    echo "==============="
    for PKG in "${PACKAGES[@]}"; do
        echo "$PKG"
    done
    echo "==============="

    # $TIER indicates what degree of "bootstrappability" is being tested currently.
    # higher values are considered as more difficult to build, or less likely to build successfully,
    # so if a package passes a higher tier, it is considered that it most likely (with possible exceptions)
    # would also pass all lower tiers if its build were tested at them too.

    # TIER=4 - builds in a docker container that has already built all other packages that it is possible to build without the container being deleted
    # TIER=3 - builds in a docker container that has been building many packages previously, but has not yet built all packages previously
    # TIER=2 - builds in a clean docker container without the -I argument to build-package.sh
    # TIER=1 - builds in a clean docker container with the -I argument to build-package.sh
    for PKG in "${PACKAGES[@]}"; do
        BUILDSTATUS_FILE="$BUILDSTATUS_DIR/$PKG"
        BUILDLOG_FILE="$BUILDSTATUS_DIR/$PKG.log"

        TIER=3
        export CONTAINER_NAME="$TERMUX_GENERATOR_CONTAINER_NAME"

        echo "===============" | tee -a "$BUILDLOG_FILE"
        echo "Building $PKG at tier $TIER..." | tee -a "$BUILDLOG_FILE"
        echo "===============" | tee -a "$BUILDLOG_FILE"

        if "$DOCKERSCRIPT" ./build-package.sh -a "$bootstrap_architecture" "$PKG" 2>&1 | tee -a "$BUILDLOG_FILE"; then
            echo "passed tier $TIER" >> "$BUILDSTATUS_FILE"
            continue
        fi

        echo "===============" | tee -a "$BUILDLOG_FILE"
        echo "$PKG failed to build at tier $TIER!" | tee -a "$BUILDLOG_FILE"
        echo "===============" | tee -a "$BUILDLOG_FILE"
        echo "failed tier $TIER" >> "$BUILDSTATUS_FILE"

        TIER=2
        export CONTAINER_NAME="tier-$TIER-$TERMUX_GENERATOR_CONTAINER_NAME"
        docker container kill $CONTAINER_NAME
        docker container rm $CONTAINER_NAME
        # Replace symbolic link /system which is inside the termux-package-builder docker image
        # pointed to /data/data/com.termux/aosp by default
        # https://github.com/termux/termux-packages/blob/650907de80114cc53b20b181161f993e3ad0dfad/scripts/setup-ubuntu.sh#L371
        # needed for building pypy and similar packages
        "$DOCKERSCRIPT" sudo ln -sf "/data/data/$TERMUX_APP__PACKAGE_NAME/aosp" /system

        echo "===============" | tee -a "$BUILDLOG_FILE"
        echo "Building $PKG at tier $TIER..." | tee -a "$BUILDLOG_FILE"
        echo "===============" | tee -a "$BUILDLOG_FILE"

        if "$DOCKERSCRIPT" ./build-package.sh -a "$bootstrap_architecture" "$PKG" 2>&1 | tee -a "$BUILDLOG_FILE"; then
            echo "passed tier $TIER" >> "$BUILDSTATUS_FILE"
            continue
        fi

        echo "===============" | tee -a "$BUILDLOG_FILE"
        echo "$PKG failed to build at tier $TIER!" | tee -a "$BUILDLOG_FILE"
        echo "===============" | tee -a "$BUILDLOG_FILE"
        echo "failed tier $TIER" >> "$BUILDSTATUS_FILE"

        # TIER=1
        # export CONTAINER_NAME="tier-$TIER-termux-package-builder"
        # docker kill $CONTAINER_NAME
        # docker rm $CONTAINER_NAME

        # echo "===============" | tee -a "$BUILDLOG_FILE"
        # echo "Building $PKG at tier $TIER..." | tee -a "$BUILDLOG_FILE"
        # echo "===============" | tee -a "$BUILDLOG_FILE"

        # if "$DOCKERSCRIPT" ./build-package.sh -a "$bootstrap_architecture" -I "$PKG" 2>&1 | tee -a "$BUILDLOG_FILE"; then
        #     echo "passed tier $TIER" >> "$BUILDSTATUS_FILE"
        #     continue
        # fi

        # echo "===============" | tee -a "$BUILDLOG_FILE"
        # echo "$PKG failed to build at tier $TIER!" | tee -a "$BUILDLOG_FILE"
        # echo "===============" | tee -a "$BUILDLOG_FILE"
        # echo "failed tier $TIER" >> "$BUILDSTATUS_FILE"
    done

    # TIER=4
    # export CONTAINER_NAME="tier-3-termux-package-builder"

    # for PKG in "${PACKAGES[@]}"; do
    #     BUILDSTATUS_FILE="$BUILDSTATUS_DIR/$PKG"
    #     BUILDLOG_FILE="$BUILDSTATUS_DIR/$PKG.log"

    #     echo "===============" | tee -a "$BUILDLOG_FILE"
    #     echo "Building $PKG at tier $TIER..." | tee -a "$BUILDLOG_FILE"
    #     echo "===============" | tee -a "$BUILDLOG_FILE"

    #     if "$DOCKERSCRIPT" ./build-package.sh -a "$bootstrap_architecture" -f "$PKG" 2>&1 | tee -a "$BUILDLOG_FILE"; then
    #         echo "passed tier $TIER" >> "$BUILDSTATUS_FILE"
    #         continue
    #     fi

    #     echo "===============" | tee -a "$BUILDLOG_FILE"
    #     echo "$PKG failed to build at tier $TIER!" | tee -a "$BUILDLOG_FILE"
    #     echo "===============" | tee -a "$BUILDLOG_FILE"
    #     echo "failed tier $TIER" >> "$BUILDSTATUS_FILE"
    # done

    set -e
}
