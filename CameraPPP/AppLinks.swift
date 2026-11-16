//
//  AppLinks.swift
//  CameraPPP
//
//  App Store 相關連結與分享（es省電王 App ID 6776604268）
//

import UIKit

enum AppLinks {
    static let appID = "6776604268"
    static let developerID = "1657111165"
    static let appStoreURL = URL(string: "https://apps.apple.com/tw/app/id\(appID)")!
    static let reviewURL = URL(string: "itms-apps://apps.apple.com/app/id\(appID)?action=write-review")!
    static let developerURL = URL(string: "https://apps.apple.com/tw/developer/id\(developerID)")!
    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    /// 跳出系統分享選單，分享 App Store 連結
    @MainActor
    static func shareApp() {
        let text = AppLanguage.current.localized("es省電王 – record a whole class with the screen off", "es省電王：黑畫面省電錄整堂課")
        let vc = UIActivityViewController(activityItems: [text, appStoreURL], applicationActivities: nil)
        guard let top = AdsManager.topViewController() else { return }
        vc.popoverPresentationController?.sourceView = top.view
        vc.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
        top.present(vc, animated: true)
    }

    @MainActor
    static func open(_ url: URL) {
        UIApplication.shared.open(url)
    }
}
