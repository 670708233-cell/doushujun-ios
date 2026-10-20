# -*- coding: utf-8 -*-
"""拉指定 run 的 uitest-log artifact"""
import io, json, urllib.request, urllib.error, zipfile, os, sys

OWNER, REPO = "670708233-cell", "doushujun-ios"
RUN_ID = sys.argv[1] if len(sys.argv) > 1 else "39473773234"
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
print("artifacts:", [(a["name"], a["size_in_bytes"]) for a in arts])
uit = [a for a in arts if a["name"] == "uitest-log"]
if not uit:
    print("NO uitest-log artifact!")
    sys.exit(0)
dl(f"{API}/actions/artifacts/{uit[0]['id']}/zip", os.path.join(BASE, "_uit.zip"))
zf = zipfile.ZipFile(os.path.join(BASE, "_uit.zip"))
log = zf.read(zf.namelist()[0]).decode("utf-8", "ignore")
out = os.path.join(BASE, "_uit_latest.log")
with open(out, "w", encoding="utf-8") as f:
    f.write(log)
print("saved %d bytes -> %s" % (len(log), out))
print("===== tail 5000 =====")
print(log[-5000:])
