//
//  SupportView.swift
//  CameraPPP
//
//  Created by Otis Lin on 2026/5/22.
//

import SwiftUI

struct SupportView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var trialManager: TrialManager
    @State private var showPaywall = false
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.6.3"
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                Text("Support")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.leading, 10)
                
                Spacer()
            }
            .padding()
            .background(Color.black)
            
            ScrollView {
                VStack {
                    VStack(spacing: 0) {
                        
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "video.badge.plus")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 30)
                            
                            Text(AppLanguage.current.localized(
                                "es省電王 Version \(appVersion)",
                                "es省電王 版本 \(appVersion)"
                            ))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)
                                .padding(.bottom, 20)
                        }
                        
                        if SubscriptionConfig.paymentsEnabled && subscriptionManager.isPremium {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                Text(AppLanguage.current.localized(
                                    "Premium Active",
                                    "已啟用進階版"
                                ))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 25)
                            .padding(.vertical, 14)
                        }

                        VStack(spacing: 0) {
                            if SubscriptionConfig.paymentsEnabled {
                            SupportMenuRow(
                                icon: subscriptionManager.isPremium ? "crown.fill" : "cart.fill",
                                title: subscriptionManager.isPremium ? "Manage Premium" : "Upgrade to Premium"
                            ) {
                                showPaywall = true
                            }
                            }
                            
                            SupportMenuRow(icon: "calendar", title: "Change log") {
                                // 顯示更新日誌
                            }
                            
                            SupportMenuRow(icon: "square.and.arrow.up", title: "Share this app") {
                                shareApp()
                            }
                            
                            SupportMenuRow(icon: "star.fill", title: "Review this app") {
                                // 跳轉到 App Store 評分頁面
                                rateApp()
                            }
                            
                            SupportMenuRow(icon: "bag.fill", title: "More apps by me!") {
                                // 跳轉到開發者的 App Store 頁面
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .background(Color(white: 0.12))
                    .cornerRadius(15)
                    // 仿 Android 的卡片陰影
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(20)
                    
                    Spacer()
                }
            }
            .background(.black) // 淺灰色背景
        }
        .background(.black)
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall, allowDismiss: true)
                .environmentObject(subscriptionManager)
                .environmentObject(trialManager)
        }
    }
    
    // MARK: - 輔助功能實作
    
    // 分享 App 功能
    private func shareApp() {
        let appLink = "https://apps.apple.com/app/idYOUR_APP_ID" // 替換成你的 App Store 連結
        let activityVC = UIActivityViewController(activityItems: [appLink], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func rateApp() {
        let appStoreReviewURL = "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review"
        if let url = URL(string: appStoreReviewURL) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Support 專用選單列元件
struct SupportMenuRow: View {
    var icon: String
    var title: LocalizedStringKey
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
