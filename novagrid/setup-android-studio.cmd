@echo off
setlocal
cd /d "%~dp0"
echo.
echo [NovaGrid] Setting up Android Studio from the GitHub checkout...
echo.
where node >nul 2>&1
if errorlevel 1 (
  echo ERROR: Node.js 22 or newer is required. Install it from https://nodejs.org/
  exit /b 1
)
where npm >nul 2>&1
if errorlevel 1 (
  echo ERROR: npm was not found. Repair your Node.js installation.
  exit /b 1
)
call npm install --no-audit --no-fund
if errorlevel 1 exit /b 1
call npm run build
if errorlevel 1 exit /b 1
if exist "android\settings.gradle" (
  echo [NovaGrid] Updating existing Android project...
  call npx cap sync android
) else (
  echo [NovaGrid] Generating Android project...
  call npx cap add android
)
if errorlevel 1 exit /b 1
call npm run android:ads
if errorlevel 1 exit /b 1
call npm run android:brand
if errorlevel 1 exit /b 1
echo.
echo [NovaGrid] Android project is ready. Opening Android Studio...
call npx cap open android
if errorlevel 1 (
  echo [NovaGrid] Open the android folder manually in Android Studio.
)
echo.
echo [NovaGrid] GitHub is linked to the PARENT Git checkout, not to the generated android folder.
echo Edit files inside novagrid\web, run "npm run android:sync", then Git Commit and Push.
endlocal
