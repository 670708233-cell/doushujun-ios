# -*- coding: utf-8 -*-
"""pbxproj 体检：括号平衡 + 悬空引用（定义了未引用 / 引用了未定义）。"""
import re
import sys

p = r"d:\hubulider\dsj\doushujunfull\doushujun-ios\Doushujun.xcodeproj\project.pbxproj"
s = open(p, encoding="utf-8").read()

# 1. 括号平衡
for a, b in [("{", "}"), ("(", ")")]:
    ca, cb = s.count(a), s.count(b)
    print(f"{a}{b}: {ca} vs {cb}", "OK" if ca == cb else "<<< MISMATCH")

# 1.5 重复 ID 定义（set 会掩盖碰撞）
all_defs = re.findall(r"^\t\t([0-9A-F]{24}) ", s, re.M)
if len(all_defs) != len(set(all_defs)):
    from collections import Counter
    print("<<< DUPLICATE DEFINITIONS:")
    for k, v in Counter(all_defs).items():
        if v > 1:
            print("  ", k, "x", v)
else:
    print("no duplicate definitions:", len(all_defs))

# 1.6 scheme XML 解析
import xml.etree.ElementTree as ET
try:
    tree = ET.parse(r"d:\hubulider\dsj\doushujunfull\doushujun-ios\Doushujun.xcodeproj\xcshareddata\xcschemes\Doushujun.xcscheme")
    root = tree.getroot()
    print("scheme XML OK, root =", root.tag)
except Exception as e:
    print("<<< SCHEME XML ERROR:", e)

# 2. ID 定义与引用
defined = set(re.findall(r"^\t\t([0-9A-F]{24}) ", s, re.M))
referenced = set(re.findall(r"\b([0-9A-F]{24})\b", s))
referenced -= set()  # 无操作

dangling_ref = referenced - defined          # 引用了但没定义 → 必炸
unref = defined - referenced                  # 定义了没引用（注释对象名不算引用？注释里是 /* name */ 不含 ID）

print("\ndefined objects:", len(defined))
print("\n== DANGLING REFERENCES (referenced but NOT defined) ==")
for i in sorted(dangling_ref):
    # 找引用位置行
    for m in re.finditer(rf"^\t\t.*\b{i}\b.*$", s, re.M):
        print(" ", i, "->", m.group(0).strip()[:150])
        break
if not dangling_ref:
    print("  none")

print("\n== DEFINED BUT NEVER REFERENCED ==")
for i in sorted(unref):
    for m in re.finditer(rf"^\t\t([0-9A-F]{{24}}) /\* (.+?) \*/", s, re.M):
        if m.group(1) == i:
            print(" ", i, m.group(2))
            break
if not unref:
    print("  none")

# 3. 各 section 关键对象存在性抽查
for key in ["PBXContainerItemProxy section", "PBXTargetDependency section"]:
    print(key, "OK" if key in s else "<<< MISSING")

# 4. uitest target 引用链完整性
uitest_target = re.search(r"([0-9A-F]{24}) /\* DoushujunUITests \*/ = \{", s)
if uitest_target:
    tid = uitest_target.group(1)
    print("\nuitest target id:", tid, "defined" if tid in defined else "<<< NOT DEFINED")
    # 抓该 target 的 buildConfigurationList / dependencies / productReference
    blk = re.search(rf"{tid} /\* DoushujunUITests \*/ = \{{(.*?)\n\t\t\}};", s, re.S)
    if blk:
        body = blk.group(1)
        for field in ["buildConfigurationList", "testTargetID", "productReference"]:
            m = re.search(field + r" = ([0-9A-F]{24})", body)
            if m:
                ok = m.group(1) in defined
                print(f"  {field} -> {m.group(1)}", "OK" if ok else "<<< DANGLING")
