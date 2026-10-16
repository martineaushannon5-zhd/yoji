@echo off
rem Build script: uses hvigor/node/jbr bundled with DevEco Studio
set NODE_HOME=C:\Program Files\Huawei\DevEco Studio\tools\node
set PATH=%NODE_HOME%;C:\Program Files\Huawei\DevEco Studio\jbr\bin;%PATH%
set DEVECO_SDK_HOME=C:\Program Files\Huawei\DevEco Studio\sdk
cd /d %~dp0
call "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" --mode module -p module=entry@default -p product=default assembleHap --no-daemon
