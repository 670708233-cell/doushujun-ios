# -*- coding: utf-8 -*-
import re

s = open(r"Doushujun.xcodeproj/project.pbxproj", encoding="utf-8").read()

m = re.search(r"CC17253B6D5B180F11AFA5F8 /\* DoushujunUITests \*/ = \{.*?\n\t\t\};", s, re.S)
print("---NATIVE TARGET---")
print(m.group(0) if m else "NOT FOUND")

m = re.search(r"targets = \(.*?\);", s, re.S)
print("---PROJECT TARGETS---")
print(m.group(0) if m else "NOT FOUND")

m = re.search(r"[0-9A-F]{24} /\* Build configuration list for PBXNativeTarget .DoushujunUITests. \*/ = \{.*?\n\t\t\};", s, re.S)
print("---UITEST BCL---")
print(m.group(0) if m else "BCL NOT FOUND")

# uitest build configs
for cid in re.findall(r"([0-9A-F]{24}) /\* (Debug|Release) \*/ = \{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = \{\n\t\t\t\tBUNDLE_LOADER", s):
    print("---UITEST CFG---", cid)

# Sources phase (uitest)
m = re.search(r"[0-9A-F]{24} /\* Sources \*/ = \{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = \(\n\t\t\t\tB4138E1894EC1E59F01EBEF9.*?\n\t\t\};", s, re.S)
print("---UITEST SOURCES PHASE---")
print(m.group(0)[:500] if m else "NOT FOUND")
