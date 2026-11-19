//
//  CustomTopAppBar.swift
//  CameraPPP
//
//  Created by Otis Lin on 2026/5/22.
//
//  上方列：左邊選單鍵；中間「錄影／排程」膠囊切換，選中的那邊金色底滑動。
//

import SwiftUI

struct CustomTopAppBar: View {
    @Binding var isMenuOpen: Bool
    @Binding var selectedTab: Int
    @Namespace private var pill
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.traditionalChinese.rawValue

    var body: some View {
        // 切換鈕以整個螢幕置中；選單鍵疊在左邊，不會把切換鈕擠偏
        ZStack {
            HStack(spacing: 0) {
                tabButton(index: 0, icon: "video.fill", title: tr("錄影頁"), id: "tab_record")
                tabButton(index: 1, icon: "calendar.badge.clock", title: tr("排程"), id: "tab_schedule")
            }
            .padding(4)
            .frame(width: 230)
            .background(Theme.chalkboard, in: Capsule())
            .overlay(Capsule().stroke(Theme.chalkLine, lineWidth: 1))

            HStack {
                Button {
                    withAnimation(.easeInOut) { isMenuOpen.toggle() }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.chalkWhite)
                        .frame(width: 42, height: 42)
                        .background(Theme.chalkboard, in: Circle())
                        .overlay(Circle().stroke(Theme.chalkLine, lineWidth: 1))
                }
                .accessibilityIdentifier("menuButton")
                .accessibilityLabel(tr("選單"))
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.chalkLine).frame(height: 1)
        }
    }

    private func tabButton(index: Int, icon: String, title: String, id: String) -> some View {
        let selected = selectedTab == index
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selectedTab = index }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                Text(title).font(.system(size: 14, weight: selected ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(selected ? .black : Theme.chalkWhite.opacity(0.75))
            .frame(maxWidth: .infinity, minHeight: 36)
            .background {
                if selected {
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.chalkYellow.opacity(1), Theme.chalkYellow.opacity(0.8)],
                                             startPoint: .top, endPoint: .bottom))
                        .matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
