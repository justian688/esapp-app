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

    /// 插頁廣告出現就截圖並關掉；回傳有沒有出現
    @discardableResult
    private func closeAdIfShown(timeout: TimeInterval = 10) -> Bool {
        let close = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'close' OR identifier CONTAINS[c] 'close'")).firstMatch
        guard close.waitForExistence(timeout: timeout) else { return false }
        pause(3)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "廣告畫面"
        shot.lifetime = .keepAlways
        add(shot)
        // 廣告前幾秒有倒數，關閉鈕要等倒數完才按得到
        for _ in 0..<20 {
            if close.exists && close.isHittable { close.tap(); sleep(2) }
            if !close.exists { break }
            sleep(1)
        }
        pause(1)
        return true
    }

    /// 讀測試面板的狀態文字；被晚到的測試廣告擋住時先關廣告再捲過去
    private var status: String {
        let e = app.staticTexts["test_status"]
        if !e.exists {
            _ = closeAdIfShown(timeout: 4)
            scrollTo(e)
        }
        return e.exists ? e.label : ""
    }

    private func openSettings() {
        app.buttons["menuButton"].tap()
        let settings = app.buttons["menu_gearshape.fill"]
        if !settings.waitForExistence(timeout: 5) {
            app.buttons["menuButton"].tap()   // 第一次沒打開選單就再按一次
            _ = settings.waitForExistence(timeout: 5)
        }
        pause(1)
        settings.tap()
        pause(2)
    }

    /// 打開「錄影畫質」滾輪選單
    private func openResolutionWheel() {
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        let row = app.staticTexts["錄影畫質"]
        scrollTo(row)
        row.tap()
        pause(2)
    }

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
        openResolutionWheel()
        let reached4K = pickWheel(containing: "4K")
        let wheelValue = (app.pickerWheels.firstMatch.value as? String) ?? ""
        step("試用中：4K 選項沒有上鎖（\(wheelValue)）", reached4K && !wheelValue.contains("🔒"))
        wheelDone()   // 試用中選 4K
        pause(1)
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
        let upTitle = app.staticTexts["upsell_title"]
        step("到期時正在用 4K → 小彈窗「4K 已改為 1080p」", upTitle.waitForExistence(timeout: 6) && upTitle.label.contains("1080p"))
        pause(2)
        step("小彈窗有「升級完整版」／「繼續使用免費版」／「查看所有方案」",
             app.buttons["upsell_subscribe"].exists && app.buttons["upsell_close"].exists && app.buttons["upsell_seeAll"].exists)
        tapIfExists(app.buttons["upsell_close"])
        let adShown = closeAdIfShown()
        print("INFO 選「繼續使用免費版」後播放廣告：\(adShown ? "有" : "沒有（測試廣告可能還沒載入）")")
        pause(2)
        step("到期後沒有其他自動跳出的付費畫面", !app.buttons["paywall_continueFree"].exists && !app.buttons["paywall_close"].exists && !app.alerts.firstMatch.exists)
        _ = closeAdIfShown(timeout: 6)   // 測試廣告有時較晚才載好播出，先關掉再看設定頁
        scrollTo(app.staticTexts["test_status"])
        step("狀態變成免費版：\(status)", status.contains("免費版") && status.contains("30 分鐘"))

        // 5. 免費版 4K 上鎖
        openResolutionWheel()
        pickWheel(containing: "4K")
        pause(1)
        step("免費版：4K 上鎖（轉到 4K 會自動收起滾輪、改跳升級小彈窗）",
             app.staticTexts["upsell_title"].waitForExistence(timeout: 6) && !app.pickerWheels.firstMatch.exists)
        let up = app.staticTexts["upsell_title"]
        step("點上鎖的 4K → 小彈窗「立即享受 4K 完整版功能」", up.waitForExistence(timeout: 6) && up.label.contains("4K"))
        pause(2)
        step("小彈窗有年訂閱、月訂閱兩個方案", app.buttons["upsell_yearly"].exists && app.buttons["upsell_monthly"].exists)
        tapIfExists(app.buttons["upsell_monthly"])
        pause(2)
        tapIfExists(app.buttons["upsell_seeAll"])
        let close = app.buttons["paywall_close"]
        step("小彈窗點「查看所有方案」→ 打開完整方案頁", close.waitForExistence(timeout: 6))
        pause(2)
        tapIfExists(close)
        pause(2)
        step("完整方案頁可以關掉", !app.buttons["paywall_close"].exists)

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
        step("側邊欄出現「升級完整版」選項", app.buttons["menu_cart.fill"].exists)
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
