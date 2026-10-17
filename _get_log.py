# -*- coding: utf-8 -*-
"""下载最近一次 run 的 build-log artifact 并提取错误行"""
import io
import json
import os
import sys
import urllib.request
import urllib.error
import zipfile

OWNER = "670708233-cell"
REPO = "doushujun-ios"
RUN_ID = sys.argv[1] if len(sys.argv) > 1 else None

cred = io.open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8").read()
TOKEN = None
for line in cred.splitlines():
    line = line.strip()
    if line.startswith("password="):
        TOKEN = line[len("password="):].strip()
        break

API = f"https://api.github.com/repos/{OWNER}/{REPO}"
HDRS = {"Authorization": "Bearer " + TOKEN, "Accept": "application/vnd.github+json", "User-Agent": "log"}


def req(method, path):
    url = path if path.startswith("http") else API + path
    r = urllib.request.Request(url, headers=HDRS, method=method)
    with urllib.request.urlopen(r, timeout=60) as resp:
        content = resp.read()
        return resp.status, (json.loads(content) if content else {})


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


if RUN_ID is None:
    code, body = req("GET", "/actions/runs?per_page=1")
    RUN_ID = body["workflow_runs"][0]["id"]
print("run id:", RUN_ID)

code, body = req("GET", f"/actions/runs/{RUN_ID}/artifacts")
target = None
for a in body.get("artifacts", []):
    print(" artifact:", a["name"])
    if a["name"] == "build-log":
        target = a
if not target:
    sys.exit("no build-log artifact")

url = f"{API}/actions/artifacts/{target['id']}/zip"
r = urllib.request.Request(url, headers=HDRS, method="GET")
opener = urllib.request.build_opener(NoRedirect)
try:
    resp = opener.open(r, timeout=60)
    location = resp.headers.get("Location")
    if location:
        r2 = urllib.request.Request(location, headers={"User-Agent": "log"}, method="GET")
        with urllib.request.urlopen(r2, timeout=300) as resp2:
            data = resp2.read()
    else:
        data = resp.read()
except urllib.error.HTTPError as e:
    if e.code in (301, 302, 303, 307):
        location = e.headers.get("Location")
        r2 = urllib.request.Request(location, headers={"User-Agent": "log"}, method="GET")
        with urllib.request.urlopen(r2, timeout=300) as resp2:
            data = resp2.read()
    else:
        raise

zp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_build_log.zip")
with open(zp, "wb") as f:
    f.write(data)

zf = zipfile.ZipFile(zp)
log_name = zf.namelist()[0]
log = zf.read(log_name).decode("utf-8", "ignore")
print("log size:", len(log))

# 提取 error 行
err_lines = []
for line in log.splitlines():
    ll = line.lower()
    if "error:" in ll or "warning:" in ll and ".swift" in ll:
        err_lines.append(line)
print("\n===== ERRORS =====")
for l in err_lines[:60]:
    print(l[:300])
if not err_lines:
    # dump 末尾 3000 字符
    print(log[-3000:])
