# -*- coding: utf-8 -*-
"""拉取 run 的 job 步骤状态 + 完整 job 日志尾部。用法：python _joblog.py [run_id]"""
import io
import sys
import urllib.request

OWNER, REPO = "670708233-cell", "doushujun-ios"
RUN_ID = sys.argv[1] if len(sys.argv) > 1 else "39455310297"

cred = io.open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8").read()
TOKEN = [l.strip()[9:] for l in cred.splitlines() if l.strip().startswith("password=")][0]
API = f"https://api.github.com/repos/{OWNER}/{REPO}"
H = {"Authorization": "Bearer " + TOKEN, "Accept": "application/vnd.github+json", "User-Agent": "dsj"}

import json
r = urllib.request.Request(API + f"/actions/runs/{RUN_ID}/jobs", headers=H)
jobs = json.loads(urllib.request.urlopen(r, timeout=30).read())["jobs"]

class NR(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


import urllib.error
opener = urllib.request.build_opener(NR)

for j in jobs:
    print(f"\n===== JOB: {j['name']}  conclusion={j['conclusion']} =====")
    for s in j["steps"]:
        print(f"  [{s['status']}/{s['conclusion']}] {s['name']}")
    # 日志：302 到签名 URL，需手动跟随（不带 auth）
    r2 = urllib.request.Request(API + f"/actions/jobs/{j['id']}/logs", headers=H)
    try:
        resp = opener.open(r2, timeout=60)
        loc = resp.headers.get("Location")
        data = resp.read() if not loc else None
    except urllib.error.HTTPError as e:
        loc = e.headers.get("Location")
        data = None
    try:
        if data is None and loc:
            data = urllib.request.urlopen(urllib.request.Request(loc, headers={"User-Agent": "dsj"}), timeout=120).read()
        log = data.decode("utf-8", "ignore")
        # 只打最后 60 行（含失败步骤详情）
        tail = log.splitlines()[-60:]
        print("  ----- LOG TAIL -----")
        for line in tail:
            print("  " + line[:250])
    except Exception as e:
        print("  log fetch failed:", e)
