:: Made by Jack'lul <jacklul.github.io>

@echo off
setlocal
set CPATH=%~dp0
set TEST_MODE=false
set HAS_ADMIN=false

:start
title RCLONE BACKUP

:: Check if rclone command is globally available
where rclone >nul 2>&1
if %ERRORLEVEL% NEQ 0 echo rclone not found && echo %ERRORLEVEL% && exit /B %ERRORLEVEL%
for /F "tokens=*" %%g in ('where rclone') do (set RCLONE_BIN=%%g)

:: This is the default location for the config file
set CONFIG_DIR=%userprofile%\.config\rclone-backup

set ARG=%1
set SCRIPT_CONFIG_OVERRIDE=

:: Check whenever first argument is config file path or directory containing config file
if exist "%1\config.conf" (
	set ARG=%2
	set CONFIG_DIR=%1
) else if exist "%1" (
	set ARG=%2
	set SCRIPT_CONFIG_OVERRIDE=%1
	for %%F in (%1) do set CPATH=%%~dpF
)

:: Strip ending slashes from current path
if "%CPATH:~-1%"=="/" (
	set CPATH=%CPATH:~0,-1%
)
if "%CPATH:~-1%"=="\" (
	set CPATH=%CPATH:~0,-1%
)

:: Test mode activated by argument
if "%ARG%"=="test" (
	set TEST_MODE=true
)

:: Make sure we are in the current config path
cd %CPATH%

set CONFIG_DIR=%CONFIG_DIR:"=%
set SCRIPT_CONFIG=%CONFIG_DIR%\config.conf
set RCLONE_CONFIG=%CONFIG_DIR%\rclone.conf
set FILTER_RULES=%CONFIG_DIR%\filter.txt
set REMOTE_PATH=remote:
set LOCAL_DRIVE=C
set LOCAL_PATH=/
set SHOW_PROGRESS=true
set DRY_RUN=false
set USE_VSS=false
set VSS_DRIVE=T
set ARGUMENTS=--skip-links --ignore-case --fast-list
set ARGUMENTS_FTP=--vfs-cache-mode off --no-modtime --crypt-show-mapping
set ARGUMENTS_WEBDAV=--vfs-cache-mode off --no-modtime --crypt-show-mapping --read-only
set PORT_FTP=2150
set PORT_WEBDAV=8050
set TEST_LOG=%TEMP%\rclone.log

:: For WebDav RW: --cache-dir="%TEMP%\rclone-vfs-cache" --vfs-cache-mode writes

:: Override script config with command line argument
if not "%SCRIPT_CONFIG_OVERRIDE%"=="" (
	set SCRIPT_CONFIG=%SCRIPT_CONFIG_OVERRIDE%
	set CONFIG_DIR=%CPATH%
)
set SCRIPT_CONFIG=%SCRIPT_CONFIG:"=%

:: Correct SCRIPT_CONFIG to relative path
if "%SCRIPT_CONFIG:~0,1%"=="." (
	set SCRIPT_CONFIG=%CPATH%%SCRIPT_CONFIG:~1%
)

:: Check if the config file exists and load variables
if not exist "%SCRIPT_CONFIG%" (
	if not %TEST_MODE% equ true (
		echo Missing config file: %SCRIPT_CONFIG%
		@pause
		exit /B 2
	)
) else (
	for /F "delims= eol=#" %%A in (%SCRIPT_CONFIG%) do set "%%A"
)

:: Correct RCLONE_CONFIG to relative path
if "%RCLONE_CONFIG:~0,1%"=="." (
	set RCLONE_CONFIG=%CPATH%%RCLONE_CONFIG:~1%
)

:: Correct FILTER_RULES to relative path
if "%FILTER_RULES:~0,1%"=="." (
	set FILTER_RULES=%CPATH%%FILTER_RULES:~1%
)

:: Check if required config files exist
if not %TEST_MODE% equ true (
	if not exist "%RCLONE_CONFIG%" (
		echo Missing rclone config file: %RCLONE_CONFIG%
		@pause
		exit /B 2
	)

	if not exist "%FILTER_RULES%" (
		echo Missing filter file: %FILTER_RULES%
		@pause
		exit /B 2
	)
)

:: Check if we are running as administrator to enable/disable VSS mode
if "%PROCESSOR_ARCHITECTURE%" equ "amd64" (
	>nul 2>&1 "%SYSTEMROOT%\SysWOW64\cacls.exe" "%SYSTEMROOT%\SysWOW64\config\system"
) else (
	>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
)
if '%errorlevel%' NEQ '0' (
	set USE_VSS=false
	set HAS_ADMIN=false
) else (
	set USE_VSS=true
	set HAS_ADMIN=true
)

:: Overwrite config with test mode variables
if %TEST_MODE% equ true (
	if not exist "%TEMP%\rclone-test.conf" (
		echo [memory]> "%TEMP%\rclone-test.conf"
		echo type = memory>> "%TEMP%\rclone-test.conf"
	)

	set RCLONE_CONFIG=%TEMP%\rclone-test.conf
	set REMOTE_PATH=memory:
	set DRY_RUN=true
	set USE_VSS=false
	set SHOW_PROGRESS=true
	set ARGUMENTS=--skip-links --ignore-case --log-level INFO --log-file="%TEST_LOG%"
)

:: Quick argument shortcuts to script functions
if "%ARG%"=="sync" goto sync
if "%ARG%"=="sync-wait" goto sync
if "%ARG%"=="gui" goto gui
if "%ARG%"=="webdav" goto serve_webdav
if "%ARG%"=="ftp" goto serve_webdav
if "%ARG%"=="edit" goto config
if "%ARG%"=="about" goto about

:: Menu handler
:menu
if %TEST_MODE% equ true (
	title RCLONE BACKUP (TEST MODE^)
) else (
	title RCLONE BACKUP
	
	for %%i in ("%SCRIPT_CONFIG%") do (
		title RCLONE BACKUP (%%~ni%%~xi^)
	)
)

cls
set M=
call :show_config

echo  MENU:
echo   1 - Run synchronization
echo   2 - Serve through FTP (read-write)
echo   3 - Serve through WebDAV (read-only)
echo   4 - Open Web GUI
echo   5 - Open configuration editor
echo   6 - Remote quota information

if %TEST_MODE% equ true (
	echo   M - Switch to normal mode
) else (
	echo   M - Switch to test mode
)

echo   Q - Exit
echo.

set /P M=Type a number or Q then press ENTER: 
if %M%==1 goto sync
if %M%==2 goto serve_ftp
if %M%==3 goto serve_webdav
if %M%==4 goto gui
if %M%==5 goto edit
if %M%==6 goto about

:: Switch test/normal mode
if %TEST_MODE% equ true (
	if "%M%"=="m" set TEST_MODE=false && goto start
	if "%M%"=="M" set TEST_MODE=false && goto start
) else (
	if "%M%"=="m" set TEST_MODE=true && goto start
	if "%M%"=="M" set TEST_MODE=true && goto start
)

if "%M%"=="q" goto eof
if "%M%"=="Q" goto eof
goto menu

:: Run Web GUI
:gui
cls
rclone rcd --config="%RCLONE_CONFIG%" --rc-web-gui

if "%ARG%"=="gui" goto eof
@pause
goto menu

:: Edit config in CLI
:edit
cls
rclone --config="%RCLONE_CONFIG%" config

if "%ARG%"=="config" goto eof
@pause
goto menu

:: Print quota information
:about
cls
echo Quota information for remote path "%REMOTE_PATH%"
rclone --config="%RCLONE_CONFIG%" about %REMOTE_PATH%

if "%ARG%"=="about" goto eof
@pause
goto menu

:: Serve remote through FTP
:serve_ftp
cls
::start "" ftp://localhost:%PORT_FTP%/
echo ftp://localhost:%PORT_FTP%/
rclone --config="%RCLONE_CONFIG%" serve ftp %REMOTE_PATH% --addr localhost:%PORT_FTP% %ARGUMENTS_FTP%

if "%ARG%"=="ftp" goto eof
@pause
goto menu

:: Serve remote through WebDAV
:serve_webdav
cls
::start "" http://localhost:%PORT_WEBDAV%/
echo http://localhost:%PORT_WEBDAV%/
rclone --config="%RCLONE_CONFIG%" serve webdav %REMOTE_PATH% --addr localhost:%PORT_WEBDAV% %ARGUMENTS_WEBDAV%

if "%ARG%"=="webdav" goto eof
@pause
goto menu

:: Print current config
:show_config
echo.
echo  CONFIGURATION:
echo   SCRIPT_CONFIG=%SCRIPT_CONFIG%
echo   RCLONE_CONFIG=%RCLONE_CONFIG%
echo   FILTER_RULES=%FILTER_RULES%
echo   REMOTE_PATH=%REMOTE_PATH%
echo   LOCAL_DRIVE=%LOCAL_DRIVE%
echo   LOCAL_PATH=%LOCAL_PATH%
echo   SHOW_PROGRESS=%SHOW_PROGRESS%
echo   DRY_RUN=%DRY_RUN%
if %USE_VSS% equ true (
	echo   USE_VSS=%USE_VSS% (VSS_DRIVE=%VSS_DRIVE%^)
) else (
	echo   USE_VSS=%USE_VSS% (ADMIN=%HAS_ADMIN%^)
)
echo   ARGUMENTS=%ARGUMENTS%

echo.
exit /B

:: Run the sync
:sync
cls
set ARGUMENTS_ACTUAL=%ARGUMENTS%

if %SHOW_PROGRESS% equ true (
	set ARGUMENTS_ACTUAL=%ARGUMENTS_ACTUAL% --progress --stats 1s
)

if %DRY_RUN% equ true (
	set ARGUMENTS_ACTUAL=%ARGUMENTS_ACTUAL% --dry-run
)

echo.
echo ARGUMENTS: --config="%RCLONE_CONFIG%" --filter-from="%FILTER_RULES%" sync %LOCAL_DRIVE%%LOCAL_PATH% %REMOTE_PATH% %ARGUMENTS_ACTUAL%
echo.

:: Remove old log file
if %TEST_MODE% equ true (
	if exist "%TEST_LOG%" (
		del "%TEST_LOG%"
	)
)

:syncwait
if "%ARG%"=="sync-wait" (
	choice /C YN /M "Beging synchronization "
	if errorlevel 2 goto syncwait_exit
	if errorlevel 1 goto syncwait_continue

	:syncwait_exit
	@pause
	goto syncwait_eof
	
	:syncwait_continue
	echo.
)

where shadowrun >nul 2>&1
if %ERRORLEVEL% NEQ 0 set USE_VSS=false
ver > nul

if %USE_VSS% equ true (
	shadowrun -env -mount -drive=%VSS_DRIVE% -exec=%RCLONE_BIN% %LOCAL_DRIVE%: -- --config="%RCLONE_CONFIG%" --filter-from="%FILTER_RULES%" sync %VSS_DRIVE%:%LOCAL_PATH% %REMOTE_PATH% %ARGUMENTS_ACTUAL%
) else (
	rclone --config="%RCLONE_CONFIG%" --filter-from="%FILTER_RULES%" sync %LOCAL_DRIVE%:%LOCAL_PATH% %REMOTE_PATH% %ARGUMENTS_ACTUAL%
)

if "%ARG%"=="sync" (
	exit /B %ERRORLEVEL%
)

echo.
@pause

:syncwait_eof
if "%ARG%"=="sync-wait" (
	exit /B %ERRORLEVEL%
)

set ARG=
goto menu

:eof
