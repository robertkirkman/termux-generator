# termux-generator

This script builds a [termux/termux-app](https://github.com/termux/termux-app) or [termux-play-store/termux-apps/termux-app](https://github.com/termux-play-store/termux-apps/tree/main/termux-app) from source, but allows changing the package name from `com.termux` to anything else with a single command.

## Building Termux in GitHub Actions

1. Fork the repository:

<img width="189" height="43" alt="image" src="https://github.com/user-attachments/assets/7aa63b58-b8d5-4b30-957b-fd041bee003d" />

2. Click the "Actions" tab and enable GitHub Actions:

<img width="953" height="407" alt="image" src="https://github.com/user-attachments/assets/76561301-61bd-4f58-8511-38d4486e26ac" />

3. Click the "Generate Termux application" workflow, then click the "Run workflow" button and type your desired settings:

<img width="450" height="810" alt="image" src="https://github.com/user-attachments/assets/7b914a69-7654-4150-8e68-4086a10ba3fd" />

4. Click the "Run workflow" button, then wait for your build to complete. If the build is successful, there will be an artifact available to download containing all possible Termux APKs for the combination of settings you selected:

<img width="1148" height="250" alt="image" src="https://github.com/user-attachments/assets/7bbc8338-1c9e-4a34-966f-87a65cadc471" />


## Building Termux locally

### Dependencies

- Docker
- Android SDK
- OpenJDK 17
- `git`
- `patch`
- `bash`

#### Common Dependencies
```bash
sudo apt update
sudo apt install -y openjdk-17-jdk git patch
```

#### Android SDK (Ubuntu 20.04 and 22.04)

```bash
sudo apt install -y android-sdk sdkmanager
```

#### Android SDK (Ubuntu 24.04 and 24.10)

```bash
sudo apt install -y google-android-cmdline-tools-13.0-installer
```

#### Android SDK common setup

```bash
echo "export ANDROID_SDK_ROOT=/usr/lib/android-sdk" >> ~/.bashrc && . ~/.bashrc
sudo chown -R $(whoami) $ANDROID_SDK_ROOT
yes | sdkmanager --licenses
```

#### Docker 

> [!NOTE]
> `docker.io` by Debian/Ubuntu or `docker-ce` by https://docker.com are both acceptable here. This example shows installing `docker.io` - to use Docker CE instead, visit the [docker.com docs for Docker CE](https://docs.docker.com/engine/install/)

```bash
sudo apt install -y docker.io
sudo usermod -aG docker $(whoami)
```

> [!NOTE]
> Restart your computer or otherwise apply the group change. For me, logging out and logging in was insufficient

```bash
sudo reboot
```

### Using termux-generator locally

#### Example: build Termux with the location changed and some popular packages preinstalled

> [!IMPORTANT]
> Best-case typical time to compile the below example with added packages and only the aarch64 bootstrap: **3 hours**

```bash
git clone https://github.com/robertkirkman/termux-generator.git
cd termux-generator
./build-termux.sh --name a.copy.of.termux.with.the.location.changed \
                  --add make,pkg-config,autoconf,automake,bc,bison,cmake,flex,gperf,libtool,libllvm,m4,git,golang,nodejs,patchelf,python,ruby,rust,subversion,python,proot-distro,ffmpeg \
                  --architectures aarch64
```

> [!IMPORTANT]
> Running the command a second time will delete all the modified files and start over. Use `--dirty` if you are troubleshooting.


#### Example: build Termux with SSH server enabled by default and install it through ADB

> [!NOTE]
> - This technique can be used to bootstrap from ADB access into full SSH access through Termux, without any access to a display or touchscreen.
> - This might be useful on devices that have **no screen or a broken screen**.
> - If you install Termux:Boot or build with `--type play-store` (which comes with Termux:Boot already built into the same APK as the main Google Play Termux APK), then the SSH server will also autolaunch every time the device is first unlocked after rebooting.
> - `adb forward tcp:8022 tcp:8022` is only necessary for:
>   - If you prefer to use SSH through USB connection and/or ADB connection
>   - If your device doesn't have network connectivity other than ADB
>   - If your ADB connection is itself being forwarded through a tunnel or firewall that you don't have set up for SSH

```bash
git clone https://github.com/robertkirkman/termux-generator.git
cd termux-generator
./build-termux.sh --enable-ssh-server
adb install com.termux-f-droid-termux-app_apt-android-7-debug_universal.apk
adb install com.termux-f-droid-termux-boot-app_v0.8.1+debug.apk
adb shell am start -n com.termux.boot/.BootActivity
adb shell am start -n com.termux/.app.TermuxActivity
adb forward tcp:8022 tcp:8022 # use only if needed
ssh -p 8022 localhost # if not using 'adb forward', replace 'localhost' with device's LAN IP
# default password is 'changeme'
passwd # change the default password
```

#### Example: build Termux with the location changed and XFCE preinstalled

```bash
git clone https://github.com/robertkirkman/termux-generator.git
cd termux-generator
./build-termux.sh  --add valac,thunar,xfce4-panel,xfce4-session,xfce4-settings,xfconf,xfwm4,xfce4-notifyd,xfce4-terminal,xfdesktop,xfce4 \
                   --architectures aarch64,x86_64 \
                   --name two.termux
```

- After installing both the main app and the X11 app that appear after building, use this command to launch XFCE:

```bash
termux-x11 -xstartup xfce4-session &
```
