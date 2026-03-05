@echo off
setlocal EnableDelayedExpansion
for %%D in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
  if exist %%D:\windows\bootstrap-win.ps1 (
    powershell -NoProfile -ExecutionPolicy Bypass -File %%D:\windows\bootstrap-win.ps1
    exit /b !errorlevel!
  )
)
echo windows\bootstrap-win.ps1 not found on mounted media
exit /b 2
