Param(
    [Parameter(Mandatory=$true)][string]$devstackIP,
    [string]$branchName='master',
    [string]$buildFor='openstack/nova'
)

$projectName = $buildFor.split('/')[-1]

#$virtualenv = "c:\OpenStack\virtualenv"
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
$pythonExec = "c:\Python27\python.exe"

$remoteLogs="\\"+$devstackIP+"\openstack\logs"
$remoteConfigs="\\"+$devstackIP+"\openstack\config"

. "$scriptdir\utils.ps1"

$hasProject = Test-Path $buildDir\$projectName
$hasNova = Test-Path $buildDir\nova
$hasNeutron = Test-Path $buildDir\neutron
$hasNeutronTemplate = Test-Path $neutronTemplate
$hasNovaTemplate = Test-Path $novaTemplate
$hasConfigDir = Test-Path $configDir
$hasBinDir = Test-Path $binDir
$hasMkisoFs = Test-Path $binDir\mkisofs.exe
$hasQemuImg = Test-Path $binDir\qemu-img.exe

$pip_conf_content = @"
[global]
index-url = http://dl.openstack.tld:8080/root/pypi/+simple/
[install]
trusted-host = dl.openstack.tld
find-links = 
    http://dl.openstack.tld/wheels
"@

$ErrorActionPreference = "SilentlyContinue"

# Do a selective teardown
Write-Host "Ensuring nova and neutron services are stopped."
Stop-Service -Name nova-compute -Force
Stop-Service -Name neutron-hyperv-agent -Force

Write-Host "Stopping any possible python processes left."
Stop-Process -Name python -Force

if (Get-Process -Name nova-compute){
    Throw "Nova is still running on this host"
}

if (Get-Process -Name neutron-hyperv-agent){
    Throw "Neutron is still running on this host"
}

if (Get-Process -Name python){
    Throw "Python processes still running on this host"
}

$ErrorActionPreference = "Stop"

if ($(Get-Service nova-compute).Status -ne "Stopped"){
    Throw "Nova service is still running"
}

if ($(Get-Service neutron-hyperv-agent).Status -ne "Stopped"){
    Throw "Neutron service is still running"
}

Write-Host "Cleaning up the config folder."
if ($hasConfigDir -eq $false) {
    mkdir $configDir
}else{
    Try
    {
        Remove-Item -Recurse -Force $configDir\*
    }
    Catch
    {
        Throw "Can not clean the config folder"
    }
}

if ($hasProject -eq $false){
    Throw "$projectName repository was not found. Please run gerrit-git-pref for this project first"
}

if ($hasBinDir -eq $false){
    mkdir $binDir
}

if (($hasMkisoFs -eq $false) -or ($hasQemuImg -eq $false)){
    Invoke-WebRequest -Uri "http://dl.openstack.tld/openstack_bin.zip" -OutFile "$bindir\openstack_bin.zip"
    if (Test-Path "C:\Program Files\7-Zip\7z.exe"){
        pushd $bindir
        & "C:\Program Files\7-Zip\7z.exe" x -y "$bindir\openstack_bin.zip"
        Remove-Item -Force "$bindir\openstack_bin.zip"
        popd
    } else {
        Throw "Required binary files (mkisofs, qemuimg etc.)  are missing"
    }
}

if ($hasNovaTemplate -eq $false){
    Throw "Nova template not found"
}

if ($hasNeutronTemplate -eq $false){
    Throw "Neutron template not found"
}

git config --global user.email "hyper-v_ci@microsoft.com"
git config --global user.name "Hyper-V CI"


if ($buildFor -eq "openstack/nova"){
    ExecRetry {
        GitClonePull "$buildDir\neutron" "https://github.com/openstack/neutron.git" $branchName
    }
    ExecRetry {
        GitClonePull "$buildDir\networking-hyperv" "https://github.com/stackforge/networking-hyperv.git" "master"
    }
}elseif ($buildFor -eq "openstack/neutron" -or $buildFor -eq "openstack/quantum"){
    ExecRetry {
        GitClonePull "$buildDir\nova" "https://github.com/openstack/nova.git" $branchName
    }
    ExecRetry {
        GitClonePull "$buildDir\networking-hyperv" "https://github.com/stackforge/networking-hyperv.git" "master"
    }
}elseif ($buildFor -eq "stackforge/networking-hyperv"){
    ExecRetry {
        GitClonePull "$buildDir\nova" "https://github.com/openstack/nova.git" $branchName
    }
    ExecRetry {
        GitClonePull "$buildDir\neutron" "https://github.com/openstack/neutron.git" $branchName
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

pushd \
if (Test-Path "C:\python27new.tar.gz")
{
    Remove-Item -Force "C:\python27new.tar.gz"
}
Invoke-WebRequest -Uri http://dl.openstack.tld/python27new.tar.gz -OutFile C:\python27new.tar.gz
if (Test-Path "C:\Python27")
{
    Remove-Item -Recurse -Force .\Python27
}
& C:\mingw-get\msys\1.0\bin\tar.exe -xvzf python27new.tar.gz
& easy_install pip
& pip install -U setuptools
& pip install -U wmi
& pip install -U pbr==0.11.0
popd

$hasPipConf = Test-Path "$env:APPDATA\pip"
if ($hasPipConf -eq $false){
    mkdir "$env:APPDATA\pip"
}
else 
{
    Remove-Item -Force "$env:APPDATA\pip\*"
}
Add-Content "$env:APPDATA\pip\pip.ini" $pip_conf_content


cp $templateDir\distutils.cfg C:\Python27\Lib\distutils\distutils.cfg

# Hack due to cicso patch problem:
#$missingPath="C:\Openstack\build\openstack\neutron\etc\neutron\plugins\cisco\cisco_cfg_agent.ini"
#if(!(Test-Path -Path $missingPath)){
#    new-item -Path $missingPath -Value ' ' –itemtype file
#}

ExecRetry {
    pushd C:\OpenStack\build\openstack\networking-hyperv
    & python setup.py install
    if ($LastExitCode) { Throw "Failed to install networking-hyperv from repo" }
    popd
}

ExecRetry {
    pushd C:\OpenStack\build\openstack\neutron
    & python setup.py install
    if ($LastExitCode) { Throw "Failed to install neutron from repo" }
    popd
}

ExecRetry {
    pushd C:\OpenStack\build\openstack\nova
    & python setup.py install
    if ($LastExitCode) { Throw "Failed to install nova fom repo" }
    popd
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

$hasNovaExec = Test-Path c:\Python27\Scripts\nova-compute.exe
if ($hasNovaExec -eq $false){
    Throw "No nova exe found"
}

$hasNeutronExec = Test-Path "c:\Python27\Scripts\neutron-hyperv-agent.exe"
if ($hasNeutronExec -eq $false){
    Throw "No neutron exe found"
}


Remove-Item -Recurse -Force "$remoteConfigs\$hostname\*"
Copy-Item -Recurse $configDir "$remoteConfigs\$hostname"

Write-Host "Starting the services"
Try
{
    Start-Service nova-compute
}
Catch
{
    Throw "Can not start the nova service"
}
Start-Sleep -s 5
Try
{
    Start-Service neutron-hyperv-agent
}
Catch
{
    Throw "Can not start neutron agent service"
}

Start-Sleep -s 30

if ((Get-Service nova-compute).Status -ne "Running")
{
    Write-Host 
    $novaJob = Start-Job -ScriptBlock {& c:\Python27\Scripts\nova-compute.exe --config-file C:\OpenStack\etc\nova.conf}
    Start-Sleep -s 30
    Receive-Job -job $novaJob
    Stop-Job -job $novaJob
    Receive-Job -job $novaJob
} 
else
{
    Write-Host "Nova service running ok"
}

if ((Get-Service neutron-hyperv-agent).Status -ne "Running")
{
    $neutronJob = Start-Job -ScriptBlock {& c:\Python27\Scripts\neutron-hyperv-agent.exe --config-file C:\OpenStack\etc\neutron_hyperv_agent.conf}
    Start-Sleep -s 30
    Receive-Job -job $neutronJob
    Stop-Job -job $neutronJob
    Receive-Job -job $neutronJob
}
else
{
    Write-Host "Neutron Hyper-V Agent Plugin running ok"
}
