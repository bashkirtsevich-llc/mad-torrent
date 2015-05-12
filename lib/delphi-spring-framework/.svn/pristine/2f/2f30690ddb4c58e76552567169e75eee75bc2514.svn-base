@echo off
echo Cleaning...
del /f /q /s *.bak
del /f /q /s *.dcu
del /f /q /s *.ddp
del /f /q /s *.~dsk
del /f /q /s *.~pas
del /f /q /s *.~dfm
del /f /q /s *.~ddp
del /f /q /s *.~dpr
del /f /q /s *.local
del /f /q /s *.identcache
del /f /q /s *.tvsconfig

del /f /q /s *.bpl
del /f /q /s *.cbk
del /f /q /s *.dcp
del /f /q /s *.dsk
del /f /q /s *.rsm
del /f /q /s *.skincfg
del /f /q /s Samples\*.exe
del /f /q /s Tests\*.exe
del /f /q /s Tests\*.ini
del /f /q /s Tests\*.xml

for /f "tokens=* delims=" %%i in ('dir /s /b /a:d __history') do (
  rd /s /q "%%i"
)
