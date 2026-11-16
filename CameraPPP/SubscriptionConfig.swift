//
//  SubscriptionConfig.swift
//  CameraPPP
//
//  訂閱方案設定（Product ID 與試用期）
//

import Foundation

nonisolated enum SubscriptionConfig {
    /// 付費功能總開關：false = 暫時隱藏所有付費畫面、選單與限制（測試期間）
    static let paymentsEnabledInRelease = false

    /// 實際使用的開關：正式版看上面那行；TestFlight / Xcode 測試版可在「設定 → 測試工具」暫時打開
    static var paymentsEnabled: Bool {
        paymentsEnabledInRelease || (isTestBuild && UserDefaults.standard.bool(forKey: testForcePaymentsKey))
    }

    /// 是不是測試版（Xcode 直接安裝或 TestFlight）。App Store 正式版永遠是 false，測試工具不會出現
    static var isTestBuild: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }
    static let testForcePaymentsKey = "test_forcePayments"
    static let testShortFreeLimitKey = "test_shortFreeLimit"

    /// 月訂閱 Product ID（須與 App Store Connect 一致）
    static let monthlyProductID = "com.lin.energysaving.premium.monthly"
    /// 年訂閱 Product ID（須與 App Store Connect 一致）
    static let yearlyProductID = "com.lin.energysaving.premium.yearly"

    static let allProductIDs: [String] = [
        monthlyProductID,
        yearlyProductID
    ]

    /// 預設顯示價格（台幣）；實際扣款金額以 App Store Connect 設定為準
    static let fallbackMonthlyPrice = "NT$299"
    static let fallbackYearlyPrice = "NT$899"

    /// App Store Connect 定價參考（台灣）
    /// - 方案 A（目前）：月 NT$299 / 年 NT$899（年付約省 75%）
    /// - 方案 B（入門）：月 NT$90  / 年 NT$690
    /// - 方案 C（高階）：月 NT$330 / 年 NT$990
    static let pricingNote = "請在 App Store Connect → 訂閱 → 定價選擇對應級距"

    /// 新下載免費試用：7 天，之後才會跳出付費牆
    static let trialDuration: TimeInterval = 7 * 24 * 60 * 60

    /// 免費版每次錄影最長秒數（30 分鐘）；付費版與試用期間不限
    /// 測試版可在測試工具改成 1 分鐘，方便確認會不會自動停
    static var freeRecordingLimit: TimeInterval {
        isTestBuild && UserDefaults.standard.bool(forKey: testShortFreeLimitKey) ? 60 : 30 * 60
    }
    /// 試用到期前多久提醒（1 天）
    static let trialReminderLead: TimeInterval = 24 * 60 * 60
    static let trialReminderShownKey = "trialEndingReminderShown"
    static let trialEndedNoticeShownKey = "trialEndedNoticeShown"

    static let firstInstallDateKey = "premiumFirstInstallDate"
    static let premiumStatusKey = "isPremiumUnlocked"

    /// 隱私權政策（esappok.com 官網）與服務條款（Apple 標準使用者授權合約）
    static let privacyPolicyURL = "https://esappok.com/privacy/"
    static let termsOfUseURL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
}

/// 目前能不能使用完整功能：付費功能關閉、已訂閱、或還在 7 天試用內 → 全開
nonisolated enum FeatureAccess {
    static var hasFullAccess: Bool {
        guard SubscriptionConfig.paymentsEnabled else { return true }
        if UserDefaults.standard.bool(forKey: SubscriptionConfig.premiumStatusKey) { return true }
        guard let start = UserDefaults.standard.object(forKey: SubscriptionConfig.firstInstallDateKey) as? Date else { return true }
        return Date().timeIntervalSince(start) < SubscriptionConfig.trialDuration
    }
}
