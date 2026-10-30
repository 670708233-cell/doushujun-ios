# -*- coding: utf-8 -*-
"""拉取失败 run 的构建日志并提取 error 行（302 两跳：第二跳裸请求只带 UA）。"""
import io
import json
import urllib.request
import urllib.error

RUN = int(io.open("_runid.txt", encoding="utf-8").read().strip())
TOKEN = [l.split("=", 1)[1].strip() for l in io.open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8") if l.startswith("password=")][0]
REPO = "670708233-cell/doushujun-ios"
H = {"Authorization": "Bearer " + TOKEN, "User-Agent": "dsj", "Accept": "application/vnd.github+json"}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


opener = urllib.request.build_opener(NoRedirect)

jobs = json.loads(urllib.request.urlopen(urllib.request.Request(
    f"https://api.github.com/repos/{REPO}/actions/runs/{RUN}/jobs", headers=H), timeout=30).read())["jobs"]
jid = [j["id"] for j in jobs if j["conclusion"] == "failure"][0]

try:
    opener.open(urllib.request.Request(
        f"https://api.github.com/repos/{REPO}/actions/jobs/{jid}/logs", headers=H), timeout=60)
except urllib.error.HTTPError as e:
    data = urllib.request.urlopen(urllib.request.Request(
        e.headers["Location"], headers={"User-Agent": "dsj"}), timeout=120).read()

log = data.decode("utf-8", errors="replace")
io.open("_ci.log", "w", encoding="utf-8").write(log)
errs = [l for l in log.splitlines() if "error:" in l.lower()]
print("\n".join(errs[:30]) if errs else "no error lines; tail:\n" + log[-1500:])
