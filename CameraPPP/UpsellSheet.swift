//
//  UpsellSheet.swift
//  CameraPPP
//
//  碰到付費限制時，從下方滑上來的小彈窗（只講這一件事＋年方案價格）。
//  完整的方案比較頁（PaywallView）只在側邊欄「升級完整版」、到期前一天「查看付費方案」時出現。
//

import SwiftUI
import StoreKit

enum UpsellReason: Identifiable {
    case fourK            // 免費版點了 4K
    case timeLimit        // 免費版錄滿 30 分鐘
    case fourKDowngraded  // 試用到期時正在用 4K，已改成 1080p

    var id: Int { hashValue }

    var icon: String {
        switch self {
        case .fourK, .fourKDowngraded: return "4k.tv"
        case .timeLimit: return "timer"
        }
    }

    var title: String {
        switch self {
        case .fourK:
            return AppLanguage.current.localized("4K is a Premium feature", "4K 是完整版功能")
        case .timeLimit:
            return AppLanguage.current.localized("30-minute limit reached", "已錄滿 30 分鐘")
        case .fourKDowngraded:
            return AppLanguage.current.localized("4K is now 1080p", "4K 已改為 1080p")
        }
    }

    var message: String {
        switch self {
        case .fourK:
            return AppLanguage.current.localized(
                "Subscribe to record in 4K — even small writing on the board stays sharp.",
                "訂閱完整版就能用 4K 錄影，板書小字也清楚。")
        case .timeLimit:
            return AppLanguage.current.localized(
                "This recording has been saved. Premium records a whole class without stopping.",
                "這段影片已經保存。完整版不限時長，整堂課一次錄完。")
        case .fourKDowngraded:
            return AppLanguage.current.localized(
                "Your free trial has ended, so recordings now use 1080p. Subscribe to keep 4K.",
                "免費試用已結束，之後錄影會用 1080p。訂閱完整版即可繼續用 4K。")
        }
    }

    var dismissTitle: String {
        switch self {
        case .fourK: return AppLanguage.current.localized("Not now", "先不用")
        case .timeLimit: return AppLanguage.current.localized("OK", "好")
        case .fourKDowngraded: return AppLanguage.current.localized("Use 1080p", "用 1080p 繼續")
        }
    }
}

struct UpsellSheet: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    let reason: UpsellReason
    /// 關閉彈窗
    var onClose: () -> Void
    /// 打開完整方案頁
    var onSeeAllPlans: () -> Void

    private static let gold = Color(red: 0.96, green: 0.80, blue: 0.36)

    @State private var plan: UpsellPlan = .yearly

    private enum UpsellPlan { case yearly, monthly }

    private var monthlyPrice: String {
        subscriptionManager.monthlyProduct?.displayPrice ?? SubscriptionConfig.fallbackMonthlyPrice
    }

    private var savings: Int {
        let m = NSDecimalNumber(decimal: subscriptionManager.monthlyProduct?.price ?? SubscriptionConfig.fallbackMonthlyValue).doubleValue * 12
        let y = NSDecimalNumber(decimal: subscriptionManager.yearlyProduct?.price ?? SubscriptionConfig.fallbackYearlyValue).doubleValue
        guard m > 0, y < m else { return 0 }
        return Int(((1 - y / m) * 100).rounded(.down))
    }

    private var yearlyPrice: String {
        subscriptionManager.yearlyProduct?.displayPrice ?? SubscriptionConfig.fallbackYearlyPrice
    }

    private var perMonth: String {
        let value = NSDecimalNumber(decimal: subscriptionManager.yearlyProduct?.price ?? SubscriptionConfig.fallbackYearlyValue).doubleValue / 12
        if let p = subscriptionManager.yearlyProduct {
            return value.rounded().formatted(.currency(code: p.priceFormatStyle.currencyCode).precision(.fractionLength(0)))
        }
        return "NT$\(Int(value.rounded()))"
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: reason.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Self.gold.opacity(0.9))
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Self.gold.opacity(0.12)))
                VStack(alignment: .leading, spacing: 6) {
                    Text(reason.title)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .accessibilityIdentifier("upsell_title")
                    Text(reason.message)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            // 完整版三大優勢（濃縮版對照）
            HStack(spacing: 8) {
                highlight(AppLanguage.current.localized("Unlimited", "不限時長"), free: AppLanguage.current.localized("Free: 30 min", "免費 30 分"))
                highlight("4K", free: AppLanguage.current.localized("Free: 1080p", "免費 1080p"))
                if AdConfig.adsEnabled {
                    highlight(AppLanguage.current.localized("No ads", "無廣告"), free: AppLanguage.current.localized("Free: ads", "免費有廣告"))
                }
            }

            // 年／月方案
            VStack(spacing: 8) {
                planRow(.yearly,
                        title: AppLanguage.current.localized("Yearly", "年訂閱"),
                        badge: savings > 0 ? AppLanguage.current.localized("SAVE \(savings)%", "省 \(savings)%") : nil,
                        sub: AppLanguage.current.localized("About \(perMonth)/month", "每月約 \(perMonth)"),
                        price: yearlyPrice, period: AppLanguage.current.localized("/yr", "/年"))
                planRow(.monthly,
                        title: AppLanguage.current.localized("Monthly", "月訂閱"),
                        badge: nil,
                        sub: AppLanguage.current.localized("Cancel anytime", "隨時可取消"),
                        price: monthlyPrice, period: AppLanguage.current.localized("/mo", "/月"))
            }

            Button {
                Task { await purchaseSelected() }
            } label: {
                Text(AppLanguage.current.localized("Upgrade to Full Version", "升級完整版"))
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [Color(red: 0.89, green: 0.73, blue: 0.33), Color(red: 0.81, green: 0.59, blue: 0.22)], startPoint: .leading, endPoint: .trailing)))
            }
            .accessibilityIdentifier("upsell_subscribe")

            HStack(spacing: 28) {
                Button(reason.dismissTitle) { onClose() }
                    .accessibilityIdentifier("upsell_close")
                Button(AppLanguage.current.localized("See all plans", "查看所有方案")) { onSeeAllPlans() }
                    .accessibilityIdentifier("upsell_seeAll")
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.65))
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .presentationBackground(Color(red: 0.07, green: 0.065, blue: 0.055))
        .presentationDetents([.height(AdConfig.adsEnabled ? 560 : 540)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .task { await subscriptionManager.loadProducts() }
        .onChange(of: subscriptionManager.isPremium) { _, isPremium in
            if isPremium { onClose() }
        }
    }

    private func highlight(_ title: String, free: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(Self.gold.opacity(0.95))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Self.gold.opacity(0.12)))
                .overlay(Capsule().stroke(Self.gold.opacity(0.35), lineWidth: 1))
            Text(free)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
                .strikethrough(true, color: .white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
    }

    private func planRow(_ p: UpsellPlan, title: String, badge: String?, sub: String, price: String, period: String) -> some View {
        let selected = plan == p
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { plan = p }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(selected ? Self.gold : .white.opacity(0.3))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        if let badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .foregroundColor(Self.gold)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Self.gold.opacity(0.15)))
                        }
                    }
                    Text(sub).font(.caption).foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(price).font(.headline).foregroundColor(.white)
                    Text(period).font(.caption).foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 14).fill(selected ? Self.gold.opacity(0.07) : Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Self.gold.opacity(0.7) : Color.white.opacity(0.08), lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(p == .yearly ? "upsell_yearly" : "upsell_monthly")
    }

    private func purchaseSelected() async {
        if subscriptionManager.yearlyProduct == nil || subscriptionManager.monthlyProduct == nil {
            await subscriptionManager.loadProducts()
        }
        let product = plan == .yearly ? subscriptionManager.yearlyProduct : subscriptionManager.monthlyProduct
        guard let product else {
            onSeeAllPlans()   // 商品還沒就緒：改開完整方案頁（那裡有錯誤提示與恢復購買）
            return
        }
        await subscriptionManager.purchase(product)
    }
}
