set -e

PATH=$PATH:/home/rev/workspace/fdroidserver/:/home/rev/depot_tools

BASE_DIR=/home/rev/REV-Chromium-Builds
BASE_GIT=github.com/REVrobotics/REV-Chromium-Builds.git
CHROMIUM_DIR=/home/rev/chromium/src
APK_OUTPUT_DIR=$CHROMIUM_DIR/out/Default/apks
METADATA_DIR=/home/rev/Software-Update-Metadata
METADATA_GIT=github.com/REVrobotics/Software-Update-Metadata.git

# Get the latest stable version for android
VERSION_URL="https://omahaproxy.appspot.com/all?os=android&channel=stable"
VERSION_CSV=$(curl $VERSION_URL)
LATEST_VERSION=$(echo $VERSION_CSV | awk -v FS=' ' '{print $2}' | awk -v FS=',' '{print $3}')

cd $BASE_DIR

git pull https://$GITHUB_TOKEN:x-oauth-basic@$BASE_GIT master
git tag -l | xargs git tag -d
git fetch https://$GITHUB_TOKEN:x-oauth-basic@$BASE_GIT master --tags

# Exit if current tag matches latest stable version
CURRENT_VERSION=$(git describe --tags `git rev-list --tags --max-count=1`) ||:
if [[ $CURRENT_VERSION == $LATEST_VERSION ]]; then
    echo "$CURRENT_VERSION is already the latest version"
    exit 0
fi

echo "New release found: $LATEST_VERSION"

cd $CHROMIUM_DIR

# Get latest commits
git reset --hard
git clean -f
git clean -fd
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
git clean -f
git clean -fd
git pull https://$GITHUB_TOKEN:x-oauth-basic@$METADATA_GIT master

# Update _redirects
grep -q '^\/fdroid-repo\/ChromePublic.apk' $METADATA_DIR/automated-deploy/_redirects \
    && sed -i '/\/fdroid-repo\/ChromePublic.apk/c\\/fdroid-repo\/ChromePublic.apk '$CHROME_URL' 200!' $METADATA_DIR/automated-deploy/_redirects \
    || echo "/fdroid-repo/ChromePublic.apk $CHROME_URL 200!" >> $METADATA_DIR/automated-deploy/_redirects
    
grep -q '^\/fdroid-repo\/SystemWebView.apk' $METADATA_DIR/automated-deploy/_redirects \
    && sed -i '/\/fdroid-repo\/SystemWebView.apk/c\\/fdroid-repo\/SystemWebView.apk '$WEBVIEW_URL' 200!' $METADATA_DIR/automated-deploy/_redirects \
    || echo "/fdroid-repo/SystemWebView.apk $WEBVIEW_URL 200!" >> $METADATA_DIR/automated-deploy/_redirects

# Update APKs and metadata
cp $APK_OUTPUT_DIR/ChromePublic.apk $METADATA_DIR/fdroid/repo/
cp $APK_OUTPUT_DIR/SystemWebView.apk $METADATA_DIR/fdroid/repo/
cd $METADATA_DIR/fdroid
fdroid update -c || (git reset --hard origin/master; exit 1)
cd $METADATA_DIR/
git add -A
git commit -m "Update metadata and redirects for Chromium $LATEST_VERSION"
git push https://$GITHUB_TOKEN:x-oauth-basic@$METADATA_GIT master
