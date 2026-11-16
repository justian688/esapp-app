//
//  BillingTests.swift
//  CameraPPPTests
//
//  收費流程測試：7 天試用（Keychain 防重裝）、到期前 1 天提醒、免費版 30 分鐘 / 4K 限制、
//  訂閱解鎖、測試工具、強制更新版本比較。CI 會用 -test-iterations 5 連跑 5 次。
//

import XCTest
@testable import CameraPPP

@MainActor
final class BillingTests: XCTestCase {
    private let d = UserDefaults.standard
    private let day: TimeInterval = 86_400

    override func setUp() async throws {
        d.set(true, forKey: SubscriptionConfig.testForcePaymentsKey)   // 模擬付費功能開啟
        d.set(false, forKey: SubscriptionConfig.testShortFreeLimitKey)
        d.set(false, forKey: SubscriptionConfig.premiumStatusKey)
        d.removeObject(forKey: SubscriptionConfig.trialReminderShownKey)
        d.removeObject(forKey: SubscriptionConfig.trialEndedNoticeShownKey)
        TrialManager().testSetRemaining(SubscriptionConfig.trialDuration)  // 每個測試都從新的 7 天開始
    }

    override func tearDown() async throws {
        d.set(false, forKey: SubscriptionConfig.testForcePaymentsKey)
        d.set(false, forKey: SubscriptionConfig.testShortFreeLimitKey)
        d.set(false, forKey: SubscriptionConfig.premiumStatusKey)
        d.removeObject(forKey: CaptureResolution.storageKey)
    }

    // MARK: - 設定值

    func testConfigValues() {
        XCTAssertEqual(SubscriptionConfig.trialDuration, 7 * day, "試用期要是 7 天")
        XCTAssertEqual(SubscriptionConfig.trialReminderLead, day, "到期前 1 天提醒")
        XCTAssertEqual(SubscriptionConfig.freeRecordingLimit, 30 * 60, "免費版每次 30 分鐘")
        XCTAssertTrue(SubscriptionConfig.isTestBuild, "Debug 版要看得到測試工具")
        XCTAssertFalse(SubscriptionConfig.paymentsEnabledInRelease, "正式版付費總開關目前應為關閉")
    }

    func testPaymentsSwitchOffMeansEverythingFree() {
        d.set(false, forKey: SubscriptionConfig.testForcePaymentsKey)
        XCTAssertFalse(SubscriptionConfig.paymentsEnabled)
        TrialManager().testSetRemaining(0)
        XCTAssertTrue(FeatureAccess.hasFullAccess, "付費功能關閉時全部免費")
        d.set(CaptureResolution.uhd4K.rawValue, forKey: CaptureResolution.storageKey)
        XCTAssertEqual(CaptureResolution.current, .uhd4K)
    }

    // MARK: - 試用期

    func testNewTrialIsActiveWithFullAccess() {
        let t = TrialManager()
        XCTAssertTrue(t.isTrialActive)
        XCTAssertFalse(t.isTrialEndingSoon)
        XCTAssertFalse(t.shouldShowPaywall(isPremium: false))
        XCTAssertTrue(FeatureAccess.hasFullAccess)
        XCTAssertEqual(t.remainingTrialSeconds, 7 * day, accuracy: 5)
    }

    func testReinstallDoesNotResetTrial() {
        TrialManager().testSetRemaining(3 * day)
        // 模擬刪 App 重裝：UserDefaults 被清掉，Keychain 還在
        d.removeObject(forKey: SubscriptionConfig.firstInstallDateKey)
        let reinstalled = TrialManager()
        XCTAssertEqual(reinstalled.remainingTrialSeconds, 3 * day, accuracy: 5, "重裝後要接著原本的天數，不能重給 7 天")
    }

    func testReinstallAfterExpiryStaysFree() {
        TrialManager().testSetRemaining(0)
        d.removeObject(forKey: SubscriptionConfig.firstInstallDateKey)
        let reinstalled = TrialManager()
        XCTAssertFalse(reinstalled.isTrialActive)
        XCTAssertFalse(FeatureAccess.hasFullAccess, "到期後重裝仍是免費版")
    }

    func testEndingSoonOneDayBefore() {
        let t = TrialManager()
        t.testSetRemaining(23 * 3600)
        XCTAssertTrue(t.isTrialActive)
        XCTAssertTrue(t.isTrialEndingSoon, "剩 23 小時要觸發「明天到期」提醒")
        XCTAssertFalse(t.shouldShowPaywall(isPremium: false), "還沒到期不能跳付費畫面")
        XCTAssertNil(d.object(forKey: SubscriptionConfig.trialReminderShownKey), "快轉要重設提醒，讓它能再跳")

        t.testSetRemaining(25 * 3600)
        XCTAssertFalse(t.isTrialEndingSoon, "剩 25 小時還不該提醒")
    }

    func testExpiredShowsPaywallAndFreeTier() {
        let t = TrialManager()
        t.testSetRemaining(0)
        XCTAssertFalse(t.isTrialActive)
        XCTAssertFalse(t.isTrialEndingSoon)
        XCTAssertTrue(t.shouldShowPaywall(isPremium: false), "到期要跳付費畫面")
        XCTAssertFalse(FeatureAccess.hasFullAccess, "到期後變免費版")
    }

    func testRefreshTrialStatusFlipsAtExpiry() {
        let t = TrialManager()
        t.testSetRemaining(1)
        XCTAssertTrue(t.isTrialActive)
        let exp = expectation(description: "1 秒後到期")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { exp.fulfill() }
        wait(for: [exp], timeout: 3)
        t.refreshTrialStatus()
        XCTAssertFalse(t.isTrialActive, "時間到 refresh 後要變成到期")
    }

    // MARK: - 免費版限制

    func test4KLockedOnlyForFreeTier() {
        d.set(CaptureResolution.uhd4K.rawValue, forKey: CaptureResolution.storageKey)
        XCTAssertTrue(CaptureResolution.uhd4K.requiresPremium)
        XCTAssertEqual(CaptureResolution.current, .uhd4K, "試用中 4K 可用")

        TrialManager().testSetRemaining(0)
        XCTAssertEqual(CaptureResolution.current, .hd1080, "免費版 4K 自動降成 1080p")

        d.set(true, forKey: SubscriptionConfig.premiumStatusKey)
        XCTAssertEqual(CaptureResolution.current, .uhd4K, "訂閱後 4K 解鎖")
    }

    func testFreeLimitTestToggle() {
        d.set(true, forKey: SubscriptionConfig.testShortFreeLimitKey)
        XCTAssertEqual(SubscriptionConfig.freeRecordingLimit, 60, "測試工具可改成 1 分鐘")
        d.set(false, forKey: SubscriptionConfig.testShortFreeLimitKey)
        XCTAssertEqual(SubscriptionConfig.freeRecordingLimit, 30 * 60)
    }

    // MARK: - 訂閱

    func testPremiumUnlocksEverythingAfterExpiry() {
        let t = TrialManager()
        t.testSetRemaining(0)
        d.set(true, forKey: SubscriptionConfig.premiumStatusKey)
        XCTAssertTrue(FeatureAccess.hasFullAccess)
        XCTAssertFalse(t.shouldShowPaywall(isPremium: true), "已訂閱不再跳付費畫面")
    }

    func testRestartTrialTool() {
        let t = TrialManager()
        t.testSetRemaining(0)
        t.testSetRemaining(SubscriptionConfig.trialDuration)
        XCTAssertTrue(t.isTrialActive)
        XCTAssertEqual(t.remainingTrialSeconds, 7 * day, accuracy: 5, "「試用重新開始」回到 7 天")
    }

    // MARK: - 強制更新

    func testVersionCompare() {
        XCTAssertLessThan(UpdateChecker.compare("1.7.0", "1.7.1"), 0)
        XCTAssertLessThan(UpdateChecker.compare("1.9", "1.10.0"), 0)
        XCTAssertEqual(UpdateChecker.compare("1.7.1", "1.7.1"), 0)
        XCTAssertGreaterThan(UpdateChecker.compare("2.0", "1.99.9"), 0)
        XCTAssertEqual(UpdateChecker.compare("1.7", "1.7.0"), 0)
    }
}
