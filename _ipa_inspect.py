# -*- coding: utf-8 -*-
# 验尸 IPA：bundle 里有没有 geetest.html / 极验相关资源
import zipfile

ip = zipfile.ZipFile(r'd:\hubulider\dsj\doushujunfull\doushujun-ios\Doushujun-unsigned.ipa')
names = ip.namelist()
app = [n for n in names if n.startswith('Payload/Doushujun.app/')]
print('=== bundle 根下的非图片文件 ===')
for n in sorted(app):
    base = n.split('Payload/Doushujun.app/', 1)[1]
    if '/' not in base and not base.lower().endswith(('.png', '.jpg')):
        print(' ', base)
print('=== geetest 相关 ===')
hits = [n for n in names if 'geetest' in n.lower()]
print(hits if hits else '  ★ 无任何 geetest 文件！')
# html 全列
print('=== 所有 html ===')
print([n for n in names if n.endswith('.html')] or '  ★ 无 html')
# Mach-O 里搜「验证组件缺失」（若 bundle 缺 html 会走这分支）
mach = ip.read('Payload/Doushujun.app/Doushujun')
for lit in ['验证组件缺失', '正在初始化安全验证']:
    print(lit, '->', lit.encode() in mach)
