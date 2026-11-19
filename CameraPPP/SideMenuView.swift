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
                    .font(.title3)
                    .fontWeight(.heavy)
                    .foregroundColor(Theme.chalkWhite)
                
                HStack(spacing: 6) {
                    Image(systemName: "graduationcap.fill")
                    Text("課堂錄影．課程筆記")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Theme.chalkYellow)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack(alignment: .bottom) {
                    Theme.chalkboard
                    // 黑板下緣的粉筆槽
                    Rectangle()
                        .fill(Color(red: 0.18, green: 0.13, blue: 0.09))
                        .frame(height: 6)
                }
            )
            
            Divider().background(Color.gray.opacity(0.5))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MenuRow(icon: "books.vertical.fill", title: "課程相簿") {
                        openPage(.gallery)
                    }
                    MenuRow(icon: "scissors", title: "課程剪輯") {
                        openPage(.trimmer)
                    }
                    MenuRow(icon: "pencil.and.list.clipboard", title: "課程筆記") {
                        openPage(.notes)
                    }
                    if SubscriptionConfig.paymentsEnabled {
                    MenuRow(
                        icon: subscriptionManager.isPremium ? "crown.fill" : "cart.fill",
                        title: subscriptionManager.isPremium ? "Premium Active" : "Upgrade Premium"
                    ) {
                        withAnimation { isMenuOpen = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            openPaywall()
                        }
                    }
                    }

                    
                    Divider().background(Color.gray.opacity(0.5)).padding(.vertical, 10)

                    MenuRow(icon: "gearshape.fill", title: "Settings") {
                        openPage(.settings)
                    }
                    
                    MenuRow(icon: "square.and.arrow.up", title: "Share this app") {
                        withAnimation { isMenuOpen = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            AppLinks.shareApp()
                        }
                    }

                    // 課程資訊表、支援放在最下面
                    MenuRow(icon: "tablecells", title: "課程資訊表") {
                        openPage(.courseInfo)
                    }
                    MenuRow(icon: "paperplane.fill", title: SubscriptionConfig.paymentsEnabled ? "Support and Upgrade" : "Support") {
                        openPage(.support)
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
/// 側邊欄左右滑動時，避免手指放開被當成點到選單項目
enum SideMenuGestureGate {
    static var lastHorizontalSwipe = Date.distantPast
    static var justSwiped: Bool { Date().timeIntervalSince(lastHorizontalSwipe) < 0.5 }
}

struct MenuRow: View {
    var icon: String
    var title: LocalizedStringKey
    var action: () -> Void
    
    var body: some View {
        Button {
            // 剛剛是在左右滑（想關掉側邊欄），不是點這一行 → 忽略
            guard !SideMenuGestureGate.justSwiped else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                
                Spacer(minLength: 0)
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            // 整列都能點，不用剛好點到文字
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuButtonStyle())
        .accessibilityIdentifier("menu_" + icon)
    }
}

struct MenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        // 點下去：文字變黃、左側亮起黃色邊條、底色亮起並輕微縮小（加上手機輕震）
        configuration.label
            .foregroundColor(configuration.isPressed ? Theme.chalkYellow : Theme.chalkWhite)
            .background(
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Theme.chalkYellow)
                        .frame(width: configuration.isPressed ? 4 : 0)
                    Theme.chalkYellow.opacity(configuration.isPressed ? 0.14 : 0)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(configuration.isPressed ? 0.96 : 1, anchor: .leading)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

enum SideMenuDestination: Hashable {
    case gallery
    case trimmer
    case settings
    case photoSettings
    case courseInfo
    case notes
    case support
}


struct ScheduleView: View {
    @State private var targetDate = Date().addingTimeInterval(300)
    @State private var showDateTimePicker = false
    @State private var showDurationOptions = false
    @State private var showCameraOptions = false
    @State private var showRepeatRecordingOptions = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @AppStorage(RecordingPreferences.segmentMinutesKey) private var selectedDurationMinutes = RecordingPreferences.defaultSegmentMinutes
    @AppStorage(RecordingPreferences.repeatRecordingKey) private var isRepeatRecordingEnabled = true
    @AppStorage(CameraFacing.storageKey) private var preferredCameraFacing = CameraFacing.defaultFacing.rawValue
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Translations.isEnglish ? "en_US" : "zh_Hant_TW")
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEE")
        return formatter.string(from: targetDate)
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        formatter.locale = Locale(identifier: Translations.isEnglish ? "en_US" : "zh_Hant_TW")
        return formatter.string(from: targetDate)
    }

    private var duration: String {
        RecordingPreferences.durationLabel(selectedDurationMinutes)
    }

    private var cameraPosition: String {
        (CameraFacing(rawValue: preferredCameraFacing) ?? CameraFacing.defaultFacing).settingsDisplayName
    }

    private var repeatRecording: String {
        isRepeatRecordingEnabled ? tr("開啟") : tr("關閉")
    }

    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    
                    CourseNotesSection()

                    Divider()
                        .background(Color.gray.opacity(0.3))
                        .padding(.top, 16)

                    ChalkSectionTitle(icon: "calendar.badge.clock", title: "排程錄影")
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    ScheduleRow(title: "開始時間", value: "\(dateString)  \(timeString)") {
                        showDateTimePicker = true
                    }
                    .accessibilityIdentifier("schedule_dateTime")
                    
                    ScheduleRow(title: "時長", value: duration) {
                        showDurationOptions = true
                    }
                    ScheduleRow(title: "相機鏡頭", value: cameraPosition) {
                        showCameraOptions = true
                    }
                    ScheduleRow(title: "重複錄影", value: repeatRecording) {
                        showRepeatRecordingOptions = true
                    }
                }
                .padding(.bottom, 20)
            }
            
            HStack(spacing: 15) {
                Button(action: {
                    targetDate = Date().addingTimeInterval(300)
                }) {
                    Text("取消")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.chalkWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.chalkboard)
                        .overlay(RoundedRectangle(cornerRadius: 25).stroke(Theme.chalkLine, lineWidth: 1))
                        .cornerRadius(25)
                }
                
                Button(action: {
                    scheduleRecording()
                }) {
                    Text("儲存")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.chalkYellow)
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
        // 日期＋時間一起選（同一組滾輪）
        .sheet(isPresented: $showDateTimePicker) {
            WheelPickerSheet(title: "開始時間", isPresented: $showDateTimePicker) {
                DatePicker("", selection: $targetDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.wheel)
                    .environment(\.locale, Locale(identifier: Translations.isEnglish ? "en_US" : "zh_Hant_TW"))
            }
        }
        .sheet(isPresented: $showRepeatRecordingOptions) {
            WheelPickerSheet(title: "重複錄影", isPresented: $showRepeatRecordingOptions) {
                Picker("重複錄影", selection: $isRepeatRecordingEnabled) {
                    Text(tr("開啟")).tag(true)
                    Text(tr("關閉")).tag(false)
                }
            }
        }
        .sheet(isPresented: $showDurationOptions) {
            WheelPickerSheet(title: "時長", isPresented: $showDurationOptions) {
                DurationTimerPicker(totalMinutes: $selectedDurationMinutes)
            }
        }
        .sheet(isPresented: $showCameraOptions) {
            WheelPickerSheet(title: "相機鏡頭", isPresented: $showCameraOptions) {
                Picker("相機鏡頭", selection: $preferredCameraFacing) {
                    Text("前置鏡頭").tag(CameraFacing.front.rawValue)
                    Text("後置鏡頭").tag(CameraFacing.back.rawValue)
                }
            }
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
                    Text(tr(value))
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
/// 全 App 統一的選擇方式：底部滑出、滾輪選、按「完成」收起
struct WheelPickerSheet<Content: View>: View {
    let title: String
    @Binding var isPresented: Bool
    var message: String? = nil
    @ViewBuilder let content: () -> Content

    init(title: String, isPresented: Binding<Bool>, message: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self._isPresented = isPresented
        self.message = message
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(tr(title))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(tr("完成")) { isPresented = false }
                    .font(.headline)
                    .foregroundColor(Theme.chalkYellow)
                    .accessibilityIdentifier("wheel_done")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            if let message {
                Text(tr(message))
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
            }

            content()
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
        }
        .presentationDetents([.height(message == nil ? 300 : 350)])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}

/// 時長：仿 iOS「計時器」— 小時、分鐘兩個滾輪；兩個都是 0 代表「不限」
struct DurationTimerPicker: View {
    @Binding var totalMinutes: Int
    @State private var hours = 0
    @State private var minutes = 0

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                wheel(selection: $hours, range: 0..<13, unit: tr("小時"))
                wheel(selection: $minutes, range: 0..<60, unit: tr("分鐘"))
            }
            .frame(height: 180)
            Text(totalMinutes == 0 ? tr("設為 0 小時 0 分鐘＝不限時長（錄到手動停止）") : RecordingPreferences.durationLabel(totalMinutes))
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .onAppear {
            hours = totalMinutes / 60
            minutes = totalMinutes % 60
        }
        .onChange(of: hours) { _, _ in totalMinutes = hours * 60 + minutes }
        .onChange(of: minutes) { _, _ in totalMinutes = hours * 60 + minutes }
    }

    private func wheel(selection: Binding<Int>, range: Range<Int>, unit: String) -> some View {
        HStack(spacing: 6) {
            Picker("", selection: selection) {
                ForEach(Array(range), id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(width: 80)
            .clipped()
            Text(unit)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 表單裡的選擇列：點一下從底部滑出滾輪（跟「時長」一樣的選法）
struct WheelSelectRow<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [(value: Value, label: String)]
    /// 緊湊樣式：標籤和值靠在一起、靠左（不會左右散開）
    var compact = false
    @State private var showing = false

    private var currentLabel: String {
        options.first { $0.value == selection }?.label ?? ""
    }

    var body: some View {
        Button { showing = true } label: {
            if compact {
                HStack(spacing: 8) {
                    Image(systemName: "graduationcap.fill").foregroundColor(Theme.chalkYellow)
                    Text(tr(title)).foregroundColor(.gray)
                    Text(currentLabel).foregroundColor(.white).fontWeight(.semibold)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            } else {
                HStack {
                    Text(tr(title)).foregroundColor(.gray)
                    Spacer()
                    Text(currentLabel).foregroundColor(.white)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showing) {
            WheelPickerSheet(title: title, isPresented: $showing) {
                Picker(tr(title), selection: $selection) {
                    ForEach(options.indices, id: \.self) { i in
                        Text(options[i].label).tag(options[i].value)
                    }
                }
            }
        }
    }
}
