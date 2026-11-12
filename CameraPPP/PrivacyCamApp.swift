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
    
    var body: some Scene {
        WindowGroup {
            MainContainerView()
                .preferredColorScheme(.dark)
                .tint(Theme.chalkYellow)
                .environment(\.locale, Locale(identifier: appLanguageRaw))
                .environmentObject(subscriptionManager)
                .environmentObject(trialManager)
        }
    }
}
