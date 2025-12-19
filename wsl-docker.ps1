############################################################################
#                                                                          #
#  This scipt will setup WSL on your system and create a WSL2 docker host  #
#                                                                          #
############################################################################

#############################################
# WSL Location and Default Name of Instance.
$wslStorage = "C:\wsl"
$wslName = "docker1"

#############################################
# Install Ubuntu 24.04
$wslDistroName = "Ubuntu-24.04"
$onlineDistoFile = "https://releases.ubuntu.com/noble/ubuntu-24.04.3-wsl-amd64.wsl"


#############################################
### Get predefined settings from .env file

# Read in a .env config file
$envFilePath = ".env"
$envVars = @{}

if  (Test-Path $envFilePath) {
    Get-Content $envFilePath | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim().Trim('"')
            $envVars[$key] = $value
        }
    }

    # Set $wslName if found.
    if ($envVars.ContainsKey('DOCKER_HOSTNAME')) {
        $wslName = $envVars['DOCKER_HOSTNAME']
    }
}

#############################################
# Set values
$localDistroFile = "$wslStorage\$wslDistroName.wsl"
$wslPath = "$wslStorage\$wslName"


#############################################
### WSL Install ###
Write-Host "Checking if WSL is enabled... " -NoNewline
$wslEnabled = (wsl.exe --status 2>&1)

# Enable WSL and Virtual Machine Platform
if ($wslEnabled) {
    Write-Host "WSL is installed."
} else {
    Write-Host "WSL is not installed."
    wsl --install --no-distribution
    return
}
### ###############


#############################################
# Setting up the WSL Distro environment

# Create WSL File Storage
Write-Host "Check WSL File Storage Location '$wslStorage' ... " -NoNewline
if (-not (Test-Path $wslStorage)) {
    Write-Host "create WSL storage location."
    New-Item -ItemType Directory -Force -Path $wslStorage
    Write-Host "Created."
} else {
    Write-Host "already exists."
}

# Get WSL Distro tar file.
if (-not (Test-Path $localDistroFile)) {
    Write-Host "Downloading WSL Distro... to $localDistroFile"
    #Invoke-WebRequest -Uri $onlineDistoFile -OutFile $localDistroFile
    #Import-Module BitsTransfer
    Start-BitsTransfer -Source $onlineDistoFile -Destination $localDistroFile
} else {
    Write-Host "WSL Distro already downloaded."
}

# Setup the Distro VHDX file
if (-not ((wsl -l -q) -contains $wslName)) {
    Write-Host "Creating WSL distribution '$wslDistroName' called '$wslName'."
    wsl --import "$wslName" "$wslPath" "$localDistroFile" --version 2
} else {
    Write-Host "WSL '$wslName' already configured."
}


#############################################
# Customize the Docker Environment

# Write-Host "Configure Container Management"
# Write-Host " -- Force apt to use IPv4"
# wsl -d $wslName -- bash -c 'echo ''Acquire::ForceIPv4 \"true\";'' | sudo tee /etc/apt/apt.conf.d/99force-ipv4 > /dev/null'
# wsl -d $wslName -- bash -c "sudo sysctl -p"


Write-Host "Install Docker in the WSL Distro"
Write-Host " -- Set Docker repository"
#wsl -d $wslName -- bash -c "sudo apt install apt-transport-https curl -y"  ## Skipped, no longer needed.
wsl -d $wslName -- bash -c "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg"
wsl -d $wslName -- bash -c 'echo deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'
Write-Host " -- Update apt repository"
wsl -d $wslName -- bash -c "sudo apt-get update"  | %{ Write-Progress "apt-get update" "$_ " }; Write-Progress "." -Completed
Write-Host " -- Install Docker"
wsl -d $wslName -- bash -c "sudo apt-get install docker-ce -y"  | %{ Write-Progress "apt-get install docker-ce" "$_ " }; Write-Progress "." -Completed

# Configure Hostname
Write-Host " -- Install crudini"
wsl -d $wslName -- bash -c "sudo apt-get install crudini -y"  | %{ Write-Progress "apt-get install crudini" "$_ " }; Write-Progress "." -Completed
Write-Host " -- Set Hostname"
wsl -d $wslName -- bash -c "crudini --set /etc/wsl.conf network hostname $wslName"

# Perform updates and upgrades
Write-Host " -- Install updates and upgrade packages"
wsl -d $wslName -- bash -c "sudo apt-get upgrade -y"  | %{ Write-Progress "apt-get upgrade" "$_ " }; Write-Progress "." -Completed
Write-Host " -- Remove unused packages"
wsl -d $wslName -- bash -c "sudo apt-get autoremove -y"  | %{ Write-Progress "apt-get autoremove" "$_ " }; Write-Progress "." -Completed

Write-Host " -- Stop WSL Distro"
wsl -t $wslName

Write-Host ""
Write-Host "Docker has been installed in the $wslDistroName distro named '$wslName'."
Write-Host ""

#############################################
# Configure DockerCLI through Windows
#

# Unfortantly, I can Just use docker.cmd and docker-compose.cmd wrappers with VS Code.
#  So instead I'm installing a socket to pipe adaptor to allow Docker CLI commands.

# # Configure PATH setting for using docker.cmd and docker-compose.cmd
# Write-Host "Configuring WSL-Docker in Environmental Path if not already set."
# # This process uses the Registry as other methods will expand %USERPROFILE%
# $currentDir = $PSScriptRoot
# $regKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment", $true)
# $currentPathRaw = $regKey.GetValue("Path", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
# # Split the current PATH variable into an array of individual paths
# $currentPathList = $currentPathRaw -split ";"
# # Check if the current directory is not already in the array
# if ($currentPathList -notcontains $currentDir) {
#     $env:Path += ";" + $currentDir # Set Current Session
#     $regKey.SetValue("Path", $currentPathRaw + ";" + $currentDir, [Microsoft.Win32.RegistryValueKind]::ExpandString) # Set Registry
#     Write-Output "-- Added $($currentDir) to the environmental PATH variable."
# } else {
#     Write-Output "-- Skipped. Already in enviromental PATH variable. ( $($currentDir) )"
# }


Write-Host "Configure Named Pipe Mapping to enable communication between Windows"
Write-Host " -- Download npipe adapter script"
wsl -d $wslName -- bash -c "sudo wget -N -q --show-progress -P ~ https://raw.githubusercontent.com/0xJonas/npipe_socket_adapter/refs/heads/main/npipe_socket_adapter.py"
Write-Host " -- Copy Docker Adaptor service file to $wslName system"
Copy-Item -Path docker-adapter.service \\wsl.localhost\$wslName\etc\systemd\system\docker-adapter.service
Write-Host " -- Setup Docker Adaptor service."
wsl -d $wslName -- bash -c "sudo systemctl daemon-reload"
wsl -d $wslName -- bash -c "sudo systemctl enable --now docker-adapter.service"


Write-Host "Install Docker CLI"
winget install Docker.DockerCLI

# Write-Host "Install Podman CLI (alternative)"
# winget install RedHat.Podman-Desktop

# Reference:
# https://dev.to/petersaktor/replacing-docker-with-podman-on-windows-56ee




# Write-Host "Configure Firewall for Docker Port"
# New-NetFirewallRule -DisplayName "Docker for Windows TCP" -Action Block -Direction Inbound -EdgeTraversalPolicy Block -Enabled True -LocalPort 2375 -Protocol TCP

#export DOCKER_HOST=tcp://localhost:2375