# -*- coding: utf-8 -*-
"""查远端 main HEAD sha 与最新 run 列表"""
import json, urllib.request

TOKEN = [l.split("=", 1)[1].strip() for l in open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8") if l.startswith("password=")][0]
H = {"Authorization": "Bearer " + TOKEN, "User-Agent": "ci"}
REPO = "670708233-cell/doushujun-ios"

def get(path):
    r = urllib.request.Request(f"https://api.github.com/repos/{REPO}/{path}", headers=H)
    return json.loads(urllib.request.urlopen(r, timeout=30).read())

ref = get("git/ref/heads/main")
print("remote HEAD:", ref["object"]["sha"])

runs = get("actions/runs?per_page=3")["workflow_runs"]
for r in runs:
    print("run:", r["id"], "sha:", r["head_sha"][:10], r["status"], r["conclusion"], r["created_at"])
