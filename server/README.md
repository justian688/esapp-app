# Linux 課程影片接收服務

Android 版「es省電王」會將課程影片保留在手機，並在 Wi-Fi 可用時把新錄製且排入佇列的影片傳到這個服務。行動網路不會觸發上傳。Linux 主機尚未架設時，App 會先保留待上傳狀態；設定 HTTPS 網址和金鑰後即可排程。

## 上傳位置

影片放在 `/srv/esapp-course-uploads/<課程ID>/<YYYY-MM>/<media-id>.mp4`；每段影片旁會有一份 JSON，記錄課程名稱、分類、老師、拍攝時間、檔案大小與 SHA-256。影片成功上傳後仍留在手機，不會自動刪除。

## Ubuntu 24.04+ / Debian 12+ 安裝

1. 把 `server/` 複製到 Linux 主機的 `/opt/esapp-upload`，並把目錄交給服務帳號：
2. 執行：

   ```sh
   sudo apt-get update
   sudo apt-get install -y python3 python3-venv nginx certbot python3-certbot-nginx
   sudo useradd --system --home /opt/esapp-upload --shell /usr/sbin/nologin esapp-upload || true
   sudo install -d -o root -g root /opt/esapp-upload
   sudo install -d -o esapp-upload -g esapp-upload /srv/esapp-course-uploads
   sudo python3 -m venv /opt/esapp-upload/.venv
   sudo /opt/esapp-upload/.venv/bin/pip install -r /opt/esapp-upload/requirements.txt
   ```

3. 建立一把只給這個 App 使用的金鑰，保存在 root-only 環境檔：

   ```sh
   TOKEN="$(openssl rand -hex 32)"
   printf 'UPLOAD_TOKEN=%s\n' "$TOKEN" | sudo tee /etc/esapp-upload.env >/dev/null
   sudo chmod 600 /etc/esapp-upload.env
   printf '把這組金鑰輸入 Android App 的「課程影片上傳」設定：\n%s\n' "$TOKEN"
   ```

4. 設定 `nginx-esapp-upload.conf` 中的 `server_name`，安裝並啟用 Nginx 站台。DNS 必須指向這台主機，且 80/443 對外可連。

   ```sh
   sudo sed -i 's/upload.example.com/你的網域/g' /opt/esapp-upload/nginx-esapp-upload.conf
   sudo install -m 644 /opt/esapp-upload/nginx-esapp-upload.conf /etc/nginx/sites-available/esapp-upload
   sudo ln -sf /etc/nginx/sites-available/esapp-upload /etc/nginx/sites-enabled/esapp-upload
   sudo nginx -t && sudo systemctl reload nginx
   ```

   申請 HTTPS 憑證：

   ```sh
   sudo certbot --nginx -d upload.example.com
   ```

   將 `upload.example.com` 換成你自己的網域。
5. 安裝並啟動服務：

   ```sh
   sudo install -m 644 /opt/esapp-upload/esapp-upload.service /etc/systemd/system/esapp-upload.service
   sudo systemctl daemon-reload
   sudo systemctl enable --now esapp-upload
   curl -fsS https://upload.example.com/healthz
   ```

健康檢查回覆 `{"ok":true,"upload_ready":true}` 後，在 App 設定填入 `https://upload.example.com` 和上一步產生的金鑰。請勿把金鑰放進程式碼或 Git。

## 備註

- 伺服器使用單一 Bearer 金鑰驗證；此金鑰只應輸入到 App 的加密儲存欄位，並透過 HTTPS 傳送。
- 請定期備份 `/srv/esapp-course-uploads`，並確認磁碟容量足以保存課程影片。
- 目前這是檔案接收端，沒有公開瀏覽頁面；檔案可透過 SSH/SFTP 管理。
