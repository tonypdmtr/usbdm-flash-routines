@echo off
cls

set DEST_DIR=%~dp0\GeneratedFiles
set DEST_DIR_HCS08=%DEST_DIR%\HCS08

rem
rem HCS08 devices
rem
if not exist %DEST_DIR_HCS08% mkdir %DEST_DIR_HCS08%

set FILE_LIST_HCS08=
set FILE_LIST_HCS08=%FILE_LIST_HCS08% HCS08-PTxx-flash-program

echo %FILE_LIST_HCS08%
for %%f in (%FILE_LIST_HCS08%) do if exist %~dp0\%%f\RAM copy %~dp0\%%f\RAM\*.s19 %DEST_DIR_HCS08%

set FILE_LIST_HCS08=
set FILE_LIST_HCS08=%FILE_LIST_HCS08% HCS08-default-flash-program\Small-0x80 HCS08-default-flash-program\Default-0x80 HCS08-default-flash-program\Default-0xB0
set FILE_LIST_HCS08=%FILE_LIST_HCS08% HCS08-PAxx-flash-program\Default-eeprom-0x40 HCS08-PAxx-flash-program\Default-flash-0x40

echo %FILE_LIST_HCS08%
for %%f in (%FILE_LIST_HCS08%) do copy %~dp0\%%f\*.abs.s19 %DEST_DIR_HCS08%

exit
echo %FILE_LIST%

rmdir /s /q "%DEST_DIR%"/*
mkdir "%DEST_DIR%"

for %%f in (%FILE_LIST%) do if exist %~dp0\%%f\RAM copy %~dp0\%%f\RAM\*.s19 %DEST_DIR%
for %%f in (%FILE_LIST%) do if exist %~dp0\%%f\RAM copy %~dp0\%%f\RAM\*.sx  %DEST_DIR%
for %%f in (%FILE_LIST%) do if exist %~dp0\%%f\RAM copy %~dp0\%%f\RAM\*.hex %DEST_DIR%
for %%f in (%FILE_LIST%) do if exist %~dp0\%%f\RAM copy %~dp0\%%f\RAM\*.p.s %DEST_DIR%
rem copy /y "%~dp0\%%f\*.s19"  "%DEST_DIR%"



pause
