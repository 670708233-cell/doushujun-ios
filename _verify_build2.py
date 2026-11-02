# -*- coding: utf-8 -*-
# 验证新 IPA 产物：文案进 Mach-O + 版本号进 Info.plist
import zipfile, io, os

Z = r'd:\hubulider\dsj\doushujunfull\doushujun-ios\_ipa\Doushujun-unsigned.zip'
OUT = r'd:\hubulider\dsj\doushujunfull\doushujun-ios\Doushujun-unsigned.ipa'

zf = zipfile.ZipFile(Z)
names = zf.namelist()
print('zip entries:', names[:6], '... total', len(names))

# 外层 zip 内套同名 ipa（两层壳）：真 IPA = 外层内那个 .ipa 直接字节写出
ipa_inner = [n for n in names if n.lower().endswith('.ipa')]
if ipa_inner:
    data = zf.read(ipa_inner[0])
    open(OUT, 'wb').write(data)
    print('ipa extracted ->', OUT, len(data), 'bytes')
    ip = zipfile.ZipFile(io.BytesIO(data))
else:
    # 或者 zip 直接就是 Payload 结构
    ip = zf

pl_names = [n for n in ip.namelist() if n.endswith('Info.plist')]
mach_names = [n for n in ip.namelist() if '/Doushujun' in n and '.' not in os.path.basename(n).split('/')[-1]]
print('Info.plist candidates:', pl_names)
print('Mach-O candidates:', mach_names)

import plistlib

for n in pl_names[:1]:
    b = ip.read(n)
    try:
        d = plistlib.loads(b)   # 内置 app 的 Info.plist 是二进制格式
        ver, build = d.get('CFBundleShortVersionString'), d.get('CFBundleVersion')
    except Exception:
        ver, build = (b'<string>1.0.1</string>' in b, b'<string>2</string>' in b)
    print('version:', ver, '| build:', build)

mach = [n for n in ip.namelist() if n == 'Payload/Doushujun.app/Doushujun']
for n in mach[:1]:
    b = ip.read(n)
    print('macho size:', len(b))
    # >=15B 字面量才保证进 Mach-O（注释不进包属预期）
    print('macho-new-errmsg(服务响应异常):', '服务响应异常'.encode() in b)
    print('macho-old-errmsg(原始:):', '原始:'.encode() in b)
