@echo off
set PROJ=%1

C:\OpenStack\virtualenv\Scripts\activate.bat && cd %PROJ% && pip install pbr==0.5.22 && python setup.py install


