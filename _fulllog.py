# -*- coding: utf-8 -*-
"""拉取指定 run 的 build-log artifact 全文（排障用）。用法：python _fulllog.py [run_id]"""
import io
import json
import sys
import urllib.request
import urllib.error
import zipfile

OWNER, REPO = "670708233-cell", "doushujun-ios"
RUN_ID = sys.argv[1] if len(sys.argv) > 1 else "39454584701"

cred = io.open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8").read()
TOKEN = [l.strip()[9:] for l in cred.splitlines() if l.strip().startswith("password=")][0]
API = f"https://api.github.com/repos/{OWNER}/{REPO}"
H = {"Authorization": "Bearer " + TOKEN, "Accept": "application/vnd.github+json", "User-Agent": "dsj"}


class NR(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


r = urllib.request.Request(API + f"/actions/runs/{RUN_ID}/artifacts", headers=H)
arts = json.loads(urllib.request.urlopen(r, timeout=30).read())["artifacts"]
print("artifacts:", [a["name"] for a in arts])
t = [a for a in arts if a["name"] == "build-log"][0]

opener = urllib.request.build_opener(NR)
r2 = urllib.request.Request(f"{API}/actions/artifacts/{t['id']}/zip", headers=H)
data = None
try:
    resp = opener.open(r2, timeout=60)
    loc = resp.headers.get("Location")
    if not loc:
        data = resp.read()
except urllib.error.HTTPError as e:
    loc = e.headers.get("Location")
if loc:
    data = urllib.request.urlopen(urllib.request.Request(loc, headers={"User-Agent": "dsj"}), timeout=120).read()
open("_bl.zip", "wb").write(data)
zf = zipfile.ZipFile("_bl.zip")
log = zf.read(zf.namelist()[0]).decode("utf-8", "ignore")
print("TOTAL", len(log))
print("========== FULL LOG ==========")
print(log)
