:: Made by Jack'lul <jacklul.github.io>

@echo off
setlocal
set CPATH=%~dp0
set TEST_MODE=false
set HAS_ADMIN=false

:start
title RCLONE BACKUP

:: Check if rclone command is available
where rclone >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
	echo Rclone not found - get it at https://rclone.org
	@pause
	goto eof
)

:: Set path to rclone binary for ShadowRun
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
set ARGUMENTS_WEBDAV=--vfs-cache-mode off --no-modtime --crypt-show-mapping
set PORT_FTP=2150
set PORT_WEBDAV=8050
set TEST_LOG=%TEMP%\rclone.log
set TEST_CONFIG=%TEMP%\rclone-test.conf

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

:: Check if ShadowRun command is available
where ShadowRun >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
	if %USE_VSS% equ true (
		echo ShadowRun not found - get it at https://github.com/albertony/vss/tree/master/shadowrun
		@pause
		goto eof
	)
)

:: Check if we are running as administrator to enable/disable VSS mode
if "%PROCESSOR_ARCHITECTURE%" equ "amd64" (
	>nul 2>&1 "%SYSTEMROOT%\SysWOW64\cacls.exe" "%SYSTEMROOT%\SysWOW64\config\system"
) else (
	>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
)

if '%ERRORLEVEL%' NEQ '0' (
	set HAS_ADMIN=false
) else (
	set HAS_ADMIN=true
)

:: Overwrite config with test mode variables
if %TEST_MODE% equ true (
	if not exist "%TEST_CONFIG%" (
		echo [memory]> "%TEST_CONFIG%"
		echo type = memory>> "%TEST_CONFIG%"
	)

	set RCLONE_CONFIG=%TEST_CONFIG%
	set REMOTE_PATH=memory:
	set DRY_RUN=true
	set USE_VSS=false
	set SHOW_PROGRESS=true
	set ARGUMENTS=--skip-links --ignore-case --log-level INFO --log-file="%TEST_LOG%" --retries 1
)

:: Quick argument shortcuts to script functions
if "%ARG%"=="sync" goto sync
if "%ARG%"=="sync-wait" goto sync
if "%ARG%"=="sync-after-getadmin" goto sync
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

if %TEST_MODE% equ true (
	set CURMODE=TEST
	set NEWMODE=NORMAL
) else (
	set CURMODE=NORMAL
	set NEWMODE=TEST
)

echo  MENU:
echo   1 - Run synchronization
echo   2 - Serve through FTP          4 - Serve through FTP (read-only)
echo   3 - Serve through WebDAV       5 - Serve through WebDAV (read-only)
echo   C - Open configuration editor  W - Open Web GUI
echo   Q - Remote quota information   M - Switch to %NEWMODE% mode
echo   E - Exit
echo.

set /P M=Type an option then press ENTER: 
if %M%==1 goto sync
if %M%==2 goto serve_ftp
if %M%==3 goto serve_webdav
if %M%==4 goto serve_ftp_ro
if %M%==5 goto serve_webdav_ro
if "%M%"=="w" goto gui
if "%M%"=="W" goto gui
if "%M%"=="c" goto edit
if "%M%"=="C" goto edit
if "%M%"=="q" goto about
if "%M%"=="Q" goto about

:: Switch test/normal mode
if %TEST_MODE% equ true (
	if "%M%"=="m" set TEST_MODE=false && goto start
	if "%M%"=="M" set TEST_MODE=false && goto start
) else (
	if "%M%"=="m" set TEST_MODE=true && goto start
	if "%M%"=="M" set TEST_MODE=true && goto start
)

if "%M%"=="e" goto eof
if "%M%"=="E" goto eof
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

:: Serve remote through FTP (read-only)
:serve_ftp_ro
cls
::start "" ftp://localhost:%PORT_FTP%/
echo ftp://localhost:%PORT_FTP%/
rclone --config="%RCLONE_CONFIG%" serve ftp %REMOTE_PATH% --addr localhost:%PORT_FTP% --read-only %ARGUMENTS_FTP%

if "%ARG%"=="ftp_ro" goto eof
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

:: Serve remote through WebDAV (read-only)
:serve_webdav_ro
cls
::start "" http://localhost:%PORT_WEBDAV%/
echo http://localhost:%PORT_WEBDAV%/
rclone --config="%RCLONE_CONFIG%" serve webdav %REMOTE_PATH% --addr localhost:%PORT_WEBDAV% --read-only %ARGUMENTS_WEBDAV%

if "%ARG%"=="webdav_ro" goto eof
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
if %USE_VSS% equ true (
	echo   USE_VSS=%USE_VSS% (VSS_DRIVE=%VSS_DRIVE%^)
) else (
	echo   USE_VSS=%USE_VSS%
)
echo   SHOW_PROGRESS=%SHOW_PROGRESS%
echo   DRY_RUN=%DRY_RUN%
echo   ARGUMENTS=%ARGUMENTS%

echo.
exit /B

:: Request admin permissions
:get_admin
echo Requesting admin privileges...
set "params=%* sync-after-getadmin"
cd /d "%~dp0" && ( if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs" ) && fsutil dirty query %systemdrive% 1>nul 2>nul || (  echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/c cd ""%~sdp0"" && %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs" && "%temp%\getadmin.vbs" && exit /B )
exit /B

:: Run the sync
:sync
if "%ARG%"=="sync-after-getadmin" set ARG=

cls

if %USE_VSS% equ true (
	if %HAS_ADMIN% equ false (
		echo Admin privileges are required to use VSS!
		goto get_admin
	)
)

set ARGUMENTS_ACTUAL=%ARGUMENTS%

if %SHOW_PROGRESS% equ true (
	set ARGUMENTS_ACTUAL=%ARGUMENTS_ACTUAL% --progress --stats 1s
)

if %DRY_RUN% equ true (
	set ARGUMENTS_ACTUAL=%ARGUMENTS_ACTUAL% --dry-run
)

echo.
echo ARGUMENTS: --config="%RCLONE_CONFIG%" --filter-from="%FILTER_RULES%" sync %LOCAL_DRIVE%:%LOCAL_PATH% %REMOTE_PATH% %ARGUMENTS_ACTUAL%
echo.

:: Remove old log file
if %TEST_MODE% equ true (
	if exist "%TEST_LOG%" (
		del "%TEST_LOG%"
	)
)

:syncwait
if "%ARG%"=="sync-wait" (
	choice /C YN /M "Begin synchronization "
	if errorlevel 2 goto syncwait_exit
	if errorlevel 1 goto syncwait_continue

	:syncwait_exit
	@pause
	goto syncwait_eof
	
	:syncwait_continue
	echo.
)

:sync_start
ver > nul

if %USE_VSS% equ true (
	ShadowRun -env -mount -drive=%VSS_DRIVE% -exec=%RCLONE_BIN% %LOCAL_DRIVE%: -- --config="%RCLONE_CONFIG%" --filter-from="%FILTER_RULES%" sync %VSS_DRIVE%:%LOCAL_PATH% %REMOTE_PATH% %ARGUMENTS_ACTUAL%
) else (
	rclone --config="%RCLONE_CONFIG%" --filter-from="%FILTER_RULES%" sync %LOCAL_DRIVE%:%LOCAL_PATH% %REMOTE_PATH% %ARGUMENTS_ACTUAL%
)

set RESULT=%ERRORLEVEL%

if not "%RESULT%"=="0" (
	rundll32 user32.dll,MessageBeep
	choice /C YN /M "Backup operation failed, restart synchronization "
	
	if errorlevel 2 goto after
	if errorlevel 1 goto sync_start
)

:after

if "%ARG%"=="sync" (
	exit /B %RESULT%
)

echo.
@pause

:syncwait_eof
if "%ARG%"=="sync-wait" (
	exit /B %RESULT%
)

set ARG=
goto menu

:eof
exit /B
