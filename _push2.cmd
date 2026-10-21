@echo off
cd /d d:\hubulider\dsj\doushujunfull\doushujun-ios
python _push_github.py
if errorlevel 1 ( echo PUSH_FAILED & exit /b 1 )
echo PUSH_OK
