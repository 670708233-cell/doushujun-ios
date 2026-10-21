# -*- coding: utf-8 -*-
# 拉 run 39629518061 的失败 job：列出步骤结论 + 下载日志 grep 错误行
import json, io, urllib.request, re

TOKEN = [l.split("=",1)[1].strip() for l in open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8") if l.startswith("password=")][0]
REPO = "670708233-cell/doushujun-ios"
RUN = "39629518061"
H = {"Authorization": "Bearer "+TOKEN, "User-Agent": "dsj", "Accept": "application/vnd.github+json"}

def req(p):
    return json.loads(urllib.request.urlopen(urllib.request.Request(f"https://api.github.com/repos/{REPO}/{p}", headers=H), timeout=30).read())

jobs = req(f"actions/runs/{RUN}/jobs")["jobs"]
for j in jobs:
    print(j["name"], "->", j["conclusion"], f"({j['id']})")
    if j["conclusion"] == "success":
        continue
    for s in j["steps"]:
        if s["conclusion"] not in ("success", "skipped", None):
            print("   FAILED step:", s["name"])
    # 下载该 job 日志（302 两跳，第二跳去掉 Authorization）
    try:
        r1 = urllib.request.Request(f"https://api.github.com/repos/{REPO}/actions/jobs/{j['id']}/logs", headers=H)
        try:
            urllib.request.urlopen(r1, timeout=30)
        except urllib.error.HTTPError as e:
            if e.code not in (301, 302, 303):
                raise
            loc = e.headers["Location"]
        else:
            loc = None
        if loc:
            body = urllib.request.urlopen(urllib.request.Request(loc, headers={"User-Agent": "dsj"}), timeout=60).read().decode("utf-8", "ignore")
            hits = [l for l in body.splitlines() if re.search(r"error:|FAILED|Build task failed|xcodebuild.*failed", l, re.I)]
            print(f"   --- {len(hits)} error lines ---")
            for l in hits[:25]:
                print("   ", l[-220:])
    except Exception as ex:
        print("   log fetch fail:", ex)
