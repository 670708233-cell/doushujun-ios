@echo off
cd /d d:\hubulider\dsj\doushujunfull\doushujun-ios
python _dl_art.py 39631097873 Doushujun-unsigned
if errorlevel 1 ( echo ART_FAILED & exit /b 1 )
python _dl_uit.py 39631097873
python -c "import io; t=io.open('_uit_latest.log',encoding='utf-8',errors='ignore').read(); [print(l) for l in t.splitlines() if 'Executed' in l or 'TEST' in l and 'SUCCEED' in l or 'FAILED **' in l]"
python -c "import zipfile; z=zipfile.ZipFile('Doushujun-unsigned.ipa'); m=[n for n in z.namelist() if n.endswith('/Doushujun') and '/Doushujun.app/' in n][0]; b=z.read(m); print('is_super_vip key hit:', b'super_vip_expire_time' in b)"
