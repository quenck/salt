#==============================================================================
# You may need to change the execution policy in order to run this script
# Run the following in powershell:
#
# Set-ExecutionPolicy RemoteSigned
#
#==============================================================================
#
#          FILE: dev_env.ps1
#
#   DESCRIPTION: Development Environment Installation for Windows
#
#          BUGS: https://github.com/saltstack/salt-windows-bootstrap/issues
#
#     COPYRIGHT: (c) 2012-2017 by the SaltStack Team, see AUTHORS.rst for more
#                details.
#
#       LICENSE: Apache 2.0
#  ORGANIZATION: SaltStack (saltstack.org)
#       CREATED: 03/15/2015
#==============================================================================

# Load parameters
param(
    [switch]$Silent
)

Write-Output "================================================================="
Write-Output ""
Write-Output "               Development Environment Installation"
Write-Output ""
Write-Output "               - Installs All Salt Dependencies"
Write-Output "               - Detects 32/64 bit Architectures"
Write-Output ""
Write-Output "               To run silently add -Silent"
Write-Output "               eg: dev_env.ps1 -Silent"
Write-Output ""
Write-Output "================================================================="
Write-Output ""

#==============================================================================
# Get the Directory of actual script
#==============================================================================
$script_path = dir "$($myInvocation.MyCommand.Definition)"
$script_path = $script_path.DirectoryName

#==============================================================================
# Get the name of actual script
#==============================================================================
$script_name = $MyInvocation.MyCommand.Name

#==============================================================================
# Import Modules
#==============================================================================
Import-Module $script_path\Modules\download-module.psm1
Import-Module $script_path\Modules\get-settings.psm1
Import-Module $script_path\Modules\uac-module.psm1
Import-Module $script_path\Modules\zip-module.psm1
Import-Module $script_path\Modules\start-process-and-test-exitcode.psm1
#==============================================================================
# Check for Elevated Privileges
#==============================================================================
If (!(Get-IsAdministrator)) {
    If (Get-IsUacEnabled) {
        # We are not running "as Administrator" - so relaunch as administrator
        # Create a new process object that starts PowerShell
        $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";

        # Specify the current script path and name as a parameter
        $newProcess.Arguments = $myInvocation.MyCommand.Definition

        # Specify the current working directory
        $newProcess.WorkingDirectory = "$script_path"

        # Indicate that the process should be elevated
        $newProcess.Verb = "runas";

        # Start the new process
        [System.Diagnostics.Process]::Start($newProcess);

        # Exit from the current, unelevated, process
        Exit
    } Else {
        Throw "You must be administrator to run this script"
    }
}

#------------------------------------------------------------------------------
# Load Settings
#------------------------------------------------------------------------------
$ini = Get-Settings

#------------------------------------------------------------------------------
# Create Directories
#------------------------------------------------------------------------------
$p = New-Item $ini['Settings']['DownloadDir'] -ItemType Directory -Force
$p = New-Item "$($ini['Settings']['DownloadDir'])\64" -ItemType Directory -Force
$p = New-Item "$($ini['Settings']['DownloadDir'])\32" -ItemType Directory -Force
$p = New-Item $ini['Settings']['SaltDir'] -ItemType Directory -Force

#------------------------------------------------------------------------------
# Determine Architecture (32 or 64 bit) and assign variables
#------------------------------------------------------------------------------
If ([System.IntPtr]::Size -ne 4) {
    Write-Output "Detected 64bit Architecture..."

    $bitDLLs     = "64bitDLLs"
    $bitPaths    = "64bitPaths"
    $bitPrograms = "64bitPrograms"
    $bitFolder   = "64"
} Else {
    Write-Output "Detected 32bit Architecture"
    $bitDLLs     = "32bitDLLs"
    $bitPaths    = "32bitPaths"
    $bitPrograms = "32bitPrograms"
    $bitFolder   = "32"
}

#------------------------------------------------------------------------------
# Check for installation of NSIS
#------------------------------------------------------------------------------
Write-Output " - Checking for NSIS installation . . ."
If (Test-Path "$($ini[$bitPaths]['NSISDir'])\NSIS.exe") {
    # Found NSIS, do nothing
    Write-Output " - NSIS Found . . ."
} Else {
    # NSIS not found, install
    Write-Output " - NSIS Not Found . . ."
    Write-Output " - Downloading $($ini['Prerequisites']['NSIS']) . . ."
    $file = "$($ini['Prerequisites']['NSIS'])"
    $url  = "$($ini['Settings']['SaltRepo'])/$file"
    $file = "$($ini['Settings']['DownloadDir'])\$file"
    DownloadFileWithProgress $url $file

    # Install NSIS
    Write-Output " - Installing $($ini['Prerequisites']['NSIS']) . . ."
    $file = "$($ini['Settings']['DownloadDir'])\$($ini['Prerequisites']['NSIS'])"
    $p    = Start-Process $file -ArgumentList '/S' -Wait -NoNewWindow -PassThru
}

#------------------------------------------------------------------------------
# Check for installation of Microsoft Visual C++ Compiler for Python 2.7
#------------------------------------------------------------------------------
Write-Output " - Checking for VC Compiler for Python 2.7 installation . . ."
If (Test-Path "$($ini[$bitPaths]['VCforPythonDir'])\vcvarsall.bat") {
    # Found Microsoft Visual C++ for Python2.7, do nothing
    Write-Output " - Microsoft Visual C++ for Python 2.7 Found . . ."
} Else {
    # Microsoft Visual C++ for Python2.7 not found, install
    Write-Output " - Microsoft Visual C++ for Python2.7 Not Found . . ."
    Write-Output " - Downloading $($ini['Prerequisites']['VCforPython']) . . ."
    $file = "$($ini['Prerequisites']['VCforPython'])"
    $url  = "$($ini['Settings']['SaltRepo'])/$file"
    $file = "$($ini['Settings']['DownloadDir'])\$file"
    DownloadFileWithProgress $url $file

    # Install Microsoft Visual C++ for Python2.7
    Write-Output " - Installing $($ini['Prerequisites']['VCforPython']) . . ."
    $file = "$($ini['Settings']['DownloadDir'])\$($ini['Prerequisites']['VCforPython'])"
    $p    = Start-Process msiexec.exe -ArgumentList "/i $file /qb ALLUSERS=1" -Wait -NoNewWindow -PassThru
}

#------------------------------------------------------------------------------
# Install Python
#------------------------------------------------------------------------------
Write-Output " - Checking for Python 2.7 installation . . ."
If (Test-Path "$($ini['Settings']['Python2Dir'])\python.exe") {
    # Found Python2.7, do nothing
    Write-Output " - Python 2.7 Found . . ."
} Else {
    Write-Output " - Downloading $($ini[$bitPrograms]['Python2']) . . ."
    $file = "$($ini[$bitPrograms]['Python2'])"
    $url  = "$($ini['Settings']['SaltRepo'])/$bitFolder/$file"
    $file = "$($ini['Settings']['DownloadDir'])\$bitFolder\$file"
    DownloadFileWithProgress $url $file

    Write-Output " - $script_name :: Installing $($ini[$bitPrograms]['Python2']) . . ."
    $p    = Start-Process msiexec -ArgumentList "/i $file /qb ADDLOCAL=DefaultFeature,SharedCRT,Extensions,pip_feature,PrependPath TARGETDIR=$($ini['Settings']['Python2Dir'])" -Wait -NoNewWindow -PassThru
}

#------------------------------------------------------------------------------
# Update Environment Variables
#------------------------------------------------------------------------------
Write-Output " - Updating Environment Variables . . ."
$Path = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
If (!($Path.ToLower().Contains("$($ini['Settings']['Scripts2Dir'])".ToLower()))) {
    $newPath  = "$($ini['Settings']['Scripts2Dir']);$Path"
    Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath
    $env:Path = $newPath
}

#==============================================================================
# Update PIP and SetupTools
#    caching depends on environmant variable SALT_PIP_LOCAL_CACHE
#==============================================================================
Write-Output " ----------------------------------------------------------------"
Write-Output " - $script_name :: Updating PIP and SetupTools . . ."
Write-Output " ----------------------------------------------------------------"
if ( ! [bool]$Env:SALT_PIP_LOCAL_CACHE) {
    Start_Process_and_test_exitcode "$($ini['Settings']['Python2Dir'])\python.exe" "-m pip --no-cache-dir install -r $($script_path)\req_pip.txt" "python pip"
} else {
    $p = New-Item $Env:SALT_PIP_LOCAL_CACHE -ItemType Directory -Force # Ensure directory exists
    if ( (Get-ChildItem $Env:SALT_PIP_LOCAL_CACHE | Measure-Object).Count -eq 0 ) {
        # folder empty
        Write-Output "    pip download from req_pip.txt into empty local cache SALT_REQ_PIP $Env:SALT_PIP_LOCAL_CACHE"
        Start_Process_and_test_exitcode "$($ini['Settings']['Python2Dir'])\python.exe"  "-m pip download --dest $Env:SALT_PIP_LOCAL_CACHE -r $($script_path)\req_pip.txt" "pip download"
    }
    Write-Output "    reading from local pip cache $Env:SALT_PIP_LOCAL_CACHE"
    Write-Output "    If a (new) ressource is missing, please delete all files in this cache, go online and repeat"
  Start_Process_and_test_exitcode "$($ini['Settings']['Python2Dir'])\python.exe" "-m pip install --no-index --find-links=$Env:SALT_PIP_LOCAL_CACHE -r $($script_path)\req_pip.txt" "pip install"
}

#==============================================================================
# Install pypi resources using pip
#    caching depends on environmant variable SALT_REQ_LOCAL_CACHE
#==============================================================================
Write-Output " ----------------------------------------------------------------"
Write-Output " - $script_name :: Installing pypi resources using pip . . ."
Write-Output " ----------------------------------------------------------------"
if ( ! [bool]$Env:SALT_REQ_LOCAL_CACHE) {
    Start_Process_and_test_exitcode "$($ini['Settings']['Scripts2Dir'])\pip.exe"  "--no-cache-dir install -r $($script_path)\req_2.txt" "pip install"
} else {
    if ( (Get-ChildItem $Env:SALT_REQ_LOCAL_CACHE | Measure-Object).Count -eq 0 ) {
        # folder empty
        Write-Output "    pip download from req_2.txt into empty local cache SALT_REQ $Env:SALT_REQ_LOCAL_CACHE"
        Start_Process_and_test_exitcode "$($ini['Settings']['Python2Dir'])\python.exe"  "-m pip download --dest $Env:SALT_REQ_LOCAL_CACHE -r $($script_path)\req_2.txt" "pip download"
    }
    Write-Output "    reading from local pip cache $Env:SALT_REQ_LOCAL_CACHE"
    Write-Output "    If a (new) ressource is missing, please delete all files in this cache, go online and repeat"
  Start_Process_and_test_exitcode "$($ini['Settings']['Python2Dir'])\python.exe" "-m pip install --no-index --find-links=$Env:SALT_REQ_LOCAL_CACHE -r $($script_path)\req_2.txt" "pip install"
}

#==============================================================================
# Install PyYAML with CLoader
# This has to be a compiled binary to get the CLoader
#==============================================================================
Write-Output " ----------------------------------------------------------------"
Write-Output " - $script_name :: Installing PyYAML . . ."
Write-Output " ----------------------------------------------------------------"
# Download
$file = "$($ini[$bitPrograms]['PyYAML2'])"
$url  = "$($ini['Settings']['SaltRepo'])/$bitFolder/$file"
$file = "$($ini['Settings']['DownloadDir'])\$bitFolder\$file"
DownloadFileWithProgress $url $file

# Install
Start_Process_and_test_exitcode "$($ini['Settings']['Scripts2Dir'])\easy_install.exe" "-Z $file " "easy_install PyYAML"

#==============================================================================
# Install PyCrypto from wheel file
#==============================================================================
Write-Output " ----------------------------------------------------------------"
Write-Output " - $script_name :: Installing PyCrypto . . ."
Write-Output " ----------------------------------------------------------------"
# Download
$file = "$($ini[$bitPrograms]['PyCrypto2'])"
$url  = "$($ini['Settings']['SaltRepo'])/$bitFolder/$file"
$file = "$($ini['Settings']['DownloadDir'])\$bitFolder\$file"
DownloadFileWithProgress $url $file

# Install
Start_Process_and_test_exitcode  "$($ini['Settings']['Scripts2Dir'])\pip.exe" "install --no-index --find-links=$($ini['Settings']['DownloadDir']) $file " "pip install PyCrypto"

#==============================================================================
# Copy DLLs to Python Directory
#==============================================================================
Write-Output " ----------------------------------------------------------------"
Write-Output "   - $script_name :: Copying DLLs . . ."
Write-Output " ----------------------------------------------------------------"
# Architecture Specific DLL's
ForEach($key in $ini[$bitDLLs].Keys) {
    If ($arrInstalled -notcontains $key) {
        Write-Output "   - $key . . ."
        $file = "$($ini[$bitDLLs][$key])"
        $url  = "$($ini['Settings']['SaltRepo'])/$bitFolder/$file"
        $file = "$($ini['Settings']['DownloadDir'])\$bitFolder\$file"
        DownloadFileWithProgress $url $file
        Copy-Item $file  -destination $($ini['Settings']['Python2Dir'])
    }
}

#------------------------------------------------------------------------------
# Script complete
#------------------------------------------------------------------------------
Write-Output "================================================================="
Write-Output " $script_name :: Salt Stack Dev Environment Script Complete"
Write-Output "================================================================="
Write-Output ""

If (-Not $Silent) {
    Write-Output "Press any key to continue ..."
    $p = $HOST.UI.RawUI.Flushinputbuffer()
    $p = $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

#------------------------------------------------------------------------------
# Remove the temporary download directory
#------------------------------------------------------------------------------
Write-Output " ----------------------------------------------------------------"
Write-Output " - $script_name :: Cleaning up downloaded files unless you use SALTREPO_LOCAL_CACHE"
Write-Output " ----------------------------------------------------------------"
Write-Output ""
if ( ! [bool]$Env:SALTREPO_LOCAL_CACHE ) {
    Remove-Item $($ini['Settings']['DownloadDir']) -Force -Recurse
}
