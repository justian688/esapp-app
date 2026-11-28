# 各 App 的版本設定（強制更新用）

每個 App 打開時會讀這裡自己的檔案：

| 檔案 | App |
|---|---|
| `../version.json` | es省電王（iOS 原生版） |
| `photo-app.json` | 愛拍照 |
| `mentora.json` | 師說 |
| `cc-music.json` | cc-music 正式版 |

- `minVersion`：低於這個版本 → 一定要更新才能用（新版上架後再調高）
- `latestVersion`：低於這個版本 → 提醒有新版，可以按「稍後」
- `message`：更新說明（空白就用預設文字）

⚠️ 新版本**審核通過、已經在 App Store 上**之後才調高，不然使用者會被要求更新卻找不到新版。
