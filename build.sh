CHROMIUM_DIR=/home/rev/chromium/src
APK_OUTPUT_DIR=$CHROMIUM_DIR/out/Default/apks
SOFTWARE_UPDATE_METADATA_DIR=/home/rev/Software-Update-Metadata

# Get the latest stable version for android
VERSION_URL="https://omahaproxy.appspot.com/all?os=android&channel=stable"
VERSION_CSV=$(curl $VERSION_URL)
LATEST_VERSION=$(echo $VERSION_CSV | awk -v FS=' ' '{print $2}' | awk -v FS=',' '{print $3}')

cd $CHROMIUM_DIR

# Exit if current tag matches latest stable version
CURRENT_VERSION=$(git describe --tags)
[[ $CURRENT_VERSION == $LATEST_VERSION ]] && exit 0

echo "New release found: $LATEST_VERSION"

# Get latest commits
git rebase-update

# Checkout latest stable version
git checkout $LATEST_VERSION

# Update Android dependencies
gclient sync -D

# Build Chromium
autoninja -C out/Default chrome_public_apk

# Build Webview
autoninja -C out/Default system_webview_apk

# Make release
RELEASE=$(curl \
    -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token $GITHUB_TOKEN" \
    https://api.github.com/repos/REVrobotics/REV-Chromium-Builds/releases \
    -d '{"tag_name":"'$LATEST_VERSION'"}')

UPLOAD_URL=$(echo $RELEASE | jq -r .upload_url)
UPLOAD_URL=${UPLOAD_URL%"{?name,label}"}

# Upload ChromePublic.apk
curl \
    -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @$APK_OUTPUT_DIR/ChromePublic.apk \
    $UPLOAD_URL?name=ChromePublic.apk 

# Upload SystemWebView.apk
curl \
    -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @$APK_OUTPUT_DIR/SystemWebView.apk \
    $UPLOAD_URL?name=SystemWebView.apk

# Update _redirect
# TODO

# Update APKs in Software-Update-Metadata repo
# TODO
