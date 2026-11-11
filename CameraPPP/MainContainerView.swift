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
    @AppStorage(CameraFacing.storageKey) private var preferredCameraFacingRaw = CameraFacing.back.rawValue
    @AppStorage(CaptureResolution.storageKey) private var captureResolutionRaw = CaptureResolution.hd720.rawValue
    @State private var navigationPath: [SideMenuDestination] = []
    @State private var showPaywall = false
    @State private var allowPaywallDismiss = true
    @State private var trialCheckTimer: Timer?
    
    @State private var cameraManager: CameraManager
    
    init() {
        let savedFacing = CameraFacing(rawValue: UserDefaults.standard.integer(forKey: CameraFacing.storageKey)) ?? .back
        _cameraManager = State(initialValue: CameraManager(initialCameraFacing: savedFacing))
    }
    
    private var preferredCameraFacing: CameraFacing {
        CameraFacing(rawValue: preferredCameraFacingRaw) ?? .back
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
                    .frame(width: UIScreen.main.bounds.width * 0.75)
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
                    GalleryView()
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
        .onAppear {
            startTrialMonitoring()
            evaluatePaywallPresentation()
            handlePendingStartRecording()
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
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall, allowDismiss: allowPaywallDismiss)
                .environmentObject(subscriptionManager)
                .environmentObject(trialManager)
        }
    }

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

    /// 試用結束後自動顯示付費牆（不可關閉，直到訂閱）
    private func evaluatePaywallPresentation() {
        guard trialManager.shouldShowPaywall(isPremium: subscriptionManager.isPremium) else { return }
        allowPaywallDismiss = false
        showPaywall = true
    }
}
