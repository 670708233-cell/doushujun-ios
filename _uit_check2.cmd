@echo off
cd /d d:\hubulider\dsj\doushujunfull\doushujun-ios
echo ==== fullflow result ====
python -c "import io,re; t=io.open('_uit_latest.log',encoding='utf-8',errors='ignore').read(); [print(l) for l in t.splitlines() if 'testLoginFullFlow' in l or 'Executed' in l or 'probe' in l.lower()][:10]"
echo ==== backend log ====
python _dl_art.py 39629518061 backend-log
if errorlevel 1 ( echo NO_BACKEND_ART & exit /b 0 )
python -c "import zipfile,glob,io; zs=glob.glob('*backend*'); print(zs); z=zipfile.ZipFile(zs[0]); names=z.namelist(); print(names); body=z.read(names[0]).decode('utf-8','ignore'); print(chr(10).join(body.splitlines()[-25:]))"
