@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "REPO_ROOT=%~dp0.."
set "FLY_CONFIG=%~dp0fly.toml"
set "APP_NAME=familiarscall-daily"

where fly >nul 2>&1
if errorlevel 1 (
  echo flyctl is not installed.
  echo Install: https://fly.io/docs/hands-on/install-flyctl/
  echo Then run: fly auth login
  goto :pause_error
)

echo Repo root: %REPO_ROOT%
echo Fly config: %FLY_CONFIG%
echo.

pushd "%REPO_ROOT%"
fly deploy . --config server\fly.toml
if errorlevel 1 goto :pop_error

echo.
echo Deploy finished.
echo Health:  https://%APP_NAME%.fly.dev/health
echo.
echo In the game: Settings ^> Developer ^> Backend URL
echo Set to:      https://%APP_NAME%.fly.dev
echo Then Sync.
popd
goto :eof

:pop_error
popd
:pause_error
echo Deploy failed.
pause
exit /b 1
