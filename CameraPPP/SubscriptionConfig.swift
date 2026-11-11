//
//  SubscriptionConfig.swift
//  CameraPPP
//
//  訂閱方案設定（Product ID 與試用期）
//

import Foundation

enum SubscriptionConfig {
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

    /// 新下載免費試用：1 個月（30 天），之後才會跳出付費牆
    static let trialDuration: TimeInterval = 30 * 24 * 60 * 60

    static let firstInstallDateKey = "premiumFirstInstallDate"
    static let premiumStatusKey = "isPremiumUnlocked"

    /// 隱私權與服務條款（上架前請替換為正式網址）
    static let privacyPolicyURL = "https://example.com/privacy"
    static let termsOfUseURL = "https://example.com/terms"
}
