@echo off
cd /d d:\hubulider\dsj\doushujunfull\doushujun-ios
python _dl_art.py 39727466626 Doushujun-unsigned
if errorlevel 1 ( echo ART_FAILED & exit /b 1 )
python _dl_uit.py 39632862974
python -c "import io; t=io.open('_uit_latest.log',encoding='utf-8',errors='ignore').read(); [print(l) for l in t.splitlines() if 'Executed' in l or 'TEST SUCCEEDED' in l or 'TEST FAILED' in l]"
