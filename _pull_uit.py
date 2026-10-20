# -*- coding: utf-8 -*-
"""拉本次 run 的 uitest-log artifact + uitest job 完整日志关键段"""
import io, json, urllib.request, urllib.error, zipfile, os, sys

OWNER, REPO = "670708233-cell", "doushujun-ios"
RUN_ID = "39459075440"
BASE = os.path.dirname(os.path.abspath(__file__))

cred = io.open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8").read()
TOKEN = [l.strip()[9:] for l in cred.splitlines() if l.strip().startswith("password=")][0]
API = f"https://api.github.com/repos/{OWNER}/{REPO}"
H = {"Authorization": "Bearer " + TOKEN, "Accept": "application/vnd.github+json", "User-Agent": "dsj"}


class NR(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def dl(url, out):
    opener = urllib.request.build_opener(NR)
    r = urllib.request.Request(url, headers=H, method="GET")
    data = None
    try:
        resp = opener.open(r, timeout=60)
        loc = resp.headers.get("Location")
        if not loc:
            data = resp.read()
    except urllib.error.HTTPError as e:
        loc = e.headers.get("Location")
    if data is None and loc:
        data = urllib.request.urlopen(urllib.request.Request(loc, headers={"User-Agent": "dsj"}), timeout=300).read()
    with open(out, "wb") as f:
        f.write(data)
    return data


# 1. uitest-log artifact
r = urllib.request.Request(API + f"/actions/runs/{RUN_ID}/artifacts", headers=H)
arts = json.loads(urllib.request.urlopen(r, timeout=30).read())["artifacts"]
print("artifacts:", [(a["name"], a["size_in_bytes"]) for a in arts])
uit = [a for a in arts if a["name"] == "uitest-log"][0]
data = dl(f"{API}/actions/artifacts/{uit['id']}/zip", os.path.join(BASE, "_uit.zip"))
zf = zipfile.ZipFile(os.path.join(BASE, "_uit.zip"))
log = zf.read(zf.namelist()[0]).decode("utf-8", "ignore")
print("===== uitest.log (%d bytes) =====" % len(log))
print(log)

# 2. uitest job 全文日志中 Run UI tests 步骤段
r2 = urllib.request.Request(API + f"/actions/runs/{RUN_ID}/jobs", headers=H)
jobs = json.loads(urllib.request.urlopen(r2, timeout=30).read())["jobs"]
for j in jobs:
    print("\n===== JOB %s conclusion=%s =====" % (j["name"], j["conclusion"]))
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
    print("job log total: %d chars" % len(full))
    # 找 xcodebuild 段
    lines = full.splitlines()
    start = None
    for i, ln in enumerate(lines):
        if "xcodebuild test" in ln or "xcodebuild build" in ln or "xcodebuild -list" in ln:
            start = i
            break
    if start is None:
        # 兜底：打最后 80 行
        print("--- (xcodebuild cmd not found) last 80 lines ---")
        for ln in lines[-80:]:
            print(ln[:260])
    else:
        seg = lines[max(0, start - 3): start + 120]
        print("--- xcodebuild segment ---")
        for ln in seg:
            print(ln[:300])
