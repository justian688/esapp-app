//
//  MainContainerView.swift
//  CameraPPP
//
//  Created by Otis Lin on 2026/5/22.
//
import SwiftUI
import UIKit

struct MainContainerView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var trialManager: TrialManager
    @State private var isMenuOpen = false
    @State private var selectedTab = 0
    @AppStorage(CameraFacing.storageKey) private var preferredCameraFacingRaw = CameraFacing.defaultFacing.rawValue
    @AppStorage(CaptureResolution.storageKey) private var captureResolutionRaw = CaptureResolution.defaultResolution.rawValue
    @AppStorage(CaptureFrameRate.storageKey) private var captureFrameRateRaw = CaptureFrameRate.defaultRate.rawValue
    @State private var navigationPath: [SideMenuDestination] = []
    @State private var showPaywall = false
    @State private var allowPaywallDismiss = true
    @State private var trialCheckTimer: Timer?
    @State private var showTrialEndingReminder = false
    @State private var upsellReason: UpsellReason?
    @State private var lastUpsell: UpsellReason?
    
    @State private var cameraManager: CameraManager
    
    init() {
        let savedFacing = CameraFacing.saved
        _cameraManager = State(initialValue: CameraManager(initialCameraFacing: savedFacing))
    }
    
    /// 免費版（付費功能開啟、試用結束、未訂閱）→ 顯示廣告
    private var showAds: Bool {
        AdConfig.adsEnabled && SubscriptionConfig.paymentsEnabled && !subscriptionManager.isPremium && !trialManager.isTrialActive
    }

    private var preferredCameraFacing: CameraFacing {
        CameraFacing(rawValue: preferredCameraFacingRaw) ?? CameraFacing.defaultFacing
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .leading) {
                CameraPreview(session: cameraManager.session)
                    .ignoresSafeArea()
                    .opacity(cameraManager.isRecording ? 1 : 0.01)
                
                VStack(spacing: 0) {
                    CustomTopAppBar(isMenuOpen: $isMenuOpen, selectedTab: $selectedTab)
                        .opacity(cameraManager.isRecording ? 0 : 1)
                    
                    TabView(selection: $selectedTab) {
                        RecordView(cameraManager: cameraManager)
                            .tag(0)
                        
                        ScheduleView()
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .ignoresSafeArea(.container, edges: .bottom)

                    // 免費版（試用結束、未訂閱）：首頁下方橫幅廣告，錄影中不顯示
                    if showAds && !cameraManager.isRecording {
                        FreeTierBanner()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(cameraManager.isRecording ? 0 : 1)
                .allowsHitTesting(!cameraManager.isRecording)
                
                if isMenuOpen {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { isMenuOpen = false } }
                        .zIndex(1)
                    
                    SideMenuView(
                        isMenuOpen: $isMenuOpen,
                        openDestination: openDestination,
                        openPaywall: openPaywallManually
                    )
                    .environmentObject(subscriptionManager)
                    .environmentObject(trialManager)
                    .frame(width: min(UIScreen.main.bounds.width * 0.66, 300))
                    .transition(.move(edge: .leading))
                    .zIndex(2)
                }

                if cameraManager.isRecording {
                    RecordingOverlayView(cameraManager: cameraManager)
                        .ignoresSafeArea()
                        .zIndex(100)
                }
            }
            .navigationDestination(for: SideMenuDestination.self) { destination in
                switch destination {
                case .gallery:
                    CourseLibraryView()
                        .navigationBarBackButtonHidden(true)
                case .courseInfo:
                    CourseInfoTableView()
                        .navigationBarBackButtonHidden(true)
                case .notes:
                    CourseNotesPageView()
                        .navigationBarBackButtonHidden(true)
                case .trimmer:
                    VideoTrimmerView()
                        .navigationBarBackButtonHidden(true)
                case .settings:
                    SettingsView()
                        .navigationBarBackButtonHidden(true)
                case .photoSettings:
                    PhotoSettingsView()
                        .navigationBarBackButtonHidden(true)
                case .support:
                    SupportView()
                        .environmentObject(subscriptionManager)
                        .environmentObject(trialManager)
                        .navigationBarBackButtonHidden(true)
                }
            }
        }
        .task(id: preferredCameraFacingRaw) {
            cameraManager.updateCameraFacing(preferredCameraFacing)
        }
        .onChange(of: captureResolutionRaw) { _, _ in
            cameraManager.applyCaptureResolution()
        }
        .onChange(of: captureFrameRateRaw) { _, _ in
            cameraManager.applyFrameRateSetting()
        }
        .alert(
            "無法錄影",
            isPresented: Binding(
                get: { cameraManager.recordingErrorMessage != nil },
                set: { if !$0 { cameraManager.recordingErrorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) { cameraManager.recordingErrorMessage = nil }
        } message: {
            Text(cameraManager.recordingErrorMessage ?? "")
        }
        #if targetEnvironment(simulator)
        .task { await applyScreenshotDemo() }
        #endif
        .onAppear {
            startTrialMonitoring()
            evaluatePaywallPresentation()
            handlePendingStartRecording()
        }
        // 錄影黑屏時隱藏上方狀態列和下方白色橫條，讓整個螢幕全黑
        .statusBarHidden(cameraManager.isRecording)
        .persistentSystemOverlays(cameraManager.isRecording ? .hidden : .automatic)
        .onChange(of: cameraManager.isRecording) { _, isRecording in
            ScreenController.setRecordingActive(isRecording)
            // 免費版：停止錄影後播一則插頁廣告（錄滿 30 分鐘的情況等提示關掉後再播）
            if !isRecording && showAds {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    if !cameraManager.freeLimitReached && !showPaywall && upsellReason == nil {
                        AdsManager.shared.showInterstitialAfterRecording()
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            ScreenController.restoreBrightness()
        }
        .onOpenURL { url in
            if AppAction.isRecordURL(url) {
                AppAction.requestStartRecording()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppAction.startRecordingNotification)) { _ in
            handlePendingStartRecording()
        }
        .onDisappear {
            trialCheckTimer?.invalidate()
            trialCheckTimer = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            trialManager.refreshTrialStatus()
            evaluatePaywallPresentation()
        }
        .onChange(of: trialManager.isTrialActive) { _, _ in
            evaluatePaywallPresentation()
        }
        .onChange(of: subscriptionManager.isPremium) { _, isPremium in
            if isPremium {
                showPaywall = false
            }
        }
        .alert(
            AppLanguage.current.localized("Your free trial ends tomorrow", "免費試用明天到期"),
            isPresented: $showTrialEndingReminder
        ) {
            Button(AppLanguage.current.localized("See Premium plans", "查看付費方案")) {
                openPaywallManually()
            }
            Button(AppLanguage.current.localized("Continue with Free", "到期後用免費版"), role: .cancel) { }
        } message: {
            Text(AppLanguage.current.localized(
                "After the trial you can subscribe to keep everything, or keep using the free version (recordings up to 30 minutes, up to 1080p).",
                "試用結束後，你可以訂閱繼續使用完整功能，或改用免費版繼續錄影（每次最多 30 分鐘、最高 1080p）。"
            ))
        }
        // 碰到限制：從下方滑上來的小彈窗
        .sheet(item: $upsellReason) { reason in
            UpsellSheet(reason: reason, onClose: {
                upsellReason = nil
            }, onSeeAllPlans: {
                upsellReason = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { openPaywallManually() }
            })
            .environmentObject(subscriptionManager)
        }
        .onChange(of: cameraManager.freeLimitReached) { _, reached in
            guard reached else { return }
            cameraManager.freeLimitReached = false
            lastUpsell = .timeLimit
            upsellReason = .timeLimit
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall, allowDismiss: allowPaywallDismiss)
                .environmentObject(subscriptionManager)
                .environmentObject(trialManager)
        }
    }

    #if targetEnvironment(simulator)
    /// 模擬器自動截圖用：放入示範資料並打開指定畫面
    private func applyScreenshotDemo() async {
        guard let screen = ScreenshotDemo.screen else { return }
        await ScreenshotDemo.seedIfNeeded()
        try? await Task.sleep(for: .seconds(1))
        switch screen {
        case "menu": withAnimation { isMenuOpen = true }
        case "gallery": navigationPath = [.gallery]
        case "courseInfo": navigationPath = [.courseInfo]
        case "notes": navigationPath = [.notes]
        case "pencil": selectedTab = 1
        case "guide": cameraManager.isRecording = true
        default: break
        }
    }
    #endif

    /// Siri 捷徑、小工具要求開始錄影：回到錄影頁並在相機就緒後開始錄
    private func handlePendingStartRecording() {
        guard AppAction.consumePendingStartRecording() else { return }
        isMenuOpen = false
        navigationPath.removeAll()
        selectedTab = 0
        guard !cameraManager.isRecording else { return }
        cameraManager.startRecordingWhenReady()
    }

    private func openDestination(_ destination: SideMenuDestination) {
        navigationPath.append(destination)
    }

    /// 側邊欄 / Support 手動開啟付費牆
    private func openPaywallManually() {
        allowPaywallDismiss = true
        showPaywall = true
    }

    /// 每秒檢查試用是否到期，到期立即弹出付費牆
    private func startTrialMonitoring() {
        trialCheckTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                trialManager.refreshTrialStatus()
                evaluatePaywallPresentation()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        trialCheckTimer = timer
    }

    /// 只在試用到期前 1 天提醒一次，讓使用者選擇付費或到期後用免費版
    private func evaluatePaywallPresentation() {
        guard SubscriptionConfig.paymentsEnabled, !subscriptionManager.isPremium else { return }
        guard !cameraManager.isRecording, !showPaywall, !showTrialEndingReminder, upsellReason == nil else { return }
        let defaults = UserDefaults.standard

        if trialManager.isTrialEndingSoon,
           !defaults.bool(forKey: SubscriptionConfig.trialReminderShownKey) {
            defaults.set(true, forKey: SubscriptionConfig.trialReminderShownKey)
            showTrialEndingReminder = true
            return
        }

        // 到期時正在用 4K：告訴他已改成 1080p，可訂閱繼續用 4K（只一次）
        if !trialManager.isTrialActive,
           captureResolutionRaw == CaptureResolution.uhd4K.rawValue,
           !defaults.bool(forKey: SubscriptionConfig.fourKDowngradeNoticeShownKey) {
            defaults.set(true, forKey: SubscriptionConfig.fourKDowngradeNoticeShownKey)
            lastUpsell = .fourKDowngraded
            upsellReason = .fourKDowngraded
        }
        // 其他情況到期後直接變免費版，不自動跳付費畫面
    }
}
