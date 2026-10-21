# -*- coding: utf-8 -*-
# 包内验证「我的」页改版：新版式文案 + 新接口路径必须在 Mach-O 内
import zipfile

z = zipfile.ZipFile('Doushujun-unsigned.ipa')
macho = [n for n in z.namelist() if n.endswith('/Doushujun') and '/Doushujun.app/' in n]
assert macho, '未找到主二进制'
m = z.read(macho[0])

markers = [
    'VIP到期', '作品查询', '权重查询', '会员中心', '联系客服', '使用协议', '版本信息',
    '去邀请', '未开通会员', '开通后畅享全部功能不限次', 'doushujun01',
    '修改昵称', '账号密码管理', '问题与建议', '套餐购买与支付',
]
paths = ['user/avatar', 'user/nickname', 'weight_used_today']

ok = True
for s in markers + paths:
    hit = s.encode('utf-8') in m
    ok = ok and hit
    print(('PASS' if hit else 'MISS'), s)

print('ALL OK' if ok else 'SOME MISSING')
