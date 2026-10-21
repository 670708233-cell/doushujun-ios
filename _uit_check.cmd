@echo off
cd /d d:\hubulider\dsj\doushujunfull\doushujun-ios
python _dl_uit.py 39629518061
if errorlevel 1 ( echo DL_FAILED & exit /b 1 )
python -c "import re,io; lines=io.open('_uit_latest.log',encoding='utf-8',errors='ignore').read().splitlines(); hits=[l for l in lines if re.search(r'Failing|failed|error:|SOFT-Fail|Assertion',l,re.I)]; print(chr(10).join(h[:200] for h in hits[:40]))"
