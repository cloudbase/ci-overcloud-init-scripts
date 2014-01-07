@echo off

set JOB=%1
set CONF=%2

C:\OpenStack\virtualenv\Scripts\activate.bat && %JOB% --config-file=%CONF%