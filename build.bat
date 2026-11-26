@echo off
rem build.bat - builds and runs Elevator Rescue Simulator.
rem
rem   build.bat         build the game   (build\ElevatorRescue.exe)
rem   build.bat run     build, then play the game
rem   build.bat test    build and run the tests
rem   build.bat clean   delete the build folder
rem
rem Needs Visual Studio ("Desktop development with C++") for MASM, and the
rem Irvine32 library in C:\Irvine or C:\Irvine32-master (or set IRVINE_DIR).
setlocal

set "ROOT=%~dp0"
set "BUILD=%ROOT%build"
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=game"

if /I "%TARGET%"=="clean" (
    if exist "%BUILD%" rmdir /s /q "%BUILD%"
    echo Cleaned.
    exit /b 0
)

rem Find the Irvine32 library
if not defined IRVINE_DIR set "IRVINE_DIR=C:\Irvine"
if not exist "%IRVINE_DIR%\Irvine32.inc" if exist "C:\Irvine32-master\Irvine32.inc" set "IRVINE_DIR=C:\Irvine32-master"
if not exist "%IRVINE_DIR%\Irvine32.inc" (
    echo ERROR: Irvine32 not found. Put it in C:\Irvine or set IRVINE_DIR.
    exit /b 1
)

rem Find MASM (ml.exe). If it is not ready, load Visual Studio's 32-bit tools.
where ml.exe >nul 2>nul
if not errorlevel 1 goto build
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VSDIR="
if exist "%VSWHERE%" for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -property installationPath`) do set "VSDIR=%%i"
if defined VSDIR call "%VSDIR%\VC\Auxiliary\Build\vcvars32.bat" >nul 2>nul
where ml.exe >nul 2>nul
if errorlevel 1 (
    echo ERROR: MASM ml.exe not found. Install Visual Studio with "Desktop development with C++".
    exit /b 1
)

:build
if not exist "%BUILD%" mkdir "%BUILD%"
set ASSEMBLE=ml /nologo /c /coff /Zi /W3 /I "%IRVINE_DIR%" /I "%ROOT%src" /I "%ROOT%tests"
set LINKER=link /nologo /SUBSYSTEM:CONSOLE /DEBUG /SAFESEH:NO /LIBPATH:"%IRVINE_DIR%"
set LIBS=Irvine32.lib kernel32.lib user32.lib

if /I "%TARGET%"=="test" goto tests

rem The game: main.asm includes every other part, so it is the only file to assemble
%ASSEMBLE% /Fo"%BUILD%\main.obj" "%ROOT%src\main.asm" || goto failed
%LINKER% /OUT:"%BUILD%\ElevatorRescue.exe" "%BUILD%\main.obj" %LIBS% || goto failed
echo Built build\ElevatorRescue.exe
if /I not "%TARGET%"=="run" exit /b 0
pushd "%ROOT%"
"%BUILD%\ElevatorRescue.exe"
popd
exit /b 0

:tests
%ASSEMBLE% /Fo"%BUILD%\TestMain.obj" "%ROOT%tests\TestMain.asm" || goto failed
%LINKER% /OUT:"%BUILD%\RunTests.exe" "%BUILD%\TestMain.obj" %LIBS% || goto failed
pushd "%ROOT%"
"%BUILD%\RunTests.exe"
set "RESULT=%ERRORLEVEL%"
popd
echo.
if "%RESULT%"=="0" (
    echo ALL TESTS PASSED
    exit /b 0
)
echo %RESULT% TEST^(S^) FAILED
exit /b 1

:failed
echo.
echo BUILD FAILED
exit /b 1
