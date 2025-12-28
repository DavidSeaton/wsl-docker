@echo off

set "envFile=%~dp0.env"

rem Check if .env file exists
if not exist "%envFile%" (
    echo "%envFile% not found."
    exit /b 1
)

for /f "usebackq tokens=1* delims==" %%A in ("%envFile%") do (

    set "line=%%A"

    rem Ignore comments and blank lines
    if not "!line:~0,1!"=="#" if not "%%A"=="" (
        set "key=%%A"
        set "value=%%B"

        rem Remove possible surrounding quotes from the value
        if "!value:~0,1!"=="\"" if "!value:~-1!"=="\"" (
            set "value=!value:~1,-1!"
        )

        rem Output set command
        rem echo "set !key!=!value!"
        set "!key!=!value!"
    )
)
