//
//  PhotoSettingsView.swift
//  CameraPPP
//
//  Created by Otis Lin on 2026/5/22.
//

import SwiftUI
import UIKit

struct PhotoSettingsView: View {
    @Environment(\.dismiss) var dismiss

    @AppStorage(PhotoCaptureMode.storageKey) private var photoModeRaw = PhotoCaptureMode.quality.rawValue
    @State private var showingModeOptions = false

    private var photoMode: PhotoCaptureMode {
        PhotoCaptureMode(rawValue: photoModeRaw) ?? .quality
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                Text("拍照與快速開始")
                    .font(.title2)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding()
            .background(Color.black)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: - 畫質
                    SectionHeader(title: "拍照")

                    SettingsMenuRow(
                        icon: "hq",
                        title: "拍照模式",
                        subtitle: "\(photoMode.title)：\(photoMode.subtitle)"
                    ) {
                        showingModeOptions = true
                    }

                    Divider().padding(.vertical, 5)

                    // MARK: - 捷徑與小工具
                    SectionHeader(title: "快速開始錄影")

                    ColoredIconActionRow(
                        icon: "mic.fill",
                        iconBgColor: Theme.danger.opacity(0.85),
                        title: "Siri 與捷徑",
                        subtitle: "對 Siri 說「用 es省電王 開始錄影」，或在「捷徑」App 加入主畫面"
                    ) {
                        if let url = URL(string: "shortcuts://") {
                            UIApplication.shared.open(url)
                        }
                    }

                    ColoredIconActionRow(
                        icon: "square.grid.2x2.fill",
                        iconBgColor: Theme.chalkYellow.opacity(0.6),
                        title: "主畫面小工具與控制中心",
                        subtitle: "長按主畫面空白處 → 左上角「編輯」→「加入小工具」→ 搜尋 es省電王"
                    ) {}

                    Spacer(minLength: 40)
                }
            }
        }
        .background(Color.black)
        .sheet(isPresented: $showingModeOptions) {
            WheelPickerSheet(title: "拍照模式", isPresented: $showingModeOptions, message: photoMode.subtitle) {
                Picker("拍照模式", selection: $photoModeRaw) {
                    ForEach(PhotoCaptureMode.allCases) { mode in
                        Text(tr(mode.title)).tag(mode.rawValue)
                    }
                }
            }
        }
    }
}

// MARK: - 專屬 UI 元件

struct SectionHeader: View {
    var title: LocalizedStringKey
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Theme.chalkYellow.opacity(0.85))
            .padding(.horizontal, 20)
            .padding(.top, 15)
            .padding(.bottom, 10)
    }
}

struct ColoredIconActionRow: View {
    var icon: String
    var iconBgColor: Color
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 20) {
                // 圓形背景 Icon
                ZStack {
                    Circle()
                        .fill(iconBgColor)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
