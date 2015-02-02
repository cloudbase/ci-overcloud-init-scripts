@echo off

set PY_EXEC=%1
set PY_FILE=%2
set CONF=%3
set CONSOLELOG=%4

C:\OpenStack\virtualenv\Scripts\activate.bat && %PY_EXEC% %PY_FILE% --config-file=%CONF% > %CONSOLELOG% 2>&1
