#!/usr/bin/env python3
"""本地验证 generate_project.py 三种模式（CI 三对照二分的前置检查）"""
import os, re, subprocess, sys

BASE = os.path.dirname(os.path.abspath(__file__))
GEN = os.path.join(BASE, "generate_project.py")
PROJ = os.path.join(BASE, "Doushujun.xcodeproj", "project.pbxproj")
SCHEME = os.path.join(BASE, "Doushujun.xcodeproj", "xcshareddata", "xcschemes", "Doushujun.xcscheme")

def run(env_extra, label):
    env = dict(os.environ)
    env.update(env_extra)
    r = subprocess.run([sys.executable, GEN], capture_output=True, text=True, cwd=BASE, env=env)
    print(f"--- {label} ---")
    print("exit:", r.returncode)
    if r.returncode != 0:
        print(r.stdout[-2000:])
        print(r.stderr[-2000:])
        return False
    pbx = open(PROJ, encoding="utf-8").read()
    has_uitest = "DoushujunUITests" in pbx
    has_scheme = os.path.isfile(SCHEME)
    # 括号平衡检查（排除注释行内的花括号：简单统计 {} 计数）
    stripped = "\n".join(re.sub(r"/\*.*?\*/", "", ln) for ln in pbx.splitlines())
    bal = stripped.count("{") - stripped.count("}")
    print(f"pbx: uitest_refs={has_uitest}, braces_balance={bal}, scheme_exists={has_scheme}")
    return True

ok = True
ok &= run({}, "full")
full_pbx = open(PROJ, encoding="utf-8").read()
assert "DoushujunUITests" in full_pbx, "full 模式必须包含 uitest"

ok &= run({"DSJ_NO_SCHEME": "1"}, "no-scheme")
no_sc_pbx = open(PROJ, encoding="utf-8").read()
assert no_sc_pbx == full_pbx, "no-scheme 模式 pbxproj 应与 full 完全一致（ID 确定性）"

ok &= run({"DSJ_NO_UITEST": "1"}, "no-uitest")
no_ui_pbx = open(PROJ, encoding="utf-8").read()
assert "DoushujunUITests" not in no_ui_pbx, "no-uitest 模式不应有 uitest 引用"
assert "PBXContainerItemProxy" not in no_ui_pbx
assert "PBXTargetDependency" not in no_ui_pbx

# 恢复 full 模式产物（与仓库现状一致）
run({}, "restore full")
print("\nALL OK" if ok else "\nFAILED")
sys.exit(0 if ok else 1)
