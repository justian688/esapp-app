//
//  Theme.swift
//  CameraPPP
//
//  學校風格的黑色系配色：黑板深綠、粉筆白、粉筆黃
//

import SwiftUI

enum Theme {
    /// 黑板深綠（卡片、標題區背景）
    static let chalkboard = Color(red: 0.10, green: 0.15, blue: 0.13)
    /// 更深的黑板色（列表底色）
    static let chalkboardDeep = Color(red: 0.06, green: 0.09, blue: 0.08)
    /// 粉筆黃（重點色、按鈕）
    static let chalkYellow = Color(red: 0.96, green: 0.79, blue: 0.30)
    /// 粉筆白（主要文字）
    static let chalkWhite = Color(red: 0.93, green: 0.93, blue: 0.89)
    /// 淡粉筆線
    static let chalkLine = Color.white.opacity(0.12)
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
