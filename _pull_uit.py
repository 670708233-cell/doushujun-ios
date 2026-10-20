# -*- coding: utf-8 -*-
"""拉 uitest-log artifact + uitest job 失败步骤日志"""
import io, json, urllib.request, urllib.error, zipfile, os, sys

OWNER, REPO = "670708233-cell", "doushujun-ios"
RUN_ID = sys.argv[1] if len(sys.argv) > 1 else "39461707854"
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
    r = urllib.request.Request(url, headers=H)
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


r = urllib.request.Request(API + f"/actions/runs/{RUN_ID}/artifacts", headers=H)
arts = json.loads(urllib.request.urlopen(r, timeout=30).read())["artifacts"]
uit = [a for a in arts if a["name"] == "uitest-log"][0]
print("uitest-log size:", uit["size_in_bytes"])
dl(f"{API}/actions/artifacts/{uit['id']}/zip", os.path.join(BASE, "_uit.zip"))
zf = zipfile.ZipFile(os.path.join(BASE, "_uit.zip"))
log = zf.read(zf.namelist()[0]).decode("utf-8", "ignore")
print("===== uitest.log tail (last 6000 chars) =====")
print(log[-6000:])
