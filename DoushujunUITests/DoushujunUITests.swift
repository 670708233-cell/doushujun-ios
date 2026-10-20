import XCTest

/// 登录全链路 UI 自动化测试（CI：macOS runner 上起本地后端 + iOS 模拟器执行）
///
/// 前置（由 CI ui-test job 保证）：
///   - runner 本机 127.0.0.1:8000 跑着 ThinkPHP 后端（dcc 库已导入结构 + uitester 测试账号）
///   - 后端 APP_DEBUG=true → captcha/generate 回传 captcha_code 明文 → app 暴露在 accessibility
///   - 后端极验配置为空 → app 探测失败自动降级自研滑块（顺带验证降级链路）
///
/// 密码错误/验证码错误等负路径断言失败时会打印服务端弹窗文案辅助排障。
final class DoushujunUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 正向链路：测试账号 + 自动读取的验证码 + 拖满滑块 → 登录成功进主页
    func testLoginFullFlow() throws {
        let app = XCUIApplication()
        app.launchEnvironment["DSJ_BASE_URL"] = "http://127.0.0.1:8000/api/"
        app.launch()

        // —— 登录面板出现 ——
        let userField = app.textFields["用户名或邮箱"]
        XCTAssertTrue(userField.waitForExistence(timeout: 15), "登录面板未出现")
        userField.tap()
        userField.typeText("uitester")

        let pwField = app.secureTextFields["密码"]
        XCTAssertTrue(pwField.waitForExistence(timeout: 5))
        pwField.tap()
        pwField.typeText("Uitest#2026")

        // —— 图形验证码：等图加载出答案（accessibility label 暴露）——
        let captcha = app.otherElements["captcha_answer"]
        XCTAssertTrue(captcha.waitForExistence(timeout: 15), "验证码组件未出现")

        // 答案可能首次拉取未就绪（空 label），触发一次点击刷新兜底
        var answer = captcha.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if answer.isEmpty {
            captcha.tap()
            _ = captcha.waitForExistence(timeout: 10)
            // tap 后 accessibility 更新需要一点时间
            let exp = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !(captcha.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }, object: nil)
            XCTWaiter().wait(for: [exp], timeout: 10)
            answer = captcha.label.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        XCTAssertFalse(answer.isEmpty, "验证码答案为空——后端是否处于 APP_DEBUG=true？")
        XCTAssertEqual(answer.count, 4, "验证码应为 4 字符，实际: \(answer)")

        let codeField = app.textFields["图形验证码"]
        codeField.tap()
        codeField.typeText(answer)

        // —— 点登录 → 探测极验失败 → 自动降级自研滑块 ——
        let loginBtn = app.buttons["登  录"]
        XCTAssertTrue(loginBtn.waitForExistence(timeout: 5))
        loginBtn.tap()

        // 滑块轨道出现（探测极验的半秒占位会先出现，等它切到滑块）
        let track = app.otherElements["slider_track"]
        XCTAssertTrue(track.waitForExistence(timeout: 20), "滑块面板未出现——验证入口探测/降级链路异常")

        // —— 模拟手指拖满滑块（上报层自带拟人噪声 + ratio 0.94 策略）——
        let knob = app.otherElements["slider_knob"]
        XCTAssertTrue(knob.waitForExistence(timeout: 5))
        let start = knob.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = track.coordinate(withNormalizedOffset: CGVector(dx: 0.995, dy: 0.5))
        // press-thenDrag 产生真实变速触摸事件；滑到位后按住片刻确保松手前 verify 采样完整
        start.press(forDuration: 0.15,
                    thenDragTo: end,
                    withVelocity: .default,
                    thenHoldForDuration: 0.4)

        // —— 断言登录成功：主页 tab 出现（失败时打印错误弹窗文案辅助排障）——
        let homeTab = app.buttons["权重"]
        let ok = homeTab.waitForExistence(timeout: 20)
        if !ok {
            let alertMsg = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '失败' OR label CONTAINS '错误' OR label CONTAINS '验证'")).allElementsBoundByIndex.first?.label
            XCTFail("登录后未进入主页。错误弹窗文案: \(alertMsg ?? "无（无弹窗）")")
        }
    }

    /// 负路径：错误密码 → 滑块通过后登录被拒 → 弹窗提示（验证弹窗机制本身）
    func testLoginWrongPasswordShowsAlert() throws {
        let app = XCUIApplication()
        app.launchEnvironment["DSJ_BASE_URL"] = "http://127.0.0.1:8000/api/"
        app.launch()

        let userField = app.textFields["用户名或邮箱"]
        XCTAssertTrue(userField.waitForExistence(timeout: 15))
        userField.tap()
        userField.typeText("uitester")

        let pwField = app.secureTextFields["密码"]
        pwField.tap()
        pwField.typeText("WrongPass#999")

        let captcha = app.otherElements["captcha_answer"]
        XCTAssertTrue(captcha.waitForExistence(timeout: 15))
        var answer = captcha.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if answer.isEmpty {
            captcha.tap()
            let exp = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !(captcha.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }, object: nil)
            XCTWaiter().wait(for: [exp], timeout: 10)
            answer = captcha.label.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        XCTAssertFalse(answer.isEmpty)
        let codeField = app.textFields["图形验证码"]
        codeField.tap()
        codeField.typeText(answer)

        app.buttons["登  录"].tap()

        // 滑块照常出现并拖满（验证链路正常）
        let track = app.otherElements["slider_track"]
        XCTAssertTrue(track.waitForExistence(timeout: 20))
        let knob = app.otherElements["slider_knob"]
        let start = knob.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = track.coordinate(withNormalizedOffset: CGVector(dx: 0.995, dy: 0.5))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.4)

        // 期望「提示」弹窗出现（账号或密码错误）；主页不应出现
        let alertTitle = app.staticTexts["提示"]
        let alertShown = alertTitle.waitForExistence(timeout: 20)
        if !alertShown {
            let homeTab = app.buttons["权重"]
            XCTAssertFalse(homeTab.exists, "错误密码不应登录成功")
            XCTFail("预期错误弹窗未出现（服务端响应或弹窗机制异常）")
        }
        // 关弹窗收尾
        if alertShown {
            app.buttons["确定"].tap()
        }
    }
}
