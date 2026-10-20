# -*- coding: utf-8 -*-
"""下载指定 artifact（两跳重定向）到 _ipa/ 目录。用法：python _dl_art.py <artifact_id> <out_name>"""
import io
import os
import sys
import urllib.request
import urllib.error

OWNER = "670708233-cell"
REPO = "doushujun-ios"

cred = io.open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8").read()
TOKEN = None
for line in cred.splitlines():
    line = line.strip()
    if line.startswith("password="):
        TOKEN = line[len("password="):].strip()
        break

ART_ID = sys.argv[1]
OUT = sys.argv[2]
API = f"https://api.github.com/repos/{OWNER}/{REPO}/actions/artifacts/{ART_ID}/zip"
HDRS = {"Authorization": "Bearer " + TOKEN, "Accept": "application/vnd.github+json",
        "User-Agent": "dsj-dl"}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


r = urllib.request.Request(API, headers=HDRS, method="GET")
opener = urllib.request.build_opener(NoRedirect)
try:
    resp = opener.open(r, timeout=60)
    location = resp.headers.get("Location")
    if location:
        r2 = urllib.request.Request(location, headers={"User-Agent": "dsj-dl"}, method="GET")
        with urllib.request.urlopen(r2, timeout=300) as resp2:
            data = resp2.read()
    else:
        data = resp.read()
except urllib.error.HTTPError as e:
    if e.code in (301, 302, 303, 307):
        location = e.headers.get("Location")
        r2 = urllib.request.Request(location, headers={"User-Agent": "dsj-dl"}, method="GET")
        with urllib.request.urlopen(r2, timeout=300) as resp2:
            data = resp2.read()
    else:
        raise

out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_ipa")
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, OUT)
with open(out_path, "wb") as f:
    f.write(data)
print("saved:", out_path, len(data), "bytes")
