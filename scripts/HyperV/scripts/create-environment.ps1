Param(
	[Parameter(Mandatory=$true)]
	[string]$devstackIP
)

#################################################################
#  virtualenv and pip install must be run via cmd. There is a bug in the           ##
#  activate.ps1 that actually installs packages in the system site package    ##
#  folder                                                                                                   ##
#################################################################

$virtualenv = "c:\OpenStack\virtualenv"
$baseDir = "C:\OpenStack\devstack"
$scriptdir = "$baseDir\scripts"
$configDir = "C:\OpenStack\etc"
$templateDir = "$baseDir\templates"
$buildDir = "c:\OpenStack\build\openstack"
$novaTemplate = "$templateDir\nova.conf"
$neutronTemplate = "$templateDir\neutron_hyperv_agent.conf"

$hasVirtualenv = Test-Path $virtualenv
$hasNova = Test-Path $buildDir\nova
$hasNeutron = Test-Path $buildDir\neutron
$hasNeutronTemplate = Test-Path $neutronTemplate
$hasNovaTemplate = Test-Path $novaTemplate

$novaIsRunning = Get-Job -Name nova -erroraction 'silentlycontinue'
$neutronIsRunning = Get-Job -Name nova -erroraction 'silentlycontinue'

if ($novaIsRunning -or $neutronIsRunning){
	Throw "Nova or Neutron is still running on this host"
}

if ($hasVirtualenv -eq $true){
	Throw "Vrtualenv already exists. Environment not clean."
}

if ($hasNova -eq $false){
	Throw "Nova repository was not found. Please run gerrit-git-pref for this project first"
}

if ($hasNovaTemplate -eq $false){
	Throw "Nova template not found"
}

if ($hasNeutron -eq $false){
	git clone https://github.com/openstack/neutron.git $buildDir\neutron > $null
	if ($? -eq $false){
		Throw "Failed to clone neutron repo"
	}
}else{
	pushd $buildDir\neutron
	git pull origin master > $null
	if ($? -eq $false){
		Throw "Failed to update neutron repo"
	}
	popd
}

# !!!!!!!REMOVE THIS WHEN FIX FOR SYMLINK FOUND!!!!!!!!
pushd $buildDir\neutron
git checkout 7be409e6d87ac140e8eec2a09cc3050f1448e35f > $null 2>&1
popd
################################

if ($hasNeutronTemplate -eq $false){
	Throw "Neutron template not found"
}

cmd.exe /C virtualenv --system-site-packages $virtualenv > $null

if ($? -eq $false){
	Throw "Failed to create virtualenv"
}

cmd.exe /C $scriptdir\install_openstack_from_repo.bat c:\OpenStack\build\openstack\neutron > $null
if ($? -eq $false){
	Throw "Failed to install Neutron"
}

cmd.exe /C $scriptdir\install_openstack_from_repo.bat c:\OpenStack\build\openstack\nova > $null
if ($? -eq $false){
	Throw "Failed to install Nova"
}

$novaConfig = (gc "$templateDir\nova.conf").replace('[DEVSTACK_IP]', "$devstackIP")
$neutronConfig = (gc "$templateDir\neutron_hyperv_agent.conf").replace('[DEVSTACK_IP]', "$devstackIP")

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

Start-Job -Name "nova" {cmd.exe /C C:\OpenStack\devstack\scripts\run_openstack_service.bat c:\OpenStack\virtualenv\Scripts\nova-compute.exe C:\Openstack\etc\nova.conf} > $null
Start-Job -Name "neutron" {cmd.exe /C C:\OpenStack\devstack\scripts\run_openstack_service.bat c:\OpenStack\virtualenv\Scripts\neutron-hyperv-agent.exe C:\Openstack\etc\neutron_hyperv_agent.conf} > $null
