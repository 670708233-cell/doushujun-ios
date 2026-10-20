# -*- coding: utf-8 -*-
"""拉 UI Test job 步骤状态与失败步骤日志尾部"""
import io, json, urllib.request, urllib.error, sys

OWNER, REPO = "670708233-cell", "doushujun-ios"
RUN_ID = sys.argv[1] if len(sys.argv) > 1 else "39472955259"

cred = io.open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8").read()
TOKEN = [l.strip()[9:] for l in cred.splitlines() if l.strip().startswith("password=")][0]
API = f"https://api.github.com/repos/{OWNER}/{REPO}"
H = {"Authorization": "Bearer " + TOKEN, "Accept": "application/vnd.github+json", "User-Agent": "dsj"}


class NR(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def get_log(job_id):
    r3 = urllib.request.Request(API + f"/actions/jobs/{job_id}/logs", headers=H)
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
    return data.decode("utf-8", "ignore")


r = urllib.request.Request(API + f"/actions/runs/{RUN_ID}/jobs", headers=H)
jobs = json.loads(urllib.request.urlopen(r, timeout=30).read())["jobs"]
for j in jobs:
    if "UI Test" not in j["name"]:
        continue
    print("JOB:", j["name"], "conclusion=", j["conclusion"])
    for s in j["steps"]:
        print("   %-44s %s" % (s["name"], s["conclusion"]))
    full = get_log(j["id"])
    lines = full.splitlines()
    print("--- last 60 lines ---")
    for ln in lines[-60:]:
        body = ln.split("Z ", 1)[1] if "Z " in ln[:30] else ln
        print(body[:250])
