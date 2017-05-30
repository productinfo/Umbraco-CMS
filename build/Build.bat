@ECHO OFF

:: UMBRACO CORE BUILD FILE
::
:: usage:
:: build [-release:release] [-comment:comment] [-build:number] [-integration]
::       [-nugetpkg] [-nugetfolder:folder] [-tests]
::   release: the release version eg -release:1.2.0
::   comment: the release comment eg -comment:alpha002
::   build: the build number (for continuous integration) eg -build:6689
::   nugetfolder: the folder where to restore packages eg -nugetpkg:"path\to\packages"
::   integration: don't pause on errors eg -integration
::   nugetpkg: create nuget package eg -nugetpkg
::   tests: build the tests eg -tests
::
:: the script tries to read from UmbracoVersion.txt
:: but release and comment can be overriden by args
:: and in any case, the script updates UmbracoVersion.txt
::

SET RELEASE=
SET COMMENT=
SET BUILD=

:: Try to get the version and comment from UmbracoVersion.txt lines 2 and 3
IF EXIST UmbracoVersion.txt (
    FOR /F "skip=1 delims=" %%i IN (UmbracoVersion.txt) DO IF NOT DEFINED RELEASE SET RELEASE=%%i
    FOR /F "skip=2 delims=" %%i IN (UmbracoVersion.txt) DO IF NOT DEFINED COMMENT SET COMMENT=%%i
)

:: process args

SET INTEGRATION=0
SET nuGetFolder=%CD%\..\src\packages
SET NUPKG=0
SET BUILD=
SET TESTS=

:processArgs

:: grab the first parameter as a whole eg "/action:start"
:: end if no more parameter
SET SWITCHPARSE=%1
IF [%SWITCHPARSE%] == [] goto endProcessArgs

:: get switch and value
SET SWITCH=
SET VALUE=
FOR /F "tokens=1,* delims=: " %%a IN ("%SWITCHPARSE%") DO SET SWITCH=%%a& SET VALUE=%%b

:: route arg
IF '%SWITCH%'=='/release' GOTO argRelease
IF '%SWITCH%'=='-release' GOTO argRelease
IF '%SWITCH%'=='/comment' GOTO argComment
IF '%SWITCH%'=='-comment' GOTO argComment
IF '%SWITCH%'=='/build' GOTO argBuild
IF '%SWITCH%'=='-build' GOTO argBuild
IF '%SWITCH%'=='/integration' GOTO argIntegration
IF '%SWITCH%'=='-integration' GOTO argIntegration
IF '%SWITCH%'=='/nugetfolder' GOTO argNugetFolder
IF '%SWITCH%'=='-nugetfolder' GOTO argNugetFolder
IF '%SWITCH%'=='/nugetpkg' GOTO argNugetPkg
IF '%SWITCH%'=='-nugetpkg' GOTO argNugetPkg
IF '%SWITCH%'=='/tests' GOTO argTests
IF '%SWITCH%'=='-tests' GOTO argTests
ECHO "Invalid switch %SWITCH%"
GOTO error

:: handle each arg

:argRelease
set RELEASE=%VALUE%
SHIFT
goto processArgs

:argComment
SET COMMENT=%VALUE%
SHIFT
GOTO processArgs

:argBuild
SET BUILD=%VALUE%
SHIFT
GOTO processArgs

:argIntegration
SET INTEGRATION=1
SHIFT
GOTO processArgs

:argNugetFolder
SET nuGetFolder=%VALUE%
SHIFT
GOTO processArgs

:argNugetPkg
SET NUPKG=1
SHIFT
GOTO processArgs

:argTests
SET TESTS=true
SHIFT
GOTO processArgs

:endProcessArgs


:: validate

IF [%RELEASE%] EQU [] (
    ECHO Could not determine release
    ECHO Release is determined by the 'release' arg, or the UmbracoVersion.txt file
    GOTO error 
)

ECHO # Usage: on line 2 put the release version, on line 3 put the version comment (example: beta)> UmbracoVersion.txt
ECHO %release%>> UmbracoVersion.txt
ECHO %comment%>> UmbracoVersion.txt


:: run

SET VERSION=%RELEASE%
IF [%COMMENT%] NEQ [] (SET VERSION=%VERSION%-%COMMENT%)
IF [%BUILD%] NEQ [] (SET VERSION=%VERSION%+%BUILD%)

ECHO ################################################################
ECHO Building Umbraco %VERSION%
ECHO ################################################################

SET MSBUILDPATH=C:\Program Files (x86)\MSBuild\14.0\Bin
SET MSBUILD="%MSBUILDPATH%\MsBuild.exe"
SET PATH="%MSBUILDPATH%";%PATH%

ReplaceIISExpressPortNumber.exe ..\src\Umbraco.Web.UI\Umbraco.Web.UI.csproj %RELEASE%

ECHO.
ECHO First make sure everything is clean as a whistle

ECHO.
ECHO Removing the belle build folder and bower_components folder
RD ..\src\Umbraco.Web.UI.Client\build /Q /S
RD ..\src\Umbraco.Web.UI.Client\bower_components /Q /S

ECHO.
ECHO Removing existing built files
RMDIR /Q /S _BuildOutput
DEL /F /Q UmbracoCms.*.zip 2>NUL
DEL /F /Q UmbracoExamine.*.zip 2>NUL
DEL /F /Q UmbracoCms.*.nupkg 2>NUL
DEL /F /Q webpihash.txt 2>NUL

ECHO.
ECHO Making sure Git is in the path so that the build can succeed
CALL InstallGit.cmd

:: Adding the default Git path so that if it's installed it can actually be found
:: This is necessary because SETLOCAL is on in InstallGit.cmd so that one might find Git, 
:: but the path setting is lost due to SETLOCAL 
SET PATH="C:\Program Files (x86)\Git\cmd";"C:\Program Files\Git\cmd";%PATH%

SET toolsFolder=%CD%\tools\
IF NOT EXIST "%toolsFolder%" (
	MD tools
)

SET nuGetExecutable=%CD%\tools\nuget.exe
IF NOT EXIST "%nuGetExecutable%" (
	ECHO Getting NuGet so we can fetch some tools
	ECHO Downloading https://dist.nuget.org/win-x86-commandline/latest/nuget.exe to %nuGetExecutable%
	powershell -Command "(New-Object Net.WebClient).DownloadFile('https://dist.nuget.org/win-x86-commandline/latest/nuget.exe', '%nuGetExecutable%')"
)

:: We need 7za.exe for BuildBelle.bat
IF NOT EXIST "%toolsFolder%7za.exe" (
	ECHO 7zip not found - fetching now
	"%nuGetExecutable%" install 7-Zip.CommandLine -OutputDirectory tools -Verbosity quiet
)

:: We need vswhere.exe for VS2017+
IF NOT EXIST "%toolsFolder%vswhere.exe" (
	ECHO vswhere not found - fetching now
	"%nuGetExecutable%" install vswhere -OutputDirectory tools -Verbosity quiet
)

:: Put 7za.exe and vswhere.exe in a predictable path (not version specific)
FOR /f "delims=" %%A in ('dir "%toolsFolder%7-Zip.CommandLine.*" /b') DO SET "sevenZipExePath=%toolsFolder%%%A\"
MOVE "%sevenZipExePath%tools\7za.exe" "%toolsFolder%7za.exe"

FOR /f "delims=" %%A in ('dir "%toolsFolder%vswhere.*" /b') DO SET "vswhereExePath=%toolsFolder%%%A\"
MOVE "%vswhereExePath%tools\vswhere.exe" "%toolsFolder%vswhere.exe"

ECHO.
ECHO Making sure we have a web.config
IF NOT EXIST "%CD%\..\src\Umbraco.Web.UI\web.config" COPY "%CD%\..\src\Umbraco.Web.UI\web.Template.config" "%CD%\..\src\Umbraco.Web.UI\web.config"

for /f "usebackq tokens=1* delims=: " %%i in (`"%CD%\tools\vswhere.exe" -latest -requires Microsoft.Component.MSBuild`) do (
  if /i "%%i"=="installationPath" set InstallDir=%%j
)

SET VSWherePath="%InstallDir%\MSBuild"

ECHO.
ECHO Visual Studio is installed in: %InstallDir%

SET MSBUILDPATH=C:\Program Files (x86)\MSBuild\14.0\Bin
SET MSBUILD="%MSBUILDPATH%\MsBuild.exe"

ECHO.
ECHO Reporting NuGet version
"%nuGetExecutable%" help | findstr "^NuGet Version:"

ECHO.
ECHO Restoring NuGet packages
ECHO Into %nuGetFolder%
"%nuGetExecutable%" restore "%CD%\..\src\umbraco.sln" -Verbosity Quiet -NonInteractive -PackagesDirectory "%nuGetFolder%"
IF ERRORLEVEL 1 GOTO :error

ECHO.
ECHO.
ECHO Performing MSBuild and producing Umbraco binaries zip files
ECHO This takes a few minutes and logging is set to report warnings
ECHO and errors only so it might seems like nothing is happening for a while. 
ECHO You can check the msbuild.log file for progress.
ECHO.
%MSBUILD% "Build.proj" ^
  /p:BUILD_RELEASE=%RELEASE% ^
  /p:BUILD_COMMENT=%COMMENT% ^
  /p:BUILD_NUMBER=%BUILD% ^
  /p:BUILD_TESTS=%TESTS% ^
  /p:NugetPackagesDirectory="%nuGetFolder%" ^
  /p:VSWherePath="%VSWherePath%" ^
  /consoleloggerparameters:Summary;ErrorsOnly ^
  /fileLogger
IF ERRORLEVEL 1 GOTO error

ECHO.
ECHO Setting node_modules folder to hidden to prevent VS13 from
ECHO crashing on it while loading the websites project
attrib +h ..\src\Umbraco.Web.UI.Client\node_modules

IF %NUPKG% EQU 0 GOTO success

ECHO.
ECHO Adding Web.config transform files to the NuGet package
REN .\_BuildOutput\WebApp\Views\Web.config Web.config.transform

ECHO.
ECHO Packing the NuGet release files
..\src\.nuget\NuGet.exe Pack NuSpecs\UmbracoCms.Core.nuspec -Version %VERSION% -Symbols -Verbosity quiet
..\src\.nuget\NuGet.exe Pack NuSpecs\UmbracoCms.Compat7.nuspec -Version %VERSION% -Symbols -Verbosity quiet
..\src\.nuget\NuGet.exe Pack NuSpecs\UmbracoCms.nuspec -Version %VERSION% -Verbosity quiet
IF ERRORLEVEL 1 GOTO error

:success
ECHO.
ECHO No errors were detected!
ECHO There may still be some in the output, which you would need to investigate.
ECHO Warnings are usually normal.
ECHO.
ECHO.
GOTO :EOF

:error

ECHO.
ECHO Errors were detected!
ECHO.

:: don't pause if continuous integration else the build server waits forever
:: before cancelling the build (and, there is noone to read the output anyways)
IF %INTEGRATION% NEQ 1 PAUSE
