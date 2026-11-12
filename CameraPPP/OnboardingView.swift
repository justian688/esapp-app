//
//  OnboardingView.swift
//  CameraPPP
//
//  第一次打開 App 的介紹頁：說明功能後才詢問相機與麥克風權限
//

import SwiftUI

nonisolated enum OnboardingState {
    static let storageKey = "hasCompletedOnboarding"

    static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: storageKey)
    }
}

struct OnboardingView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "video.badge.checkmark")
                .font(.system(size: 64))
                .foregroundColor(.red)

            VStack(spacing: 8) {
                Text(verbatim: "es省電王")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                Text("上課、講座長時間錄影，省電不發燙")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 18) {
                OnboardingRow(icon: "moon.fill", title: "省電黑屏錄影", detail: "錄影時螢幕全黑並降低亮度，長時間錄影也不燙")
                OnboardingRow(icon: "camera.fill", title: "錄影中快速拍照", detail: "點一下畫面就能拍下投影片或板書，不中斷錄影")
                OnboardingRow(icon: "repeat", title: "自動分段重複錄影", detail: "依設定時長自動存檔並接著錄，不怕一次錄太長")
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 10) {
                Text("接下來會請你允許使用相機和麥克風，才能錄下畫面和聲音。")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button(action: onStart) {
                    Text("開始使用")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .cornerRadius(28)
                }
                .padding(.horizontal, 28)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

private struct OnboardingRow: View {
    let icon: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.red)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(detail)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
}
