@echo off
rem Build script: uses hvigor/node/jbr bundled with DevEco Studio
set "DEVECO_HOME=C:\Program Files\Huawei\huawei\DevEco Studio"
if not exist "%DEVECO_HOME%\tools\node\node.exe" set "DEVECO_HOME=C:\Program Files\Huawei\DevEco Studio"
set "NODE_HOME=%DEVECO_HOME%\tools\node"
set "PATH=%NODE_HOME%;%DEVECO_HOME%\jbr\bin;%PATH%"
set "DEVECO_SDK_HOME=%DEVECO_HOME%\sdk"
cd /d %~dp0
call "%DEVECO_HOME%\tools\hvigor\bin\hvigorw.bat" --mode module -p module=entry@default -p product=default assembleHap --no-daemon
