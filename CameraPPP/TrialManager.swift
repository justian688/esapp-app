//
//  TrialManager.swift
//  CameraPPP
//
//  新下載 7 天試用期管理
//  開始日期存在 Keychain：刪掉 App 重裝也不會重新計算（防止一直重裝白用）
//

import Foundation
import Combine
import Security

@MainActor
final class TrialManager: ObservableObject {
    @Published private(set) var firstInstallDate: Date
    @Published private(set) var isTrialActive: Bool

    init() {
        let installDate: Date
        if let keychainDate = Self.loadFromKeychain() {
            installDate = keychainDate
        } else if let savedDate = UserDefaults.standard.object(forKey: SubscriptionConfig.firstInstallDateKey) as? Date {
            // 舊版存在 UserDefaults 的日期，搬到 Keychain
            installDate = savedDate
            Self.saveToKeychain(savedDate)
        } else {
            installDate = Date()
            Self.saveToKeychain(installDate)
        }
        UserDefaults.standard.set(installDate, forKey: SubscriptionConfig.firstInstallDateKey)
        firstInstallDate = installDate
        isTrialActive = Date().timeIntervalSince(installDate) < SubscriptionConfig.trialDuration
    }

    // MARK: - Keychain（App 刪除後仍保留）

    private static let keychainService = "com.lin.energysaving.trial"

    private static func baseQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: keychainService,
         kSecAttrAccount as String: SubscriptionConfig.firstInstallDateKey]
    }

    private static func loadFromKeychain() -> Date? {
        var q = baseQuery()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let t = Double(String(decoding: data, as: UTF8.self)) else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    private static func saveToKeychain(_ date: Date) {
        let data = Data(String(date.timeIntervalSince1970).utf8)
        SecItemDelete(baseQuery() as CFDictionary)
        var q = baseQuery()
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }

    /// 更新試用狀態（試用滿 7 天時觸發付費牆）
    func refreshTrialStatus() {
        let active = Date().timeIntervalSince(firstInstallDate) < SubscriptionConfig.trialDuration
        if isTrialActive != active {
            isTrialActive = active
        }
    }

    /// 試用剩餘秒數
    var remainingTrialSeconds: TimeInterval {
        max(0, SubscriptionConfig.trialDuration - Date().timeIntervalSince(firstInstallDate))
    }

    /// 試用剩餘時間文字
    var remainingTrialText: String {
        let totalSeconds = Int(remainingTrialSeconds)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60

        if days > 0 {
            return AppLanguage.current.localized(
                "\(days)d \(hours)h remaining",
                "剩餘 \(days) 天 \(hours) 小時"
            )
        }

        if hours > 0 {
            return AppLanguage.current.localized(
                "\(hours)h \(minutes)m remaining",
                "剩餘 \(hours) 小時 \(minutes) 分鐘"
            )
        }

        return AppLanguage.current.localized(
            "\(minutes)m remaining",
            "剩餘 \(minutes) 分鐘"
        )
    }

    // MARK: - 測試工具（只在 TestFlight / Xcode 測試版使用）

    /// 把試用剩餘時間直接設成指定秒數（0 = 立刻到期），並重設提醒，讓提醒可以再跳一次
    func testSetRemaining(_ seconds: TimeInterval) {
        guard SubscriptionConfig.isTestBuild else { return }
        let start = Date().addingTimeInterval(seconds - SubscriptionConfig.trialDuration)
        Self.saveToKeychain(start)
        UserDefaults.standard.set(start, forKey: SubscriptionConfig.firstInstallDateKey)
        UserDefaults.standard.removeObject(forKey: SubscriptionConfig.trialReminderShownKey)
        UserDefaults.standard.removeObject(forKey: SubscriptionConfig.trialEndedNoticeShownKey)
        firstInstallDate = start
        isTrialActive = Date().timeIntervalSince(start) < SubscriptionConfig.trialDuration
    }

    /// 試用剩不到 1 天（還沒到期）
    var isTrialEndingSoon: Bool {
        isTrialActive && remainingTrialSeconds <= SubscriptionConfig.trialReminderLead
    }

    /// 是否應顯示付費牆（試用結束且未訂閱）
    func shouldShowPaywall(isPremium: Bool) -> Bool {
        !isPremium && !isTrialActive
    }
}
