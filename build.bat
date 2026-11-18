@echo off
rem ====================================================================
rem  build.bat - builds Elevator Rescue Simulator with MASM + Irvine32
rem
rem  Usage:   build.bat            build the game  (build\ElevatorRescue.exe)
rem           build.bat run        build and run the game
rem           build.bat test       build and run the tests (build\RunTests.exe)
rem           build.bat clean      delete the build folder
rem
rem  Needs:   Visual Studio with "Desktop development with C++"
rem           Irvine32 library in C:\Irvine  (or set IRVINE_DIR first)
rem ====================================================================
setlocal EnableDelayedExpansion

set "ROOT=%~dp0"
set "BUILD=%ROOT%build"
set "IRVINE=C:\Irvine"
if defined IRVINE_DIR set "IRVINE=%IRVINE_DIR%"
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=game"

if /I "%TARGET%"=="clean" goto clean
if /I "%TARGET%"=="game"  goto setup
if /I "%TARGET%"=="run"   goto setup
if /I "%TARGET%"=="test"  goto setup
echo Unknown target "%TARGET%". Use: game, run, test or clean.
exit /b 1

:clean
if exist "%BUILD%" rmdir /s /q "%BUILD%"
echo Cleaned.
exit /b 0

rem --------------------------------------------------------------------
rem  Find MASM (ml.exe). If it is not on PATH, load the 32-bit
rem  Visual Studio environment with vcvars32.bat (located via vswhere).
rem --------------------------------------------------------------------
:setup
if not exist "%IRVINE%\Irvine32.inc" (
    echo ERROR: Irvine32 not found in "%IRVINE%". Install it or set IRVINE_DIR.
    exit /b 1
)
where ml.exe >nul 2>nul
if not errorlevel 1 goto build

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" goto noVS
set "VSDIR="
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSDIR=%%i"
if not defined VSDIR goto noVS
call "%VSDIR%\VC\Auxiliary\Build\vcvars32.bat" >nul 2>nul
where ml.exe >nul 2>nul
if errorlevel 1 goto noVS
goto build

:noVS
echo ERROR: MASM (ml.exe) not found. Install Visual Studio with
echo        "Desktop development with C++", or run this from a
echo        "Developer Command Prompt for VS" (x86).
exit /b 1

rem --------------------------------------------------------------------
rem  Assemble and link
rem --------------------------------------------------------------------
:build
if not exist "%BUILD%" mkdir "%BUILD%"
if not exist "%BUILD%\src"   mkdir "%BUILD%\src"
if not exist "%BUILD%\tests" mkdir "%BUILD%\tests"

set "MLFLAGS=/nologo /c /coff /Zi /W3 /I "%IRVINE%" /I "%ROOT%include" /I "%ROOT%tests""
set "LINKFLAGS=/nologo /SUBSYSTEM:CONSOLE /DEBUG /SAFESEH:NO /LIBPATH:"%IRVINE%""
set "LIBS=Irvine32.lib kernel32.lib user32.lib"

rem Game modules (every src\*.asm)
set "SRC_OBJS="
set "GAME_OBJS="
for %%f in ("%ROOT%src\*.asm") do (
    ml %MLFLAGS% /Fo"%BUILD%\src\%%~nf.obj" "%%f"
    if errorlevel 1 goto failed
    set "GAME_OBJS=!GAME_OBJS! "%BUILD%\src\%%~nf.obj""
    if /I not "%%~nf"=="main" set "SRC_OBJS=!SRC_OBJS! "%BUILD%\src\%%~nf.obj""
)

if /I "%TARGET%"=="test" goto buildTests

link %LINKFLAGS% /OUT:"%BUILD%\ElevatorRescue.exe" %GAME_OBJS% %LIBS%
if errorlevel 1 goto failed
echo.
echo Built build\ElevatorRescue.exe
if /I not "%TARGET%"=="run" exit /b 0

rem Run from the project root so the game finds data\
pushd "%ROOT%"
"%BUILD%\ElevatorRescue.exe"
popd
exit /b 0

:buildTests
rem Test runner = every src module except main.asm + every tests\*.asm
set "TEST_OBJS="
for %%f in ("%ROOT%tests\*.asm") do (
    ml %MLFLAGS% /Fo"%BUILD%\tests\%%~nf.obj" "%%f"
    if errorlevel 1 goto failed
    set "TEST_OBJS=!TEST_OBJS! "%BUILD%\tests\%%~nf.obj""
)
link %LINKFLAGS% /OUT:"%BUILD%\RunTests.exe" %SRC_OBJS% %TEST_OBJS% %LIBS%
if errorlevel 1 goto failed

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
