CHROMIUM_DIR=/home/rev/chromium/src
APK_OUTPUT_DIR=$CHROMIUM_DIR/out/Default/apks
METADATA_DIR=/home/rev/Software-Update-Metadata
METADATA_GIT=github.com/REVrobotics/Software-Update-Metadata.git

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
autoninja -C out/Default chrome_public_apk || exit 1

# Build Webview
autoninja -C out/Default system_webview_apk || exit 1

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
CHROME_URL=$(curl \
    -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @$APK_OUTPUT_DIR/ChromePublic.apk \
    $UPLOAD_URL?name=ChromePublic.apk \
    | jq -r .browser_download_url)

# Upload SystemWebView.apk
WEBVIEW_URL=$(curl \
    -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @$APK_OUTPUT_DIR/SystemWebView.apk \
    $UPLOAD_URL?name=SystemWebView.apk \
    | jq -r .browser_download_url)

# Update Software-Update-Metadata Repo
cd $METADATA_DIR
git reset --hard origin/master
git pull https://$GITHUB_TOKEN:x-oauth-basic@$METADATA_GIT master

# Update _redirects
cat << END > $METADATA_DIR/automated-deploy/_redirects
/fdroid-repo/ChromePublic.apk $CHROME_URL 200!
/fdroid-repo/SystemWebView.apk $WEBVIEW_URL 200!
END

# Update APKs and metadata
cp $APK_OUTPUT_DIR/ChromePublic.apk $METADATA_DIR/fdroid/repo/
cp $APK_OUTPUT_DIR/SystemWebView.apk $METADATA_DIR/fdroid/repo/
cd $METADATA_DIR/fdroid
fdroid update || git reset --hard origin/master; exit 1
cd $METADATA_DIR/
git add -A
git commit -m "Update metadata and redirects for Chromium $LATEST_VERSION"
git push https://$GITHUB_TOKEN:x-oauth-basic@$METADATA_GIT master

