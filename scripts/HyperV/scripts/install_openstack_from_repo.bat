@echo off
set PROJ=%1
C:\Python27\Scripts\pip.exe install -U networking-hyperv
C:\OpenStack\virtualenv\Scripts\activate.bat && cd %PROJ% && python setup.py install


