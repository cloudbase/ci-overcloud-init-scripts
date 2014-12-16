Param(
    [Parameter(Mandatory=$true)][string]$devstackIP,
    [string]$branchName='master',
    [string]$buildFor='openstack/nova'
)

############################################################################
#  virtualenv and pip install must be run via cmd. There is a bug in the   #
#  activate.ps1 that actually installs packages in the system site package #
#  folder                                                                  #
############################################################################

$projectName = $buildFor.split('/')[-1]

$virtualenv = "c:\OpenStack\virtualenv"
$openstackDir = "C:\OpenStack"
$baseDir = "$openstackDir\devstack"
$scriptdir = "$baseDir\scripts"
$configDir = "C:\OpenStack\etc"
$templateDir = "$baseDir\templates"
$buildDir = "c:\OpenStack\build\openstack"
$binDir = "$openstackDir\bin"
$novaTemplate = "$templateDir\nova.conf"
$neutronTemplate = "$templateDir\neutron_hyperv_agent.conf"
$hostname = hostname

$remoteLogs="\\"+$devstackIP+"\openstack\logs"
$remoteConfigs="\\"+$devstackIP+"\openstack\config"

. "$scriptdir\utils.ps1"

$hasProject = Test-Path $buildDir\$projectName
$hasVirtualenv = Test-Path $virtualenv
$hasNova = Test-Path $buildDir\nova
$hasNeutron = Test-Path $buildDir\neutron
$hasNeutronTemplate = Test-Path $neutronTemplate
$hasNovaTemplate = Test-Path $novaTemplate
$hasConfigDir = Test-Path $configDir
$hasBinDir = Test-Path $binDir
$hasMkisoFs = Test-Path $binDir\mkisofs.exe
$hasQemuImg = Test-Path $binDir\qemu-img.exe
$hasLogDir = Test-Path $remoteLogs\$hostname
$hasRemoteConfigDir = Test-Path $remoteConfigs\$hostname

$ErrorActionPreference = "SilentlyContinue"

# Do a selective teardown
Stop-Service -Name nova-compute -Force -ErrorAction $ErrorActionPreference
Stop-Service -Name neutron-hyperv-agent -Force -ErrorAction $ErrorActionPreference

Stop-Process -Name python -Force -ErrorAction $ErrorActionPreference

$ErrorActionPreference = "Stop"

if ($hasVirtualenv -eq true){
    Try
    {
        Remove-Item -Recurse -Force $virtualenv -ErrorAction $ErrorActionPreference
    }
    Catch
    {
        Throw "Vrtualenv already exists. Environment not clean."
    }
}

if ($hasConfigDir -eq $false) {
    mkdir $configDir
}else{
    Try
    {
        Remove-Item -Recurse -Force $configDir\* -ErrorAction $ErrorActionPreference
    }
    Catch
    {
        Throw "Can not clean the config folder"
    }
}

Try
{
    $novaIsRunning = Get-Process -Name nova-compute -ErrorAction $ErrorActionPreference
}
Catch
{
    Throw "Nova is still running on this host"
}

Try
{
    $neutronIsRunning = Get-Process -Name neutron-hyperv-agent -ErrorAction $ErrorActionPreference
}
Catch
{
    Throw "Neutron is still running on this host"
}

if ($hasProject -eq $false){
    Throw "$projectName repository was not found. Please run gerrit-git-pref for this project first"
}

if ($hasBinDir -eq $false){
    mkdir $binDir
}

if (($hasMkisoFs -eq $false) -or ($hasQemuImg -eq $false)){
    Throw "Required binary files (mkisofs, qemuimg etc.)  are missing"
}

if ($hasNovaTemplate -eq $false){
    Throw "Nova template not found"
}

if ($hasNeutronTemplate -eq $false){
    Throw "Neutron template not found"
}

if ($hasLogDir -eq $false){
    mkdir $remoteLogs\$hostname
}

if ($hasRemoteConfigDir -eq $false){
    mkdir $remoteConfigs\$hostname
}

if ($buildFor -eq "openstack/nova"){
    ExecRetry {
        GitClonePull "$buildDir\neutron" "https://github.com/openstack/neutron.git" $branchName
    }
}elseif ($buildFor -eq "openstack/neutron"){
    ExecRetry {
        GitClonePull "$buildDir\nova" "https://github.com/openstack/nova.git" $branchName
    }
}else{
    Throw "Cannot build for project: $buildFor"
}

cmd.exe /C virtualenv --system-site-packages $virtualenv

if ($? -eq $false){
    Throw "Failed to create virtualenv"
}

cp $templateDir\distutils.cfg $virtualenv\Lib\distutils\distutils.cfg

# Hack due to cicso patch problem:
$missingPath="C:\Openstack\build\openstack\neutron\etc\neutron\plugins\cisco\cisco_cfg_agent.ini"
if(!(Test-Path -Path $missingPath)){
    new-item -Path $missingPath -Value ' ' –itemtype file
}

ExecRetry {
    cmd.exe /C $scriptdir\install_openstack_from_repo.bat C:\OpenStack\build\openstack\neutron
    if ($LastExitCode) { Throw "Failed to install neutron from repo" }
}

ExecRetry {
    cmd.exe /C $scriptdir\install_openstack_from_repo.bat C:\OpenStack\build\openstack\nova
    if ($LastExitCode) { Throw "Failed to install nova fom repo" }
}

Try
{
    Copy-Item -Recurse $buildDir\nova\etc\nova\rootwrap.d $configDir
    Copy-Item -Recurse $buildDir\nova\etc\nova\api-paste.ini $configDir
    Copy-Item -Recurse $buildDir\nova\etc\nova\cells.json $configDir
    Copy-Item -Recurse $buildDir\nova\etc\nova\policy.json $configDir
    Copy-Item -Recurse $buildDir\nova\etc\nova\rootwrap.conf $configDir    
    Copy-Item "$templateDir\interfaces.template" "$configDir\"
}
Catch
{
    Throw "Failed copying the default config files"
}

Try
{
    $novaConfig = (gc "$templateDir\nova.conf").replace('[DEVSTACK_IP]', "$devstackIP").Replace('[LOGDIR]', "$($remoteLogs)\$($hostname)")
    $neutronConfig = (gc "$templateDir\neutron_hyperv_agent.conf").replace('[DEVSTACK_IP]', "$devstackIP").Replace('[LOGDIR]', "$($remoteLogs)\$($hostname)")

    Set-Content C:\OpenStack\etc\nova.conf $novaConfig
    if ($? -eq $false){
        Throw "Error writting $templateDir\nova.conf"
    }

    Set-Content C:\OpenStack\etc\neutron_hyperv_agent.conf $neutronConfig
    if ($? -eq $false){
        Throw "Error writting neutron_hyperv_agent.conf"
    }
}
Catch
{
    Throw "Error generating the nova and neutron config files from template."
}

$hasNovaExec = Test-Path c:\OpenStack\virtualenv\Scripts\nova-compute.exe
if ($hasNovaExec -eq $false){
    Throw "No nova exe found"
}else{
    $novaExec = "c:\OpenStack\virtualenv\Scripts\nova-compute.exe"
}

$hasNeutronExec = Test-Path "c:\OpenStack\virtualenv\Scripts\neutron-hyperv-agent.exe"
if ($hasNeutronExec -eq $false){
    Throw "No neutron exe found"
}else{
    $neutronExe = "c:\OpenStack\virtualenv\Scripts\neutron-hyperv-agent.exe"
}

Copy-Item -Recurse $configDir "$remoteConfigs\$hostname"

Try
{
    Start-Service nova-compute -ErrorAction $ErrorActionPreference
}
Catch
{
    Throw "Can not start the nova service"
}
Start-Sleep -s 15
Try
{
    Start-Service neutron-hyperv-agent -ErrorAction $ErrorActionPreference
}
Catch
{
    Throw "Can not start neutron agent service"
}
