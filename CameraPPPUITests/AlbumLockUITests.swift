//
//  AlbumLockUITests.swift
//  相簿密碼鎖：設定 → 打開相簿要密碼 → 輸錯提示 → 輸對進入 → 關閉
//

import XCTest

final class AlbumLockUITests: XCTestCase {
    private var app: XCUIApplication!
    private var n = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_TW"]
    }

    private func check(_ title: String, _ ok: @autoclosure () -> Bool) {
        n += 1
        let passed = ok()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = String(format: "L%02d %@", n, title)
        shot.lifetime = .keepAlways
        add(shot)
        print("LOCK \(String(format: "%02d", n)) \(passed ? "PASS" : "FAIL") \(title)")
        XCTAssertTrue(passed, title)
    }

    private func type(_ code: String) {
        for c in code {
            let k = app.buttons["passcode_\(c)"]
            if k.waitForExistence(timeout: 3) { k.tap() }
            usleep(250_000)
        }
        sleep(1)
    }

    private func openMenu(_ row: String) {
        app.buttons["menuButton"].tap()
        let r = app.buttons[row]
        if !r.waitForExistence(timeout: 4) { app.buttons["menuButton"].tap(); _ = r.waitForExistence(timeout: 4) }
        sleep(1)
        r.tap()
        sleep(2)
    }

    private func scrollTo(_ e: XCUIElement) {
        var i = 0
        while !(e.exists && e.isHittable) && i < 10 { app.swipeUp(velocity: .slow); i += 1 }
    }

    private func lockSwitch() -> XCUIElement {
        app.switches.containing(NSPredicate(format: "label CONTAINS '相簿密碼鎖'")).firstMatch
    }

    func testAlbumLock() throws {
        app.launch()
        sleep(3)
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for l in ["允許", "Allow", "好", "OK"] where sb.alerts.buttons[l].exists { sb.alerts.buttons[l].tap() }

        openMenu("menu_gearshape.fill")
        let sw = lockSwitch()
        scrollTo(sw)
        check("設定頁有「相簿密碼鎖」", sw.exists)
        sw.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        check("打開開關 → 出現設定密碼畫面", app.buttons["passcode_1"].waitForExistence(timeout: 4))
        type("1234"); type("1234")
        check("輸入兩次相同密碼 → 密碼鎖開啟", ((lockSwitch().value as? String) ?? "") == "1")

        // 重新開 App（等同離開後回來，會重新上鎖）
        app.terminate(); app.launch(); sleep(3)
        openMenu("menu_books.vertical.fill")
        check("打開課程相簿 → 要求輸入密碼", app.buttons["passcode_1"].waitForExistence(timeout: 4) && !app.staticTexts["課程相簿"].isHittable)
        type("1111")
        check("輸錯 → 顯示「密碼錯誤」、相簿沒打開", app.staticTexts.containing(NSPredicate(format: "label CONTAINS '密碼錯誤'")).firstMatch.exists)
        type("1234")
        check("輸對 → 進入課程相簿", app.buttons["library_videos"].waitForExistence(timeout: 4))

        // 關閉密碼鎖（還原）
        app.terminate(); app.launch(); sleep(3)
        openMenu("menu_gearshape.fill")
        let sw2 = lockSwitch()
        scrollTo(sw2)
        sw2.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        sleep(1)
        check("關閉密碼鎖 → 開關變回關閉", ((lockSwitch().value as? String) ?? "") == "0")
        app.terminate(); app.launch(); sleep(3)
        openMenu("menu_books.vertical.fill")
        check("關閉後打開相簿不用密碼", app.buttons["library_videos"].waitForExistence(timeout: 4))
    }
}
