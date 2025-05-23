# termux-generator

This script builds a [termux/termux-app](https://github.com/termux/termux-app) or [termux-play-store/termux-apps/termux-app](https://github.com/termux-play-store/termux-apps/tree/main/termux-app) from source, but allows changing the package name from `com.termux` to anything else with a single command.

> [!TIP]
> termux-generator now supports using **"F-Droid" Termux** as the fork base!
> The original "F-Droid" Termux project is upstream of "Google Play" Termux.
> At time of writing, it has some bootstrap storage use inefficiency and may be more susceptible to errors when additional packages are built with `--add`, but provides slightly newer packages at build-time, more UI features, support for Android 7 through 10, and `termux-exec` 2+ for better Android 14+ support.

### Dependencies

- Docker
- Android SDK
- OpenJDK 17
- git
- patch

### Example

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

#### Android SDK Common Setup

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

#### Using termux-generator

> [!IMPORTANT]
> Best-case typical time to compile the below example with added packages and only the aarch64 bootstrap: **3 hours**

```bash
git clone https://github.com/robertkirkman/termux-generator.git
cd termux-generator
./build-termux.sh --name a.copy.of.termux.with.the.location.changed \
                  --add build-essential,cmake,python,proot-distro \
                  --architectures aarch64
```

> [!IMPORTANT]
> Running the command a second time will delete all the modified files and start over. Use `--dirty` if you are troubleshooting.
