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
    @State private var albumLock = AlbumLock.shared
    @State private var showCreatePasscode = false
    @State private var showEraseOptions = false
    @State private var pendingEraseAfter: Int?
    @AppStorage(AlbumLock.faceIDKey) private var albumFaceID = true
    @AppStorage(AlbumLock.eraseAfterKey) private var albumEraseAfter = 0
    
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
                    
                    // ── 錄影 ──
                    sectionHeader("錄影設定", icon: "video.fill")

                    SettingsMenuRow(icon: "video.badge.waveform", title: "錄影畫質", subtitle: currentResolutionTitle) {
                        showingResolutionOptions = true
                    }
                    SettingsMenuRow(icon: "speedometer", title: "錄影幀數", subtitle: frameRateSubtitle) {
                        showingFrameRateOptions = true
                    }
                    SettingsMenuRow(icon: "camera.rotate", title: "相機鏡頭", subtitle: selectedCameraFacingName) {
                        showingCameraOptions = true
                    }

                    // ── 拍照與快速開始 ──
                    sectionHeader("拍照與快速開始", icon: "camera.fill")

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

                    // ── 儲存 ──
                    sectionHeader("儲存位置", icon: "externaldrive.fill")

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

                    // ── 隱私 ──
                    sectionHeader("隱私", icon: "lock.fill")

                    SettingsToggleRow(
                        icon: "lock.rectangle.stack",
                        title: "相簿密碼鎖",
                        subtitle: "打開課程相簿、課程剪輯前要輸入密碼",
                        isOn: Binding(
                            get: { albumLock.isEnabled },
                            set: { on in
                                if on { showCreatePasscode = true } else { albumLock.disable(); albumEraseAfter = 0 }
                            })
                    )
                    .accessibilityIdentifier("settings_albumLock")

                    if albumLock.isEnabled {
                        if AlbumLock.biometricsAvailable {
                            SettingsToggleRow(icon: "faceid", title: "用 Face ID 解鎖", subtitle: nil, isOn: $albumFaceID)
                        }
                        SettingsMenuRow(icon: "exclamationmark.triangle", title: "輸錯太多次清除相簿",
                                        subtitle: albumEraseAfter == 0 ? tr("關閉（建議）") : trf("連續輸錯 %lld 次清除", albumEraseAfter)) {
                            showEraseOptions = true
                        }
                        SettingsMenuRow(icon: "key", title: "更改密碼", subtitle: "") {
                            showCreatePasscode = true
                        }
                    }

                    // ── 一般（語言放最下面）──
                    sectionHeader("一般", icon: "gearshape.fill")

                    SettingsMenuRow(icon: "globe", title: "語言", subtitle: selectedLanguageName) {
                        showingLanguageOptions = true
                    }

                    if SubscriptionConfig.isTestBuild {
                        testToolsSection
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .background(Color.black)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingResolutionOptions) {
            WheelPickerSheet(title: "錄影畫質", isPresented: $showingResolutionOptions,
                             message: SubscriptionConfig.paymentsEnabled ? "畫質越高越清楚，但越耗電、檔案越大。4K 需要完整版。" : "畫質越高越清楚，但越耗電、檔案越大。") {
                Picker("錄影畫質", selection: Binding(
                    get: { effectiveResolution.rawValue },
                    set: { new in
                        let option = CaptureResolution(rawValue: new) ?? .defaultResolution
                        if option.requiresPremium && !hasFullAccess {
                            // 免費版選到 4K → 滾輪彈回原本的畫質，關掉選單後跳出升級小彈窗
                            showingResolutionOptions = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { upsellReason = .fourK }
                        } else {
                            resolutionRaw = new
                        }
                    })) {
                    ForEach(CaptureResolution.allCases) { option in
                        Text(option.requiresPremium && !hasFullAccess ? "🔒 " + option.title : option.title).tag(option.rawValue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingFrameRateOptions) {
            WheelPickerSheet(title: "錄影幀數", isPresented: $showingFrameRateOptions,
                             message: "幀數越高畫面越流暢，但越耗電、檔案越大。手機或目前畫質不支援時，會自動改用支援的最高幀數。") {
                Picker("錄影幀數", selection: $frameRateRaw) {
                    ForEach(CaptureFrameRate.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCameraOptions) {
            WheelPickerSheet(title: "相機鏡頭", isPresented: $showingCameraOptions) {
                Picker("相機鏡頭", selection: $preferredCameraFacing) {
                    Text(tr("前置鏡頭")).tag(CameraFacing.front.rawValue)
                    Text(tr("後置鏡頭")).tag(CameraFacing.back.rawValue)
                }
            }
        }
        .sheet(isPresented: $showingLanguageOptions) {
            WheelPickerSheet(title: "語言", isPresented: $showingLanguageOptions) {
                Picker("語言", selection: $appLanguageRaw) {
                    Text("中文").tag(AppLanguage.traditionalChinese.rawValue)
                    Text("English").tag(AppLanguage.english.rawValue)
                }
            }
        }
        .fullScreenCover(isPresented: $showCreatePasscode) {
            PasscodeScreen(mode: .create)
        }
        .sheet(isPresented: $showEraseOptions) {
            WheelPickerSheet(title: "輸錯太多次清除相簿", isPresented: $showEraseOptions,
                             message: "開啟後，連續輸錯密碼達到次數，相簿裡所有影片和照片都會被永久刪除，無法復原。輸錯 3 次起會先暫停一段時間。") {
                Picker("輸錯太多次清除相簿", selection: Binding(
                    get: { albumEraseAfter },
                    set: { new in
                        if new == 0 { albumEraseAfter = 0 } else { pendingEraseAfter = new }
                    })) {
                    Text(tr("關閉（建議）")).tag(0)
                    Text(trf("連續輸錯 %lld 次", 3)).tag(3)
                    Text(trf("連續輸錯 %lld 次", 5)).tag(5)
                    Text(trf("連續輸錯 %lld 次", 10)).tag(10)
                }
            }
            .confirmationDialog(tr("確定要開啟自動清除？"), isPresented: Binding(
                get: { pendingEraseAfter != nil }, set: { if !$0 { pendingEraseAfter = nil } }), titleVisibility: .visible) {
                Button(tr("開啟（我了解會永久刪除）"), role: .destructive) {
                    if let n = pendingEraseAfter { albumEraseAfter = n }
                    pendingEraseAfter = nil
                }
                Button(tr("取消"), role: .cancel) { pendingEraseAfter = nil }
            } message: {
                Text(trf("別人亂按或你自己打錯 %lld 次，所有課程影片和照片都會消失，而且救不回來。", pendingEraseAfter ?? 0))
            }
        }
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

    /// 目前實際使用的畫質（免費版存著 4K 時會用 1080p）
    private var effectiveResolution: CaptureResolution {
        let saved = CaptureResolution(rawValue: resolutionRaw) ?? .defaultResolution
        return saved.requiresPremium && !hasFullAccess ? .hd1080 : saved
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold))
            Text(tr(title)).font(.system(size: 13, weight: .bold)).tracking(1)
        }
        .foregroundColor(Theme.chalkYellow.opacity(0.85))
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 6)
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
            status = tr("付費功能關閉中（全部免費）")
        } else if subscriptionManager.isPremium {
            status = tr("已訂閱")
        } else if trialManager.isTrialActive {
            status = tr("試用中，") + trialManager.remainingTrialText
        } else {
            status = trf("免費版（每次錄影最多 %lld 分鐘、最高 1080p）", Int(SubscriptionConfig.freeRecordingLimit / 60))
        }
        return tr("目前狀態：") + status
    }

    private var frameRateSubtitle: String {
        let chosen = CaptureFrameRate(rawValue: frameRateRaw) ?? .defaultRate
        let actual = UserDefaults.standard.integer(forKey: CaptureFrameRate.actualKey)
        if actual > 0 && actual < chosen.rawValue {
            return chosen.title + trf("（這支手機目前畫質最高 %lld fps，會自動使用 %lld fps）", actual, actual)
        }
        return chosen.title
    }

    private var currentResolutionTitle: String {
        let saved = CaptureResolution(rawValue: resolutionRaw) ?? .defaultResolution
        if saved.requiresPremium && !hasFullAccess {
            return CaptureResolution.hd1080.title + tr("（4K 需完整版）")
        }
        return saved.title
    }

    private var selectedLanguageName: String {
        AppLanguage(rawValue: appLanguageRaw)?.displayName ?? tr("中文")
    }

    private var selectedCameraFacingName: String {
        CameraFacing(rawValue: preferredCameraFacing)?.settingsDisplayName ?? tr("後置鏡頭")
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
                .tint(Theme.chalkYellow)
                .accessibilityLabel(Text(title))   // 開關有名稱：語音朗讀、自動測試都找得到
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

                    if !subtitle.isEmpty {
                        Text(tr(subtitle))
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
