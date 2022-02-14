@echo off
setlocal
set STATUS=0
set TEST_MODE=false
set DEBUG=true

:start
title RCLONE BACKUP

where rclone >nul 2>&1
if %ERRORLEVEL% NEQ 0 echo rclone not found && set STATUS=%ERRORLEVEL% && goto eof

set CONFIG_DIR=%userprofile%\.config\rclone-backup

set ARG=%1
set SCRIPT_CONFIG_OVERRIDE=
if exist "%1\config.conf" (
	set ARG=%2
	set CONFIG_DIR=%1
) else if exist "%1" (
	set ARG=%2
	set SCRIPT_CONFIG_OVERRIDE=%1
)

set CONFIG_DIR=%CONFIG_DIR:"=%

set SCRIPT_CONFIG=%CONFIG_DIR%\config.conf
set RCLONE_CONFIG=%CONFIG_DIR%\rclone.conf
set FILTER_RULES=%CONFIG_DIR%\filter.txt
set REMOTE_PATH=remote:
set LOCAL_PATH=/
set SHOW_PROGRESS=true
set DRY_RUN=false
set EXTRA_ARGUMENTS=--skip-links --ignore-case --fast-list
set EXTRA_ARGUMENTS_FTP=--vfs-cache-mode off --no-modtime
set EXTRA_ARGUMENTS_WEBDAV=--cache-dir="%TEMP%\rclone-vfs-cache" --vfs-cache-mode writes --no-modtime --read-only
set TEST_LOG=%TEMP%\rclone.log

if not "%SCRIPT_CONFIG_OVERRIDE%"=="" (
	set SCRIPT_CONFIG=%SCRIPT_CONFIG_OVERRIDE%
)

set SCRIPT_CONFIG=%SCRIPT_CONFIG:"=%

if "%SCRIPT_CONFIG:~0,1%"=="." (
	set SCRIPT_CONFIG=%CD%%SCRIPT_CONFIG:~1%
)

if not exist "%SCRIPT_CONFIG%" (
	if not %TEST_MODE% equ true (
		echo Missing config file: %SCRIPT_CONFIG%
		@pause
		goto eof
	)
) else (
	for /F "delims= eol=#" %%A in (%SCRIPT_CONFIG%) do set "%%A"
)

if "%RCLONE_CONFIG:~0,1%"=="." (
	set RCLONE_CONFIG=%CD%%RCLONE_CONFIG:~1%
)

if "%FILTER_RULES:~0,1%"=="." (
	set FILTER_RULES=%CD%%FILTER_RULES:~1%
)

if not %TEST_MODE% equ true (
	if not exist "%RCLONE_CONFIG%" (
		echo Missing rclone config file: %RCLONE_CONFIG%
		@pause
		goto eof
	)

	if not exist "%FILTER_RULES%" (
		echo Missing filter file: %FILTER_RULES%
		@pause
		goto eof
	)
)

if "%ARG%"=="test" (
	set TEST_MODE=true
)

if %TEST_MODE% equ true (
	set RCLONE_CONFIG=%~dp0rclone-test.conf
	set REMOTE_PATH=memory:
	set SHOW_PROGRESS=true
	set DRY_RUN=true
	set EXTRA_ARGUMENTS=--skip-links --ignore-case --log-level INFO --log-file="%TEST_LOG%"
)

if "%ARG%"=="sync" goto sync
if "%ARG%"=="sync-wait" goto sync
if "%ARG%"=="gui" goto gui
if "%ARG%"=="webdav" goto serve_webdav
if "%ARG%"=="ftp" goto serve_webdav
if "%ARG%"=="edit" goto config

:menu
if %TEST_MODE% equ true (
	title RCLONE BACKUP (TEST MODE^)
) else (
	title RCLONE BACKUP
)

cls
set M=

if not "%DEBUG%"=="" (
	call :show_config
) else (
	echo.
)

echo  MENU:
echo   1 - Run synchronization
echo   2 - Serve through FTP (read-write)
echo   3 - Serve through WebDAV (read-only)
echo   4 - Open Web GUI
echo   5 - Open configuration editor

if %TEST_MODE% equ true (
	echo   6 - Switch to normal mode
) else (
	echo   6 - Switch to test mode
)

echo   Q - Exit
echo.

set /P M=Type a number or Q then press ENTER: 
if %M%==1 goto sync
if %M%==2 goto serve_ftp
if %M%==3 goto serve_webdav
if %M%==4 goto gui
if %M%==5 goto config

if %TEST_MODE% equ true (
	if %M%==6 set TEST_MODE=false && goto start
) else (
	if %M%==6 set TEST_MODE=true && goto start
)

if "%M%"=="q" goto eof
goto menu

:gui
cls
rclone rcd --config="%RCLONE_CONFIG%" --rc-web-gui
set STATUS=%ERRORLEVEL%

if "%ARG%"=="gui" goto eof
@pause
goto menu

:edit
cls
rclone --config="%RCLONE_CONFIG%" config
set STATUS=%ERRORLEVEL%

if "%ARG%"=="config" goto eof
@pause
goto menu

:serve_ftp
cls
start "" ftp://localhost:2172/
rclone --config="%RCLONE_CONFIG%" serve ftp %REMOTE_PATH% --addr localhost:2172 %EXTRA_ARGUMENTS_FTP%
set STATUS=%ERRORLEVEL%

if "%ARG%"=="ftp" goto eof
@pause
goto menu

:serve_webdav
cls
start "" http://localhost:8072/
rclone --config="%RCLONE_CONFIG%" serve webdav %REMOTE_PATH% --addr localhost:8072 %EXTRA_ARGUMENTS_WEBDAV%
set STATUS=%ERRORLEVEL%

if "%ARG%"=="webdav" goto eof
@pause
goto menu

:show_config
echo.
echo  CONFIGURATION:
echo   CONFIG_DIR=%CONFIG_DIR%
echo   SCRIPT_CONFIG=%SCRIPT_CONFIG%
echo   RCLONE_CONFIG=%RCLONE_CONFIG%
echo   FILTER_RULES=%FILTER_RULES%
echo   REMOTE_PATH=%REMOTE_PATH%
echo   LOCAL_PATH=%LOCAL_PATH%
echo   SHOW_PROGRESS=%SHOW_PROGRESS%
echo   DRY_RUN=%DRY_RUN%
echo   EXTRA_ARGUMENTS=%EXTRA_ARGUMENTS%
echo.
exit /b

:sync
cls

if %SHOW_PROGRESS% equ true (
	set EXTRA_ARGUMENTS=%EXTRA_ARGUMENTS% --progress --stats 1s
)

if %DRY_RUN% equ true (
	set EXTRA_ARGUMENTS=%EXTRA_ARGUMENTS% --dry-run
)

echo.
echo ARGUMENTS: --config="%RCLONE_CONFIG%" --filter-from "%FILTER_RULES%" sync %LOCAL_PATH% %REMOTE_PATH% %EXTRA_ARGUMENTS%
echo.

if %TEST_MODE% equ true (
	if exist "%TEST_LOG%" (
		del "%TEST_LOG%"
	)
)

if "%ARG%"=="sync-wait" @pause

if not "%DEBUG%"=="" (
	@pause
)

cd %~dp0
rclone --config="%RCLONE_CONFIG%" --filter-from "%FILTER_RULES%" sync %LOCAL_PATH% %REMOTE_PATH% %EXTRA_ARGUMENTS%
set STATUS=%ERRORLEVEL%
echo.

if "%ARG%"=="sync" goto eof
@pause
goto menu

:exit
echo.
@pause

:eof
exit /B %STATUS%
