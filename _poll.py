# -*- coding: utf-8 -*-
"""
轮询本次 commit 的 GitHub Actions CI 状态，直到完成。
成功 → 列出 artifacts；失败 → 自动下载 build-log 并提取错误行。
用法：python _poll.py [run_id]
"""
import io
import json
import sys
import time
import urllib.request
import urllib.error
import zipfile

OWNER = "670708233-cell"
REPO = "doushujun-ios"
HEAD_SHA = "890470fd76f16399fa4c89469c8cfcbacde0342c"
POLL_INTERVAL = 30          # 秒
MAX_WAIT_SEC = 30 * 60      # 最长等 30 分钟

cred = io.open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8").read()
TOKEN = None
for line in cred.splitlines():
    line = line.strip()
    if line.startswith("password="):
        TOKEN = line[len("password="):].strip()
        break

API = f"https://api.github.com/repos/{OWNER}/{REPO}"
HDRS = {"Authorization": "Bearer " + TOKEN, "Accept": "application/vnd.github+json",
        "User-Agent": "dsj-poll"}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def req(method, path):
    url = path if path.startswith("http") else API + path
    r = urllib.request.Request(url, headers=HDRS, method=method)
    with urllib.request.urlopen(r, timeout=60) as resp:
        content = resp.read()
        return resp.status, (json.loads(content) if content else {})


def find_run():
    code, body = req("GET", f"/actions/runs?head_sha={HEAD_SHA}&per_page=5")
    runs = body.get("workflow_runs", [])
    return runs[0] if runs else None


def download_build_log(run_id):
    code, body = req("GET", f"/actions/runs/{run_id}/artifacts")
    target = None
    for a in body.get("artifacts", []):
        if a["name"] == "build-log":
            target = a
    if not target:
        print("(no build-log artifact yet)")
        return
    url = f"{API}/actions/artifacts/{target['id']}/zip"
    r = urllib.request.Request(url, headers=HDRS, method="GET")
    opener = urllib.request.build_opener(NoRedirect)
    try:
        resp = opener.open(r, timeout=60)
        location = resp.headers.get("Location")
        if location:
            r2 = urllib.request.Request(location, headers={"User-Agent": "dsj-poll"}, method="GET")
            with urllib.request.urlopen(r2, timeout=300) as resp2:
                data = resp2.read()
        else:
            data = resp.read()
    except urllib.error.HTTPError as e:
        if e.code in (301, 302, 303, 307):
            location = e.headers.get("Location")
            r2 = urllib.request.Request(location, headers={"User-Agent": "dsj-poll"}, method="GET")
            with urllib.request.urlopen(r2, timeout=300) as resp2:
                data = resp2.read()
        else:
            raise

    import os
    zp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_build_log.zip")
    with open(zp, "wb") as f:
        f.write(data)
    zf = zipfile.ZipFile(zp)
    log = zf.read(zf.namelist()[0]).decode("utf-8", "ignore")
    print("log size:", len(log))

    err_lines = []
    for line in log.splitlines():
        ll = line.lower()
        if "error:" in ll or ("warning:" in ll and ".swift" in ll):
            err_lines.append(line)
    print("\n===== ERRORS / WARNINGS =====")
    for l in err_lines[:60]:
        print(l[:300])
    if not err_lines:
        print(log[-3000:])


def main():
    run_id = sys.argv[1] if len(sys.argv) > 1 else None
    started = time.time()

    while True:
        if run_id:
            code, run = req("GET", f"/actions/runs/{run_id}")
        else:
            run = find_run()
            if run is None:
                if time.time() - started > 120:
                    print("ERROR: no run found for HEAD_SHA after 120s")
                    sys.exit(2)
                print(f"[{time.strftime('%H:%M:%S')}] run not registered yet, retry in 15s...")
                time.sleep(15)
                continue
            run_id = run["id"]

        status = run.get("status")
        conclusion = run.get("conclusion")
        print(f"[{time.strftime('%H:%M:%S')}] run {run_id} status={status} conclusion={conclusion} "
              f"({int(time.time() - started)}s elapsed)")

        if status == "completed":
            if conclusion == "success":
                code, body = req("GET", f"/actions/runs/{run_id}/artifacts")
                print("\nBUILD SUCCEEDED. Artifacts:")
                for a in body.get("artifacts", []):
                    print(f"  - {a['name']}  ({a['size_in_bytes']} bytes, id={a['id']})")
                print(f"\nrun url: {run.get('html_url')}")
                sys.exit(0)
            else:
                print(f"\nBUILD FAILED (conclusion={conclusion}). Fetching log...")
                download_build_log(run_id)
                print(f"\nrun url: {run.get('html_url')}")
                sys.exit(1)

        if time.time() - started > MAX_WAIT_SEC:
            print("TIMEOUT waiting for CI")
            sys.exit(3)
        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
