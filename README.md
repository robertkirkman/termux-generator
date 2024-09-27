# termux-generator

This script builds a vanilla [termux-play-store/termux-apps/termux-app](https://github.com/termux-play-store/termux-apps/tree/main/termux-app) from source at a September 27th 2024 snapshot, but allows changing the package name from `com.termux` to anything else with a single command.

### Dependencies

- Docker
- Android SDK
- wget
- unzip
- patch

### Example (Ubuntu 24.04)

```bash
sudo apt install -y docker.io android-sdk wget unzip patch
wget https://github.com/robertkirkman/termux-generator/archive/refs/heads/main.zip
unzip main.zip
cd termux-generator-main
./build-termux.sh a.copy.of.termux.in.a.different.folder
```

> [!IMPORTANT]
> Running the command a second time will delete all the modified files and start over. Remove `clean.sh` or run commands manually if you are troubleshooting.
