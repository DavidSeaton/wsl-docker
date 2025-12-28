@echo off
setlocal enabledelayedexpansion

rem Import all variables from .env via read_all_env.cmd
if exist "%~dp0read_all_env.cmd" (
    call %~dp0read_all_env.cmd
) else (
    echo %~dp0read_all_env.cmd not found.
)

rem Set value or use a default if not defined
set "wslName=!DOCKER_HOSTNAME!"
if "!wslName!"=="" set "wslName=docker1"

::echo %wslName%
@ wsl -d %wslName% docker -H unix:///var/run/docker.sock %*
