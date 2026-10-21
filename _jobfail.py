import json, io, urllib.request, sys
TOKEN = [l.split("=",1)[1].strip() for l in open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8") if l.startswith("password=")][0]
REPO = "670708233-cell/doushujun-ios"
H = {"Authorization": "Bearer "+TOKEN, "User-Agent": "dsj", "Accept": "application/vnd.github+json"}
def req(p):
    return json.loads(urllib.request.urlopen(urllib.request.Request(f"https://api.github.com/repos/{REPO}/{p}", headers=H), timeout=30).read())
jobs = req("actions/runs/39540620274/jobs")["jobs"]
for j in jobs:
    print(j["name"], "->", j["conclusion"], f"({j['id']})")
    if j["conclusion"] != "success":
        for s in j["steps"]:
            if s["conclusion"] not in ("success", "skipped", None):
                print("   step FAILED:", s["name"])
