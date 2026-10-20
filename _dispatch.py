# -*- coding: utf-8 -*-
"""手动触发 iOS workflow（backend 仓更新后无需 iOS 新 commit）"""
import io, json, urllib.request, sys

OWNER, REPO = "670708233-cell", "doushujun-ios"
cred = io.open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8").read()
TOKEN = [l.strip()[9:] for l in cred.splitlines() if l.strip().startswith("password=")][0]
H = {"Authorization": "Bearer " + TOKEN, "Accept": "application/vnd.github+json", "User-Agent": "dsj"}
url = f"https://api.github.com/repos/{OWNER}/{REPO}/actions/workflows/ios-build.yml/dispatches"
body = json.dumps({"ref": "main"}).encode()
r = urllib.request.Request(url, data=body, headers=dict(H, **{"Content-Type": "application/json"}), method="POST")
try:
    resp = urllib.request.urlopen(r, timeout=30)
    print("dispatch HTTP", resp.status, "(204=no body, expected)")
except urllib.error.HTTPError as e:
    print("dispatch FAILED", e.code, e.read()[:300])
    sys.exit(1)
# 拿最新 run 的 HEAD_SHA 更新提示
r2 = urllib.request.Request(f"https://api.github.com/repos/{OWNER}/{REPO}/actions/runs?per_page=1", headers=H)
run = json.loads(urllib.request.urlopen(r2, timeout=30).read())["workflow_runs"][0]
print("latest run:", run["id"], "sha:", run["head_sha"], "status:", run["status"])
