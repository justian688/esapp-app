//
//  PaywallView.swift
//  CameraPPP
//
//  付費訂閱畫面
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var trialManager: TrialManager
    @Binding var isPresented: Bool
    /// 試用結束自動弹出時為 false，不可關閉；手動開啟時為 true
    var allowDismiss: Bool = true

    @State private var selectedPlan: PaywallPlan = .yearly
    @State private var crownPulse = false

    private var monthlyPriceText: String {
        subscriptionManager.monthlyProduct?.displayPrice ?? SubscriptionConfig.fallbackMonthlyPrice
    }

    private var yearlyPriceText: String {
        subscriptionManager.yearlyProduct?.displayPrice ?? SubscriptionConfig.fallbackYearlyPrice
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.09, blue: 0.06), .black, .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    headerSection
                    featureSection
                    planSection
                    actionSection
                    footerSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }

            // 讀取價格／購買中：只顯示小轉圈，不擋住按鈕（價格讀取卡住時仍可關閉付費畫面）
            if subscriptionManager.isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.6)))
                    .allowsHitTesting(false)
            }
        }
        .interactiveDismissDisabled(!allowDismiss)
        .task {
            await subscriptionManager.loadProducts()
        }
        .alert(isPresented: $subscriptionManager.showAlert) {
            Alert(
                title: Text("Premium"),
                message: Text(subscriptionManager.alertMessage ?? ""),
                dismissButton: .default(Text("OK")) {
                    if subscriptionManager.isPremium {
                        isPresented = false
                    }
                }
            )
        }
    }

    // MARK: - 樣式

    private static let gold = Color(red: 0.96, green: 0.80, blue: 0.36)
    private static let card = Color(white: 0.10)
    private static let line = Color.white.opacity(0.08)

    // MARK: - 價格計算

    private var monthlyValue: Decimal {
        subscriptionManager.monthlyProduct?.price ?? SubscriptionConfig.fallbackMonthlyValue
    }

    private var yearlyValue: Decimal {
        subscriptionManager.yearlyProduct?.price ?? SubscriptionConfig.fallbackYearlyValue
    }

    /// 年訂閱換算每月多少錢
    private var yearlyPerMonthText: String {
        let perMonth = (NSDecimalNumber(decimal: yearlyValue).doubleValue / 12).rounded()
        if let product = subscriptionManager.yearlyProduct {
            return perMonth.formatted(.currency(code: product.priceFormatStyle.currencyCode).precision(.fractionLength(0)))
        }
        return "NT$\(Int(perMonth))"
    }

    /// 年訂閱比月訂閱省多少（%）
    private var yearlySavingsPercent: Int {
        let fullYear = NSDecimalNumber(decimal: monthlyValue * 12).doubleValue
        let yearly = NSDecimalNumber(decimal: yearlyValue).doubleValue
        guard fullYear > 0, yearly < fullYear else { return 0 }
        return Int(((1 - yearly / fullYear) * 100).rounded(.down))
    }

    private var ctaTitle: String {
        switch selectedPlan {
        case .yearly:
            return AppLanguage.current.localized("Subscribe yearly · \(yearlyPriceText)/yr", "訂閱年方案 · \(yearlyPriceText)/年")
        case .monthly:
            return AppLanguage.current.localized("Subscribe monthly · \(monthlyPriceText)/mo", "訂閱月方案 · \(monthlyPriceText)/月")
        }
    }

    // MARK: - 標題

    private var headerSection: some View {
        VStack(spacing: 14) {
            if allowDismiss {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .accessibilityIdentifier("paywall_close")
                }
            }

            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Self.gold.opacity(0.35), .clear], center: .center, startRadius: 4, endRadius: 60))
                    .frame(width: 120, height: 120)
                Image(systemName: "crown.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(LinearGradient(colors: [Self.gold, Color(red: 0.85, green: 0.6, blue: 0.2)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Self.gold.opacity(crownPulse ? 0.8 : 0.3), radius: crownPulse ? 18 : 8)
                    .scaleEffect(crownPulse ? 1.06 : 1.0)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { crownPulse = true }
            }
            .padding(.top, allowDismiss ? -16 : 8)

            Text(AppLanguage.current.localized("Record every class, start to finish", "整堂課完整錄下來"))
                .font(.title2.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Group {
                if trialManager.isTrialActive {
                    Label(AppLanguage.current.localized("Free trial · ", "免費試用中 · ") + trialManager.remainingTrialText, systemImage: "clock")
                        .foregroundColor(Self.gold)
                } else {
                    Text(AppLanguage.current.localized(
                        "Your 7-day free trial has ended. Subscribe, or keep using the free version.",
                        "7 天免費試用已結束。可以訂閱進階版，或繼續使用免費版。"
                    ))
                    .foregroundColor(.white.opacity(0.6))
                }
            }
            .font(.subheadline)
            .multilineTextAlignment(.center)
        }
    }

    // MARK: - 免費版 vs 進階版 對照表

    private var featureSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text(AppLanguage.current.localized("Feature", "功能"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(AppLanguage.current.localized("Free", "免費版"))
                    .frame(width: 80)
                HStack(spacing: 3) {
                    Image(systemName: "crown.fill").font(.system(size: 10))
                    Text(AppLanguage.current.localized("Premium", "進階版"))
                }
                .foregroundColor(Self.gold)
                .frame(width: 80)
            }
            .font(.caption.bold())
            .foregroundColor(.white.opacity(0.5))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            compareRow(AppLanguage.current.localized("Recording length", "錄影時長"),
                       free: .text(AppLanguage.current.localized("30 min", "30 分鐘")),
                       premium: .text(AppLanguage.current.localized("Unlimited", "不限")), highlight: true)
            compareRow(AppLanguage.current.localized("Video quality", "錄影畫質"),
                       free: .text("1080p"), premium: .text("4K"), highlight: true)
            if AdConfig.adsEnabled {
                compareRow(AppLanguage.current.localized("Ads", "廣告"),
                           free: .text(AppLanguage.current.localized("Has ads", "有廣告")),
                           premium: .text(AppLanguage.current.localized("Ad-free", "無廣告")), highlight: true)
            }
            compareRow(AppLanguage.current.localized("Up to 60 fps", "最高 60 fps"), free: .check, premium: .check)
            compareRow(AppLanguage.current.localized("Scheduled recording", "排程錄影"), free: .check, premium: .check)
            compareRow(AppLanguage.current.localized("Trimming & course notes", "剪輯、課程筆記"), free: .check, premium: .check, isLast: true)
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(Self.card))
        .overlay(
            // 進階版那一欄的金色外框
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Self.gold.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 80)
                    .padding(.vertical, 4)
            }
            .padding(.horizontal, 16)
        )
    }

    private enum CompareValue {
        case text(String)
        case check
    }

    private func compareRow(_ title: String, free: CompareValue, premium: CompareValue, highlight: Bool = false, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(Self.line).frame(height: 1)
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: highlight ? .semibold : .regular))
                    .foregroundColor(.white.opacity(highlight ? 1 : 0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                compareCell(free, isPremium: false).frame(width: 80)
                compareCell(premium, isPremium: true).frame(width: 80)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
    }

    @ViewBuilder
    private func compareCell(_ value: CompareValue, isPremium: Bool) -> some View {
        switch value {
        case .text(let t):
            if isPremium {
                // 進階版優勢：金色發光標籤
                Text(t)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(LinearGradient(colors: [Self.gold, Color(red: 0.90, green: 0.66, blue: 0.22)], startPoint: .top, endPoint: .bottom))
                    )
                    .shadow(color: Self.gold.opacity(0.7), radius: 6)
            } else {
                Text(t)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.45))
                    .strikethrough(false)
            }
        case .check:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isPremium ? Self.gold : .white.opacity(0.45))
        }
    }

    // MARK: - 方案

    private var planSection: some View {
        VStack(spacing: 12) {
            planCard(
                plan: .yearly,
                title: AppLanguage.current.localized("Yearly", "年訂閱"),
                price: yearlyPriceText,
                period: AppLanguage.current.localized("/yr", "/年"),
                subtitle: AppLanguage.current.localized("About \(yearlyPerMonthText)/month", "每月約 \(yearlyPerMonthText)"),
                badge: yearlySavingsPercent > 0
                    ? AppLanguage.current.localized("SAVE \(yearlySavingsPercent)%", "省 \(yearlySavingsPercent)%")
                    : AppLanguage.current.localized("BEST VALUE", "最划算")
            )
            planCard(
                plan: .monthly,
                title: AppLanguage.current.localized("Monthly", "月訂閱"),
                price: monthlyPriceText,
                period: AppLanguage.current.localized("/mo", "/月"),
                subtitle: AppLanguage.current.localized("Cancel anytime", "隨時可取消")
            )
        }
    }

    private func planCard(plan: PaywallPlan, title: String, price: String, period: String, subtitle: String, badge: String? = nil) -> some View {
        let selected = selectedPlan == plan
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { selectedPlan = plan }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selected ? Self.gold : .white.opacity(0.3))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.white)
                        if let badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Self.gold))
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text(period)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(selected ? Self.gold.opacity(0.10) : Self.card))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Self.gold : Self.line, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 按鈕

    private var actionSection: some View {
        VStack(spacing: 14) {
            Button {
                Task { await purchaseSelectedPlan() }
            } label: {
                Text(ctaTitle)
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(colors: [Self.gold, Color(red: 0.90, green: 0.68, blue: 0.25)], startPoint: .leading, endPoint: .trailing))
                    )
                    .overlay(ShimmerSweep().clipShape(RoundedRectangle(cornerRadius: 16)))
                    .shadow(color: Self.gold.opacity(0.45), radius: 14, y: 4)
            }
            .accessibilityIdentifier("paywall_subscribe")

            HStack(spacing: 24) {
                Button {
                    Task { await subscriptionManager.restorePurchases() }
                } label: {
                    Text(AppLanguage.current.localized("Restore Purchases", "恢復購買"))
                }

                if allowDismiss && !trialManager.isTrialActive && !subscriptionManager.isPremium {
                    Button {
                        isPresented = false
                    } label: {
                        Text(AppLanguage.current.localized("Continue with Free", "繼續使用免費版"))
                    }
                    .accessibilityIdentifier("paywall_continueFree")
                }
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.65))
        }
    }

    private var footerSection: some View {
        VStack(spacing: 8) {
            Text(AppLanguage.current.localized(
                "Payment will be charged to your Apple ID. Subscription renews automatically unless canceled at least 24 hours before the end of the current period.",
                "費用將從 Apple ID 扣款。訂閱會自動續訂，除非在目前期間結束前至少 24 小時取消。"
            ))
            .font(.caption2)
            .foregroundColor(.white.opacity(0.35))
            .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                if let termsURL = URL(string: SubscriptionConfig.termsOfUseURL) {
                    Link(AppLanguage.current.localized("Terms of Use", "使用條款"), destination: termsURL)
                }
                if let privacyURL = URL(string: SubscriptionConfig.privacyPolicyURL) {
                    Link(AppLanguage.current.localized("Privacy Policy", "隱私權政策"), destination: privacyURL)
                }
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.5))
        }
        .padding(.top, 4)
    }

    private func purchaseSelectedPlan() async {
        if subscriptionManager.monthlyProduct == nil || subscriptionManager.yearlyProduct == nil {
            await subscriptionManager.loadProducts()
        }

        let product: Product?

        switch selectedPlan {
        case .monthly:
            product = subscriptionManager.monthlyProduct
        case .yearly:
            product = subscriptionManager.yearlyProduct
        }

        guard let product else {
            subscriptionManager.alertMessage = AppLanguage.current.localized(
                "Subscription is not ready yet. Please confirm products are configured in App Store Connect, or try again on TestFlight with a sandbox account.",
                "訂閱商品尚未就緒。請確認 App Store Connect 已建立訂閱商品，或使用 TestFlight 沙盒帳號再試。"
            )
            subscriptionManager.showAlert = true
            return
        }

        await subscriptionManager.purchase(product)
    }
}

private enum PaywallPlan {
    case monthly
    case yearly
}


/// 進階版欄位：金色漸層底＋發光外框＋流動光澤
private struct PremiumColumnGlow: View {
    let gold: Color
    @State private var glow = false

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(LinearGradient(colors: [gold.opacity(0.22), gold.opacity(0.06)], startPoint: .top, endPoint: .bottom))
            .overlay(ShimmerSweep(period: 3.2).clipShape(RoundedRectangle(cornerRadius: 14)))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(LinearGradient(colors: [gold, gold.opacity(0.4), gold], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
            )
            .shadow(color: gold.opacity(glow ? 0.55 : 0.2), radius: glow ? 14 : 6)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { glow = true }
            }
            .allowsHitTesting(false)
    }
}

/// 斜向掃過的一道光
private struct ShimmerSweep: View {
    var period: Double = 2.6
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, .white.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: max(geo.size.width, geo.size.height) * 0.6)
                .rotationEffect(.degrees(20))
                .offset(x: phase * geo.size.width * 1.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: period).repeatForever(autoreverses: false)) { phase = 1 }
        }
    }
}
