@echo off
setlocal EnableExtensions
title Ambil Driver Epson L120 dari PC ini
REM Jalankan di PC/laptop yang SUDAH bisa print (driver L120 sudah terpasang).
REM Hasil: driver disalin ke folder driver\x64 (atau x86) dalam paket ini.
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
cd /d "%~dp0"
set "ARCH=x86"
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "ARCH=x64"
if defined PROCESSOR_ARCHITEW6432 set "ARCH=x64"
set "OUT=%~dp0driver\%ARCH%\inf"
echo Mengambil driver Epson L120 (%ARCH%) ke "%OUT%" ...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$d = Get-PrinterDriver | Where-Object { $_.Name -like '*L120*' } | Select-Object -First 1;" ^
 "if (-not $d) { Write-Host 'Driver L120 tidak ditemukan di PC ini!' -f Red; exit 1 };" ^
 "Write-Host ('Driver: ' + $d.Name + '  INF: ' + $d.InfPath);" ^
 "$src = Split-Path $d.InfPath; $dst = '%OUT%';" ^
 "if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }; New-Item -ItemType Directory $dst | Out-Null;" ^
 "Copy-Item (Join-Path $src '*') $dst -Recurse -Force;" ^
 "Write-Host ('Disalin: ' + (Get-ChildItem $dst -Recurse).Count + ' file') -f Green"
if errorlevel 1 ( pause & exit /b 1 )
echo.
echo SELESAI. Sekarang copy SELURUH folder paket ini ke PC lain,
echo lalu jalankan Pasang-Printer-L120.bat di sana.
pause
