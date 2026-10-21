# -*- coding: utf-8 -*-
"""把用户提供的 A/B/C/D 级评级徽章图加入 iOS Assets（rating_a/b/c/d.imageset）"""
import json, os, shutil

# 用户上传的徽章源图（与后端 /img/rating/ 同源资源）
SRC = r'C:\Users\Administrator\AppData\Local\CodeBuddyExtension\Data\affcf835-227b-46d9-8c81-ae9122e92279\CodeBuddyIDE\affcf835-227b-46d9-8c81-ae9122e92279\history\f4f7c41bbf78b7590c65c8570d0e9ab3\62788582c1e7431b8464ecafab2cb709\assets'
MAPPING = {
    'A级.fd5772e073.png': 'rating_a',
    'B级.e991ec8031.png': 'rating_b',
    'C级.c7b52c3338.png': 'rating_c',
    'D级.ae89592dc0.png': 'rating_d',
}
BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'Doushujun', 'Assets.xcassets')

for f, name in MAPPING.items():
    d = os.path.join(BASE, name + '.imageset')            # 每图一个 imageset 目录
    os.makedirs(d, exist_ok=True)
    shutil.copy(os.path.join(SRC, f), os.path.join(d, name + '.png'))   # 拷贝为统一资源名
    with open(os.path.join(d, 'Contents.json'), 'w', encoding='utf-8') as fp:
        json.dump({'images': [{'filename': name + '.png', 'idiom': 'universal'}],
                   'info': {'author': 'xcode', 'version': 1}}, fp)      # 单倍图声明（徽章小图够用）
    print('added:', name)
