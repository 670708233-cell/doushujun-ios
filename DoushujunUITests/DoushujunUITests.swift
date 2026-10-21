import XCTest

/// 登录全链路 UI 自动化测试（CI：macOS runner 上起本地后端 + iOS 模拟器执行）
///
/// 前置（由 CI ui-test job 保证）：
///   - runner 本机 127.0.0.1:8000 跑着 ThinkPHP 后端（dcc 库已导入结构 + uitester 测试账号）
///   - 后端 APP_DEBUG=true → captcha/generate 回传 captcha_code 明文 → app 暴露在 accessibility
///   - 后端极验配置为空 → app 探测失败自动降级自研滑块（顺带验证降级链路）
///
/// 输入策略：无头模拟器软键盘不弹（tap 后 typeText 报 "Neither element nor any descendant
/// has keyboard focus"，iOS 17 模拟器的 ConnectHardwareKeyboard 偏好对 DevicePreferences 无效）。
/// 统一走 launchEnvironment 预填：UITEST_USER/UITEST_PASS 注入表单初值，UITEST_AUTO=1 时
/// app 把验证码明文自动填入输入框。测试只负责读取断言与点击/拖拽，全程无 typeText。
final class DoushujunUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 启动 app 并注入测试环境（baseURL + 表单预填 + 验证码自动填）
    private func launch(user: String, pass: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DSJ_BASE_URL"] = "http://127.0.0.1:8000/api/"
        app.launchEnvironment["UITEST_USER"] = user
        app.launchEnvironment["UITEST_PASS"] = pass
        app.launchEnvironment["UITEST_AUTO"] = "1"
        app.launch()
        return app
    }

    /// 等元素出现，失败即停
    private func waitExists(_ el: XCUIElement, _ timeout: TimeInterval,
                            _ msg: @autoclosure () -> String = "元素未出现",
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(el.waitForExistence(timeout: timeout), msg(), file: file, line: line)
    }

    /// 等元素 value 等于期望文本
    private func waitValue(_ el: XCUIElement, _ value: String, _ timeout: TimeInterval,
                           _ msg: @autoclosure () -> String = "value 未到位",
                           file: StaticString = #filePath, line: UInt = #line) {
        let exp = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value), object: el)
        XCTAssertEqual(XCTWaiter().wait(for: [exp], timeout: timeout), .completed,
                       msg(), file: file, line: line)
    }

    /// 等验证码答案非空（首次拉取可能未就绪，点图刷新兜底）
    private func waitCaptchaAnswer(_ captcha: XCUIElement) -> String {
        let hasAnswer = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                !captcha.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }, object: nil)
        if XCTWaiter().wait(for: [hasAnswer], timeout: 10) != .completed {
            captcha.tap()                                      // 触发刷新
            _ = XCTWaiter().wait(for: [hasAnswer], timeout: 10)
        }
        return captcha.label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 正向链路：预填账号 + 自动验证码 + 拖满滑块 → 登录成功进主页
    func testLoginFullFlow() throws {
        let app = launch(user: "uitester", pass: "Uitest#2026")

        // —— 登录面板出现，且用户名已预填到位 ——
        let userField = app.textFields["用户名或邮箱"]
        waitExists(userField, 15, "登录面板未出现")
        waitValue(userField, "uitester", 5, "用户名预填失败")

        // —— 图形验证码：app 自动填明文，测试读 accessibility label 校验 debug 链路 ——
        let captcha = app.otherElements["captcha_answer"]
        waitExists(captcha, 15, "验证码组件未出现")
        let answer = waitCaptchaAnswer(captcha)
        XCTAssertFalse(answer.isEmpty, "验证码答案为空——后端是否处于 APP_DEBUG=true？")
        XCTAssertEqual(answer.count, 4, "验证码应为 4 字符，实际: \(answer)")

        // 输入框已被 app 自动填充
        let codeField = app.textFields["图形验证码"]
        waitExists(codeField, 5)
        waitValue(codeField, answer, 5, "验证码未自动填入输入框")

        // —— 点登录 → 探测极验失败 → 自动降级自研滑块 ——
        let loginBtn = app.buttons["登  录"]
        waitExists(loginBtn, 5)
        loginBtn.tap()

        // 诊断：读 sheet 请求探针（GEE=1 表示按钮 action 已触发、sheet 已请求）
        let probe = app.descendants(matching: .any).matching(identifier: "gee_state").firstMatch
        if probe.waitForExistence(timeout: 3) {
            print("=== PROBE gee_state=\(probe.label) ===")
        }

        // 滑块轨道出现（探测极验的半秒占位会先出现，等它切到滑块）
        let track = app.descendants(matching: .any).matching(identifier: "slider_track").firstMatch
        if !track.waitForExistence(timeout: 20) {
            print("=== APP ACCESSIBILITY TREE DUMP (slider missing) ===")
            print(app.debugDescription)
            print("=== END DUMP ===")
            XCTFail("滑块面板未出现——验证入口探测/降级链路异常")
        }

        // —— 模拟手指拖满滑块（上报层自带拟人噪声 + ratio 0.94 策略）——
        let knob = app.descendants(matching: .any).matching(identifier: "slider_knob").firstMatch
        waitExists(knob, 5)
        let start = knob.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = track.coordinate(withNormalizedOffset: CGVector(dx: 0.995, dy: 0.5))
        // press-thenDrag 产生真实变速触摸事件；滑到位后按住片刻确保松手前 verify 采样完整
        start.press(forDuration: 0.15,
                    thenDragTo: end,
                    withVelocity: .default,
                    thenHoldForDuration: 0.4)

        // —— 断言登录成功：主页 tab 出现（失败时打印错误弹窗文案辅助排障）——
        let homeTab = app.buttons["权重"]
        if !homeTab.waitForExistence(timeout: 20) {
            let alertMsg = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '失败' OR label CONTAINS '错误' OR label CONTAINS '验证'")).allElementsBoundByIndex.first?.label
            XCTFail("登录后未进入主页。错误弹窗文案: \(alertMsg ?? "无（无弹窗）")")
        }
    }

    /// 负路径：错误密码 → 滑块通过后登录被拒 → 弹窗提示（验证弹窗机制本身）
    func testLoginWrongPasswordShowsAlert() throws {
        let app = launch(user: "uitester", pass: "WrongPass#999")

        let userField = app.textFields["用户名或邮箱"]
        waitExists(userField, 15)

        let captcha = app.otherElements["captcha_answer"]
        waitExists(captcha, 15)
        let answer = waitCaptchaAnswer(captcha)
        XCTAssertFalse(answer.isEmpty)
        let codeField = app.textFields["图形验证码"]
        waitValue(codeField, answer, 5, "验证码未自动填入输入框")

        app.buttons["登  录"].tap()

        // 滑块照常出现并拖满（验证链路正常）
        let track = app.descendants(matching: .any).matching(identifier: "slider_track").firstMatch
        if !track.waitForExistence(timeout: 20) {
            print("=== APP ACCESSIBILITY TREE DUMP (wrongpw slider missing) ===")
            print(app.debugDescription)
            print("=== END DUMP ===")
            XCTFail("滑块面板未出现")
        }
        let knob = app.descendants(matching: .any).matching(identifier: "slider_knob").firstMatch
        let start = knob.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = track.coordinate(withNormalizedOffset: CGVector(dx: 0.995, dy: 0.5))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.4)

        // 期望「提示」弹窗出现（账号或密码错误）；主页不应出现
        let alertTitle = app.staticTexts["提示"]
        if !alertTitle.waitForExistence(timeout: 20) {
            let homeTab = app.buttons["权重"]
            XCTAssertFalse(homeTab.exists, "错误密码不应登录成功")
            XCTFail("预期错误弹窗未出现（服务端响应或弹窗机制异常）")
        } else {
            app.buttons["确定"].tap()
        }
    }
}
