//
//  SideMenuView.swift
//  CameraPPP
//
//  Created by Otis Lin on 2026/5/22.
//
import SwiftUI

struct SideMenuView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Binding var isMenuOpen: Bool
    var openDestination: (SideMenuDestination) -> Void
    var openPaywall: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Image("aaa")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 40)
                
                Text(verbatim: "es省電王")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("省電錄影，一鍵開錄")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemGray6))
            
            Divider().background(Color.gray.opacity(0.5))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MenuRow(icon: "play.rectangle.on.rectangle", title: "Gallery") {
                        openPage(.gallery)
                    }
                    MenuRow(icon: "scissors", title: "Video Trimmer") {
                        openPage(.trimmer)
                    }
                    MenuRow(icon: "gearshape.fill", title: "Settings") {
                        openPage(.settings)
                    }
                    MenuRow(
                        icon: subscriptionManager.isPremium ? "crown.fill" : "cart.fill",
                        title: subscriptionManager.isPremium ? "Premium Active" : "Upgrade Premium"
                    ) {
                        withAnimation { isMenuOpen = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            openPaywall()
                        }
                    }

                    MenuRow(icon: "paperplane.fill", title: "Support and Upgrade") {
                        openPage(.support)
                    }
                    
                    Divider().background(Color.gray.opacity(0.5)).padding(.vertical, 10)
                    
                    MenuRow(icon: "square.and.arrow.up", title: "Share this app") {
                        withAnimation { isMenuOpen = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            // shareApp() // 呼叫你的分享邏輯
                        }
                    }
                }
                .padding(.vertical)
            }
            Spacer()
        }
        .background(Color.black)
        .ignoresSafeArea()
    }

    private func openPage(_ destination: SideMenuDestination) {
        withAnimation {
            isMenuOpen = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            openDestination(destination)
        }
    }
}

// MARK: - 側邊欄選單列
struct MenuRow: View {
    var icon: String
    var title: LocalizedStringKey
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(MenuButtonStyle())
    }
}

struct MenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .red : .white)
            .background(configuration.isPressed ? Color.red.opacity(0.2) : Color.clear)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

enum SideMenuDestination: Hashable {
    case gallery
    case trimmer
    case settings
    case photoSettings
    case support
}


struct ScheduleView: View {
    @State private var targetDate = Date().addingTimeInterval(300)
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @State private var showDurationOptions = false
    @State private var showCameraOptions = false
    @State private var showRepeatRecordingOptions = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @AppStorage(RecordingPreferences.segmentMinutesKey) private var selectedDurationMinutes = RecordingPreferences.defaultSegmentMinutes
    @AppStorage(RecordingPreferences.repeatRecordingKey) private var isRepeatRecordingEnabled = true
    @AppStorage(CameraFacing.storageKey) private var preferredCameraFacing = CameraFacing.back.rawValue
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: targetDate)
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: targetDate)
    }

    private var duration: String {
        RecordingPreferences.durationLabel(selectedDurationMinutes)
    }

    private var cameraPosition: String {
        (CameraFacing(rawValue: preferredCameraFacing) ?? .back).settingsDisplayName
    }

    private var repeatRecording: String {
        isRepeatRecordingEnabled ? "開啟" : "關閉"
    }

    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    
                    Text("Set Up a Recording Automatically")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    ScheduleRow(title: "DATE", value: dateString) {
                        showDatePicker = true
                    }
                    
                    ScheduleRow(title: "TIME", value: timeString) {
                        showTimePicker = true
                    }
                    
                    ScheduleRow(title: "時長", value: duration) {
                        showDurationOptions = true
                    }
                    ScheduleRow(title: "相機鏡頭", value: cameraPosition) {
                        showCameraOptions = true
                    }
                    ScheduleRow(title: "重複錄影", value: repeatRecording) {
                        showRepeatRecordingOptions = true
                    }
                    .confirmationDialog("重複錄影", isPresented: $showRepeatRecordingOptions, titleVisibility: .visible) {
                        Button("開啟") {
                            isRepeatRecordingEnabled = true
                        }

                        Button("關閉") {
                            isRepeatRecordingEnabled = false
                        }

                        Button("Cancel", role: .cancel) { }
                    }

                    Divider()
                        .background(Color.gray.opacity(0.4))
                        .padding(.top, 8)

                    CourseNotesSection()
                }
                .padding(.bottom, 20)
            }
            
            HStack(spacing: 15) {
                Button(action: {
                    targetDate = Date().addingTimeInterval(300)
                }) {
                    Text("CANCEL")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.6))
                        .cornerRadius(25)
                }
                
                Button(action: {
                    scheduleRecording()
                }) {
                    Text("SCHEDULE")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(25)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .padding(.top, 10)
            .background(Color.black)
        }
        .background(Color.black)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Schedule"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showDatePicker) {
            VStack {
                DatePicker("Select Date", selection: $targetDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                Button("Done") { showDatePicker = false }
                    .font(.headline)
                    .padding()
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showDurationOptions) {
            WheelPickerSheet(title: "時長", isPresented: $showDurationOptions) {
                Picker("時長", selection: $selectedDurationMinutes) {
                    ForEach(RecordingPreferences.durationOptions, id: \.self) { minutes in
                        Text(RecordingPreferences.durationLabel(minutes)).tag(minutes)
                    }
                }
            }
        }
        .sheet(isPresented: $showCameraOptions) {
            WheelPickerSheet(title: "相機鏡頭", isPresented: $showCameraOptions) {
                Picker("相機鏡頭", selection: $preferredCameraFacing) {
                    Text("後置鏡頭").tag(CameraFacing.back.rawValue)
                    Text("前置鏡頭").tag(CameraFacing.front.rawValue)
                }
            }
        }
        .sheet(isPresented: $showTimePicker) {
            VStack {
                DatePicker("Select Time", selection: $targetDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()
                Button("Done") { showTimePicker = false }
                    .font(.headline)
                    .padding()
            }
            .presentationDetents([.medium])
        }
    }
    
    // MARK: - 排程邏輯
    private func scheduleRecording() {
        if targetDate < Date() {
            alertMessage = AppLanguage.current.localized("Please select a future time.", "請選擇未來的時間。")
            showAlert = true
            return
        }
        
        // 按下「設定排程」時才詢問通知權限
        NotificationManager.shared.requestPermission()
        NotificationManager.shared.scheduleNotification(at: targetDate)
        
        alertMessage = AppLanguage.current.localized(
            "Recording scheduled successfully!\nYou will receive a notification at \(timeString).",
            "錄影排程已成功建立！\n您將在 \(timeString) 收到通知。"
        )
        showAlert = true
    }
}

struct ScheduleRow: View {
    var title: LocalizedStringKey
    var value: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if !value.isEmpty {
                    Text(value)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}


/// 底部滑動選單（滾輪）
struct WheelPickerSheet<Content: View>: View {
    let title: String
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button("完成") { isPresented = false }
                    .font(.headline)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            content()
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}
