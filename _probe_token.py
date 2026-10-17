# -*- coding: utf-8 -*-
"""检查 token 类型和权限"""
import io
import json
import urllib.request

cred = io.open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8").read()
TOKEN = None
for line in cred.splitlines():
    line = line.strip()
    if line.startswith("password="):
        TOKEN = line[len("password="):].strip()
        break
print("token prefix:", TOKEN[:8] if TOKEN else None, "len:", len(TOKEN) if TOKEN else 0)
print("token looks classic:", TOKEN.startswith("ghp_") or TOKEN.startswith("github_pat"))

for url in ["https://api.github.com/user",
            "https://api.github.com/user/repos?per_page=100"]:
    r = urllib.request.Request(url, headers={
        "Authorization": "Bearer " + TOKEN,
        "Accept": "application/vnd.github+json",
        "User-Agent": "probe",
    })
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if isinstance(data, dict):
                print("\nGET", url, "->", resp.status)
                print("  login:", data.get("login"))
                scopes = resp.headers.get("X-OAuth-Scopes")
                print("  X-OAuth-Scopes:", scopes)
            else:
                print("\nGET", url, "->", resp.status, "repos count:", len(data))
                for repo in data:
                    print("   -", repo["full_name"], "default:", repo["default_branch"])
    except urllib.error.HTTPError as e:
        print("\nGET", url, "->", e.code, e.read()[:300])
