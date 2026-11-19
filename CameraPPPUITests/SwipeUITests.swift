//
//  SwipeUITests.swift
//  CameraPPPUITests
//
//  滑動手勢全測：首頁左右滑分頁、側邊欄滑動關閉與捲動、彈窗往下滑關閉、
//  設定頁／排程頁／課程資訊表上下左右捲動、快速亂滑不閃退。
//  每一項印出 SWIPE PASS/FAIL；失敗不中斷，繼續測下一項。
//

import XCTest

final class SwipeUITests: XCTestCase {
    private var app: XCUIApplication!
    private var n = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_TW"]
    }

    // MARK: - 小工具

    private func pause(_ s: UInt32 = 1) { sleep(s) }

    private func check(_ title: String, _ ok: @autoclosure () -> Bool) {
        n += 1
        let passed = ok()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = String(format: "S%02d %@", n, title)
        shot.lifetime = .keepAlways
        add(shot)
        print("SWIPE \(String(format: "%02d", n)) \(passed ? "PASS" : "FAIL") \(title)")
        XCTAssertTrue(passed, title)
    }

    private func text(_ s: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", s)).firstMatch
    }

    private func button(_ s: String) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", s)).firstMatch
    }

    private func visible(_ e: XCUIElement) -> Bool { e.exists && e.isHittable }

    private func dismissSystemAlerts() {
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<3 {
            let alert = sb.alerts.firstMatch
            guard alert.waitForExistence(timeout: 2) else { return }
            for l in ["允許", "Allow", "好", "OK", "允許使用 App 時", "Allow While Using App"] where alert.buttons[l].exists {
                alert.buttons[l].tap(); break
            }
        }
    }

    private func relaunch() {
        app.terminate()
        app.launch()
        dismissSystemAlerts()
        _ = app.buttons["menuButton"].waitForExistence(timeout: 10)
        pause(1)
    }

    private var onRecordTab: Bool { app.buttons["tab_record"].exists && app.buttons["tab_record"].isSelected }
    private var onScheduleTab: Bool { app.buttons["tab_schedule"].exists && app.buttons["tab_schedule"].isSelected }

    /// 首頁分頁區中間的一點（避開頂部列與底部廣告）
    private var pageArea: XCUICoordinate { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)) }

    private func swipePage(left: Bool) {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.85 : 0.15, dy: 0.55))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.1 : 0.9, dy: 0.55))
        from.press(forDuration: 0.05, thenDragTo: to)
        pause(1)
    }

    private func openMenu() -> Bool {
        app.buttons["menuButton"].tap()
        let row = app.buttons["menu_gearshape.fill"]
        if !row.waitForExistence(timeout: 4) { app.buttons["menuButton"].tap(); _ = row.waitForExistence(timeout: 4) }
        pause(1)
        return visible(row)
    }

    private var menuOpen: Bool { visible(app.buttons["menu_gearshape.fill"]) }

    private func scrollTo(_ e: XCUIElement, max: Int = 10) {
        var i = 0
        while !visible(e) && i < max { app.swipeUp(velocity: .slow); i += 1 }
    }

    private func setSwitch(_ id: String, on: Bool) {
        let sw = app.switches[id]
        scrollTo(sw)
        if ((sw.value as? String) == "1") != on {
            sw.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        pause(1)
    }

    private func tapTool(_ id: String) {
        let b = app.buttons[id]
        scrollTo(b)
        if visible(b) { b.tap() }
        pause(1)
    }

    private func openSettings() {
        _ = openMenu()
        app.buttons["menu_gearshape.fill"].tap()
        _ = text("錄影畫質").waitForExistence(timeout: 5)
        pause(1)
    }

    /// 廣告出現就等倒數完關掉
    private func closeAdIfShown(timeout: TimeInterval = 8) {
        let close = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'close' OR identifier CONTAINS[c] 'close'")).firstMatch
        guard close.waitForExistence(timeout: timeout) else { return }
        for _ in 0..<20 {
            if visible(close) { close.tap(); sleep(2) }
            if !close.exists { break }
            sleep(1)
        }
    }

    // MARK: - 滑動全測

    func testSwipeGestures() throws {
        relaunch()

        // 1–4 首頁分頁左右滑
        check("首頁：一開始停在錄影頁", onRecordTab)
        swipePage(left: true)
        check("錄影頁往左滑 → 切到排程錄影頁", onScheduleTab && text("重複錄影").exists)
        app.swipeUp(velocity: .slow); app.swipeUp(velocity: .slow)
        let notes = text("課程筆記")
        check("排程頁往上滑 → 捲到下方的課程筆記", notes.exists)
        app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)
        check("排程頁往下滑 → 回到頂部（看得到時長設定）", visible(text("時長")))
        swipePage(left: false)
        check("排程頁往右滑 → 回到錄影頁", onRecordTab && button("開始上課").exists)
        swipePage(left: false)
        check("錄影頁再往右滑 → 停在錄影頁、不會亂跳", onRecordTab)

        // 5 快速亂滑
        for i in 0..<8 { swipePage(left: i % 2 == 0) }
        app.swipeUp(velocity: .fast); app.swipeDown(velocity: .fast)
        check("快速左右亂滑 8 次 → 不閃退、頂部按鈕還能按", app.state == .runningForeground && visible(app.buttons["menuButton"]))
        app.buttons["tab_record"].tap(); pause(1)
        check("亂滑後點錄影分頁 → 正常回到錄影頁", onRecordTab)

        // 6–9 側邊欄
        check("點選單鍵 → 側邊欄打開", openMenu())
        app.swipeUp(velocity: .slow)
        check("側邊欄往上滑 → 最下面的「分享」還在、可以點", visible(app.buttons["menu_square.and.arrow.up"]))
        app.swipeDown(velocity: .slow)
        let menuView = app.buttons["menu_gearshape.fill"]
        let start = menuView.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -220, dy: 0)))
        pause(1)
        check("側邊欄往左滑 → 側邊欄關閉", !menuOpen)
        if !app.buttons["tab_record"].exists {
            let ids = app.buttons.allElementsBoundByIndex.prefix(15).map { "\($0.identifier)|\($0.label)" }
            let texts = app.staticTexts.allElementsBoundByIndex.prefix(10).map { $0.label }
            print("DEBUG 滑動後畫面 buttons=\(ids) texts=\(texts)")
        }
        check("滑掉側邊欄後 → 仍停在原本的錄影頁（沒誤切分頁）", onRecordTab)

        _ = openMenu()
        let overlay = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.6))
        overlay.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.6)))
        pause(1)
        check("在側邊欄外的暗色區域往左滑 → 也會關閉", !menuOpen)
        _ = openMenu()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        pause(1)
        check("點側邊欄外面 → 關閉（原本的方式仍正常）", !menuOpen)

        // 10 選課程彈窗往下滑關閉
        relaunch()
        let course = text("目前課程")
        if course.waitForExistence(timeout: 4) { course.tap() }
        pause(2)
        let picker = text("不指定課程")
        let pickerOpened = picker.exists
        app.swipeDown(velocity: .fast)
        pause(2)
        check("選課程彈窗往下滑 → 關閉回首頁", pickerOpened && !visible(picker) && visible(app.buttons["menuButton"]))

        // 11 課程資訊表上下左右捲動
        relaunch()
        _ = openMenu()
        app.buttons["menu_tablecells"].tap()
        _ = text("課程資訊表").waitForExistence(timeout: 5)
        if text("還沒有課程").exists, button("新增").exists {
            button("新增").tap(); pause(2)
            let f = app.textFields.firstMatch
            if f.waitForExistence(timeout: 3) { f.tap(); f.typeText("滑動測試課") }
            if button("儲存").exists { button("儲存").tap() }
            pause(2)
        }
        // 課程資訊表改成直向卡片：不用再左右拉
        let card = text("段錄影")
        check("課程資訊表：課程是直向卡片，不用左右拉就看得到錄影數", card.exists && card.isHittable)
        let table = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        table.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.4)))
        pause(1)
        check("課程資訊表往左滑 → 不會跑版，卡片還在原位", card.exists && card.isHittable && text("課程資訊表").exists)
        app.swipeUp(velocity: .fast); app.swipeDown(velocity: .fast)
        check("課程資訊表上下滑 → 標題列還在、不閃退", text("課程資訊表").exists && app.state == .runningForeground)

        // 12 設定頁滑到底再滑回頂
        relaunch()
        openSettings()
        let status = app.staticTexts["test_status"]
        scrollTo(status, max: 12)
        check("設定頁一路往上滑 → 到最底的測試工具", visible(status))
        for _ in 0..<6 { app.swipeDown(velocity: .fast) }
        check("設定頁往下滑 → 回到最上面的「錄影畫質」", visible(text("錄影畫質")))

        // 13–15 付費相關彈窗往下滑（需要付費功能開啟、試用到期）
        setSwitch("test_forcePayments", on: true)
        tapTool("test_expire")
        closeAdIfShown(timeout: 4)
        let upTitle = app.staticTexts["upsell_title"]
        if upTitle.waitForExistence(timeout: 3) {    // 到期時若正在用 4K 會先跳一次，先關掉
            app.buttons["upsell_close"].tap(); pause(1); closeAdIfShown()
        }
        for _ in 0..<6 { app.swipeDown(velocity: .fast) }
        let row = text("錄影畫質")
        if visible(row) { row.tap() }
        pause(2)
        // 畫質改成滾輪：轉到 4K（免費版上鎖）→ 選單自動收起、跳出升級小彈窗
        let wheel = app.pickerWheels.firstMatch
        if wheel.waitForExistence(timeout: 3) {
            for _ in 0..<4 where wheel.exists && !((wheel.value as? String) ?? "").contains("4K") {
                wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68)).tap()
                usleep(600_000)
            }
        }
        let opened = upTitle.waitForExistence(timeout: 5)
        app.swipeDown(velocity: .fast)
        pause(2)
        check("免費版小彈窗（4K）往下滑 → 可以關閉", opened && !upTitle.exists)
        check("滑掉小彈窗後 → 畫質沒有變成 4K", !app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH '4K'")).firstMatch.exists)
        closeAdIfShown(timeout: 3)

        // 付費頁（側邊欄「升級完整版」打開，可關閉的那種）
        app.buttons["settings_back"].tap(); pause(2)
        closeAdIfShown(timeout: 3)
        _ = openMenu()
        let upgrade = app.buttons["menu_cart.fill"]
        if visible(upgrade) { upgrade.tap() }
        let pay = app.buttons["paywall_subscribe"]
        let payOpened = pay.waitForExistence(timeout: 6)
        app.swipeUp(velocity: .slow)
        check("付費頁往上滑 → 內容可以捲動、訂閱鈕還在", payOpened && pay.exists)
        app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)
        pause(2)
        check("手動打開的付費頁往下滑 → 可以關閉", payOpened && !pay.exists)
        closeAdIfShown(timeout: 3)

        // 16 免費版首頁左右滑（底部有廣告橫幅時）
        relaunch()
        swipePage(left: true)
        let toSchedule = onScheduleTab
        swipePage(left: false)
        check("免費版（有廣告橫幅）首頁左右滑 → 分頁照常切換", toSchedule && onRecordTab)

        // 還原：試用重新開始、關閉付費模擬
        openSettings()
        tapTool("test_restart")
        let afterRestart = app.staticTexts["test_status"].label
        check("試用重新開始 → 回到試用中：\(afterRestart)", afterRestart.contains("試用中"))
        setSwitch("test_forcePayments", on: false)
        let restored = app.staticTexts["test_status"].label
        check("還原測試狀態（付費模擬關閉）：\(restored)", restored.contains("付費功能關閉中"))
    }
}
