//
//  SettingsView.swift
//  CameraPPP
//
//  Created by Otis Lin on 2026/5/22.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(MediaPreferences.saveToPhotosKey) private var saveToPhotosLibrary = false
    @AppStorage(CameraFacing.storageKey) private var preferredCameraFacing = CameraFacing.defaultFacing.rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.traditionalChinese.rawValue
    @State private var showingLanguageOptions = false
    @State private var showingCameraOptions = false
    @AppStorage(CaptureResolution.storageKey) private var resolutionRaw = CaptureResolution.defaultResolution.rawValue
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var trialManager: TrialManager
    @AppStorage(SubscriptionConfig.testForcePaymentsKey) private var testForcePayments = false
    @AppStorage(SubscriptionConfig.testShortFreeLimitKey) private var testShortFreeLimit = false
    @State private var showingResolutionOptions = false
    @AppStorage(CaptureFrameRate.storageKey) private var frameRateRaw = CaptureFrameRate.defaultRate.rawValue
    @State private var showingFrameRateOptions = false
    @State private var showPaywall = false
    @State private var upsellReason: UpsellReason?
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 仿 Android 頂部導覽列 (Top App Bar)
            HStack(spacing: 20) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                .accessibilityIdentifier("settings_back")
                
                Text("設定")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding()
            .background(Color.black)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // Section Header
                    Text("GENERAL SETTINGS")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.red.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 15)

                    SettingsMenuRow(
                        icon: "globe",
                        title: "語言",
                        subtitle: selectedLanguageName
                    ) {
                        showingLanguageOptions = true
                    }
                    .confirmationDialog("語言", isPresented: $showingLanguageOptions, titleVisibility: .visible) {
                        Button("中文") {
                            appLanguageRaw = AppLanguage.traditionalChinese.rawValue
                        }

                        Button("English") {
                            appLanguageRaw = AppLanguage.english.rawValue
                        }

                        Button("Cancel", role: .cancel) { }
                    }
                    
                    SettingsToggleRow(
                        icon: "photo.on.rectangle",
                        title: "錄完自動存到「照片」App",
                        subtitle: "影片和照片會另存一份到 iPhone 的「照片」，方便分享與 iCloud 備份",
                        isOn: $saveToPhotosLibrary
                    )
                    .onChange(of: saveToPhotosLibrary) { _, enabled in
                        guard enabled else { return }
                        Task {
                            let granted = await PhotoLibrarySaver.requestAccess()
                            if !granted { saveToPhotosLibrary = false }
                        }
                    }


                    SettingsMenuRow(
                        icon: "camera.rotate",
                        title: "相機鏡頭",
                        subtitle: selectedCameraFacingName
                    ) {
                        showingCameraOptions = true
                    }
                    .confirmationDialog("相機鏡頭", isPresented: $showingCameraOptions, titleVisibility: .visible) {
                        Button("前置鏡頭") {
                            preferredCameraFacing = CameraFacing.front.rawValue
                        }

                        Button("後置鏡頭") {
                            preferredCameraFacing = CameraFacing.back.rawValue
                        }

                        Button("Cancel", role: .cancel) { }
                    }

                    SettingsMenuRow(
                        icon: "video.badge.waveform",
                        title: "錄影畫質",
                        subtitle: currentResolutionTitle
                    ) {
                        showingResolutionOptions = true
                    }
                    .confirmationDialog("錄影畫質", isPresented: $showingResolutionOptions, titleVisibility: .visible) {
                        ForEach(CaptureResolution.allCases) { option in
                            Button(option.requiresPremium && !hasFullAccess ? "🔒 " + option.title : option.title) {
                                if option.requiresPremium && !hasFullAccess {
                                    upsellReason = .fourK
                                } else {
                                    resolutionRaw = option.rawValue
                                }
                            }
                        }
                        Button("取消", role: .cancel) { }
                    } message: {
                        Text(SubscriptionConfig.paymentsEnabled ? "畫質越高越清楚，但越耗電、檔案越大。4K 需要完整版。" : "畫質越高越清楚，但越耗電、檔案越大。")
                    }
                    
                    SettingsMenuRow(
                        icon: "speedometer",
                        title: "錄影幀數",
                        subtitle: frameRateSubtitle
                    ) {
                        showingFrameRateOptions = true
                    }
                    .confirmationDialog("錄影幀數", isPresented: $showingFrameRateOptions, titleVisibility: .visible) {
                        ForEach(CaptureFrameRate.allCases) { option in
                            Button(option.title) { frameRateRaw = option.rawValue }
                        }
                        Button("取消", role: .cancel) { }
                    } message: {
                        Text("幀數越高畫面越流暢，但越耗電、檔案越大。手機或目前畫質不支援時，會自動改用支援的最高幀數。")
                    }

                    NavigationLink(value: SideMenuDestination.photoSettings) {
                        HStack(alignment: .center, spacing: 20) {
                            Image(systemName: "camera.badge.ellipsis")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("拍照與快速開始")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                Text("拍照模式、Siri 捷徑、主畫面小工具")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings_photoSettings")

                    if SubscriptionConfig.isTestBuild {
                        testToolsSection
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .background(Color.black)
        .navigationBarHidden(true)
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall, allowDismiss: true)
        }
        .sheet(item: $upsellReason) { reason in
            UpsellSheet(reason: reason, onClose: {
                upsellReason = nil
            }, onSeeAllPlans: {
                upsellReason = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showPaywall = true }
            })
            .environmentObject(subscriptionManager)
        }
    }

    /// 已訂閱或還在試用期 → 4K 可用
    private var hasFullAccess: Bool {
        subscriptionManager.isPremium || FeatureAccess.hasFullAccess
    }

    /// 測試工具：只在 TestFlight / Xcode 測試版出現，App Store 正式版看不到
    private var testToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🧪 測試工具（只有測試版看得到）")
                .font(.headline)
                .foregroundColor(.orange)

            Text(testStatusText)
                .accessibilityIdentifier("test_status")
                .font(.subheadline)
                .foregroundColor(.white)

            Toggle("模擬付費功能開啟", isOn: $testForcePayments).accessibilityIdentifier("test_forcePayments")
            Toggle("免費版上限改成 1 分鐘", isOn: $testShortFreeLimit).accessibilityIdentifier("test_shortLimit")

            Group {
                Button("試用重新開始（剩 7 天）") { trialManager.testSetRemaining(SubscriptionConfig.trialDuration) }.accessibilityIdentifier("test_restart")
                Button("快轉到剩 23 小時（會跳「明天到期」提醒）") { trialManager.testSetRemaining(23 * 3600) }.accessibilityIdentifier("test_23h")
                Button("快轉到剩 1 分鐘（看到期畫面）") { trialManager.testSetRemaining(60) }.accessibilityIdentifier("test_1min")
                Button("立刻到期（變免費版）") { trialManager.testSetRemaining(0) }.accessibilityIdentifier("test_expire")
            }
            .foregroundColor(Theme.chalkYellow)

            Text("改完回到錄影首頁，約 1 秒內就會跳出對應的提醒或付費畫面。")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .toggleStyle(SwitchToggleStyle(tint: .orange))
        .foregroundColor(.white)
        .padding(16)
        .background(Color(white: 0.12))
        .cornerRadius(14)
        .padding(.horizontal)
        .padding(.top, 24)
    }

    private var testStatusText: String {
        let status: String
        if !SubscriptionConfig.paymentsEnabled {
            status = "付費功能關閉中（全部免費）"
        } else if subscriptionManager.isPremium {
            status = "已訂閱"
        } else if trialManager.isTrialActive {
            status = "試用中，" + trialManager.remainingTrialText
        } else {
            status = "免費版（每次錄影最多 \(Int(SubscriptionConfig.freeRecordingLimit / 60)) 分鐘、最高 1080p）"
        }
        return "目前狀態：" + status
    }

    private var frameRateSubtitle: String {
        let chosen = CaptureFrameRate(rawValue: frameRateRaw) ?? .defaultRate
        let actual = UserDefaults.standard.integer(forKey: CaptureFrameRate.actualKey)
        if actual > 0 && actual < chosen.rawValue {
            return chosen.title + "（這支手機目前畫質最高 \(actual) fps，會自動使用 \(actual) fps）"
        }
        return chosen.title
    }

    private var currentResolutionTitle: String {
        let saved = CaptureResolution(rawValue: resolutionRaw) ?? .defaultResolution
        if saved.requiresPremium && !hasFullAccess {
            return CaptureResolution.hd1080.title + "（4K 需完整版）"
        }
        return saved.title
    }

    private var selectedLanguageName: String {
        AppLanguage(rawValue: appLanguageRaw)?.displayName ?? "中文"
    }

    private var selectedCameraFacingName: String {
        CameraFacing(rawValue: preferredCameraFacing)?.settingsDisplayName ?? "後置鏡頭"
    }
}

// MARK: - 帶有 Toggle 開關的 Row
struct SettingsToggleRow: View {
    var icon: String
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.red.opacity(0.8))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation { isOn.toggle() }
        }
    }
}

struct SettingsActionRow: View {
    var icon: String
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsMenuRow: View {
    var icon: String
    var title: LocalizedStringKey
    var subtitle: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsPickerRow: View {
    var icon: String
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey
    @Binding var selection: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            
            Picker("", selection: $selection) {
                ForEach(CameraFacing.allCases) { facing in
                    Text(facing.displayName)
                        .tag(facing.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}
