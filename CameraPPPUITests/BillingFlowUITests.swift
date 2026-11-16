//
//  BillingFlowUITests.swift
//  CameraPPPUITests
//
//  實際操作畫面的收費流程測試（CI 會同時錄下模擬器畫面）：
//  試用中 → 4K 可用 → 快轉剩 23 小時跳「明天到期」→ 到期時正在用 4K 才提醒改 1080p → 其他不跳畫面
//  → 4K 上鎖、點了跳付費畫面 → 免費版上限 → 側邊欄有升級選項
//

import XCTest

final class BillingFlowUITests: XCTestCase {
    private var app: XCUIApplication!
    private var stepNo = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_TW"]
    }

    // MARK: - 小工具

    private func pause(_ s: UInt32 = 2) { sleep(s) }

    /// 每一步：記錄結果、截圖、在 log 印出 STEP 行（報告用）
    private func step(_ title: String, _ ok: @autoclosure () -> Bool) {
        stepNo += 1
        let passed = ok()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = String(format: "%02d %@", stepNo, title)
        shot.lifetime = .keepAlways
        add(shot)
        print("STEP \(String(format: "%02d", stepNo)) \(passed ? "PASS" : "FAIL") \(title)")
        XCTAssertTrue(passed, title)
    }

    private func dismissSystemAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<3 {
            let alert = springboard.alerts.firstMatch
            guard alert.waitForExistence(timeout: 2) else { return }
            for label in ["允許", "Allow", "好", "OK", "允許使用 App 時", "Allow While Using App"] {
                let b = alert.buttons[label]
                if b.exists { b.tap(); break }
            }
        }
    }

    private func scrollTo(_ element: XCUIElement, max: Int = 8) {
        var n = 0
        while (!element.exists || !element.isHittable) && n < max {
            app.swipeUp(velocity: .slow)
            n += 1
        }
    }

    private func setSwitch(_ id: String, on: Bool) {
        let sw = app.switches[id]
        scrollTo(sw)
        let isOn = (sw.value as? String) == "1"
        if isOn != on {
            sw.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        pause(1)
    }

    private func tapTool(_ id: String) {
        let b = app.buttons[id]
        scrollTo(b)
        b.tap()
    }

    /// 關掉選單：有「取消」就按，沒有（iOS 26）就點畫面上方空白處
    private func dismissDialog() {
        let cancel = app.buttons["取消"]
        if cancel.exists && cancel.isHittable {
            cancel.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        }
        pause(1)
    }

    private func tapIfExists(_ e: XCUIElement, timeout: TimeInterval = 4) {
        if e.waitForExistence(timeout: timeout) && e.isHittable { e.tap() }
    }

    private var status: String { app.staticTexts["test_status"].label }

    private func openSettings() {
        app.buttons["menuButton"].tap()
        pause(1)
        app.buttons["menu_gearshape.fill"].tap()
        pause(2)
    }

    /// 打開「錄影畫質」選單，回傳 4K 那個選項的文字
    private func open4KOption() -> XCUIElement {
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        let row = app.staticTexts["錄影畫質"]
        scrollTo(row)
        row.tap()
        pause(2)
        return app.buttons.containing(NSPredicate(format: "label CONTAINS '4K'")).firstMatch
    }

    // MARK: - 完整流程

    func testFullBillingFlow() throws {
        app.launch()
        dismissSystemAlerts()
        pause(3)
        step("App 開啟，進入錄影首頁", app.buttons["menuButton"].waitForExistence(timeout: 10))

        // 1. 打開設定 → 測試工具
        openSettings()
        let tools = app.switches["test_forcePayments"]
        scrollTo(tools)
        step("設定頁最下面看得到「🧪 測試工具」", tools.exists)

        setSwitch("test_forcePayments", on: true)
        setSwitch("test_shortLimit", on: false)
        tapTool("test_restart")
        pause(2)
        step("模擬付費開啟、試用重新開始 → 狀態：\(status)", status.contains("試用中"))

        // 2. 試用中 4K 可用
        var opt = open4KOption()
        step("試用中：4K 選項沒有上鎖（\(opt.label)）", opt.exists && !opt.label.contains("🔒"))
        tapIfExists(opt)   // 試用中選 4K
        pause(2)
        step("試用中可以選 4K 錄影", app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH '4K'")).firstMatch.exists)

        // 3. 快轉到剩 23 小時 → 明天到期提醒
        tapTool("test_23h")
        let reminder = app.alerts["免費試用明天到期"]
        step("快轉剩 23 小時 → 跳出「免費試用明天到期」", reminder.waitForExistence(timeout: 6))
        pause(2)
        step("提醒有兩個選擇：查看付費方案／到期後用免費版",
             reminder.buttons["查看付費方案"].exists && reminder.buttons["到期後用免費版"].exists)
        tapIfExists(reminder.buttons["到期後用免費版"])
        pause(3)
        step("選「到期後用免費版」後不會再跳提醒", !app.alerts["免費試用明天到期"].exists)

        // 4. 立刻到期 → 不跳任何東西，直接變免費版
        tapTool("test_expire")
        let fourK = app.alerts["4K 已改為 1080p"]
        step("到期時正在用 4K → 提醒「4K 已改為 1080p」", fourK.waitForExistence(timeout: 6))
        pause(2)
        step("提醒有「訂閱繼續用 4K」／「用 1080p 繼續」", fourK.buttons["訂閱繼續用 4K"].exists && fourK.buttons["用 1080p 繼續"].exists)
        tapIfExists(fourK.buttons["用 1080p 繼續"])
        pause(3)
        step("到期後沒有其他自動跳出的付費畫面", !app.buttons["paywall_continueFree"].exists && !app.buttons["paywall_close"].exists && !app.alerts.firstMatch.exists)
        scrollTo(app.staticTexts["test_status"])
        step("狀態變成免費版：\(status)", status.contains("免費版") && status.contains("30 分鐘"))

        // 5. 免費版 4K 上鎖
        opt = open4KOption()
        step("免費版：4K 選項上鎖（\(opt.label)）", opt.label.contains("🔒"))
        tapIfExists(opt)
        let close = app.buttons["paywall_close"]
        step("點上鎖的 4K → 跳出付費畫面", close.waitForExistence(timeout: 6))
        pause(2)
        tapIfExists(close)
        pause(2)
        step("付費畫面可以關掉", !app.buttons["paywall_close"].exists)

        // 6. 測試用 1 分鐘上限
        setSwitch("test_shortLimit", on: true)
        scrollTo(app.staticTexts["test_status"])
        step("免費版上限改成 1 分鐘：\(status)", status.contains("1 分鐘"))
        setSwitch("test_shortLimit", on: false)

        // 7. 側邊欄出現升級選項
        tapIfExists(app.buttons["settings_back"])
        let banner = app.descendants(matching: .any)["adBanner"]
        step("免費版：首頁下方出現廣告", banner.waitForExistence(timeout: 8))
        pause(6)
        app.buttons["menuButton"].tap()
        pause(2)
        step("側邊欄出現「升級進階版」選項", app.buttons["menu_cart.fill"].exists)
        tapIfExists(app.buttons["menu_cart.fill"])
        step("從側邊欄可以打開付費畫面", app.buttons["paywall_close"].waitForExistence(timeout: 6))
        pause(3)
        tapIfExists(app.buttons["paywall_close"])
        pause(2)

        // 8. 試用重新開始 → 回到全開
        openSettings()
        tapTool("test_restart")
        pause(2)
        scrollTo(app.staticTexts["test_status"])
        step("「試用重新開始」→ 回到試用中：\(status)", status.contains("試用中"))
        tapIfExists(app.buttons["settings_back"])
        pause(3)
        step("試用中（等同付費）：首頁沒有廣告", !app.descendants(matching: .any)["adBanner"].exists)
        openSettings()
        setSwitch("test_forcePayments", on: false)
        pause(2)
    }
}
