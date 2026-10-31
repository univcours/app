@echo off
setlocal
cd /d "%~dp0"

where git >nul 2>&1
if errorlevel 1 (
  echo ERROR: Git for Windows is not installed or not available on PATH.
  exit /b 1
)
where node >nul 2>&1
if errorlevel 1 (
  echo ERROR: Install Node.js 22 or newer before synchronizing the game.
  exit /b 1
)
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
  echo ERROR: This folder is not a Git clone. Clone the novagrid-mvp branch first.
  echo git clone --branch novagrid-mvp --single-branch https://github.com/univcours/app.git
  exit /b 1
)
for /f "delims=" %%B in ('git branch --show-current') do set "GIT_BRANCH=%%B"
if /I not "%GIT_BRANCH%"=="novagrid-mvp" (
  echo ERROR: Checked-out branch is "%GIT_BRANCH%". Expected: novagrid-mvp.
  echo Switch branches in Android Studio before running this script.
  exit /b 1
)
echo [NovaGrid] Pulling new source from GitHub without overwriting local commits...
git pull --ff-only origin novagrid-mvp
if errorlevel 1 (
  echo ERROR: Pull stopped. Resolve local changes or branch divergence in Android Studio.
  exit /b 1
)
echo [NovaGrid] Checking Android build prerequisites...
call npm install --no-audit --no-fund
if errorlevel 1 exit /b 1
if not exist "android\settings.gradle" (
  echo [NovaGrid] Generating Android native project for first run...
  call npm run build
  if errorlevel 1 exit /b 1
  call npx cap add android
  if errorlevel 1 exit /b 1
) else (
  echo [NovaGrid] Applying newest web assets and Capacitor config to Android...
  call npm run android:sync
  if errorlevel 1 exit /b 1
)
echo.
echo SUCCESS: NovaGrid Android project updated from GitHub.
echo Return to Android Studio, allow Gradle Sync if prompted, and click Run.
endlocal
