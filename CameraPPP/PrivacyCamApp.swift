//
//  PrivacyCamApp.swift
//  CameraPPP
//
//  Created by Otis Lin on 2026/5/21.
//

import SwiftUI

@main
struct PrivacyCamApp: App {
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.traditionalChinese.rawValue
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var trialManager = TrialManager()
    @StateObject private var updateChecker = UpdateChecker()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainContainerView()
                .preferredColorScheme(.dark)
                .tint(Theme.chalkYellow)
                .environment(\.locale, Locale(identifier: appLanguageRaw))
                .environmentObject(subscriptionManager)
                .environmentObject(trialManager)
                // 強制更新：版本太舊時蓋住整個畫面
                .overlay {
                    if updateChecker.state == .required {
                        ForceUpdateView(checker: updateChecker)
                    }
                }
                // 有新版（不強制）：提醒一次，可以按稍後
                .alert(AppLanguage.current.localized("New version available", "有新版本"),
                       isPresented: Binding(get: { updateChecker.state == .optional },
                                            set: { if !$0 { updateChecker.state = .ok } })) {
                    Button(AppLanguage.current.localized("Later", "稍後"), role: .cancel) {}
                    Button(AppLanguage.current.localized("Update", "前往更新")) { updateChecker.openStore() }
                } message: {
                    Text(updateChecker.message.isEmpty
                         ? AppLanguage.current.localized("A new version is available on the App Store.", "App Store 有新版本，要現在更新嗎？")
                         : updateChecker.message)
                }
                .task { await updateChecker.check() }
                .onChange(of: scenePhase) { _, phase in
                    // 從背景回來也再檢查一次（例如去 App Store 沒更新就回來）
                    if phase == .active { Task { await updateChecker.check() } }
                    // 相簿密碼鎖：一離開 App 就重新上鎖
                    if phase == .background { AlbumLock.shared.relock() }
                }
        }
    }
}
