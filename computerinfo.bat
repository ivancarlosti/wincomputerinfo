@echo off
chcp 65001
cls

:begin
echo Select desired option:
echo.
echo 1) Execute Computer Info report and show information on PowerShell prompt
echo 2) Execute Computer Info report and show information on Browser + HTML on Downloads folder
echo.
set /p op=Digite o número da opção: 
if "%op%"=="1" goto op1
if "%op%"=="2" goto op2

cls
goto begin

:op1
echo Computer Info report and show information on PowerShell prompt
powershell -ExecutionPolicy Bypass -File computerinfo-local.ps1
goto exit

:op2
echo Computer Info report and show information on Browser + HTML on Downloads folder
powershell -ExecutionPolicy Bypass -File computerinfo-html.ps1
goto exit

:exit
echo Processo finalizado.
@exit
