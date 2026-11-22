//
//  AllFeaturesUITests.swift
//  CameraPPPUITests
//
//  把 App 每個畫面、每個主要按鈕都實際點一遍（CI 會錄影）。
//  每一步印出 FEAT PASS/FAIL，報告用；點不到的東西記成 FAIL 但不中斷，繼續測下一項。
//

import XCTest

final class AllFeaturesUITests: XCTestCase {
    private var app: XCUIApplication!
    private var n = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_TW"]
    }

    // MARK: - 小工具

    private func pause(_ s: UInt32 = 2) { sleep(s) }

    private func check(_ title: String, _ ok: @autoclosure () -> Bool) {
        n += 1
        let passed = ok()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = String(format: "F%02d %@", n, title)
        shot.lifetime = .keepAlways
        add(shot)
        print("FEAT \(String(format: "%02d", n)) \(passed ? "PASS" : "FAIL") \(title)")
        XCTAssertTrue(passed, title)
    }

    private func tapIfExists(_ e: XCUIElement, timeout: TimeInterval = 4) -> Bool {
        guard e.waitForExistence(timeout: timeout) else { return false }
        if !e.isHittable { app.swipeUp(velocity: .slow) }
        guard e.isHittable else { return false }
        e.tap()
        return true
    }

    private func text(_ s: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", s)).firstMatch
    }

    private func button(_ s: String) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", s)).firstMatch
    }

    private func dismissSystemAlerts() {
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<3 {
            let alert = sb.alerts.firstMatch
            guard alert.waitForExistence(timeout: 2) else { return }
            for l in ["允許", "Allow", "好", "OK"] where alert.buttons[l].exists {
                alert.buttons[l].tap(); break
            }
        }
    }

    /// 每一段都從首頁重新開始，避免上一段卡住影響下一段
    private func relaunch() {
        app.terminate()
        app.launch()
        dismissSystemAlerts()
        _ = app.buttons["menuButton"].waitForExistence(timeout: 10)
        pause(1)
    }

    private func openMenu(_ id: String) -> Bool {
        guard tapIfExists(app.buttons["menuButton"]) else { return false }
        let row = app.buttons[id]
        if !row.waitForExistence(timeout: 4) { _ = tapIfExists(app.buttons["menuButton"]) }
        pause(1)
        let ok = tapIfExists(row)
        pause(2)
        return ok
    }

    // MARK: - 全功能巡檢

    /// 滾輪選單：一格一格轉，直到目前值包含指定文字（先往下找、再往上找）
    @discardableResult
    private func pickWheel(containing sub: String, maxSteps: Int = 8) -> Bool {
        let wheel = app.pickerWheels.firstMatch
        guard wheel.waitForExistence(timeout: 3) else { return false }
        for dy in [0.68, 0.32] {
            for _ in 0..<maxSteps {
                guard wheel.exists else { return true }   // 選到上鎖項目時選單會自動關閉
                if ((wheel.value as? String) ?? "").contains(sub) { return true }
                wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: dy)).tap()
                usleep(600_000)
            }
        }
        return ((wheel.value as? String) ?? "").contains(sub)
    }

    private func wheelDone() {
        let done = app.buttons["wheel_done"]
        if done.waitForExistence(timeout: 2) { done.tap() }
        sleep(1)
    }

    private func scrollToElement(_ e: XCUIElement, max: Int = 8) {
        var i = 0
        while !(e.exists && e.isHittable) && i < max { app.swipeUp(velocity: .slow); i += 1 }
    }

    func testEveryFeature() throws {
        relaunch()

        // 1. 首頁
        check("首頁：有「開始上課」按鈕", button("開始上課").exists || text("開始上課").exists)
        check("首頁：有目前課程卡片", text("目前課程").exists)

        // 2. 選擇課程
        if tapIfExists(text("目前課程")) {
            pause(2)
            check("點目前課程 → 打開選課程畫面", text("不指定課程").exists || button("關閉").exists)
            _ = tapIfExists(button("關閉"))
            pause(1)
        } else {
            check("點目前課程 → 打開選課程畫面", false)
        }

        // 3. 開始錄影（模擬器沒有相機，預期跳出「無法錄影」說明）
        _ = tapIfExists(button("開始上課"))
        pause(3)
        let noCam = app.alerts.firstMatch
        check("按開始上課：模擬器沒相機時會說明原因（不閃退）", noCam.exists || app.buttons["menuButton"].exists)
        if noCam.exists { _ = tapIfExists(noCam.buttons.firstMatch) }
        pause(1)

        // 4. 排程錄影分頁
        _ = tapIfExists(app.buttons["tab_schedule"])
        pause(2)
        check("排程錄影分頁：打開正常", text("排程錄影").exists)
        check("排程錄影分頁：有時長、相機鏡頭、重複錄影設定", text("時長").exists && text("重複錄影").exists)
        app.swipeUp(velocity: .slow)
        pause(1)
        check("排程錄影分頁：課程筆記區塊已移除", !text("課程筆記").exists)
        _ = tapIfExists(app.buttons["tab_record"])
        pause(1)

        // 5. 課程相簿
        relaunch()
        check("側邊欄 → 課程相簿：打開正常", openMenu("menu_books.vertical.fill") && text("課程相簿").waitForExistence(timeout: 4))

        // 6. 課程資訊表：新增一堂課
        relaunch()
        let infoOpened = openMenu("menu_tablecells") && text("課程資訊表").waitForExistence(timeout: 4)
        check("側邊欄 → 課程資訊表：打開正常", infoOpened)
        if tapIfExists(button("新增")) {
            pause(2)
            let field = app.textFields.firstMatch
            if field.waitForExistence(timeout: 3) {
                field.tap()
                field.typeText("測試課程A")
            }
            pause(1)
            _ = tapIfExists(button("儲存"))
            pause(2)
            let added = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "測試課程")).firstMatch
            check("課程資訊表：新增課程「測試課程A」後出現在列表", added.exists)
        } else {
            check("課程資訊表：找得到「新增」按鈕", false)
        }

        // 7. 課程剪輯
        relaunch()
        _ = tapIfExists(app.buttons["menuButton"])
        pause(1)
        check("側邊欄沒有「課程剪輯」（改在相簿點影片進去剪）", !app.buttons["menu_scissors"].exists)

        // 8. 課程筆記：新增一則
        relaunch()
        let notesOpened = openMenu("menu_pencil.and.list.clipboard") && text("課程筆記").waitForExistence(timeout: 4)
        check("側邊欄 → 課程筆記：打開正常", notesOpened)
        if tapIfExists(button("新增")) {
            pause(2)
            let editor = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
            if editor.waitForExistence(timeout: 3) {
                editor.tap()
                editor.typeText("期中考範圍第三章")
            }
            pause(1)
            _ = tapIfExists(button("儲存"))
            pause(2)
            check("課程筆記：新增筆記後出現在列表", text("期中考範圍第三章").exists)
        } else {
            check("課程筆記：找得到「新增」按鈕", false)
        }

        // 9. 支援頁
        relaunch()
        check("側邊欄 → 支援：打開正常", openMenu("menu_paperplane.fill"))
        check("支援頁：選單文字是中文（沒有殘留英文）", !text("Change log").exists && !text("More apps").exists)

        // 10. 分享 App（側邊欄）
        relaunch()
        _ = openMenu("menu_square.and.arrow.up")
        var shareSheet = false
        for _ in 0..<6 where !shareSheet {   // 最多等 6 秒
            pause(1)
            shareSheet = app.otherElements["ActivityListView"].exists || app.navigationBars["UIActivityContentView"].exists || app.buttons["Close"].exists || app.buttons["關閉"].exists
        }
        check("側邊欄 → 分享這個 App：跳出分享選單", shareSheet)
        if app.buttons["Close"].exists { app.buttons["Close"].tap() } else if app.buttons["關閉"].exists { app.buttons["關閉"].tap() }
        pause(1)

        // 11. 設定頁
        relaunch()
        check("側邊欄 → 設定：打開正常", openMenu("menu_gearshape.fill") && text("設定").waitForExistence(timeout: 4))
        // 相機鏡頭（滾輪選單）
        if tapIfExists(text("相機鏡頭")) {
            pause(1)
            let hasFront = pickWheel(containing: "前置")
            let hasBack = pickWheel(containing: "後置")
            check("設定：相機鏡頭滾輪有前置／後置", hasFront && hasBack)
            wheelDone()
        }
        // 幀數（滾輪選單）
        if tapIfExists(text("錄影幀數")) {
            pause(1)
            let all = pickWheel(containing: "24 fps") && pickWheel(containing: "60 fps") && pickWheel(containing: "30 fps")
            check("設定：錄影幀數滾輪有 24／30／60 fps", all)
            wheelDone()
            check("設定：選 30 fps 後顯示 30 fps", text("30 fps").exists)
        }
        // 拍照與快速開始
        if tapIfExists(app.buttons["settings_photoSettings"]) {
            pause(2)
            check("設定 → 拍照與快速開始：打開正常", text("拍照與快速開始").exists || text("Siri").exists)
            app.swipeUp(velocity: .slow)
            pause(1)
            check("拍照與快速開始：有 Siri 與小工具教學", text("Siri").exists && text("小工具").exists)
        } else {
            check("設定：找得到「拍照與快速開始」入口", false)
        }

        // 12. 語言切換：英文 → 中文
        relaunch()
        _ = openMenu("menu_gearshape.fill")
        scrollToElement(text("語言"))
        if tapIfExists(text("語言")) {
            pause(1)
            pickWheel(containing: "English")
            wheelDone()
            pause(1)
            app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)
            check("英文：設定頁標題、語言、錄影畫質、幀數都變英文",
                  text("Settings").exists && text("Language").exists && text("Video quality").exists && text("Frame rate").exists)
            check("英文：設定頁沒有殘留中文（錄影畫質／錄影幀數）", !text("錄影畫質").exists && !text("錄影幀數").exists)
            // 側邊欄
            relaunch()
            _ = tapIfExists(app.buttons["menuButton"])
            pause(2)
            check("英文：側邊欄變英文（Course Library／Course Notes）", text("Course Library").exists && text("Course Notes").exists)
            app.swipeLeft()
            pause(1)
            // 首頁按鈕
            relaunch()
            check("英文：首頁「Start Class」", button("Start Class").exists || text("Start Class").exists)
            // 排程頁
            _ = tapIfExists(app.buttons["tab_schedule"])
            pause(2)
            check("英文：排程錄影頁變英文（Scheduled Recording／Duration）", text("Scheduled Recording").exists && text("Duration").exists)
            // 課程資訊表
            relaunch()
            _ = openMenu("menu_tablecells")
            check("英文：課程資訊表變英文（Course List）", text("Course List").waitForExistence(timeout: 4))
            // 切回中文
            relaunch()
            _ = openMenu("menu_gearshape.fill")
            scrollToElement(text("Language"))
            if tapIfExists(text("Language")) {
                pause(1)
                pickWheel(containing: "中文")
                wheelDone()
                pause(1)
                app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)
            }
            check("切回中文：設定頁恢復中文", text("設定").exists && text("錄影畫質").exists)
        } else {
            check("設定：找得到「語言」", false)
        }
    }
}
