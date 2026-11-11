//
//  AppShortcuts.swift
//  CameraPPP
//
//  Siri／捷徑：「用 es省電王 開始錄影」
//  小工具與控制中心按鈕會開啟 esapp://record，同樣走這裡的流程
//

import AppIntents
import Foundation

nonisolated enum AppAction {
    static let pendingStartRecordingKey = "pendingStartRecording"
    static let startRecordingNotification = Notification.Name("AppActionStartRecording")
    static let urlScheme = "esapp"
    static let recordHost = "record"

    /// 要求 App 開啟後立刻開始錄影
    static func requestStartRecording() {
        UserDefaults.standard.set(true, forKey: pendingStartRecordingKey)
        NotificationCenter.default.post(name: startRecordingNotification, object: nil)
    }

    /// 取出待處理的開始錄影要求（取出後清除，避免重複觸發）
    static func consumePendingStartRecording() -> Bool {
        let pending = UserDefaults.standard.bool(forKey: pendingStartRecordingKey)
        if pending {
            UserDefaults.standard.set(false, forKey: pendingStartRecordingKey)
        }
        return pending
    }

    static func isRecordURL(_ url: URL) -> Bool {
        url.scheme == urlScheme && url.host == recordHost
    }
}

nonisolated struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource { "開始錄影" }
    static var description: IntentDescription? { IntentDescription("打開 es省電王 並立即開始省電錄影") }
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppAction.requestStartRecording()
        return .result()
    }
}

nonisolated struct EsAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "用 \(.applicationName) 開始錄影",
                "\(.applicationName) 開始錄影",
                "Start recording with \(.applicationName)"
            ],
            shortTitle: "開始錄影",
            systemImageName: "video.fill"
        )
    }
}
