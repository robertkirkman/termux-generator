# termux-generator

This script builds a vanilla [termux-play-store/termux-apps/termux-app](https://github.com/termux-play-store/termux-apps/tree/main/termux-app) from source, but allows changing the package name from `com.termux` to anything else with a single command.

### Dependencies

- Docker
- Android SDK
- OpenJDK 17
- wget
- unzip
- patch

### Example

```bash
sudo apt install -y docker.io android-sdk sdkmanager openjdk-17-jdk wget unzip patch
sudo usermod -aG docker $(whoami)
echo "export ANDROID_SDK_ROOT=/usr/lib/android-sdk" >> ~/.bashrc && . ~/.bashrc
sudo chown -R $(whoami) $ANDROID_SDK_ROOT
yes | sdkmanager --licenses
```

- Restart your computer or otherwise apply the group change

> [!NOTE]
> For me, logging out and logging in was insufficient on Ubuntu 22.04

```bash
sudo reboot
```

> [!IMPORTANT]
> Total time for Termux to compile entirely from source with:
> - an AMD Ryzen 9 5950X
> - running a server Linux distro 
> - bare metal (no virtualization) 
> - connected to 32 GB of RAM 
> - and an NVMe SSD 
> - with 80 GB of Swap 
> - without the `--add` argument
> - and no other intensive containers or services running: 
> 
> **1 hour**
> 
> Time to compile the below example with `--name` and `--add` on the same system:
> 
> **3 hours**

```bash
wget https://github.com/robertkirkman/termux-generator/archive/refs/heads/main.zip
unzip main.zip
cd termux-generator-main
./build-termux.sh --name a.copy.of.termux.with.the.location.changed \
                  --add build-essential,cmake,python,proot-distro
```

> [!IMPORTANT]
> Running the command a second time will delete all the modified files and start over. Use `--dirty` if you are troubleshooting.
