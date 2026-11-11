#!/bin/zsh
# 在 Mac mini 上打包 es省電王（CameraPPP）並上傳到 TestFlight（只限內部測試，不會送審）
# 用法（從 Windows PowerShell）：ssh -t mac-mini 'zsh ~/esapp-app/scripts/testflight-upload.sh'
set -e
REPO=~/esapp-app
BUILD=~/esapp-build

echo ">> 1/4 Updating code"
if [ -d "$REPO/.git" ]; then
  git -C "$REPO" fetch origin main && git -C "$REPO" reset --hard origin/main
else
  git clone https://github.com/justian688/esapp-app "$REPO"
fi
cd "$REPO"
echo "   Version: $(grep -m1 MARKETING_VERSION CameraPPP.xcodeproj/project.pbxproj | tr -d ' \t;') / build $(grep -m1 CURRENT_PROJECT_VERSION CameraPPP.xcodeproj/project.pbxproj | tr -dc 0-9)"

if [ "$1" = "nounlock" ]; then
  echo ">> 2/4 skip keychain unlock"
else
  echo ">> 2/4 Type your Mac mini login password, then press Enter (nothing will show while typing):"
  security unlock-keychain ~/Library/Keychains/login.keychain-db
fi

echo ">> 3/4 Building (3-5 min)..."
rm -rf "$BUILD"
xcodebuild -project CameraPPP.xcodeproj -scheme CameraPPP -configuration Release \
  -destination generic/platform=iOS -archivePath "$BUILD/CameraPPP.xcarchive" \
  -allowProvisioningUpdates archive | grep -E 'error:|warning: .*CameraPPP/|ARCHIVE (SUCCEEDED|FAILED)' || true
[ -d "$BUILD/CameraPPP.xcarchive" ] || { echo "!! BUILD FAILED - send the error lines above to Claude"; exit 1; }

echo ">> 4/4 Uploading to TestFlight..."
xcodebuild -exportArchive -archivePath "$BUILD/CameraPPP.xcarchive" -exportPath "$BUILD/export" \
  -exportOptionsPlist scripts/ExportOptions.plist -allowProvisioningUpdates 2>&1 | grep -E 'error|Upload|EXPORT (SUCCEEDED|FAILED)' || true
echo "DONE. It will appear in TestFlight in 10-30 min."
