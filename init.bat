@echo off
REM ==============================================================================
REM Docker LAMP Stack - Windows Initialization Script
REM ==============================================================================
REM For use without Git Bash - native Windows Command Prompt
REM ==============================================================================

echo ===================================================================
echo Docker LAMP Stack - Windows Initialization
echo ===================================================================
echo.

REM Check if Docker is installed
where docker >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Docker is not installed or not in PATH
    echo Please install Docker Desktop from: https://www.docker.com/products/docker-desktop
    pause
    exit /b 1
)

echo [INFO] Docker is installed
echo.

REM Check if docker compose is available
docker compose version >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Docker Compose is not available
    echo Please make sure Docker Desktop is running
    pause
    exit /b 1
)

echo [INFO] Docker Compose is available
echo.

echo ===================================================================
echo Environment Configuration
echo ===================================================================
echo.

REM Check if .env already exists
if exist .env (
    echo [WARNING] .env file already exists!
    set /p OVERWRITE="Do you want to overwrite it? (Y/N): "
    if /i not "%OVERWRITE%"=="Y" (
        echo [INFO] Keeping existing .env file
        goto :create_dirs
    )
)

REM Check if sample.env exists
if not exist sample.env (
    echo [ERROR] sample.env not found!
    pause
    exit /b 1
)

REM Copy sample.env to .env
copy sample.env .env >nul
echo [INFO] .env file created
echo [INFO] On Windows, Docker Desktop handles file permissions automatically
echo.

:create_dirs
echo ===================================================================
echo Creating Directories
echo ===================================================================
echo.

REM Create necessary directories
if not exist www mkdir www
if not exist data\mysql mkdir data\mysql
if not exist logs\apache2 mkdir logs\apache2
if not exist logs\mysql mkdir logs\mysql
if not exist logs\nginx mkdir logs\nginx
if not exist config\ssl mkdir config\ssl
if not exist config\nginx\ssl mkdir config\nginx\ssl
if not exist config\initdb mkdir config\initdb

echo [INFO] All directories created
echo.

echo ===================================================================
echo Configuration Summary
echo ===================================================================
echo.

REM Read configuration from .env (simplified)
for /f "tokens=1,2 delims==" %%a in ('type .env ^| findstr /v "^#" ^| findstr /v "^$"') do (
    if "%%a"=="COMPOSE_PROJECT_NAME" set PROJECT_NAME=%%b
    if "%%a"=="PHPVERSION" set PHP_VER=%%b
    if "%%a"=="DATABASE" set DB_VER=%%b
    if "%%a"=="HTTP_PORT" set HTTP=%%b
    if "%%a"=="USE_REVERSE_PROXY" set PROXY=%%b
)

echo Operating System: Windows
echo Project: %PROJECT_NAME%
echo PHP Version: %PHP_VER%
echo Database: %DB_VER%
echo Reverse Proxy: %PROXY%
echo HTTP Port: http://localhost:%HTTP%
echo.

echo ===================================================================
echo Next Steps
echo ===================================================================
echo.
echo 1. Review and customize your .env file if needed:
echo    notepad .env
echo.
echo 2. Start your stack:
echo    docker compose up -d
echo.
echo 3. Access your site:
echo    http://localhost:%HTTP%
echo.
echo 4. Access phpMyAdmin:
echo    http://localhost:%HTTP%/%PROJECT_NAME%-mysql
echo.
echo [INFO] Windows Notes:
echo   - Docker Desktop must be running
echo   - File permissions are handled automatically
echo   - For bash scripts, use Git Bash or WSL2
echo.

echo [INFO] Initialization complete!
echo.
pause
