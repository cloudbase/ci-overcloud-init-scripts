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
$rabbitUser = "stackrabbit"

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

$ErrorActionPreference = "SilentlyContinue"

# Do a selective teardown
Stop-Process -Name nova-compute -Force -ErrorAction $ErrorActionPreference
Stop-Process -Name neutron-hyperv-agent -Force -ErrorAction $ErrorActionPreference
Stop-Process -Name quantum-hyperv-agent -Force -ErrorAction $ErrorActionPreference
Stop-Process -Name python -Force -ErrorAction $ErrorActionPreference
Remove-Item -Recurse -Force $virtualenv -ErrorAction $ErrorActionPreference

if ($hasConfigDir -eq $false) {
    mkdir $configDir
}

$novaIsRunning = Get-Process -Name nova-compute -ErrorAction $ErrorActionPreference
$neutronIsRunning = Get-Process -Name neutron-hyperv-agent -ErrorAction $ErrorActionPreference
$quantumIsRunning = Get-Process -Name quantum-hyperv-agent -ErrorAction $ErrorActionPreference

if ($hasProject -eq $false){
    Throw "$projectName repository was not found. Please run gerrit-git-pref for this project first"
}

if ($hasBinDir -eq $false){
    mkdir $binDir
}

if (($hasMkisoFs -eq $false) -or ($hasQemuImg -eq $false)){
    Throw "Required binary files (mkisofs, qemuimg etc.)  are missing"
}

if ($novaIsRunning -or $neutronIsRunning -or $quantumIsRunning){
    Throw "Nova or Neutron is still running on this host"
}

if ($hasVirtualenv -eq $true){
    Throw "Vrtualenv already exists. Environment not clean."
}

if ($hasNovaTemplate -eq $false){
    Throw "Nova template not found"
}

if ($hasNeutronTemplate -eq $false){
    Throw "Neutron template not found"
}

if ($buildFor -eq "openstack/nova"){
    ExecRetry {
        GitClonePull "$buildDir\neutron" "https://github.com/openstack/neutron.git" $branchName
    }
}elseif ($buildFor -eq "openstack/neutron" -or $buildFor -eq "openstack/quantum"){
    ExecRetry {
        GitClonePull "$buildDir\nova" "https://github.com/openstack/nova.git" $branchName
    }
}else{
    Throw "Cannot build for project: $buildFor"
}

$hasLogDir = Test-Path $remoteLogs\$hostname
if ($hasLogDir -eq $false){
    mkdir $remoteLogs\$hostname
}

$hasConfigDir = Test-Path $remoteConfigs\$hostname
if ($hasConfigDir -eq $false){
    mkdir $remoteConfigs\$hostname
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

if (($branchName.ToLower().CompareTo($('stable/juno').ToLower()) -eq 0) -or ($branchName.ToLower().CompareTo($('stable/icehouse').ToLower()) -eq 0)) {
    $rabbitUser = "guest"
}

$novaConfig = (gc "$templateDir\nova.conf").replace('[DEVSTACK_IP]', "$devstackIP").Replace('[LOGDIR]', "$($remoteLogs)\$($hostname)").Replace('[RABBITUSER]', $rabbitUser)
$neutronConfig = (gc "$templateDir\neutron_hyperv_agent.conf").replace('[DEVSTACK_IP]', "$devstackIP").Replace('[LOGDIR]', "$($remoteLogs)\$($hostname)").Replace('[RABBITUSER]', $rabbitUser)

Set-Content C:\OpenStack\etc\nova.conf $novaConfig
if ($? -eq $false){
    Throw "Error writting $templateDir\nova.conf"
}

Set-Content C:\OpenStack\etc\neutron_hyperv_agent.conf $neutronConfig
if ($? -eq $false){
    Throw "Error writting neutron_hyperv_agent.conf"
}

cp "$templateDir\policy.json" "$configDir\" 
cp "$templateDir\interfaces.template" "$configDir\"

$hasNovaExec = Test-Path c:\OpenStack\virtualenv\Scripts\nova-compute.exe
if ($hasNovaExec -eq $false){
    $novaExec = "C:\Python27\python.exe c:\OpenStack\virtualenv\Scripts\nova-compute-script.py"
}else{
    $novaExec = "c:\OpenStack\virtualenv\Scripts\nova-compute.exe"
}

$hasNeutronExec = Test-Path "c:\OpenStack\virtualenv\Scripts\neutron-hyperv-agent.exe"
$hasQuantumExec = Test-Path "c:\OpenStack\virtualenv\Scripts\quantum-hyperv-agent.exe"
if ($hasNeutronExec -eq $false){
    if ($hasQuantumExec -eq $false){
        Throw "No neutron exe found"
    }
    $neutronExe = "c:\OpenStack\virtualenv\Scripts\quantum-hyperv-agent.exe"
}else{
    $neutronExe = "c:\OpenStack\virtualenv\Scripts\neutron-hyperv-agent.exe"
}

Copy-Item -Recurse $configDir "$remoteConfigs\$hostname"

Invoke-WMIMethod -path win32_process -name create -argumentlist "C:\OpenStack\devstack\scripts\run_openstack_service.bat c:\OpenStack\virtualenv\Scripts\nova-compute.exe C:\Openstack\etc\nova.conf $remoteLogs\$hostname\nova-console.log"
Start-Sleep -s 15
Invoke-WMIMethod -path win32_process -name create -argumentlist "C:\OpenStack\devstack\scripts\run_openstack_service.bat $neutronExe C:\Openstack\etc\neutron_hyperv_agent.conf $remoteLogs\$hostname\neutron-hyperv-agent-console.log"
