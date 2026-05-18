@echo off
cls
echo.
echo =================================================
echo ==      BITE HUB SYSTEM INSTALLER ^& LAUNCHER     ==
echo =================================================
echo.

echo [1/5] Checking for Python installation...
python --version >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Python is not installed or not added to PATH.
    echo Please install Python from python.org and check the "Add Python to PATH" box during installation.
    pause
    exit /b
)
echo Python found!

echo.
echo [2/5] Creating virtual environment (this might take a moment)...
if not exist .venv (
    python -m venv .venv
)
echo Virtual environment is ready.

echo.
echo [3/5] Installing required libraries (Django, API, etc.)...
echo This is a one-time setup and might take a few minutes.
call .venv\Scripts\activate.bat
pip install --upgrade pip >nul
pip install -r requirements.txt

echo.
echo [4/5] Starting the Bite Hub server...
echo.
echo ====================================================================
echo    SERVER IS RUNNING!
echo    Open your web browser and go to: http://127.0.0.1:8000/
echo    To stop the server, close this window or press CTRL+C.
echo ====================================================================
echo.

python manage.py runserver

echo.
echo [5/5] Server stopped.
pause
