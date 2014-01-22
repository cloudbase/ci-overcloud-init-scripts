@echo off
set PROJ=%1

C:\OpenStack\virtualenv\Scripts\activate.bat && cd %PROJ% && easy_install pip==1.4.1 && python setup.py install


