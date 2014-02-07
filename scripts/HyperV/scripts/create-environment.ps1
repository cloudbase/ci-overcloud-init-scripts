Param(
    [Parameter(Mandatory=$true)][string]$devstackIP,
    [string]$branchName='master',
    [string]$buildFor='openstack/nova',
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

# Do a selective teardown
Stop-Process -Name nova-compute -Force -ErrorAction SilentlyContinue
Stop-Process -Name neutron-hyperv-agent -Force -ErrorAction SilentlyContinue
Stop-Process -Name quantum-hyperv-agent -Force -ErrorAction SilentlyContinue
Stop-Process -Name python -Force -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $virtualenv -ErrorAction SilentlyContinue

if ($hasConfigDir -eq $false) {
    mkdir $configDir
}

$novaIsRunning = Get-Process -Name nova-compute -erroraction 'silentlycontinue'
$neutronIsRunning = Get-Process -Name neutron-hyperv-agent -erroraction 'silentlycontinue'
$quantumIsRunning = Get-Process -Name quantum-hyperv-agent -erroraction 'silentlycontinue'

function exec_with_retry([string]$cmd, [int]$retry, [int]$interval=0){
    $c = 0
    $success = $false
    do
    {
        $newCmd = "$cmd; if(`$? -eq `$false){return `$false}else{return `$true}"
        $scriptblock = $ExecutionContext.InvokeCommand.NewScriptBlock($newCmd)
        $ret = Invoke-Command -ScriptBlock $scriptblock
        echo $ret
        if ($ret){
            $success = $true
            break
        }
        Start-Sleep $interval
        $c+=1
    } while ($c -lt $retry)
    if ($success -eq $false){
        Throw $error[0]
    }
}

function fech_master_repo($project="nova"){
    $testProjectExists = Test-Path $buildDir\$project
    if ($testProjectExists -eq $false){
        exec_with_retry -cmd "git clone https://github.com/openstack/$project.git $buildDir\$project" -retry 5 -interval 5
        if ($branchName){
            pushd $buildDir\$project
            git checkout "$branchName"
            popd
        }
        if ($? -eq $false){
            Throw "Failed to clone $project repo"
        }
    }else{
        pushd $buildDir\$project
        if ($branchName){
            git fetch
            git checkout "$branchName"
        }
        exec_with_retry -cmd "git pull" -retry 5 -interval 5 -discardOutput
        popd
    }
}

if ($hasProject -eq $false){
    Throw "$projectName repository was not found. Please run gerrit-git-pref for this project first"
}

if ($hasBinDir -eq $false){
    mkdir $binDir
}

if (($hasMkisoFs -eq $false) -or ($hasQemuImg -eq $false)){
    exec_with_retry "Invoke-WebRequest -Uri http://us.samfira.com/bin.zip -OutFile `$env:TEMP\bin.zip"
    & 'C:\Program Files\7-Zip\7z.exe' x $env:TEMP\bin.zip -o"$openstackDir\" -y
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

if ($buildFor == "openstack/nova"){
    fech_master_repo neutron
}elif ($buildFor == "openstack/neutron" -or $buildFor == "openstack/quantum"){
    fech_master_repo nova
}else{
    Throw "Cannot build for project: $buildFor"
}


# Mount devstack samba. Used for log storage
exec_with_retry "New-SmbMapping -RemotePath \\$devstackIP\openstack -LocalPath u:"  -retry 5 -interval 5

$hasLogDir = Test-Path U:\$hostname
if ($hasLogDir -eq $false){
    mkdir U:\$hostname
}

cmd.exe /C virtualenv --system-site-packages $virtualenv > $null

if ($? -eq $false){
    Throw "Failed to create virtualenv"
}

cp $templateDir\distutils.cfg $virtualenv\Lib\distutils\distutils.cfg

exec_with_retry "cmd.exe /C $scriptdir\install_openstack_from_repo.bat c:\OpenStack\build\openstack\neutron"
exec_with_retry "cmd.exe /C $scriptdir\install_openstack_from_repo.bat c:\OpenStack\build\openstack\nova"

$novaConfig = (gc "$templateDir\nova.conf").replace('[DEVSTACK_IP]', "$devstackIP").Replace('[LOGDIR]', "U:\$hostname")
$neutronConfig = (gc "$templateDir\neutron_hyperv_agent.conf").replace('[DEVSTACK_IP]', "$devstackIP").Replace('[LOGDIR]', "U:\$hostname")

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

if (Test-Path c:\OpenStack\virtualenv\Scripts\nova-compute.exe -eq $false){
    $novaExec = "C:\Python27\python.exe c:\OpenStack\virtualenv\Scripts\nova-compute-script.py"
}else{
    $novaExec = "c:\OpenStack\virtualenv\Scripts\nova-compute.exe"
}

$hasNeutronExec = Test-Path c:\OpenStack\virtualenv\Scripts\neutron-hyperv-agent.exe
$hasQuantumExec = Test-Path c:\OpenStack\virtualenv\Scripts\quantum-hyperv-agent.exe
if ($hasNeutronExec -eq $false){
    if ($hasQuantumExec -eq $false){
        Throw "No neutron exe found"
    }
    $neutronExe = "c:\OpenStack\virtualenv\Scripts\quantum-hyperv-agent.exe"
}else{
    $neutronExe = "c:\OpenStack\virtualenv\Scripts\neutron-hyperv-agent.exe"
}


Invoke-WMIMethod -path win32_process -name create -argumentlist "C:\OpenStack\devstack\scripts\run_openstack_service.bat c:\OpenStack\virtualenv\Scripts\nova-compute.exe C:\Openstack\etc\nova.conf U:\$hostname\nova-console.log"
Invoke-WMIMethod -path win32_process -name create -argumentlist "C:\OpenStack\devstack\scripts\run_openstack_service.bat $neutronExe C:\Openstack\etc\neutron_hyperv_agent.conf U:\$hostname\neutron-hyperv-agent-console.log"
