//
//  AdsManager.swift
//  CameraPPP
//
//  免費版廣告（Google AdMob）：7 天試用結束、還沒訂閱 → 顯示廣告；訂閱後全部關閉。
//  - 首頁下方橫幅廣告（錄影中不顯示）
//  - 每次停止錄影後一則插頁廣告（間隔至少 3 分鐘）
//  目前用的是 Google 官方「測試廣告」ID，上架前要換成自己 AdMob 帳號的 ID（見 AdConfig）。
//

import SwiftUI
import UIKit
import GoogleMobileAds
import Combine

enum AdConfig {
    /// ⚠️ 上架前換成自己的 AdMob ID（Info.plist 的 GADApplicationIdentifier 也要換）
    static let bannerUnitID = "ca-app-pub-3940256099942544/2435281174"        // Google 測試橫幅
    static let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"  // Google 測試插頁
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
    static var shouldShowAds: Bool { !FeatureAccess.hasFullAccess }

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
        guard Self.shouldShowAds else { return }
        startIfNeeded()
        if let last = lastInterstitialAt, Date().timeIntervalSince(last) < AdConfig.interstitialMinInterval { return }
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
