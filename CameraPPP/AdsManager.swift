//
//  AdsManager.swift
//  CameraPPP
//
//  免費版廣告（Google AdMob）：7 天試用結束、還沒訂閱 → 顯示廣告；訂閱後全部關閉。
//  - 首頁下方橫幅廣告（錄影中不顯示）
//  - 每次停止錄影後一則插頁廣告（間隔至少 3 分鐘）
//  App Store 正式版用自己的 AdMob 廣告；TestFlight／Xcode 測試版自動改用 Google 測試廣告。
//

import SwiftUI
import UIKit
import GoogleMobileAds
import Combine

enum AdConfig {
    /// 廣告總開關：true = 免費版（試用結束、未訂閱）顯示廣告；false = 完全不顯示廣告、不啟動廣告 SDK
    static let adsEnabled = true

    /// 正式廣告版位（AdMob 帳號 pub-9802042309810483，App「es省電王」）
    private static let prodBanner = "ca-app-pub-9802042309810483/5273038127"        // 首頁橫幅
    private static let prodInterstitial = "ca-app-pub-9802042309810483/3768384769"  // 錄影結束插頁
    /// Google 官方測試版位：TestFlight／Xcode 測試版一律用測試廣告，避免自己點到正式廣告被 AdMob 停權
    private static let testBanner = "ca-app-pub-3940256099942544/2435281174"
    private static let testInterstitial = "ca-app-pub-3940256099942544/4411468910"

    static var bannerUnitID: String { SubscriptionConfig.isTestBuild ? testBanner : prodBanner }
    static var interstitialUnitID: String { SubscriptionConfig.isTestBuild ? testInterstitial : prodInterstitial }
    /// 兩則插頁廣告之間至少隔多久
    static let interstitialMinInterval: TimeInterval = 3 * 60
}

@MainActor
final class AdsManager: NSObject, ObservableObject, FullScreenContentDelegate {
    static let shared = AdsManager()

    private var started = false
    private var interstitial: InterstitialAd?
    private var lastInterstitialAt: Date?

    /// 現在要不要顯示廣告：付費功能開啟、沒訂閱、試用已結束
    static var shouldShowAds: Bool { AdConfig.adsEnabled && !FeatureAccess.hasFullAccess }

    func startIfNeeded() {
        guard Self.shouldShowAds, !started else { return }
        started = true
        MobileAds.shared.start(completionHandler: nil)
        loadInterstitial()
    }

    private func loadInterstitial() {
        Task {
            do {
                let ad = try await InterstitialAd.load(with: AdConfig.interstitialUnitID, request: Request())
                ad.fullScreenContentDelegate = self
                self.interstitial = ad
            } catch {
                print("插頁廣告載入失敗：\(error.localizedDescription)")
            }
        }
    }

    /// 停止錄影後呼叫：免費版且距離上一則夠久才播
    func showInterstitialAfterRecording() {
        showInterstitial(ignoringInterval: false)
    }

    /// 播一則插頁廣告（免費版才播）；ignoringInterval = 使用者剛選「繼續使用免費版」，不受 3 分鐘間隔限制
    func showInterstitial(ignoringInterval: Bool) {
        guard Self.shouldShowAds else { return }
        startIfNeeded()
        if !ignoringInterval, let last = lastInterstitialAt, Date().timeIntervalSince(last) < AdConfig.interstitialMinInterval { return }
        guard let ad = interstitial, let root = Self.topViewController() else {
            loadInterstitial()
            return
        }
        lastInterstitialAt = Date()
        ad.present(from: root)
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.interstitial = nil
            self.loadInterstitial()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            self.interstitial = nil
            self.loadInterstitial()
        }
    }

    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var vc = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }
}

/// 首頁下方的橫幅廣告
struct AdBannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let width = UIScreen.main.bounds.width
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        banner.adUnitID = AdConfig.bannerUnitID
        banner.rootViewController = AdsManager.topViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}

/// 免費版才會出現的橫幅區塊（高度約 50～60pt）
struct FreeTierBanner: View {
    var body: some View {
        AdBannerView()
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("adBanner")
            .onAppear { AdsManager.shared.startIfNeeded() }
    }
}
