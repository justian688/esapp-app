//
//  SettingsView.swift
//  CameraPPP
//
//  Created by Otis Lin on 2026/5/22.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(MediaPreferences.saveToPhotosKey) private var saveToPhotosLibrary = true
    @AppStorage(CameraFacing.storageKey) private var preferredCameraFacing = CameraFacing.back.rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.traditionalChinese.rawValue
    @State private var showingLanguageOptions = false
    @State private var showingCameraOptions = false
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 仿 Android 頂部導覽列 (Top App Bar)
            HStack(spacing: 20) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                Text("設定")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding()
            .background(Color.black)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // Section Header
                    Text("GENERAL SETTINGS")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.red.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 15)

                    SettingsMenuRow(
                        icon: "globe",
                        title: "語言",
                        subtitle: selectedLanguageName
                    ) {
                        showingLanguageOptions = true
                    }
                    .confirmationDialog("語言", isPresented: $showingLanguageOptions, titleVisibility: .visible) {
                        Button("中文") {
                            appLanguageRaw = AppLanguage.traditionalChinese.rawValue
                        }

                        Button("English") {
                            appLanguageRaw = AppLanguage.english.rawValue
                        }

                        Button("Cancel", role: .cancel) { }
                    }
                    
                    SettingsToggleRow(
                        icon: "photo.on.rectangle",
                        title: "錄完自動存到「照片」App",
                        subtitle: "影片和照片會另存一份到 iPhone 的「照片」，方便分享與 iCloud 備份",
                        isOn: $saveToPhotosLibrary
                    )
                    .onChange(of: saveToPhotosLibrary) { _, enabled in
                        guard enabled else { return }
                        Task {
                            let granted = await PhotoLibrarySaver.requestAccess()
                            if !granted { saveToPhotosLibrary = false }
                        }
                    }


                    SettingsMenuRow(
                        icon: "camera.rotate",
                        title: "相機鏡頭",
                        subtitle: selectedCameraFacingName
                    ) {
                        showingCameraOptions = true
                    }
                    .confirmationDialog("相機鏡頭", isPresented: $showingCameraOptions, titleVisibility: .visible) {
                        Button("前置鏡頭") {
                            preferredCameraFacing = CameraFacing.front.rawValue
                        }

                        Button("後置鏡頭") {
                            preferredCameraFacing = CameraFacing.back.rawValue
                        }

                        Button("Cancel", role: .cancel) { }
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .background(Color.black)
        .navigationBarHidden(true)
    }

    private var selectedLanguageName: String {
        AppLanguage(rawValue: appLanguageRaw)?.displayName ?? "中文"
    }

    private var selectedCameraFacingName: String {
        CameraFacing(rawValue: preferredCameraFacing)?.settingsDisplayName ?? "後置鏡頭"
    }
}

// MARK: - 帶有 Toggle 開關的 Row
struct SettingsToggleRow: View {
    var icon: String
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.red.opacity(0.8))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation { isOn.toggle() }
        }
    }
}

struct SettingsActionRow: View {
    var icon: String
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsMenuRow: View {
    var icon: String
    var title: LocalizedStringKey
    var subtitle: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsPickerRow: View {
    var icon: String
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey
    @Binding var selection: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            
            Picker("", selection: $selection) {
                ForEach(CameraFacing.allCases) { facing in
                    Text(facing.displayName)
                        .tag(facing.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}
