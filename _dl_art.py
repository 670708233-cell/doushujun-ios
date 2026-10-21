import json, io, os, sys, urllib.request, urllib.error, zipfile
TOKEN = [l.split("=",1)[1].strip() for l in open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8") if l.startswith("password=")][0]
REPO = "670708233-cell/doushujun-ios"
RUN, WANT = sys.argv[1], sys.argv[2]   # run_id, artifact_name
H = {"Authorization": "Bearer "+TOKEN, "User-Agent": "dsj", "Accept": "application/vnd.github+json"}
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl): return None
opener = urllib.request.build_opener(NoRedirect)
arts = json.loads(urllib.request.urlopen(urllib.request.Request(
    f"https://api.github.com/repos/{REPO}/actions/runs/{RUN}/artifacts", headers=H), timeout=30).read())["artifacts"]
a = [x for x in arts if x["name"] == WANT][0]
try:
    opener.open(urllib.request.Request(f"https://api.github.com/repos/{REPO}/actions/artifacts/{a['id']}/zip", headers=H), timeout=60)
except urllib.error.HTTPError as e:
    data = urllib.request.urlopen(urllib.request.Request(e.headers["Location"], headers={"User-Agent": "dsj"}), timeout=120).read()
z = zipfile.ZipFile(io.BytesIO(data))
for n in z.namelist():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.path.basename(n))
    open(out, "wb").write(z.read(n))
    print("saved", out, os.path.getsize(out))
