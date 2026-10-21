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

    /// 启动 app 并注入测试环境（baseURL + 表单预填 + 验证码自动填 + 登录态重置）
    private func launch(user: String, pass: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DSJ_BASE_URL"] = "http://127.0.0.1:8000/api/"
        app.launchEnvironment["UITEST_USER"] = user
        app.launchEnvironment["UITEST_PASS"] = pass
        app.launchEnvironment["UITEST_AUTO"] = "1"
        app.launchEnvironment["UITEST_RESET"] = "1"   // 测试隔离：清上个用例留下的登录态
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

    /// 等验证码答案就绪（4 字符才算：app 侧答案未到时 label 显示 pending 哨兵；
    /// 不点刷新：刷新会换答案导致与已填入 code 漂移，app 侧已有 5 次自动重试兜底）。
    /// ⚠每轮重新 resolve 查询：持有旧元素引用访问 .label 时若快照失效，
    /// XCUITest 抛 ObjC 异常 "Failed to match snapshot"（Swift catch 不住，测试直接崩）
    private func waitCaptchaAnswer(_ app: XCUIApplication) -> String {
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            let el = app.otherElements["captcha_answer"]
            if el.exists {
                let a = el.label.trimmingCharacters(in: .whitespacesAndNewlines)
                if a.count == 4 { return a }
            }
            usleep(400_000)
        }
        return app.otherElements["captcha_answer"].label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 等验证码输入框 value 与 captcha_answer 当前 label 一致（label 动态读取，容忍拉码刷新换答案；
    /// 同 waitCaptchaAnswer：每轮重新 resolve 防失效快照抛异常）
    @discardableResult
    private func waitCodeFilled(_ app: XCUIApplication, _ timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let captcha = app.otherElements["captcha_answer"]
            let codeField = app.textFields["图形验证码"]
            if captcha.exists, codeField.exists {
                let a = captcha.label.trimmingCharacters(in: .whitespacesAndNewlines)
                let v = codeField.value as? String ?? ""
                if a.count == 4 && v == a { return true }
            }
            usleep(400_000)
        }
        return false
    }

    /// 正向链路：预填账号 + 自动验证码 + 拖满滑块 → 登录成功进主页。
    /// 冷启动首用例的 accessibility 快照偶发缺元素（实证 flake：captcha_answer/
    /// 图形验证码先后中招，热启动第二用例从未挂过），失败热启动重试一轮吸收。
    func testLoginFullFlow() throws {
        if runFullFlowOnce() { return }
        XCTAssertTrue(runFullFlowOnce(), "热启动重试后正向链路仍未通过")
    }

    /// 诊断摘要：拉码探针 + 树上关键元素清单（失败定位用）
    private func diagBrief(_ app: XCUIApplication) -> String {
        var parts = ["probe=<\(app.otherElements["captcha_debug"].exists ? app.otherElements["captcha_debug"].label : "n/a")>"]
        for (desc, q) in [("user", app.textFields["用户名或邮箱"]),
                          ("code", app.textFields["图形验证码"]),
                          ("answer", app.otherElements["captcha_answer"])] {
            parts.append("\(desc):\(q.exists ? "label=\(q.label.prefix(12))" : "MISSING")")
        }
        return parts.joined(separator: " ")
    }

    /// 正向单轮：全部就绪检查通过且进主页返回 true；任何一步超时返回 false（不抛断言）
    @discardableResult
    private func runFullFlowOnce() -> Bool {
        let app = launch(user: "uitester", pass: "Uitest#2026")

        // —— 登录面板出现，且用户名已预填到位 ——
        let userField = app.textFields["用户名或邮箱"]
        guard userField.waitForExistence(timeout: 15) else {
            print("DIAG no-userField: \(diagBrief(app))"); return false
        }
        guard waitValueBool(userField, "uitester", 5) else {
            print("DIAG bad-prefill: \(diagBrief(app))"); return false
        }

        // —— 图形验证码：app 自动填明文（answer 恒在树上，等 4 字符答案=拉码就绪）——
        guard app.otherElements["captcha_answer"].waitForExistence(timeout: 15),
              waitCaptchaAnswer(app).count == 4 else {
            print("DIAG no-answer: \(diagBrief(app))"); return false
        }

        // 输入框已被 app 自动填充（与当前答案动态比对，容忍拉码刷新换答案）
        guard app.textFields["图形验证码"].waitForExistence(timeout: 8),
              waitCodeFilled(app, 8) else {
            print("DIAG not-filled: \(diagBrief(app))"); return false
        }

        // —— app 端自动链（UITEST_AUTO=1）：验证码自动填完 → 延时自动弹滑块 sheet →
        // autoSlide 合成真人轨迹 verify → doLogin。测试端全程不 tap（无头模拟器 Button tap
        // 事件随机丢失实证）。sheet 生命周期仅 ~1s（autoSlide 完成即关），
        // 故不做中间断言，直接等登录最终结果 ——

        // —— 断言登录成功：主页 tab 出现（失败时打印错误弹窗文案辅助排障）——
        let homeTab = app.buttons["权重"]
        if !homeTab.waitForExistence(timeout: 30) {
            let alertMsg = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '失败' OR label CONTAINS '错误' OR label CONTAINS '验证'")).allElementsBoundByIndex.first?.label
            print("=== APP ACCESSIBILITY TREE DUMP (home missing) ===")
            print(app.debugDescription)
            print("=== END DUMP ===")
            return false
        }
        return true
    }

    /// waitValue 的 Bool 版（不落断言，供重试包装）
    private func waitValueBool(_ el: XCUIElement, _ value: String, _ timeout: TimeInterval) -> Bool {
        let exp = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value), object: el)
        return XCTWaiter().wait(for: [exp], timeout: timeout) == .completed
    }

    /// 负路径：错误密码 → 滑块通过后登录被拒 → 弹窗提示（验证弹窗机制本身）
    func testLoginWrongPasswordShowsAlert() throws {
        let app = launch(user: "uitester", pass: "WrongPass#999")

        let userField = app.textFields["用户名或邮箱"]
        if !userField.waitForExistence(timeout: 15) {
            print("=== APP ACCESSIBILITY TREE DUMP (login panel missing) ===")
            print(app.debugDescription)
            print("=== END DUMP ===")
            XCTFail("登录面板未出现")
        }

        let captcha = app.otherElements["captcha_answer"]
        waitExists(captcha, 15)
        let answer = waitCaptchaAnswer(app)
        XCTAssertFalse(answer.isEmpty)
        XCTAssertTrue(waitCodeFilled(app, 8), "验证码未自动填入输入框")

        // app 端自动链（同正向）：自动弹 sheet → autoSlide verify → doLogin(WrongPass)
        // sheet 生命周期 ~1s 不做中间断言，直接等登录结果弹窗

        // 期望「提示」弹窗出现（账号或密码错误）；主页不应出现
        let alertTitle = app.staticTexts["提示"]
        if !alertTitle.waitForExistence(timeout: 30) {
            let homeTab = app.buttons["权重"]
            XCTAssertFalse(homeTab.exists, "错误密码不应登录成功")
            XCTFail("预期错误弹窗未出现（服务端响应或弹窗机制异常）")
        } else {
            app.buttons["确定"].tap()
        }
    }
}
