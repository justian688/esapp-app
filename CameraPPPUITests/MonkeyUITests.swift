//
//  MonkeyUITests.swift
//  亂按測試：每個畫面隨機點擊／滑動 20 次，檢查不閃退、不卡死、還能回到主畫面
//

import XCTest

final class MonkeyUITests: XCTestCase {
    private var app: XCUIApplication!
    private var n = 0
    /// 固定種子：出問題可以重現同一串亂按
    private var rng = SeededRandom(seed: 20261120)

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_TW"]
    }

    private func check(_ title: String, _ ok: @autoclosure () -> Bool) {
        n += 1
        let passed = ok()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = String(format: "M%02d %@", n, title)
        shot.lifetime = .keepAlways
        add(shot)
        print("MONKEY \(String(format: "%02d", n)) \(passed ? "PASS" : "FAIL") \(title)")
        XCTAssertTrue(passed, title)
    }

    private func relaunch() {
        app.terminate()
        app.launch()
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for l in ["允許", "Allow", "好", "OK"] where sb.alerts.buttons[l].exists { sb.alerts.buttons[l].tap() }
        _ = app.buttons["menuButton"].waitForExistence(timeout: 10)
        sleep(1)
    }

    private func openMenu(_ row: String) {
        app.buttons["menuButton"].tap()
        let r = app.buttons[row]
        if !r.waitForExistence(timeout: 4) { app.buttons["menuButton"].tap(); _ = r.waitForExistence(timeout: 4) }
        sleep(1)
        if r.exists { r.tap() }
        sleep(2)
    }

    /// 被帶去別的 App（App Store、分享）或系統彈窗擋住時，拉回來
    private func recover() {
        if app.state != .runningForeground { app.activate(); sleep(2) }
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for l in ["取消", "Cancel", "好", "OK", "不允許", "Don’t Allow"] where sb.alerts.buttons[l].exists { sb.alerts.buttons[l].tap() }
        // 分享選單
        for l in ["關閉", "Close"] where app.buttons[l].exists && app.otherElements["ActivityListView"].exists { app.buttons[l].tap() }
    }

    /// 隨機點擊／滑動 20 次；避開系統狀態列
    private func monkey(_ screen: String, times: Int = 20) {
        var crashed = false
        for _ in 0..<times {
            let x = rng.next(0.05, 0.95), y = rng.next(0.08, 0.95)
            let p = app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
            switch rng.int(10) {
            case 0...5: p.tap()
            case 6: p.doubleTap()
            case 7: p.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: rng.next(0.05, 0.95), dy: y)))
            case 8: app.swipeUp(velocity: .fast)
            default: app.swipeDown(velocity: .fast)
            }
            usleep(450_000)
            if app.state == .notRunning { crashed = true; break }
            recover()
        }
        check("\(screen)：亂按 \(times) 次沒閃退", !crashed && app.state == .runningForeground)
        // 還能回到主畫面（重開後主畫面正常）
        relaunch()
        check("\(screen)：亂按後重開，主畫面正常", app.buttons["menuButton"].exists && app.buttons["tab_record"].exists)
    }

    func testRandomTapsEveryScreen() throws {
        relaunch()
        // 首頁：避免真的開始錄影卡在黑畫面 → 亂按範圍包含開始鈕，按到就用雙擊結束
        monkey("首頁")

        app.buttons["tab_schedule"].tap(); sleep(1)
        monkey("排程頁")

        let screens: [(String, String)] = [
            ("menu_books.vertical.fill", "課程相簿"),
            ("menu_scissors", "課程剪輯"),
            ("menu_pencil.and.list.clipboard", "課程筆記"),
            ("menu_tablecells", "課程資訊表"),
            ("menu_gearshape.fill", "設定"),
            ("menu_paperplane.fill", "支援"),
        ]
        for (row, name) in screens {
            openMenu(row)
            monkey(name)
        }

        openMenu("menu_gearshape.fill")
        let photo = app.buttons["settings_photoSettings"]
        var i = 0
        while !(photo.exists && photo.isHittable) && i < 8 { app.swipeUp(); i += 1 }
        if photo.exists { photo.tap(); sleep(2) }
        monkey("拍照與快速開始")

        app.buttons["menuButton"].tap(); sleep(1)
        monkey("側邊欄")
    }
}

/// 可重現的隨機數（固定種子）
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func nextUInt() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state >> 11
    }
    mutating func next(_ lo: Double, _ hi: Double) -> Double {
        lo + (hi - lo) * Double(nextUInt() % 1_000_000) / 1_000_000
    }
    mutating func int(_ n: Int) -> Int { Int(nextUInt() % UInt64(n)) }
}
