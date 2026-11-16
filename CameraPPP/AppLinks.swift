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
    static func shareApp(attempt: Int = 0) {
        let text = AppLanguage.current.localized("es省電王 – record a whole class with the screen off", "es省電王：黑畫面省電錄整堂課")
        // 最上層畫面還在關閉動畫中時，present 會被 iOS 忽略 → 稍後重試（最多 5 次）
        guard let top = AdsManager.topViewController(),
              !top.isBeingDismissed, !top.isBeingPresented, top.view.window != nil else {
            if attempt < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shareApp(attempt: attempt + 1) }
            }
            return
        }
        let vc = UIActivityViewController(activityItems: [text, appStoreURL], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = top.view
        vc.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
        top.present(vc, animated: true)
    }

    @MainActor
    static func open(_ url: URL) {
        UIApplication.shared.open(url)
    }
}
