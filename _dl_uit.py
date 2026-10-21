import json, io, os, sys, urllib.request, urllib.error, zipfile
TOKEN = [l.split("=",1)[1].strip() for l in open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8") if l.startswith("password=")][0]
REPO = "670708233-cell/doushujun-ios"
RUN = sys.argv[1] if len(sys.argv) > 1 else "39540620274"
H = {"Authorization": "Bearer "+TOKEN, "User-Agent": "dsj", "Accept": "application/vnd.github+json"}

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

opener = urllib.request.build_opener(NoRedirect)
arts = json.loads(urllib.request.urlopen(urllib.request.Request(
    f"https://api.github.com/repos/{REPO}/actions/runs/{RUN}/artifacts", headers=H), timeout=30).read())["artifacts"]
uit = [a for a in arts if a["name"] == "uitest-log"][0]
url = f"https://api.github.com/repos/{REPO}/actions/artifacts/{uit['id']}/zip"
r = urllib.request.Request(url, headers=H)
try:
    resp = opener.open(r, timeout=60)
    data = resp.read()
except urllib.error.HTTPError as e:
    loc = e.headers["Location"]
    r2 = urllib.request.Request(loc, headers={"User-Agent": "dsj"})
    data = urllib.request.urlopen(r2, timeout=120).read()
z = zipfile.ZipFile(io.BytesIO(data))
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_uit_latest.log")
open(out, "wb").write(z.read(z.namelist()[0]))
print("saved", os.path.getsize(out), "->", out)
