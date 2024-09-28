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
sudo apt install -y docker.io android-sdk openjdk-17-jdk wget unzip patch
sudo usermod -aG docker $(whoami)
```

- Restart your computer or otherwise apply the group change (for me, logging out and logging in was actually insufficient on Ubuntu 20.04)
```bash
sudo reboot
```

```bash
wget https://github.com/robertkirkman/termux-generator/archive/refs/heads/main.zip
unzip main.zip
cd termux-generator-main
./build-termux.sh a.copy.of.termux.with.the.location.changed
```

> [!IMPORTANT]
> Running the command a second time will delete all the modified files and start over. Remove `clean.sh` or run commands manually if you are troubleshooting.
