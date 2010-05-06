@echo off
rem --------------------------------------------------------------------------- 
rem tc Runtime Control Script 
rem 
rem Copyright 2009 SpringSource Inc. All Rights Reserved. 
rem --------------------------------------------------------------------------- 

rem tcruntime-ctl.bat  This Win32 script takes care of starting and stopping
rem                     tomcat and installing and removing the service.
rem version: 6.0.25.A-RELEASE
rem build date: 20100406141135

setlocal
rem where do we create tc Runtime instances. Overide any
rem existing settings from environment here
rem set INSTANCE_BASE=setme

set instance=%1
set action=%2
set user=%3

if "%instance%" == "" (
  echo ERROR First parameter must be an instance name
  goto usage
)

if "%action%" == "" (
  echo ERROR Second parameter must be an instance command
  goto usage
)


rem %~dp0 is location of current script under NT
set _REALPATH=%~dp0

rem Determine CATALINA_BASE first
if not "%INSTANCE_BASE%" == "" goto gotInstanceBase
set INSTANCE_BASE=%_REALPATH%

:gotInstanceBase
rem Make sure instance base exists
if NOT EXIST "%INSTANCE_BASE%" (
  echo ERROR Instance base directory "%INSTANCE_BASE%" does not exist 
  endlocal
  set INSTANCE_BASE=
  exit /b 1
)

rem Strip instance_base of trailing backslash
:beginstriptrail
IF "%INSTANCE_BASE:~-1%"=="\" (
  set INSTANCE_BASE=%INSTANCE_BASE:~0,-1%
  goto beginstriptrail
) else (
  goto donestriptrail
)
:donestriptrail


set INSTANCE_NAME=%instance%
set CATALINA_BASE=%INSTANCE_BASE%\%INSTANCE_NAME%

rem Check for tomcat.version file and read it in to set CATALINA_HOME
rem tomcat.version can contain either a version (eg: 6.0.20.A) or
rem a full pathname (eg: C:\foo\bar\tomcat-6.0.20.A) and we need
rem to handle both

if not "%TOMCAT_VER%" == "" goto guessCH
if not exist "%CATALINA_BASE%\conf\tomcat.version" goto guessTV
set /p TOMCAT_VER2=<"%CATALINA_BASE%\conf\tomcat.version"
if exist "%_REALPATH%\tomcat-%TOMCAT_VER2%" (
  set CATALINA_HOME=%_REALPATH%\tomcat-%TOMCAT_VER2%
  goto checkCH
)
if exist "%TOMCAT_VER2%" (
  set CATALINA_HOME="%TOMCAT_VER2%"
  goto checkCH
)

:guessTV
rem need to auto determine TOMCAT_VER from DIR
rem Simplest way is to loop thru and keep the last
rem one as the "latest" (lex sorting)
set CURRENT_DIR=%cd%
cd %_REALPATH%
FOR /D %%X IN (tomcat-*) DO (set TOMCAT_VER2=%%X)
cd %CURRENT_DIR%
rem TOMCAT_VER2 now contains either tomcat-<whatever> or NUL
rem Now strip off the 'tomcat-' part
set TOMCAT_VER=%TOMCAT_VER2:~7%

:guessCH
rem Guess CATALINA_HOME if not defined
if not "%CATALINA_HOME%" == "" goto checkCH
set CURRENT_DIR=%cd%
set CATALINA_HOME=%_REALPATH%\tomcat-%TOMCAT_VER%
if not "%CATALINA_HOME%" == "" goto gotHome

:checkCH
if exist "%CATALINA_HOME%\bin\tcruntime-ctl.bat" goto okHome
cd %_REALPATH%
cd ..
set CATALINA_HOME=%cd%
cd %CURRENT_DIR%

:gotHome
if exist "%CATALINA_HOME%\bin\tcruntime-ctl.bat" goto okHome
echo ERROR The CATALINA_HOME environment variable is not defined correctly
echo ERROR This environment variable is needed to run this program
echo ERROR CATALINA_HOME is "%CATALINA_HOME%"
endlocal
rem set INSTANCE_BASE=
exit /b 1

:okHome
rem Get standard environment variables
if "%CATALINA_BASE%" == "" goto gotSetenvHome
if exist "%CATALINA_BASE%\bin\setenv.bat" call "%CATALINA_BASE%\bin\setenv.bat"
goto gotSetenvBase

:gotSetenvHome
if exist "%CATALINA_HOME%\bin\setenv.bat" call "%CATALINA_HOME%\bin\setenv.bat"

:gotSetenvBase
rem Add on extra jar files to CLASSPATH
if "%JSSE_HOME%" == "" goto noJsse
set CLASSPATH=%CLASSPATH%;%JSSE_HOME%\lib\jcert.jar;%JSSE_HOME%\lib\jnet.jar;%JSSE_HOME%\lib\jsse.jar

:noJsse
set CLASSPATH=%CLASSPATH%;%CATALINA_HOME%\bin\bootstrap.jar

if not "%CATALINA_BASE%" == "" goto gotBase
set CATALINA_BASE=%CATALINA_HOME%

:gotBase
if not "%CATALINA_TMPDIR%" == "" goto gotTmpdir
set CATALINA_TMPDIR=%CATALINA_BASE%\temp

:gotTmpdir
set ARCH=win32
if EXIST "%CATALINA_BASE%\conf\windows.arch" (
    set /p ARCH=<"%CATALINA_BASE%\conf\windows.arch"
)
echo Running Windows architecture: %ARCH%

set tomcat_bin=%CATALINA_HOME%\bin\%ARCH%\wrapper.exe
set wrapper_conf=%CATALINA_BASE%\conf\wrapper.conf

set default_flags=

rem shift

if NOT EXIST "%wrapper_conf%" (
    echo ERROR Server file "%wrapper_conf%" does not exist 
    endlocal
    rem set INSTANCE_BASE=
    exit /b 1
)

set wrapper_update0=%JAVA_OPTS% %CATALINA_OPTS%
set wrapper_update1=set.CATALINA_BASE=%CATALINA_BASE%
set wrapper_update2=set.CATALINA_HOME=%CATALINA_HOME%
set wrapper_update3=set.ARCH=%ARCH%
set wrapper_update4=
if not "%user%" == "" (
    set wrapper_update4=wrapper.ntservice.account=.\%user% wrapper.ntservice.password.prompt=TRUE
)

rem Generate a service name based on the location of the instance
set catbase=%CATALINA_BASE%
set catbase=%catbase:\=-%
set catbase=%catbase: =-%
set catbase=%catbase::=%
set wrapper_update6=set.wrapper.ntservice.id=tcruntime-%catbase%

echo INFO Service Information %wrapper_update6%

set wrapper_update5=set.INSTANCE_NAME=%INSTANCE_NAME%

if /i "%action%" == "start" (
    echo INFO Starting instance at %CATALINA_BASE%
    "%tomcat_bin%" -t "%wrapper_conf%" %wrapper_update0% "%wrapper_update1%" "%wrapper_update2%" "%wrapper_update3%" %wrapper_update4% %wrapper_update5% %wrapper_update6%

) else if /i "%action%" == "stop" (
    echo INFO Stopping instance at %CATALINA_BASE%
    "%tomcat_bin%" -p "%wrapper_conf%" %wrapper_update0% "%wrapper_update1%" "%wrapper_update2%" "%wrapper_update3%" %wrapper_update4% %wrapper_update5% %wrapper_update6%

) else if /i "%action%" == "restart" (
    echo INFO Restartomg instance at %CATALINA_BASE%
    "%tomcat_bin%" -p "%wrapper_conf%" %wrapper_update0% "%wrapper_update1%" "%wrapper_update2%" "%wrapper_update3%" %wrapper_update4% %wrapper_update5% %wrapper_update6%
    "%tomcat_bin%" -t "%wrapper_conf%" %wrapper_update0% "%wrapper_update1%" "%wrapper_update2%" "%wrapper_update3%" %wrapper_update4% %wrapper_update5% %wrapper_update6%

) else if /i "%action%" == "install" (
    echo INFO Installing instance at %CATALINA_BASE%
    "%tomcat_bin%" -i "%wrapper_conf%" %wrapper_update0% "%wrapper_update1%" "%wrapper_update2%" "%wrapper_update3%" %wrapper_update4% %wrapper_update5% %wrapper_update6%

) else if /i "%action%" == "uninstall" (
    echo INFO Uninstalling instance at %CATALINA_BASE%
    "%tomcat_bin%" -r "%wrapper_conf%" %wrapper_update0% "%wrapper_update1%" "%wrapper_update2%" "%wrapper_update3%" %wrapper_update4% %wrapper_update5% %wrapper_update6%

) else if /i "%action%" == "reinstall" (
    echo INFO Reinstalling instance at %CATALINA_BASE%
    "%tomcat_bin%" -r "%wrapper_conf%" %wrapper_update0% "%wrapper_update1%" "%wrapper_update2%" "%wrapper_update3%" %wrapper_update4% %wrapper_update5% %wrapper_update6%
    "%tomcat_bin%" -i "%wrapper_conf%" %wrapper_update0% "%wrapper_update1%" "%wrapper_update2%" "%wrapper_update3%" %wrapper_update4% %wrapper_update5% %wrapper_update6%

) else if /i "%action%" == "run" (
    echo INFO Running instance at %CATALINA_BASE%
    "%tomcat_bin%" -c "%wrapper_conf%" %wrapper_update0% "%wrapper_update1%" "%wrapper_update2%" "%wrapper_update3%" %wrapper_update4% %wrapper_update5% %wrapper_update6%

) else if /i "%action%" == "status" (
    echo INFO Checking status instance at %CATALINA_BASE%
    "%tomcat_bin%" -q "%wrapper_conf%" %wrapper_update0% "%wrapper_update1%" "%wrapper_update2%" "%wrapper_update3%" %wrapper_update4% %wrapper_update5% %wrapper_update6%

) else if /i "%action%" == "batch" (
    call %CATALINA_HOME%\bin\catalina.bat run

) else (
    if not "%action%" == "" (
        echo WARN Command %action% was not recognized!
        echo.
    )
  :usage
  echo Usage:
  echo tcserver-ctl.bat instance_name cmd [options]
rem  echo   cmd is one of create - install - uninstall - start - run - stop - status - info - modver
  echo   cmd is one of install - uninstall - start - run - stop - batch - status
  echo     install   - installs the instance as a Windows service, svc name defined in wrapper.conf
  echo     uninstall - uninstalls the Windows service for this instance
  echo     reinstall - reinstalls the Windows service for this instance
  echo     start     - starts an instance as a daemon process
  echo     run       - starts an instance as a foreground process
  echo     stop      - stops a running instance
  echo     batch     - runs an instance using the catalina.bat script as a batch job 
  echo     status    - reports the status of an instance
  echo.
  echo.
  endlocal
  rem set INSTANCE_BASE=
  exit /b 1
)
endlocal & set _ret=%ERRORLEVEL%
rem set INSTANCE_BASE=
exit /b %_ret%
