//
//  Theme.swift
//  CameraPPP
//
//  學校風格的黑色系配色：黑板深綠、粉筆白、粉筆黃
//

import SwiftUI

enum Theme {
    /// 黑板深綠（卡片、標題區背景）
    static let chalkboard = Color(red: 0.07, green: 0.09, blue: 0.08)
    /// 更深的黑板色（列表底色）
    static let chalkboardDeep = Color(red: 0.04, green: 0.05, blue: 0.05)
    /// 粉筆黃（重點色、按鈕）
    static let chalkYellow = Color(red: 0.55, green: 0.48, blue: 0.30)
    /// 粉筆白（主要文字）
    static let chalkWhite = Color(red: 0.78, green: 0.78, blue: 0.75)
    /// 淡粉筆線
    static let chalkLine = Color.white.opacity(0.08)
    /// 完整版專用亮金色（付費頁、升級小彈窗）
    static let premiumGold = Color(red: 0.96, green: 0.80, blue: 0.36)
    static let premiumGoldDeep = Color(red: 0.85, green: 0.62, blue: 0.22)
    /// 危險動作（刪除、錄影中）
    static let danger = Color(red: 0.86, green: 0.33, blue: 0.30)
}

/// 黑板風格的區塊標題，例如「排程錄影」「課程筆記」
struct ChalkSectionTitle: View {
    let icon: String
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .tracking(1)
        }
        .foregroundColor(Theme.chalkYellow)
    }
}
