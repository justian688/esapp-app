//
//  TrialManager.swift
//  CameraPPP
//
//  新下載 1 個月（30 天）試用期管理
//

import Foundation
import Combine

@MainActor
final class TrialManager: ObservableObject {
    @Published private(set) var firstInstallDate: Date
    @Published private(set) var isTrialActive: Bool

    init() {
        let installDate: Date
        if let savedDate = UserDefaults.standard.object(forKey: SubscriptionConfig.firstInstallDateKey) as? Date {
            installDate = savedDate
        } else {
            let now = Date()
            installDate = now
            UserDefaults.standard.set(now, forKey: SubscriptionConfig.firstInstallDateKey)
        }
        firstInstallDate = installDate
        isTrialActive = Date().timeIntervalSince(installDate) < SubscriptionConfig.trialDuration
    }

    /// 更新試用狀態（試用滿 30 天時觸發付費牆）
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

    /// 是否應顯示付費牆（試用結束且未訂閱）
    func shouldShowPaywall(isPremium: Bool) -> Bool {
        !isPremium && !isTrialActive
    }
}
