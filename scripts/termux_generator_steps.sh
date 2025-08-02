# Funktion, um den Paketnamen zu überprüfen
check_names() {
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
        echo "[!] Package name must not contain underscores, dashes, or invalid patterns!"
        exit 2
    fi

    if [[ $TERMUX_APP__PACKAGE_NAME == *"com.termux"* ]] && \
        [[ "$TERMUX_APP__PACKAGE_NAME" != "com.termux" ]]; then
        echo "[!] Sorry, please choose a unique custom name that does not contain 'com.termux'"
        echo "(and is not an exact substring of it either) to avoid side effects."
        echo "Examples: 'com.test.termux' is OK, but 'com.termux.test' or 'com.ter' could have side effects."
        exit 2
    fi

    if [[ $ADDITIONAL_PACKAGES == *"termux-x11-nightly"* ]]; then
        echo "[!] That version of termux-x11-nightly is precompiled and"
        echo "cannot be compiled by termux-generator with any custom name inserted!"
        echo "To use termux-x11-nightly with termux-generator, just set"
        echo "'--type f-droid', then install the .apk files termux-generator builds."
        echo "A source-built and patched 'termux-x11-nightly' package is"
        echo "automatically preinstalled."
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
    pushd "plugins/$TERMUX_GENERATOR_PLUGIN"

    ./gradlew build

    popd
}

install_plugin() {
    mkdir -p termux-apps-main/termux-app/src/main/assets/
    cp -rf "plugins/$TERMUX_GENERATOR_PLUGIN" termux-apps-main/termux-app/src/main/assets/
    apply_patches "plugins/$TERMUX_GENERATOR_PLUGIN/$TERMUX_APP_TYPE-patches/bootstrap-patches" termux-packages-main
    apply_patches "plugins/$TERMUX_GENERATOR_PLUGIN/$TERMUX_APP_TYPE-patches/app-patches" termux-apps-main
}

# Funktion, um Bootstrap-Patches anzuwenden
patch_bootstraps() {
    # The reason why it is necessary to replace the name first, then patch bootstraps, but do the reverse for apps,
    # is because command-not-found must be partially unpatched back to the default TERMUX_PREFIX to build,
    # so that patch must apply after the bootstraps' name replacement has completed, but the apps contain the
    # string "com.termux" in their code in many more places than the bootstraps do, so it's easier to patch them first.
    if [[ "$TERMUX_APP__PACKAGE_NAME" != "com.termux" ]]; then
        replace_termux_name termux-packages-main "$TERMUX_APP__PACKAGE_NAME"
    fi

    apply_patches "$TERMUX_APP_TYPE-patches/bootstrap-patches" termux-packages-main

    local bashrc="termux-packages-main/packages/bash/etc-bash.bashrc"

    if [[ -n "$ENABLE_SSH_SERVER" ]]; then
        cat <<- EOF >> "$bashrc"
            if [ ! -f "\$HOME/.termux/boot/start-sshd" ]; then
                mkdir -p "\$HOME/.termux/boot"
                echo '#!/data/data/$TERMUX_APP__PACKAGE_NAME/files/usr/bin/sh' > "\$HOME/.termux/boot/start-sshd"
                echo '. /data/data/$TERMUX_APP__PACKAGE_NAME/files/usr/etc/bash.bashrc' >> "\$HOME/.termux/boot/start-sshd"
                chmod +x "\$HOME/.termux/boot/start-sshd"
            fi
            if [ ! -f "\$HOME/.termux_authinfo" ]; then
                printf '$DEFAULT_PASSWORD\n$DEFAULT_PASSWORD' | passwd
            fi
            sshd
EOF
    fi

    cp -f "$TERMUX_GENERATOR_HOME/scripts/termux_generator_utils.sh" termux-packages-main/scripts/
}

# Funktion, um die App zu patchen
patch_apps() {
    apply_patches "$TERMUX_APP_TYPE-patches/app-patches" termux-apps-main

    if [[ "$TERMUX_APP__PACKAGE_NAME" == "com.termux" ]]; then
        return
    fi

    replace_termux_name termux-apps-main "$TERMUX_APP__PACKAGE_NAME"

    migrate_termux_folder_tree termux-apps-main "$TERMUX_APP__PACKAGE_NAME"
}

build_termux_x11() {
    pushd termux-apps-main/termux-x11

    ./gradlew assembleDebug
    ./build_termux_package

    popd
}


move_termux_x11_deb() {
    pushd termux-apps-main/termux-x11

    mkdir -p "$TERMUX_GENERATOR_HOME/termux-packages-main/output"
    mv app/build/outputs/apk/debug/*.deb "$TERMUX_GENERATOR_HOME/termux-packages-main/output/termux-x11-nightly_all.deb"

    popd
}

# Funktion, um Bootstraps zu erstellen
build_bootstraps() {
    pushd termux-packages-main

    local bootstrap_script_args=""

    if [ -n "$ENABLE_SSH_SERVER" ]; then
        ADDITIONAL_PACKAGES+=",openssh"
    fi

    bootstrap_script_args+=" --add ${ADDITIONAL_PACKAGES}"

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

    if [[ "${CI-}" != "true" ]]; then
        scripts/run-docker.sh "scripts/$bootstrap_script" $bootstrap_script_args
    else
        scripts/setup-ubuntu.sh
        scripts/setup-android-sdk.sh
        scripts/free-space.sh
        rm -f "${HOME}"/lib/ndk-*.zip "${HOME}"/lib/sdk-*.zip
        sed -i "s|/home/builder/termux-packages|$(pwd)|g" "scripts/$bootstrap_script"
        "scripts/$bootstrap_script" $bootstrap_script_args
    fi

    popd
}

# Funktion, um Bootstraps zu kopieren
move_bootstraps() {
    if [[ "$TERMUX_APP_TYPE" == "f-droid" ]]; then
        local app_assets_dir="app/src/main/assets/"
    else
        local app_assets_dir="src/main/assets/"
    fi
    mkdir -p "termux-apps-main/termux-app/$app_assets_dir"
    mv termux-packages-main/bootstrap-*.zip "termux-apps-main/termux-app/$app_assets_dir"
}

# Funktion, um die App zu bauen
build_apps() {
    pushd termux-apps-main

    if [[ "$TERMUX_APP_TYPE" == "f-droid" ]]; then
        pushd termux-app
            ./gradlew publishReleasePublicationToMavenLocal
        popd
        for app in *; do
            if [[ "$app" == "termux-x11" ]]; then
                continue
            fi
            pushd "$app"
                ./gradlew assembleDebug
            popd
        done
    else
        ./gradlew assembleDebug
    fi

    popd
}

# Funktion, um die APK zu kopieren
move_apks() {
    if [[ "$TERMUX_APP_TYPE" == "f-droid" ]]; then
        local build_dir="app/build/outputs/apk/debug"
    else
        local build_dir="build/outputs/apk/debug"
    fi

    for apk in termux-apps-main/*/"$build_dir"/*.apk; do
        mv "$apk" "$TERMUX_APP__PACKAGE_NAME-$TERMUX_APP_TYPE-$(basename $apk)"
    done
}
