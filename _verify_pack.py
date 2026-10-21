# -*- coding: utf-8 -*-
"""验证最终包：评级图资源、本地地址、小程序密钥、tab 名"""
import zipfile

z = zipfile.ZipFile('Doushujun-unsigned.ipa')
ns = z.namelist()

car = [n for n in ns if 'Assets.car' in n][0]
b = z.read(car)
print('rating assets in car:', [x.decode() for x in [b'rating_a', b'rating_b', b'rating_c', b'rating_d'] if x in b])

mach = [n for n in ns if n.endswith('/Doushujun')][0]
m = z.read(mach)
print('local-url:', b'http://192.168.31.100:8000/api/' in m)
print('legacy-key:', b'd74230e9262ee220c7c130aec28c97b5' in m)
print('tab-name:', 'AI账号权重分析'.encode() in m)
