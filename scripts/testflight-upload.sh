#!/bin/zsh
# 在 Mac mini 上打包 es省電王（CameraPPP）並上傳到 TestFlight（只限內部測試，不會送審）
# 用法（從 Windows PowerShell）：ssh -t mac-mini 'zsh ~/esapp-app/scripts/testflight-upload.sh'
set -e
REPO=~/esapp-app
BUILD=~/esapp-build

echo "▶ 1/4 更新程式碼"
if [ -d "$REPO/.git" ]; then
  git -C "$REPO" fetch origin main && git -C "$REPO" reset --hard origin/main
else
  git clone https://github.com/justian688/esapp-app "$REPO"
fi
cd "$REPO"
echo "   版本：$(grep -m1 MARKETING_VERSION CameraPPP.xcodeproj/project.pbxproj | tr -d ' \t;') / build $(grep -m1 CURRENT_PROJECT_VERSION CameraPPP.xcodeproj/project.pbxproj | tr -dc 0-9)"

echo "▶ 2/4 解鎖鑰匙圈（請輸入 Mac mini 的登入密碼）"
security unlock-keychain ~/Library/Keychains/login.keychain-db

echo "▶ 3/4 打包（約 3–5 分鐘）"
rm -rf "$BUILD"
xcodebuild -project CameraPPP.xcodeproj -scheme CameraPPP -configuration Release \
  -destination generic/platform=iOS -archivePath "$BUILD/CameraPPP.xcarchive" \
  -allowProvisioningUpdates archive | grep -E 'error:|warning: .*CameraPPP/|ARCHIVE (SUCCEEDED|FAILED)' || true
[ -d "$BUILD/CameraPPP.xcarchive" ] || { echo "❌ 打包失敗，請把上面的 error 貼給 Claude"; exit 1; }

echo "▶ 4/4 上傳到 TestFlight"
xcodebuild -exportArchive -archivePath "$BUILD/CameraPPP.xcarchive" -exportPath "$BUILD/export" \
  -exportOptionsPlist scripts/ExportOptions.plist -allowProvisioningUpdates 2>&1 | grep -E 'error|Upload|EXPORT (SUCCEEDED|FAILED)' || true
echo "✅ 完成。約 10–30 分鐘後會出現在 App Store Connect → TestFlight"
