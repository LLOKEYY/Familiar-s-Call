@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0.."

echo Familiar's Call - Supabase deploy
echo.

where npx.cmd >nul 2>&1
if errorlevel 1 (
  where npx >nul 2>&1
  if errorlevel 1 (
    echo ERROR: Node.js not found. Install from https://nodejs.org/
    goto :pause_error
  )
  set "NPX=npx"
) else (
  set "NPX=npx.cmd"
)

echo [1/4] Checking Supabase CLI...
call %NPX% supabase --version
if errorlevel 1 goto :pause_error

if not exist "supabase\.temp\project-ref" (
  echo.
  echo Project not linked yet.
  echo  1. Run: %NPX% supabase login
  echo  2. Run: %NPX% supabase link --project-ref YOUR_REF
  echo     ^(Dashboard - Settings - General - Reference ID^)
  echo.
  set /p DOREF="Paste your project ref now (or press Enter to skip): "
  if not "!DOREF!"=="" (
    call %NPX% supabase link --project-ref !DOREF!
  )
)

echo.
echo [2/4] Pushing database migrations...
call %NPX% supabase db push
if errorlevel 1 (
  echo Migration push failed - you can also run SQL files manually in the dashboard.
)

echo.
echo [3/4] Deploying Edge Function: daily...
call %NPX% supabase functions deploy daily
if errorlevel 1 goto :pause_error

echo.
echo [4/4] Done.
echo.
echo Function URL: https://YOUR_PROJECT.supabase.co/functions/v1/daily
echo ^(replace YOUR_PROJECT with your project ref^)
echo.
echo In the game: Settings - Developer - Supabase URL + anon key - Sync
goto :eof

:pause_error
echo.
echo Deploy failed. Run manually from this folder:
echo   %NPX% supabase login
echo   %NPX% supabase link --project-ref YOUR_REF
echo   %NPX% supabase db push
echo   %NPX% supabase functions deploy daily
pause
exit /b 1
