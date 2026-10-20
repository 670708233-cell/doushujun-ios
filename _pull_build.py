# -*- coding: utf-8 -*-
"""build job 全文日志落盘（供 read_file 分析）"""
import io, json, urllib.request, urllib.error

OWNER, REPO = "670708233-cell", "doushujun-ios"
RUN_ID = "39460046649"

cred = io.open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8").read()
TOKEN = [l.strip()[9:] for l in cred.splitlines() if l.strip().startswith("password=")][0]
API = f"https://api.github.com/repos/{OWNER}/{REPO}"
H = {"Authorization": "Bearer " + TOKEN, "Accept": "application/vnd.github+json", "User-Agent": "dsj"}


class NR(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


r = urllib.request.Request(API + f"/actions/runs/{RUN_ID}/jobs", headers=H)
jobs = json.loads(urllib.request.urlopen(r, timeout=30).read())["jobs"]
for j in jobs:
    if "Build Unsigned" not in j["name"]:
        continue
    r3 = urllib.request.Request(API + f"/actions/jobs/{j['id']}/logs", headers=H)
    opener = urllib.request.build_opener(NR)
    try:
        resp = opener.open(r3, timeout=60)
        loc = resp.headers.get("Location")
        data = resp.read() if not loc else None
    except urllib.error.HTTPError as e:
        loc = e.headers.get("Location")
        data = None
    if data is None and loc:
        data = urllib.request.urlopen(urllib.request.Request(loc, headers={"User-Agent": "dsj"}), timeout=300).read()
    full = data.decode("utf-8", "ignore")
    out = full.replace("2026-10-20T", "").replace("2026-10-21T", "")
    with open("_build_job_full.txt", "w", encoding="utf-8") as f:
        f.write(out)
    print("saved build job log:", len(full), "chars ->", "_build_job_full.txt")
