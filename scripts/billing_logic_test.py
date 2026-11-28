"""
es省電王 收費邏輯模擬測試：逐行對照 Swift 程式（TrialManager / FeatureAccess /
MainContainerView.evaluatePaywallPresentation / CameraManager.beginRecordingSegment /
handleSegmentFinished / CaptureResolution.current / PaywallView 按鈕）。
"""
DAY = 86400
TRIAL = 7 * DAY
LEAD = DAY


class Phone:
    """一支手機：Keychain 刪 App 不會清；UserDefaults 刪 App 會清。"""
    def __init__(self, release_payments=False, test_build=True):
        self.now = 1_000_000.0
        self.keychain = {}
        self.release_payments = release_payments
        self.test_build = test_build
        self.install()

    # ---- App 安裝 / 重裝 ----
    def install(self):
        self.ud = {}
        self.app = App(self)

    def reinstall(self):
        self.install()

    # ---- SubscriptionConfig ----
    @property
    def payments_enabled(self):
        return self.release_payments or (self.test_build and self.ud.get("test_forcePayments", False))

    @property
    def free_limit(self):
        return 60 if (self.test_build and self.ud.get("test_shortFreeLimit")) else 30 * 60

    # ---- FeatureAccess.hasFullAccess ----
    def full_access(self):
        if not self.payments_enabled:
            return True
        if self.ud.get("isPremiumUnlocked"):
            return True
        start = self.ud.get("premiumFirstInstallDate")
        if start is None:
            return True
        return self.now - start < TRIAL


class App:
    def __init__(self, phone):
        self.p = phone
        # TrialManager.init
        kc = phone.keychain.get("trial")
        if kc is not None:
            start = kc
        elif "premiumFirstInstallDate" in phone.ud:
            start = phone.ud["premiumFirstInstallDate"]
            phone.keychain["trial"] = start
        else:
            start = phone.now
            phone.keychain["trial"] = start
        phone.ud["premiumFirstInstallDate"] = start
        self.first = start
        self.is_premium = phone.ud.get("isPremiumUnlocked", False)
        self.show_paywall = False
        self.allow_dismiss = True
        self.show_reminder = False
        self.recording = False
        self.free_limit_alert = False
        self.events = []
        self.saved_res = "1080p"
        self.show_4k_notice = False

    # TrialManager
    def remaining(self):
        return max(0, TRIAL - (self.p.now - self.first))

    def trial_active(self):
        return self.p.now - self.first < TRIAL

    def ending_soon(self):
        return self.trial_active() and self.remaining() <= LEAD

    def test_set_remaining(self, s):
        assert self.p.test_build
        start = self.p.now + s - TRIAL
        self.p.keychain["trial"] = start
        self.p.ud["premiumFirstInstallDate"] = start
        self.p.ud.pop("trialEndingReminderShown", None)
        self.p.ud.pop("trialEndedNoticeShown", None)
        self.p.ud.pop("fourKDowngradeNoticeShown", None)
        self.first = start

    # MainContainerView.evaluatePaywallPresentation（每秒 timer 呼叫）
    def tick(self):
        if not self.p.payments_enabled or self.is_premium:
            return
        if self.recording or self.show_paywall or self.show_reminder or self.show_4k_notice:
            return
        ud = self.p.ud
        if self.ending_soon() and not ud.get("trialEndingReminderShown"):
            ud["trialEndingReminderShown"] = True
            self.show_reminder = True
            self.events.append("提醒：明天到期")
            return
        if not self.trial_active() and self.saved_res == "4K" and not ud.get("fourKDowngradeNoticeShown"):
            ud["fourKDowngradeNoticeShown"] = True
            self.show_4k_notice = True
            self.events.append("提醒：4K 改 1080p")
        # 其他情況到期後不自動跳付費畫面

    # PaywallView：「繼續使用免費版」按鈕是否出現
    def free_button_visible(self):
        return self.allow_dismiss and not self.trial_active() and not self.is_premium

    def subscribe(self):
        self.is_premium = True
        self.p.ud["isPremiumUnlocked"] = True
        self.show_paywall = False

    # CaptureResolution.current
    def resolution(self, saved):
        requires = self.p.payments_enabled and saved == "4K"
        if requires and not self.p.full_access():
            return "1080p"
        return saved

    # CameraManager：錄一次，回傳實際錄到的秒數與各段
    def record(self, want_seconds, segment_min=0, repeat=False):
        self.recording = True
        self.free_limit_alert = False
        session_start = self.p.now
        self.warnings = []
        recorded, segments = 0.0, []
        while True:
            max_s = segment_min * 60 if segment_min > 0 else None
            capped = False
            if not self.p.full_access():
                rem = self.p.free_limit - (self.p.now - session_start)
                if rem <= 1:
                    self.recording = False
                    self.free_limit_alert = True
                    break
                if max_s is None or rem < max_s:
                    max_s, capped = rem, True
                # 錄影畫面：剩 5 分鐘、剩 1 分鐘時提前提醒（RecordingOverlayView）
                el = self.p.now - session_start
                for m in (5, 1):
                    at = self.p.free_limit - m * 60
                    if at > 0 and el <= at <= el + max_s and m not in self.warnings:
                        self.warnings.append(m)
            left = want_seconds - recorded
            seg = left if max_s is None else min(left, max_s)
            self.p.now += seg
            recorded += seg
            segments.append(round(seg))
            reached = max_s is not None and seg >= max_s and left >= max_s
            if not reached:  # 使用者自己按停止
                self.recording = False
                break
            if capped:
                self.recording = False
                self.free_limit_alert = True
                break
            if repeat:
                continue
            self.recording = False
            break
        return round(recorded), segments


def check(cond, msg, log):
    log.append(("✅" if cond else "❌") + " " + msg)
    return cond


def full_flow(round_no, segment_min, repeat, short_limit):
    log = []
    ph = Phone(release_payments=False, test_build=True)
    a = ph.app
    ok = True
    # 0. 付費總開關關著 → 全開、不跳任何東西
    a.tick()
    ok &= check(not a.show_reminder and not a.show_paywall, "付費功能關閉時不跳任何提醒", log)
    ok &= check(a.resolution("4K") == "4K", "付費功能關閉時 4K 可用", log)
    # 1. 測試工具打開模擬付費
    ph.ud["test_forcePayments"] = True
    if short_limit:
        ph.ud["test_shortFreeLimit"] = True
    limit = ph.free_limit
    a.tick()
    ok &= check(a.trial_active() and not a.show_paywall, "第 1 天：試用中、不跳付費畫面", log)
    ok &= check(a.resolution("4K") == "4K", "試用中 4K 可用", log)
    r, _ = a.record(3 * 3600, segment_min, repeat)
    ok &= check(r == 3 * 3600 or (segment_min and not repeat and r == segment_min * 60),
                f"試用中錄 3 小時不受 30 分鐘限制（實錄 {r//60} 分）", log)
    # 2. 第 3 天刪 App 重裝 → 不會重新給 7 天
    ph.now += 2 * DAY
    ph.reinstall(); a = ph.app
    ph.ud["test_forcePayments"] = True
    if short_limit:
        ph.ud["test_shortFreeLimit"] = True
    ok &= check(abs(a.remaining() - (TRIAL - 2 * DAY - r)) < 2,
                f"重裝後試用剩 {a.remaining()/DAY:.1f} 天（沒有重置成 7 天）", log)
    # 3. 錄影中剛好進入最後 1 天 → 錄影時不跳，停下後才跳
    a.test_set_remaining(23 * 3600 + 120)
    a.recording = True; ph.now += 180; a.tick()
    ok &= check(not a.show_reminder, "錄影中不打斷（不跳提醒）", log)
    a.recording = False; a.tick()
    ok &= check(a.show_reminder, "停止錄影後跳出「免費試用明天到期」", log)
    a.show_reminder = False  # 使用者按「到期後用免費版」
    a.tick(); a.tick()
    ok &= check(a.events.count("提醒：明天到期") == 1, "提醒只跳一次", log)
    # 4. 到期：試用中選了 4K → 只跳「4K 改 1080p」，其他不跳
    a.saved_res = "4K"
    ph.now += a.remaining() + 1
    for _ in range(5):
        a.tick()
    ok &= check(a.events.count("提醒：4K 改 1080p") == 1 and not a.show_paywall, "到期時正在用 4K → 只提醒一次「4K 改 1080p」，不跳付費畫面", log)
    a.show_4k_notice = False
    for _ in range(5):
        a.tick()
    ok &= check(a.events.count("提醒：4K 改 1080p") == 1 and not ph.full_access(), "之後安靜用免費版，不再跳任何提醒", log)
    # 5. 免費版限制
    ok &= check(a.resolution("4K") == "1080p", "免費版 4K 自動降成 1080p", log)
    r, segs = a.record(3 * 3600, segment_min, repeat)
    expect = limit if not (segment_min and not repeat and segment_min * 60 < limit) else segment_min * 60
    ok &= check(r == expect, f"免費版錄 3 小時 → 只錄 {r} 秒（上限 {limit} 秒，分段 {segs}）", log)
    if r == limit:
        if limit > 300:
            ok &= check(a.warnings == [5, 1], f"錄影中提前提醒：剩 5 分鐘、剩 1 分鐘（{a.warnings}）", log)
        ok &= check(a.free_limit_alert, "錄滿停止後告訴他「已錄滿 30 分鐘，影片已保存」", log)
    r2, _ = a.record(10 * 60, segment_min, repeat)
    ok &= check(r2 == min(600, limit, segment_min * 60 if segment_min else 10**9),
                f"免費版錄短的（10 分）正常結束（實錄 {r2} 秒）", log)
    # 6. 免費版重裝也不會回到試用
    ph.reinstall(); a = ph.app
    ph.ud["test_forcePayments"] = True
    if short_limit:
        ph.ud["test_shortFreeLimit"] = True
    ok &= check(not a.trial_active() and not ph.full_access(), "到期後重裝仍是免費版", log)
    # 7. 訂閱
    a.subscribe()
    ok &= check(ph.full_access() and a.resolution("4K") == "4K", "訂閱後 4K 解鎖", log)
    r, _ = a.record(3 * 3600, 0, False)
    ok &= check(r == 3 * 3600, "訂閱後錄 3 小時不中斷", log)
    a.tick()
    ok &= check(not a.show_paywall and not a.show_reminder, "訂閱後不再跳任何付費提醒", log)
    # 8. 測試工具：試用重新開始
    a.is_premium = False; ph.ud["isPremiumUnlocked"] = False
    a.test_set_remaining(TRIAL)
    ok &= check(a.trial_active() and abs(a.remaining() - TRIAL) < 1, "測試工具「試用重新開始」有效", log)
    # 9. 正式版（非測試版）：測試開關無效
    rel = Phone(release_payments=False, test_build=False)
    rel.ud["test_forcePayments"] = True
    ok &= check(not rel.payments_enabled, "App Store 正式版：測試開關無效、看不到測試工具", log)
    return ok, log


if __name__ == "__main__":
    variants = [
        (1, 0, False, False, "不分段、30 分鐘上限"),
        (2, 20, True, False, "每 20 分一段 + 重複錄影（防止分段繞過 30 分鐘）"),
        (3, 45, False, False, "每 45 分一段、不重複"),
        (4, 10, True, True, "每 10 分一段 + 重複錄影、測試用 1 分鐘上限"),
        (5, 0, False, True, "不分段、測試用 1 分鐘上限"),
    ]
    allok = True
    for n, seg, rep, short, desc in variants:
        ok, log = full_flow(n, seg, rep, short)
        allok &= ok
        print(f"\n=== 第 {n} 次：{desc} → {'全部通過' if ok else '有失敗'} ===")
        print("\n".join(log))
    print("\n總結：", "5 次全部通過" if allok else "有失敗項目")
