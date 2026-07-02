@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "APP_NAME=familiarscall-daily"
set "REGION=iad"

where fly >nul 2>&1
if errorlevel 1 (
  echo Install flyctl: https://fly.io/docs/hands-on/install-flyctl/
  goto :pause_error
)

echo This prepares a NEW Fly.io app (one-time setup).
echo Edit server\fly.toml if you want a different app name than %APP_NAME%.
echo.

fly auth login
if errorlevel 1 goto :pause_error

fly apps create %APP_NAME% 2>nul
fly volumes create fc_daily_data --app %APP_NAME% --region %REGION% --size 1

echo.
echo Setup complete. Run deploy_fly.bat to deploy.
goto :eof

:pause_error
pause
exit /b 1
