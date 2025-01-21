@ECHO OFF

REM detect the absolute directory path of this script
SET MYPATH=%~dp0
SET "MYPATH=%MYPATH:\=/%"

set command=ELFintoBIT.py

:loop
IF NOT "%1"=="" (
	SET "command=%command% %1%"
	SHIFT
	
	GOTO :loop
)

echo Calling:
echo vitis -s %MYPATH%/%command%
vitis -s %MYPATH%/%command%
