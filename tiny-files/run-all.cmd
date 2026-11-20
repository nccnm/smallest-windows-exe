@echo off
rem Run each file and print the Windows message together with the exit code.
cd /d "%~dp0"
for %%F in (20.com 97.exe 133.exe 252.exe 267.exe 268.exe) do (
  echo.
  echo ===== %%F  ^(%%~zF bytes^) =====
  ".\%%F"
  call echo exit code = %%errorlevel%%
)
echo.
pause
