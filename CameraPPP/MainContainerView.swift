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
    @State private var navigationPath: [SideMenuDestination] = []
    @State private var showPaywall = false
    @State private var allowPaywallDismiss = true
    @State private var trialCheckTimer: Timer?
    @State private var showTrialEndingReminder = false
    
    @State private var cameraManager: CameraManager
    
    init() {
        let savedFacing = CameraFacing.saved
        _cameraManager = State(initialValue: CameraManager(initialCameraFacing: savedFacing))
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
        .alert(
            AppLanguage.current.localized("30-minute free limit reached", "已錄滿免費版 30 分鐘"),
            isPresented: Binding(
                get: { cameraManager.freeLimitReached },
                set: { if !$0 { cameraManager.freeLimitReached = false } }
            )
        ) {
            Button(AppLanguage.current.localized("Upgrade", "升級進階版")) {
                cameraManager.freeLimitReached = false
                openPaywallManually()
            }
            Button(AppLanguage.current.localized("OK", "好"), role: .cancel) { }
        } message: {
            Text(AppLanguage.current.localized(
                "This recording has been saved. Premium removes the time limit.",
                "這段影片已經保存。升級進階版即可不限時長錄影。"
            ))
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

    /// 試用到期前 1 天提醒一次；到期當下再顯示一次付費方案（可關閉，關掉就是繼續用免費版）
    private func evaluatePaywallPresentation() {
        guard SubscriptionConfig.paymentsEnabled, !subscriptionManager.isPremium else { return }
        guard !cameraManager.isRecording, !showPaywall, !showTrialEndingReminder else { return }
        let defaults = UserDefaults.standard

        if trialManager.isTrialEndingSoon,
           !defaults.bool(forKey: SubscriptionConfig.trialReminderShownKey) {
            defaults.set(true, forKey: SubscriptionConfig.trialReminderShownKey)
            showTrialEndingReminder = true
            return
        }

        if trialManager.shouldShowPaywall(isPremium: subscriptionManager.isPremium),
           !defaults.bool(forKey: SubscriptionConfig.trialEndedNoticeShownKey) {
            defaults.set(true, forKey: SubscriptionConfig.trialEndedNoticeShownKey)
            allowPaywallDismiss = true
            showPaywall = true
        }
    }
}
