# -*- coding: utf-8 -*-
"""诊断 iOS CI 连续 cancelled：查账单/通知/账户状态"""
import io, sys, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

_ns = {}
exec(open("_push_github.py", encoding="utf-8").read().split("def main")[0], _ns)
req = _ns["req"]

ENDPOINTS = [
    "/users/670708233-cell/settings/billing/actions",   # Actions 用量（需 billing scope，403 属预期）
    "/notifications",                                    # 通知（额度告警等）
    "/user",                                             # 账户状态
    "/repos/670708233-cell/doushujun-ios",               # 仓库状态
]
for ep in ENDPOINTS:
    code, d = req("GET", ep)
    if code == 200 and isinstance(d, dict):
        if "login" in d:  # /user 与 /repos 共有字段
            keys = ["login", "plan", "two_factor_authentication", "disabled", "archived", "permissions"]
            print(ep, "->", code, {k: d.get(k) for k in keys if k in d})
        else:
            print(ep, "->", code, json.dumps(d, ensure_ascii=False)[:400])
    else:
        print(ep, "->", code, str(d)[:200])

# 最近 run 的 annotation（取消原因常在这）
code, d = req("GET", "/repos/670708233-cell/doushujun-ios/check-runs/124884455808/annotations")
print("annotations ->", code, json.dumps(d, ensure_ascii=False)[:600] if isinstance(d, list) else str(d)[:200])
