# REV-Chromium-Builds

## Check out Chromium
Install the dependencies and download the code by following the instructions from sections _Install depot_tools_ and _Get the code_ found [here](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/android_build_instructions.md).

## Set up the Chromium build configuration
Run the following command in _~/chromium/src/_ to edit the build configuration:
```bash
gn args out/Default
```

Add the following arguments to the build configuration:

```bash
target_os = "android"
target_cpu = "arm"
is_debug = false
is_official_build = true
use_errorprone_java_compiler = false
disable_android_lint = true
fieldtrial_testing_like_official_build = true
is_component_build = false
is_chrome_branded = false
use_official_google_api_keys = false
android_channel = "stable"
system_webview_package_name = "com.revrobotics.webview"
chrome_public_manifest_package = "com.revrobotics.chromium"
```

Once you save and quit the editor, the targets for the files will be automatically updated.

## Get the latest stable Chromium release for Android
The latest versions for all OSs and channels of chromium can be found on [OmahaProxy](https://omahaproxy.appspot.com/).

Look for the version where the OS is `android` and channel is `stable` or [query OmahaProxy](https://omahaproxy.appspot.com/all?os=android&channel=stable) to get a CSV of the version information. The version will be used to do a git tag checkout for the latest stable Chromium release for Android.

Make sure you are in _~/chromium/src/_ and that the repository is up to date:
```bash
git rebase-update
```

Checkout the latest stable version:

```bash
git checkout <version>
```

Update the Android dependencies:

```bash
gclient sync
```

## Build Chromium and Webview
Make sure you are in _~/chromium/src/_

Build Chromium:

```bash
autoninja -C out/Default chrome_public_apk
```

Build Webview:

```bash
autoninja -C out/Default system_webview_apk
```
