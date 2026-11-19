//
//  SupportView.swift
//  CameraPPP
//
//  Created by Otis Lin on 2026/5/22.
//
//  支援頁：上方 App 卡片（名稱、版本、目前方案），下面分成三組選項
//

import SwiftUI

struct SupportView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var trialManager: TrialManager
    @State private var showPaywall = false

    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                        .foregroundColor(Theme.chalkWhite)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(tr("返回"))
                Text("Support")
                    .font(.title2.weight(.bold))
                    .foregroundColor(Theme.chalkWhite)
                Spacer()
            }
            .padding(.horizontal, 8)

            ScrollView {
                VStack(spacing: 22) {
                    heroCard

                    if SubscriptionConfig.paymentsEnabled {
                        group(title: "完整版") {
                            SupportMenuRow(
                                icon: subscriptionManager.isPremium ? "crown.fill" : "sparkles",
                                tint: Theme.chalkYellow,
                                title: subscriptionManager.isPremium ? "Manage Premium" : "Upgrade to Premium",
                                subtitle: subscriptionManager.isPremium ? "變更或取消訂閱" : "不限時長、4K、無廣告"
                            ) {
                                if subscriptionManager.isPremium {
                                    AppLinks.open(AppLinks.manageSubscriptionsURL)
                                } else {
                                    showPaywall = true
                                }
                            }
                        }
                    }

                    group(title: "支持我們") {
                        SupportMenuRow(icon: "star.fill", tint: Color(red: 0.85, green: 0.65, blue: 0.25),
                                       title: "Review this app", subtitle: "到 App Store 給我們評分") {
                            AppLinks.open(AppLinks.reviewURL)
                        }
                        divider
                        SupportMenuRow(icon: "square.and.arrow.up", tint: Color(red: 0.35, green: 0.6, blue: 0.5),
                                       title: "Share this app", subtitle: "推薦給同學、朋友") {
                            AppLinks.shareApp()
                        }
                    }

                    group(title: "更多") {
                        SupportMenuRow(icon: "clock.arrow.circlepath", tint: Color(red: 0.4, green: 0.5, blue: 0.7),
                                       title: "Change log", subtitle: "每個版本更新了什麼") {
                            AppLinks.open(AppLinks.appStoreURL)
                        }
                        divider
                        SupportMenuRow(icon: "square.grid.2x2.fill", tint: Color(red: 0.6, green: 0.45, blue: 0.6),
                                       title: "More apps by me!", subtitle: "看看我們做的其他 App") {
                            AppLinks.open(AppLinks.developerURL)
                        }
                    }

                    Text("Made with ♥ in Taiwan")
                        .font(.footnote)
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall, allowDismiss: true)
                .environmentObject(subscriptionManager)
                .environmentObject(trialManager)
        }
    }

    // MARK: App 卡片

    private var heroCard: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.chalkboard, Theme.chalkboardDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.chalkYellow.opacity(0.5), lineWidth: 1.5))
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(Theme.chalkYellow)
            }
            Text("es省電王")
                .font(.title2.weight(.bold))
                .foregroundColor(Theme.chalkWhite)
            Text(AppLanguage.current.localized("Version \(appVersion)", "版本 \(appVersion)"))
                .font(.subheadline)
                .foregroundColor(.gray)
            if SubscriptionConfig.paymentsEnabled {
                planBadge
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Theme.chalkboard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.chalkLine, lineWidth: 1))
    }

    private var planBadge: some View {
        let (icon, text): (String, String) = {
            if subscriptionManager.isPremium { return ("checkmark.seal.fill", tr("完整版已啟用")) }
            if trialManager.isTrialActive { return ("hourglass", tr("試用中，") + trialManager.remainingTrialText) }
            return ("person.fill", tr("免費版"))
        }()
        return Label(text, systemImage: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(subscriptionManager.isPremium ? .black : Theme.chalkWhite)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(subscriptionManager.isPremium ? Theme.chalkYellow : Color.white.opacity(0.08), in: Capsule())
    }

    // MARK: 群組

    private func group<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr(title))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.chalkYellow.opacity(0.85))
                .padding(.leading, 6)
            VStack(spacing: 0) { content() }
                .background(Theme.chalkboard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.chalkLine, lineWidth: 1))
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.chalkLine).frame(height: 1).padding(.leading, 64)
    }
}

// MARK: - Support 專用選單列元件
struct SupportMenuRow: View {
    var icon: String
    var tint: Color = Theme.chalkYellow
    var title: LocalizedStringKey
    var subtitle: String = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(tint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.chalkWhite)
                    if !subtitle.isEmpty {
                        Text(tr(subtitle))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
