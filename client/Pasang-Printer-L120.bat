@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Pasang Printer Epson L120 (Server NGEMIS-AI)
REM ==== Pengaturan ====
set "SERVER=NGEMIS-AI"
set "PRN=Epson L120 Server"

REM ==== Minta hak Administrator ====
net session >nul 2>&1
if errorlevel 1 (
  echo Meminta hak Administrator...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" 2>nul
  if errorlevel 1 echo Klik kanan file ini lalu pilih "Run as administrator". & pause
  exit /b
)
cd /d "%~dp0"

set "ARCH=x86"
set "ENV=Windows NT x86"
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "ARCH=x64"
if defined PROCESSOR_ARCHITEW6432 set "ARCH=x64"
if "%ARCH%"=="x64" set "ENV=Windows x64"
set "DRVROOT=HKLM\SYSTEM\CurrentControlSet\Control\Print\Environments\%ENV%\Drivers\Version-3"
echo Windows %ARCH%

REM ==== 1. Cek server ====
echo [1/4] Mencari server %SERVER% ...
ping -n 2 %SERVER% >nul 2>&1
if errorlevel 1 (
  echo   Server "%SERVER%" tidak ditemukan lewat nama.
  echo   Pastikan server menyala dan satu jaringan WiFi/LAN.
  set /p "SERVER=  Ketik IP server (di server: hostname -I) lalu Enter: "
)

REM ==== 2. Driver ====
REM Mode A: driver Epson asli sudah ada  -> port 9100 (diteruskan apa adanya)
REM Mode B: TANPA driver Epson           -> driver bawaan Windows (PostScript)
REM         ke port 9101, server yang mengubah ke bahasa printer Epson.
REM         Tidak perlu installer Epson / kabel USB.
echo [2/4] Menyiapkan driver ...
call :findepson
if defined DRV goto :modeA

set "INF="
for /r "driver\%ARCH%" %%F in (*.inf) do if not defined INF set "INF=%%F"
if defined INF (
  echo   Memasang driver Epson dari paket: !INF!
  rundll32 printui.dll,PrintUIEntry /ia /m "EPSON L120 Series" /f "!INF!"
  timeout /t 5 /nobreak >nul
  call :findepson
  if defined DRV goto :modeA
  echo   Driver Epson gagal dipasang, pakai driver bawaan Windows.
)
goto :modeB

:modeA
set "PORTNO=9100"
echo   Pakai driver Epson: "!DRV!"
goto :port

:modeB
set "PORTNO=9101"
set "DRV="
for %%D in ("MS Publisher Color Printer" "Microsoft PS Class Driver" "MS Publisher Imagesetter") do (
  if not defined DRV (
    reg query "%DRVROOT%\%%~D" >nul 2>&1
    if errorlevel 1 rundll32 printui.dll,PrintUIEntry /ia /m "%%~D" /f "%windir%\inf\ntprint.inf"
    reg query "%DRVROOT%\%%~D" >nul 2>&1
    if not errorlevel 1 set "DRV=%%~D"
  )
)
if not defined DRV ( echo   GAGAL memasang driver bawaan Windows. & pause & exit /b 1 )
echo   Pakai driver bawaan Windows: "!DRV!" (tanpa driver Epson)

:port
set "PORT=IP_%SERVER%_%PORTNO%"
REM ==== 3. Port TCP/IP (pakai NAMA server, aman walau IP berubah) ====
echo [3/4] Membuat port %PORT% -^> %SERVER%:%PORTNO% ...
set "SCR="
for /d %%D in ("%windir%\System32\Printing_Admin_Scripts\*") do if exist "%%D\prnport.vbs" set "SCR=%%D"
if not defined SCR ( echo   prnport.vbs tidak ditemukan! & pause & exit /b 1 )
cscript //nologo "%SCR%\prnmngr.vbs" -d -p "%PRN%" >nul 2>&1
cscript //nologo "%SCR%\prnport.vbs" -d -r "%PORT%" >nul 2>&1
cscript //nologo "%SCR%\prnport.vbs" -a -r "%PORT%" -h %SERVER% -o raw -n %PORTNO% -md
if errorlevel 1 ( echo   Gagal membuat port. & pause & exit /b 1 )

REM ==== 4. Tambah printer ====
echo [4/4] Menambahkan printer "%PRN%" ...
cscript //nologo "%SCR%\prnmngr.vbs" -a -p "%PRN%" -m "!DRV!" -r "%PORT%"
if errorlevel 1 ( echo   Gagal menambah printer. & pause & exit /b 1 )
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Print\Printers\%PRN%\PrinterDriverData" /v "EnableBidi" /t REG_DWORD /d 0 /f >nul 2>&1

choice /c YN /m "Jadikan printer default?"
if not errorlevel 2 cscript //nologo "%SCR%\prnmngr.vbs" -t -p "%PRN%" >nul
choice /c YN /m "Cetak halaman test?"
if not errorlevel 2 rundll32 printui.dll,PrintUIEntry /k /n "%PRN%"
echo.
echo SELESAI. Printer "%PRN%" siap dipakai (port %PORTNO%).
pause
exit /b 0

:findepson
REM cari driver Epson yang namanya mengandung L120
set "DRV="
for /f "tokens=*" %%K in ('reg query "%DRVROOT%" 2^>nul ^| findstr /i "L120"') do (
  if not defined DRV for %%N in ("%%K") do set "DRV=%%~nxN"
)
exit /b
