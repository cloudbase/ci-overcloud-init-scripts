@echo off
set PROJ=%1
C:\OpenStack\virtualenv\Scripts\activate.bat && pip install -U networking-hyper-v --pre && cd %PROJ% && python setup.py install


