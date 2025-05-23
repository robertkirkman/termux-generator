## example-plugins

> [!WARNING]
> This feature is experimental and here as a stub-like example

Put a folder here to have it installed into `$HOME` automatically during each launch of the app after installation if the folder name was specified in the `--plugin` argument and `copy-assets-to-home.patch` is included appropriately.

Additionally, put patches inside an "app-patches" folder or "bootstrap-patches" folder inside a "play-store-patches" or "f-droid-patches" folder corresponding to the app type used, inside that folder to have them applied to the app or bootstraps, respectively, that are built when the `--plugin` argument is used.

### Example

```
./build-termux.sh --name com.example --type play-store --plugin gradle-project
```