## example-plugins

Put a folder here to have it installed into `$HOME` automatically during each launch of the app after installation if the folder name was specified in the `--plugin` argument.

Additionally, put patches inside an "app-patches" folder or "bootstrap-patches" folder inside that folder to have them applied to the app or bootstraps, respectively, that are built when the `--plugin` argument is used.

### Example

```
./build-termux.sh --name com.example --plugin gradle-project
```