@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "VENV_PY=%CD%\.venv\Scripts\python.exe"

if exist "%VENV_PY%" (
  "%VENV_PY%" --version >nul 2>&1
  if errorlevel 1 (
    echo Removing broken .venv ...
    rmdir /s /q ".venv"
  )
)

if not exist "%VENV_PY%" (
  echo Creating virtual environment in:
  echo   %CD%\.venv
  echo.
  call :create_venv
  if not exist "%VENV_PY%" goto :no_python
)

echo Using Python:
"%VENV_PY%" --version
if errorlevel 1 goto :pause_error

echo.
echo Installing dependencies...
"%VENV_PY%" -m pip install --upgrade pip
if errorlevel 1 goto :pause_error
"%VENV_PY%" -m pip install -r requirements.txt
if errorlevel 1 (
  echo ERROR: pip install failed. Delete .venv and try again.
  goto :pause_error
)

echo.
echo Daily API: http://127.0.0.1:8080
echo Health:    http://127.0.0.1:8080/health
echo Press Ctrl+C to stop.
echo.
"%VENV_PY%" -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8080
if errorlevel 1 goto :pause_error
goto :eof

:create_venv
python --version >nul 2>&1
if not errorlevel 1 (
  python -m venv .venv
  if exist "%VENV_PY%" exit /b 0
)

py -3 --version >nul 2>&1
if not errorlevel 1 (
  py -3 -m venv .venv
  if exist "%VENV_PY%" exit /b 0
)

for /d %%D in ("%LocalAppData%\Programs\Python\Python3*") do (
  if exist "%%D\python.exe" (
    "%%D\python.exe" -m venv .venv
    if exist "%VENV_PY%" exit /b 0
  )
)

for /d %%D in ("%ProgramFiles%\Python3*") do (
  if exist "%%D\python.exe" (
    "%%D\python.exe" -m venv .venv
    if exist "%VENV_PY%" exit /b 0
  )
)
exit /b 1

:no_python
echo.
echo ERROR: Python 3 is not installed or not on PATH.
echo.
echo Install it:
echo   1. Open https://www.python.org/downloads/
echo   2. Download Python 3.12 or 3.13
echo   3. Run the installer
echo   4. CHECK the box "Add python.exe to PATH"
echo   5. Click "Install Now"
echo   6. Close this window and run run_dev.bat again
echo.
goto :pause_error

:pause_error
echo Failed to start dev server.
pause
exit /b 1
