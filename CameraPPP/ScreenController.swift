//
//  ScreenController.swift
//  CameraPPP
//
//  錄影時讓螢幕不自動鎖定（鎖定會讓錄影中斷），黑屏時把亮度降到最低省電
//

import UIKit

@MainActor
enum ScreenController {
    private static var savedBrightness: CGFloat?

    /// 錄影中保持螢幕不鎖定
    static func setRecordingActive(_ active: Bool) {
        UIApplication.shared.isIdleTimerDisabled = active
        if !active { restoreBrightness() }
    }

    /// 黑屏模式：亮度降到最低（記住原本亮度）
    static func dimForBlackScreen() {
        if savedBrightness == nil {
            savedBrightness = UIScreen.main.brightness
        }
        UIScreen.main.brightness = 0
    }

    /// 恢復原本亮度
    static func restoreBrightness() {
        guard let saved = savedBrightness else { return }
        UIScreen.main.brightness = saved
        savedBrightness = nil
    }
}
