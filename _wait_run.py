import json, sys, time, urllib.request

TOKEN = [l.split("=", 1)[1].strip() for l in open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8") if l.startswith("password=")][0]
REPO = "670708233-cell/doushujun-ios"
SHA = sys.argv[1]

def req(path):
    r = urllib.request.Request(f"https://api.github.com/repos/{REPO}/{path}",
                               headers={"Authorization": f"Bearer {TOKEN}", "User-Agent": "ci"})
    return json.loads(urllib.request.urlopen(r, timeout=30).read())

for i in range(12):
    runs = req(f"actions/runs?head_sha={SHA}")["workflow_runs"]
    if runs:
        print(runs[0]["id"])
        sys.exit(0)
    time.sleep(5)
print("NO RUN FOUND", file=sys.stderr)
sys.exit(1)
